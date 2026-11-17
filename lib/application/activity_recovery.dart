part of 'activity_calendar.dart';

typedef RecoveryConflict = ({
  String restoredId,
  String restoredTitle,
  DateTime restoredStart,
  DateTime restoredEnd,
  String existingId,
  String existingTitle,
  DateTime existingStart,
  DateTime existingEnd,
  ScheduleWarning warning,
});

typedef RecoveryCheck = ({
  Set<RecoveryConflict> conflicts,
  Set<String> removedCategories,
  String displayZone,
  String deviceZone,
  bool checksRecurring,
});

extension ActivityRecovery on ActivityCalendar {
  /// Runs inside the caller's transaction. The caller either accepts the
  /// checked result or throws to roll back the entire recovery.
  Future<RecoveryCheck> checkRecovery(
    PlannerData data,
    TrashEntry entry, {
    DateTime? moveTo,
  }) async {
    final before = await _recoveryCalendar(data);
    final removed = await data.restore(
      entry.id,
      expectedRevision: entry.metadata.revision,
    );
    if (moveTo != null) await _moveRestoredEvent(data, entry, moveTo);
    final after = await _recoveryCalendar(data);
    final conflicts = await _restoredConflicts(data, before, after);
    return (
      conflicts: Set.unmodifiable(conflicts.$1),
      removedCategories: Set.unmodifiable(removed),
      displayZone: zones.displayId,
      deviceZone: zones.deviceId,
      checksRecurring: conflicts.$2,
    );
  }

  Future<_RecoveryCalendar> _recoveryCalendar(PlannerData data) async => (
    events: await _snapshot(data),
    sessions: {for (final row in await data.workSessions.all()) row.id: row},
    routines: {
      for (final row in await data.routineOccurrences.all()) row.id: row,
    },
  );

  Future<void> _moveRestoredEvent(
    PlannerData data,
    TrashEntry entry,
    DateTime day,
  ) async {
    if (entry.target.kind != RecordKind.eventOccurrence) {
      throw TrashProblem.invalidSchedule;
    }
    final event = await data.events.find(entry.target.id);
    final logs = await data.timeLogs.all();
    if (event == null ||
        !canMoveRecoveredEvent(
          event,
          hasLogs: logs.any((log) => log.target.id == event.id),
        )) {
      throw TrashProblem.invalidSchedule;
    }
    final info = event.schedule.start;
    final original = _project(event);
    final wall = zones.wall(original.start, zones.displayId);
    final toDay = civilDate(day);
    final newStart = zones.instant(
      toDay.add(wall.difference(civilDate(wall))),
      zones.displayId,
    );
    if (!newStart.isAfter(now())) throw TrashProblem.invalidSchedule;
    final newEnd = newStart.add(original.end.difference(original.start));
    final zone = info.mode == TimeMode.localWallTime
        ? zones.deviceId
        : info.zoneId;
    ZonedTime at(DateTime instant) => ZonedTime(
      instant: instant,
      zoneId: zone,
      mode: info.mode,
      localWallTime: zones
          .wall(instant, zone)
          .toIso8601String()
          .replaceFirst('Z', ''),
    );
    await data.events.save(
      _copyOccurrence(
        event,
        schedule: ScheduledInterval(at(newStart), at(newEnd)),
        override: event.seriesId == null ? null : true,
      ),
    );
  }

  Future<(Set<RecoveryConflict>, bool)> _restoredConflicts(
    PlannerData data,
    _RecoveryCalendar before,
    _RecoveryCalendar after,
  ) async {
    final current = now().toUtc();
    final added = <String, SchedulingSlot>{};
    void add(String id, DateTime start, DateTime end) {
      if (end.isAfter(current)) added[id] = (start: start, end: end);
    }

    for (final row in after.events.active.values) {
      if (before.events.active.containsKey(row.id) ||
          row.status != ActivityStatus.planned) {
        continue;
      }
      final event = _project(row);
      if (event.blocks) add(event.id, event.start, event.end);
    }
    for (final row in after.sessions.values) {
      if (before.sessions.containsKey(row.id) ||
          row.status != ActivityStatus.planned) {
        continue;
      }
      final slot = _effectiveRestoredInterval(row.schedule);
      add(row.id, slot.start.instant, slot.end.instant);
    }
    for (final row in after.routines.values) {
      if (before.routines.containsKey(row.id) ||
          row.status != ActivityStatus.planned ||
          row.schedule == null) {
        continue;
      }
      final slot = _effectiveRestoredInterval(row.schedule!);
      add(row.id, slot.start.instant, slot.end.instant);
    }
    final recurring = _recoveredSeriesWindows(before, after, current);
    final ranges = [...added.values, ...recurring.values]
      ..sort((a, b) => a.start.compareTo(b.start));
    final merged = <SchedulingSlot>[];
    for (final range in ranges) {
      final previous = merged.lastOrNull;
      if (previous == null || range.start.isAfter(previous.end)) {
        merged.add(range);
      } else if (range.end.isAfter(previous.end)) {
        merged[merged.length - 1] = (start: previous.start, end: range.end);
      }
    }

    final conflicts = <RecoveryConflict>{};
    final reviewedPairs = <(String, String)>{};
    String? routineLink(_Entry row) =>
        row.routineLink ?? after.sessions[row.id]?.routineOccurrenceId;
    final fallback = profile?.defaultBuffer ?? Duration.zero;
    for (final span in merged) {
      final active = (await _paddedEntries(
        data,
        after.events,
        span.start,
        span.end,
        fallback,
      )).where((row) => row.blocks).toList();
      for (final row in active) {
        final window = recurring[row.event?.seriesId];
        final generated =
            window != null &&
            !after.events.active.containsKey(row.id) &&
            !row.start.isBefore(window.start) &&
            row.start.isBefore(window.end);
        if (!added.containsKey(row.id) && !generated) continue;
        for (final other in active) {
          final sameRoutine =
              routineLink(row) != null &&
              routineLink(row) == routineLink(other);
          if (row.id == other.id || sameRoutine) continue;
          if (!overlapsSlot(
            row.busy.slot,
            bufferedSlot(other.busy, before: row.before, after: row.after),
          )) {
            continue;
          }
          if (reviewedPairs.contains((other.id, row.id)) ||
              !reviewedPairs.add((row.id, other.id))) {
            continue;
          }
          conflicts.add((
            restoredId: row.id,
            restoredTitle: row.title,
            restoredStart: zones.wall(row.start, zones.displayId),
            restoredEnd: zones.wall(row.end, zones.displayId),
            existingId: other.id,
            existingTitle: other.title,
            existingStart: zones.wall(other.start, zones.displayId),
            existingEnd: zones.wall(other.end, zones.displayId),
            warning: overlapsSlot(row.busy.slot, other.busy.slot)
                ? ScheduleWarning.overlap
                : ScheduleWarning.buffer,
          ));
        }
      }
    }
    return (conflicts, recurring.isNotEmpty);
  }

  ScheduledInterval _effectiveRestoredInterval(ScheduledInterval interval) =>
      interval.start.mode == TimeMode.originalZone
      ? interval
      : zones.interval(
          DateTime.parse(interval.start.localWallTime!),
          DateTime.parse(interval.end.localWallTime!),
          zones.deviceId,
          TimeMode.localWallTime,
        );

  Map<String, SchedulingSlot> _recoveredSeriesWindows(
    _RecoveryCalendar before,
    _RecoveryCalendar after,
    DateTime current,
  ) {
    final result = <String, SchedulingSlot>{};
    final materialized = {
      for (final event in after.events.all)
        if (event.seriesId != null) (event.seriesId!, event.recurrenceKey),
    };
    for (final series in after.events.series.values) {
      if (series.template == null) continue;
      final old = before.events.series[series.id];
      final template = _SeriesTemplate.decode(series.template!);
      final linked = template.routineOccurrenceId;
      if (linked != null && !after.routines.containsKey(linked)) continue;
      final newlyVisible =
          old == null ||
          (linked != null && !before.routines.containsKey(linked));
      if (!newlyVisible && old.endsBefore?.value == series.endsBefore?.value) {
        continue;
      }
      final cutoff = series.endsBefore == null
          ? DateTime.utc(10000)
          : DateTime.parse(series.endsBefore!.value);
      final zone = template.availability != EventAvailability.timed
          ? zones.displayId
          : series.timeMode == TimeMode.originalZone
          ? series.zoneId
          : zones.deviceId;
      final span = civilDate(
        template.end,
      ).difference(civilDate(template.start)).inDays;
      final localNow = civilDate(
        zones.wall(current, zone),
      ).subtract(Duration(days: span));
      final previousEnd = old?.endsBefore;
      final restoredFrom = newlyVisible || previousEnd == null
          ? localNow
          : DateTime.parse(previousEnd.value);
      final from = restoredFrom.isAfter(localNow) ? restoredFrom : localNow;
      final rule = EventRecurrence.decode(series.recurrenceRule);
      for (final day in rule.dates(template.start, from, cutoff)) {
        final key = civilKey(day);
        if (template.excluded.contains(key) ||
            materialized.contains((series.id, key))) {
          continue;
        }
        final row = _project(template.occurrence(series, day, zones));
        if (!row.blocks || !row.end.isAfter(current)) continue;
        final date = civilDate(
          zones.wall(row.start, zones.displayId),
        ).add(const Duration(days: ActivityCalendar.conflictHorizonDays));
        result[series.id] = (
          start: row.start,
          end: zones.instant(date, zones.displayId),
        );
        break;
      }
    }
    return result;
  }
}

typedef _RecoveryCalendar = ({
  _Snapshot events,
  Map<String, WorkSession> sessions,
  Map<String, RoutineOccurrence> routines,
});

bool canMoveRecoveredEvent(EventOccurrence event, {required bool hasLogs}) =>
    event.status == ActivityStatus.planned &&
    event.availability == EventAvailability.timed &&
    !hasLogs;
