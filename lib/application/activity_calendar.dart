import 'dart:convert';
import 'dart:math' as math;

import 'package:routina/application/calendar_zones.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';
import 'package:routina/domain/productivity.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/domain/scheduling_engine.dart';

typedef ReminderCalendarItem = ({
  String id,
  String title,
  CalendarEntryKind kind,
  ActivityStatus status,
  String obligationId,
  DateTime start,
  DateTime end,
  bool allDay,
  bool deviceTime,
  List<String> reminders,
});

typedef CalendarConflict = ({
  String key,
  String title,
  DateTime until,
  bool deviceTime,
});

class ActivityCalendar {
  ActivityCalendar(
    this.store,
    this.zones, {
    required this.now,
    this.profile,
    this.categories = const [],
  });

  final PlannerStore store;
  final CalendarZones zones;
  final DateTime Function() now;
  final PreviewProfile? profile;
  final List<Category> categories;

  static const conflictHorizonDays = 90;

  /// Shares the recurrence, exception, tombstone and zone projection used
  /// by the agenda. Reminder times stay in UTC across repeated wall hours.
  Future<({List<ReminderCalendarItem> items, List<CalendarConflict> conflicts})>
  reminderCalendar(PlannerData data, DateTime from, DateTime until) async {
    final rows = await _paddedEntries(
      data,
      await _snapshot(data),
      from,
      until,
      Duration.zero,
    );
    final busy = rows.where((row) => row.blocks).toList()
      ..sort((a, b) {
        final start = a.start.compareTo(b.start);
        return start == 0 ? a.id.compareTo(b.id) : start;
      });
    final conflicts = <CalendarConflict>[];
    final current = now().toUtc();
    final largestBefore = busy.fold(
      Duration.zero,
      (duration, row) => row.before > duration ? row.before : duration,
    );
    for (final (i, left) in busy.indexed) {
      final cutoff = left.end.add(left.after + largestBefore);
      if (!cutoff.isAfter(current)) continue;
      for (
        var j = i + 1;
        j < busy.length && busy[j].start.isBefore(cutoff);
        j++
      ) {
        final right = busy[j];
        final leftPending =
            left.end.isAfter(current) && left.status == ActivityStatus.planned;
        final rightPending =
            right.end.isAfter(current) &&
            right.status == ActivityStatus.planned;
        if ((!leftPending && !rightPending) ||
            (left.routineLink != null &&
                left.routineLink == right.routineLink) ||
            !overlapsSlot(
              left.busy.slot,
              bufferedSlot(right.busy, before: left.before, after: left.after),
            )) {
          continue;
        }
        final until =
            !rightPending || (leftPending && left.end.isBefore(right.end))
            ? left.end
            : right.end;
        conflicts.add((
          key:
              'conflict:${left.id}:${left.start.millisecondsSinceEpoch}:'
              '${left.end.millisecondsSinceEpoch}:${right.id}:'
              '${right.start.millisecondsSinceEpoch}:${right.end.millisecondsSinceEpoch}',
          title: '${left.title} · ${right.title}',
          until: until,
          deviceTime: left.deviceTime || right.deviceTime,
        ));
      }
    }
    return (
      items: [
        for (final row in rows)
          if (row.start.isBefore(until) && row.end.isAfter(from))
            (
              id: row.id,
              title: row.title,
              status: row.status!,
              kind: row.other?.kind ?? CalendarEntryKind.event,
              obligationId:
                  row.other?.obligationId ?? row.routineLink ?? row.id,
              start: row.start,
              end: row.end,
              allDay: row.allDay,
              deviceTime: row.deviceTime,
              reminders: row.event?.details.reminders ?? const <String>[],
            ),
      ],
      conflicts: conflicts,
    );
  }

  Future<List<PreviewEvent>> read(DateTime from, DateTime until) async {
    if (!civilTime(from).isBefore(civilTime(until))) {
      throw ArgumentError('Invalid calendar range');
    }
    final snapshot = await _snapshot(store);
    final source = await _entries(
      store,
      snapshot,
      civilTime(from),
      civilTime(until),
    );
    return _presentAgenda(store, snapshot, source);
  }

  Future<
    ({
      List<PreviewEvent> agenda,
      ProductivitySummary productivity,
      PreviewEvent? next,
    })
  >
  readHome(int previousDays) => store.transaction((data) async {
    final calendar = await withLatestProfile(data);
    final current = now().toUtc();
    final day = civilDate(
      calendar.zones.wall(current, calendar.zones.displayId),
    );
    final snapshot = await calendar._snapshot(data);
    final rows = await calendar._entries(
      data,
      snapshot,
      day.subtract(Duration(days: previousDays)),
      day.add(const Duration(days: 32)),
    );
    final dates = ReportingDates(day, day.add(const Duration(days: 1)));
    final items = await calendar._productivityItems(data, snapshot, [
      dates,
    ], rows);
    final upcoming = rows.where((row) => _upcomingEvent(row, current)).toList()
      ..sort(_compareStarts);
    final next =
        upcoming.firstOrNull ??
        await calendar._nextEvent(data, snapshot, current);
    return (
      agenda: await calendar._presentAgenda(data, snapshot, rows),
      productivity: ProductivitySummary(
        dates,
        items,
        const ProductivityFilter(),
      ),
      next: next == null
          ? null
          : calendar._present(next, snapshot.series, current),
    );
  });

  Future<ProductivityReport> productivity(
    ProductivityQuery query,
  ) => store.transaction((data) async {
    final calendar = await withLatestProfile(data);
    final today = civilDate(
      calendar.zones.wall(now(), calendar.zones.displayId),
    );
    final sundayFirst = calendar.profile?.sundayFirst ?? false;
    final windows = ProductivityWindows(query, today, sundayFirst: sundayFirst);
    final ranges = [
      windows.selected,
      ?windows.comparison,
    ].where((range) => !range.isEmpty).toList();
    final snapshot = await calendar._snapshot(data);
    final rows = [
      for (final range in ranges)
        ...await calendar._entries(data, snapshot, range.start, range.until),
    ];
    return ProductivityReport(
      windows: windows,
      today: today,
      zone: calendar.zones.displayId,
      sundayFirst: sundayFirst,
      categories: calendar.categories,
      filter: query.filter,
      items: await calendar._productivityItems(data, snapshot, ranges, rows),
    );
  });

  Future<List<ProductivityItem>> _productivityItems(
    PlannerData data,
    _Snapshot snapshot,
    List<ReportingDates> ranges,
    List<_Entry> rows,
  ) async {
    final days = {for (final range in ranges) ...range.days};
    final routines = await data.routines.all();
    final occurrences = await data.routineOccurrences.all();
    final allOccurrences = await data.routineOccurrences.all(
      includeDeleted: true,
    );
    final byId = {for (final row in allOccurrences) row.id: row};
    final targets = {
      for (final row in occurrences) (row.routineId, row.day.value): row,
    };
    final recordedDays = {
      for (final row in allOccurrences) (row.routineId, row.day.value),
    };
    final routineDays = <(String, String)>{};
    final items = <ProductivityItem>[];
    for (final routine in routines) {
      final createdAt = routine.metadata.createdAt;
      final history = routine.cadenceHistory.isNotEmpty || createdAt == null
          ? routine.cadenceHistory
          : [
              RoutineCadence(
                LocalDate.parse(
                  civilKey(zones.wall(createdAt, zones.displayId)),
                ),
                routine.frequencyRule,
              ),
            ];
      for (final day in days) {
        final key = (routine.id, civilKey(day));
        final occurrence = targets[key];
        final virtual =
            occurrence == null &&
            !recordedDays.contains(key) &&
            _matchesCadence(history, day);
        if (occurrence == null && !virtual) continue;
        if (occurrence?.status != ActivityStatus.cancelled) {
          routineDays.add(key);
        }
        items.add(
          ProductivityItem(
            id: occurrence?.id ?? '${routine.id}:${key.$2}',
            kind: ProductivityKind.routine,
            title: routine.title,
            day: day,
            status: occurrence?.status ?? ActivityStatus.planned,
            categoryId: routine.categoryId,
            routineId: routine.id,
            isUnscheduledTarget: occurrence == null,
          ),
        );
      }
    }

    final origins = {for (final row in snapshot.all) row.id: row};
    for (final row in rows) {
      final time = zones.wall(row.start, zones.displayId);
      final day = civilDate(time);
      if (!days.contains(day)) continue;
      if (row.event case final event?) {
        // An approved replacement keeps its own date and status. Only an
        // existing target for the related routine on that date absorbs it.
        final related = _originRoutine(event, origins, byId);
        final linked =
            event.routineOccurrenceId != null ||
            (related != null && routineDays.contains((related, civilKey(day))));
        items.add(
          ProductivityItem(
            id: row.id,
            title: row.title,
            kind: ProductivityKind.event,
            day: day,
            time: row.allDay ? null : time,
            status: event.status,
            categoryId: event.categoryId,
            isCalendarBlock: linked,
          ),
        );
      } else if (row.other case final task?
          when task.kind == CalendarEntryKind.deadline) {
        items.add(
          ProductivityItem(
            id: task.obligationId,
            title: task.title,
            kind: ProductivityKind.task,
            day: day,
            time: time,
            status: task.status,
            categoryId: task.categoryId,
          ),
        );
      }
    }
    return items;
  }

  bool _matchesCadence(List<RoutineCadence> history, DateTime date) {
    final key = civilKey(date);
    final rule = history.reversed
        .where((version) => version.from.value.compareTo(key) <= 0)
        .firstOrNull
        ?.rule;
    if (rule == null) return false;
    final fields = rule.split(';');
    if (fields.first != 'FREQ=DAILY' && fields.first != 'FREQ=WEEKLY') {
      return false;
    }
    final byDay = fields
        .where((field) => field.startsWith('BYDAY='))
        .firstOrNull;
    if (byDay == null) return fields.first == 'FREQ=DAILY';
    const weekdays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
    return byDay
        .substring('BYDAY='.length)
        .split(',')
        .contains(weekdays[date.weekday - 1]);
  }

  String? _originRoutine(
    EventOccurrence event,
    Map<String, EventOccurrence> origins,
    Map<String, RoutineOccurrence> occurrences,
  ) {
    final visited = <String>{};
    for (
      EventOccurrence? row = event;
      row != null && visited.add(row.id);
      row = origins[row.supersedesId]
    ) {
      if (occurrences[row.routineOccurrenceId] case final occurrence?) {
        return occurrence.routineId;
      }
    }
    return null;
  }

  static bool _upcomingEvent(_Entry row, DateTime now) =>
      row.event?.status == ActivityStatus.planned && row.start.isAfter(now);

  static int _compareStarts(_Entry a, _Entry b) {
    final start = a.start.compareTo(b.start);
    return start == 0 ? a.id.compareTo(b.id) : start;
  }

  Future<_Entry?> _nextEvent(
    PlannerData data,
    _Snapshot snapshot,
    DateTime now,
  ) async {
    final routineIds = (await data.routineOccurrences.all())
        .map((row) => row.id)
        .toSet();
    _Entry? next;
    void consider(_Entry row) {
      final existing = next;
      if (_upcomingEvent(row, now) &&
          (existing == null || _compareStarts(row, existing) < 0)) {
        next = row;
      }
    }

    for (final event in snapshot.active.values) {
      if (event.routineOccurrenceId == null ||
          routineIds.contains(event.routineOccurrenceId)) {
        consider(_project(event));
      }
    }
    final keys = {
      for (final row in snapshot.all)
        if (row.seriesId != null) (row.seriesId, row.recurrenceKey),
    };
    for (final series in snapshot.series.values) {
      if (series.template == null) continue;
      final template = _SeriesTemplate.decode(series.template!);
      if (template.routineOccurrenceId != null &&
          !routineIds.contains(template.routineOccurrenceId)) {
        continue;
      }
      final rule = EventRecurrence.decode(series.recurrenceRule);
      final zone = template.availability != EventAvailability.timed
          ? zones.displayId
          : series.timeMode == TimeMode.originalZone
          ? series.zoneId
          : zones.deviceId;
      final from = civilDate(zones.wall(now, zone));
      final cutoff = series.endsBefore == null
          ? DateTime.utc(10000)
          : DateTime.parse(series.endsBefore!.value);
      final known = next;
      final lastRelevant = known == null
          ? cutoff
          : civilDate(
              zones.wall(known.start, zone),
            ).add(const Duration(days: 1));
      final until = cutoff.isBefore(lastRelevant) ? cutoff : lastRelevant;
      for (final day in rule.dates(template.start, from, until)) {
        final key = civilKey(day);
        if (keys.contains((series.id, key)) ||
            template.excluded.contains(key)) {
          continue;
        }
        final candidate = _project(template.occurrence(series, day, zones));
        if (!_upcomingEvent(candidate, now)) continue;
        consider(candidate);
        break;
      }
    }
    return next;
  }

  Future<List<PreviewEvent>> _presentAgenda(
    PlannerData data,
    _Snapshot snapshot,
    List<_Entry> source,
  ) async {
    final current = now().toUtc();
    final futureSessions = source.where(
      (row) =>
          row.other?.kind == CalendarEntryKind.workSession &&
          row.other?.status == ActivityStatus.planned &&
          row.start.isAfter(current),
    );
    final conflicts = <String, ScheduleWarning>{};
    if (futureSessions.isNotEmpty) {
      final first = futureSessions
          .map((row) => row.start)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final last = futureSessions
          .map((row) => row.end)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final busy = await _paddedEntries(
        data,
        snapshot,
        first,
        last,
        Duration.zero,
      );
      for (final row in futureSessions) {
        final slot = (start: row.start, end: row.end);
        for (final entry in busy.where(
          (entry) => entry.blocks && entry.id != row.id,
        )) {
          if (overlapsSlot(slot, (start: entry.start, end: entry.end))) {
            conflicts[row.id] = ScheduleWarning.overlap;
            break;
          }
          if (overlapsSlot(
            slot,
            bufferedSlot(entry.busy, before: row.before, after: row.after),
          )) {
            conflicts[row.id] = ScheduleWarning.buffer;
          }
        }
      }
    }
    final visible = source
        .map(
          (entry) => _present(
            entry,
            snapshot.series,
            current,
            warningOverride: conflicts[entry.id],
          ),
        )
        .toList();
    visible.sort((a, b) {
      final start = a.start.compareTo(b.start);
      return start != 0 ? start : a.id.compareTo(b.id);
    });
    return visible;
  }

  Future<List<ScheduleWarning>> warnings(
    PreviewEvent draft, {
    SeriesScope? scope,
  }) async {
    final snapshot = await _snapshot(store);
    return _warnings(store, snapshot, _plan(snapshot, draft, scope));
  }

  Future<List<PreviewEvent>> trash() async {
    final snapshot = await _snapshot(store);
    final deleted = (await store.trashEntries.all())
        .where(
          (entry) =>
              entry.target.kind == RecordKind.eventOccurrence &&
              entry.restoredAt == null,
        )
        .map((entry) => entry.target.id)
        .toSet();
    return [
      for (final event in snapshot.all)
        if (deleted.contains(event.id))
          _present(
            _project(event),
            snapshot.series,
            now().toUtc(),
          ).withState(PreviewEventState.trashed),
    ];
  }

  Future<PreviewEvent> save(
    PreviewEvent draft, {
    SeriesScope? scope,
    Set<ScheduleWarning> approved = const {},
  }) => store.transaction((data) async {
    final snapshot = await _snapshot(data);
    final plan = _plan(snapshot, draft, scope);
    final warnings = await _warnings(data, snapshot, plan);
    if (!approved.containsAll(warnings)) throw ActivityWarnings(warnings);
    var event = _withWarnings(plan.event, warnings);
    if (plan.branch case final branch?) {
      await data.eventSeries.save(_shortened(branch.series, branch.cut));
    }
    if (plan.rule case final rule?) {
      final template = _SeriesTemplate.fromEvent(event, plan.excluded);
      final series = await data.eventSeries.save(
        EventSeries(
          RecordMetadata.create(),
          title: event.title,
          recurrenceRule: rule.encode(),
          zoneId: event.schedule.start.zoneId,
          timeMode: event.schedule.start.mode,
          categoryId: event.categoryId,
          splitFromId: plan.branch?.series.id,
          template: template.encode(),
        ),
      );
      if (plan.previous != null && plan.branch == null) {
        event = await data.events.save(
          _copyOccurrence(
            event,
            metadata: plan.previous!.metadata,
            seriesId: series.id,
            recurrenceKey: civilKey(template.start),
            override: false,
          ),
        );
      } else {
        final first = civilDate(template.start);
        final next = rule
            .dates(
              template.start,
              first,
              first.add(const Duration(days: 366 * 32)),
            )
            .where((day) => !plan.excluded.contains(civilKey(day)))
            .firstOrNull;
        if (next == null) {
          throw StateError('Tidak ada kejadian baru pada cakupan ini.');
        }
        event = template.occurrence(series, next, zones);
      }
      snapshot.series[series.id] = series;
    } else {
      event = await data.events.save(event);
    }
    return _present(_project(event), snapshot.series, now().toUtc());
  });

  Future<PreviewEvent> change(
    PreviewEvent entry,
    PreviewEventState next, {
    SeriesScope? scope,
  }) => store.transaction((data) async {
    final snapshot = await _snapshot(data);
    final occurrence = _find(snapshot, entry);
    final current = now().toUtc();
    if (next == PreviewEventState.trashed) {
      if (occurrence.seriesId != null &&
          scope != null &&
          scope != SeriesScope.occurrence) {
        final branch = _branch(snapshot, occurrence, scope);
        await data.eventSeries.save(_shortened(branch.series, branch.cut));
        final removed = snapshot.active.values.where(
          (row) =>
              row.seriesId == branch.series.id &&
              row.recurrenceKey != null &&
              row.recurrenceKey!.compareTo(civilKey(branch.cut)) >= 0 &&
              row.status == ActivityStatus.planned &&
              !_project(row).start.isBefore(current),
        );
        for (final row in removed) {
          await data.softDelete((kind: RecordKind.eventOccurrence, id: row.id));
        }
        if (occurrence.status == ActivityStatus.planned &&
            !_project(occurrence).start.isBefore(current) &&
            !snapshot.active.containsKey(occurrence.id)) {
          await data.events.save(occurrence);
          await data.softDelete((
            kind: RecordKind.eventOccurrence,
            id: occurrence.id,
          ));
        }
      } else {
        if (!snapshot.active.containsKey(occurrence.id)) {
          await data.events.save(occurrence);
        }
        await data.softDelete((
          kind: RecordKind.eventOccurrence,
          id: occurrence.id,
        ));
      }
      return entry.withState(PreviewEventState.trashed);
    }
    if (occurrence.status != ActivityStatus.planned ||
        _project(occurrence).end.isAfter(current)) {
      throw StateError('Kegiatan belum dapat dikonfirmasi.');
    }
    final status = switch (next) {
      PreviewEventState.done => ActivityStatus.completed,
      PreviewEventState.postponed => ActivityStatus.postponed,
      PreviewEventState.skipped => ActivityStatus.skipped,
      _ => throw ArgumentError.value(next),
    };
    // Materialize a planned row first so SQLite writes the same history as a
    // standalone occurrence when the outcome is explicitly confirmed.
    final base =
        snapshot.active[occurrence.id] ?? await data.events.save(occurrence);
    final saved = await data.events.save(
      _copyOccurrence(base, status: status, schedule: _floatingSchedule(base)),
    );
    return _present(_project(saved), snapshot.series, current);
  });

  Future<ActivityCalendar> withLatestProfile(PlannerData data) async {
    final settings = (await data.profiles.all()).singleOrNull;
    if (settings == null) return this;
    return ActivityCalendar(
      store,
      CalendarZones(
        deviceZoneId: zones.deviceId,
        displayZoneId: settings.preferences.calendarZoneId,
      ),
      profile: PreviewProfile.fromRecord(settings),
      categories: await data.categories.all(),
      now: now,
    );
  }

  Map<int, DailyHours> get schedulingHours => {
    for (final e
        in (profile?.activeHours ?? const <int, ActiveInterval>{}).entries)
      e.key: (startMinute: e.value.start, endMinute: e.value.end),
  };

  String schedulingPreference(String? categoryId) {
    final settings = profile;
    if (settings == null) return '';
    if (settings.categoryTimes[categoryId] case final preference?) {
      return preference;
    }
    final name = categories
        .where((row) => row.id == categoryId)
        .firstOrNull
        ?.name;
    return switch (name?.trim().toLowerCase()) {
      'belajar' => settings.study,
      'workout' || 'olahraga' => settings.workout,
      _ => settings.other,
    };
  }

  Future<EventReplacement?> suggestReplacement(
    PreviewEvent original,
  ) => store.transaction((data) async {
    final calendar = await withLatestProfile(data);
    final event = await _replacementSource(data, original.id);
    final duration = event.schedule.duration;
    final current = now().toUtc();
    final day = civilDate(
      calendar.zones.wall(current, calendar.zones.deviceId),
    );
    final period = (
      start: nextSchedulingMinute(current),
      end: calendar.zones.instant(
        day.add(const Duration(days: 7)),
        calendar.zones.deviceId,
      ),
    );
    final hours = calendar.schedulingHours;
    final before =
        event.bufferBefore ?? calendar.profile?.defaultBuffer ?? Duration.zero;
    final after =
        event.bufferAfter ?? calendar.profile?.defaultBuffer ?? Duration.zero;
    final result = findWorkSlots(
      active: schedulingWindows(calendar.zones, hours, period),
      busy: await calendar.busyIntervals(
        data,
        period.start,
        period.end,
        sessionBuffer: before > after ? before : after,
      ),
      duration: duration,
      minimum: duration,
      maximum: 1,
      before: before,
      after: after,
      preferred: preferredSchedulingWindows(
        calendar.zones,
        hours,
        calendar.schedulingPreference(event.categoryId),
        period,
      ),
    );
    if (result.slots.isEmpty) return null;
    return EventReplacement(
      original: original,
      revision: event.metadata.revision,
      id: RecordMetadata.create().id,
      slot: result.slots.single,
      deviceZone: calendar.zones.deviceId,
      displayZone: calendar.zones.displayId,
    );
  });

  Future<PreviewEvent> approveReplacement(
    EventReplacement proposal,
  ) => store.transaction((data) async {
    final calendar = await withLatestProfile(data);
    final event = await _replacementSource(data, proposal.original.id);
    final slot = proposal.slot;
    if (proposal.revision != event.metadata.revision ||
        proposal.deviceZone != calendar.zones.deviceId ||
        proposal.displayZone != calendar.zones.displayId ||
        slotDuration(slot) != event.schedule.duration ||
        !slot.start.isAfter(now())) {
      throw StaleRecord(event.id);
    }
    final day = civilDate(calendar.zones.wall(now(), calendar.zones.deviceId));
    final period = (
      start: nextSchedulingMinute(now().toUtc()),
      end: calendar.zones.instant(
        day.add(const Duration(days: 7)),
        calendar.zones.deviceId,
      ),
    );
    final before =
        event.bufferBefore ?? calendar.profile?.defaultBuffer ?? Duration.zero;
    final after =
        event.bufferAfter ?? calendar.profile?.defaultBuffer ?? Duration.zero;
    final busy = await calendar.busyIntervals(
      data,
      slot.start,
      slot.end,
      sessionBuffer: before > after ? before : after,
    );
    if (!schedulingWindows(
          calendar.zones,
          calendar.schedulingHours,
          period,
        ).any((window) => containsSlot(window, slot)) ||
        busy.any(
          (row) => overlapsSlot(
            slot,
            bufferedSlot(row, before: before, after: after),
          ),
        )) {
      throw StaleRecord(event.id);
    }
    final replacement = await data.events.save(
      EventOccurrence(
        RecordMetadata(id: proposal.id),
        title: event.title,
        schedule: ScheduledInterval(
          ZonedTime(
            instant: slot.start,
            zoneId: calendar.zones.displayId,
            mode: TimeMode.originalZone,
          ),
          ZonedTime(
            instant: slot.end,
            zoneId: calendar.zones.displayId,
            mode: TimeMode.originalZone,
          ),
        ),
        categoryId: event.categoryId,
        description: event.description,
        supersedesId: event.id,
        bufferBefore: before,
        bufferAfter: after,
        details: EventDetails(
          location: event.details.location,
          note: event.details.note,
          link: event.details.link,
          color: event.details.color,
          reminders: event.details.reminders,
        ),
      ),
    );
    final current = now().toUtc();
    if (!slot.start.isAfter(current)) throw StaleRecord(event.id);
    return calendar._present(calendar._project(replacement), const {}, current);
  });

  Future<EventOccurrence> _replacementSource(
    PlannerData data,
    String id,
  ) async {
    final event = await data.events.find(id);
    if (event == null ||
        event.availability != EventAvailability.timed ||
        (event.status != ActivityStatus.postponed &&
            event.status != ActivityStatus.skipped)) {
      throw StaleRecord(id);
    }
    return event;
  }

  Future<Set<ScheduleWarning>> intervalWarnings(
    PlannerData data,
    ScheduledInterval schedule, {
    String? excludeId,
  }) async {
    final start = schedule.start.instant;
    final end = schedule.end.instant;
    final buffer = profile?.defaultBuffer ?? Duration.zero;
    final snapshot = await _snapshot(data);
    final entries = await _paddedEntries(data, snapshot, start, end, buffer);
    return _warningsFor(
      _Entry(
        start: start,
        end: end,
        title: '',
        id: '',
        before: buffer,
        after: buffer,
      ),
      entries.where((entry) => entry.id != excludeId),
    );
  }

  Future<_Snapshot> _snapshot(PlannerData data) async {
    final sources = await data.eventSeries.all();
    final live = await data.events.all();
    final all = await data.events.all(includeDeleted: true);
    return _Snapshot(
      {for (final series in sources) series.id: series},
      {for (final event in live) event.id: event},
      all,
    );
  }

  Future<List<_Entry>> _entries(
    PlannerData data,
    _Snapshot snapshot,
    DateTime from,
    DateTime until, {
    bool instants = false,
  }) async {
    final utcStart = instants ? from : zones.instant(from, zones.displayId);
    final utcEnd = instants ? until : zones.instant(until, zones.displayId);
    bool overlaps(_Entry event) =>
        event.start.isBefore(utcEnd) && event.end.isAfter(utcStart);

    final routineDays = await data.routineOccurrences.all();
    final visibleRoutineIds = routineDays.map((row) => row.id).toSet();
    final result = [
      ...snapshot.active.values
          .where(
            (event) =>
                event.routineOccurrenceId == null ||
                visibleRoutineIds.contains(event.routineOccurrenceId),
          )
          .map(_project)
          .where(overlaps),
    ];
    final keys = {
      for (final event in snapshot.all)
        if (event.seriesId != null) (event.seriesId, event.recurrenceKey),
    };
    for (final series in snapshot.series.values) {
      if (series.template == null) continue;
      final template = _SeriesTemplate.decode(series.template!);
      if (template.routineOccurrenceId != null &&
          !visibleRoutineIds.contains(template.routineOccurrenceId)) {
        continue;
      }
      final rule = EventRecurrence.decode(series.recurrenceRule);
      final zone = series.timeMode == TimeMode.originalZone
          ? series.zoneId
          : zones.deviceId;
      final span = civilDate(
        template.end,
      ).difference(civilDate(template.start)).inDays;
      final lower = civilDate(
        zones.wall(utcStart, zone),
      ).subtract(Duration(days: span + 1));
      final upper = civilDate(
        zones.wall(utcEnd, zone),
      ).add(const Duration(days: 2));
      final cutoff = series.endsBefore == null
          ? upper
          : DateTime.parse(series.endsBefore!.value);
      for (final day in rule.dates(
        template.start,
        lower,
        cutoff.isBefore(upper) ? cutoff : upper,
      )) {
        final key = civilKey(day);
        if (keys.contains((series.id, key)) ||
            template.excluded.contains(key)) {
          continue;
        }
        final record = template.occurrence(series, day, zones);
        final projected = _project(record);
        if (overlaps(projected)) result.add(projected);
      }
    }

    // A floating schedule can move across two civil dates after a zone change.
    const travelWindow = Duration(days: 2);
    for (final entry in await data.calendar(
      utcStart.subtract(travelWindow),
      utcEnd.add(travelWindow),
    )) {
      if (entry.kind == CalendarEntryKind.event) continue;
      final floating =
          entry.startTime?.mode == TimeMode.localWallTime &&
          (entry.kind == CalendarEntryKind.deadline
              ? entry.status != ActivityStatus.completed
              : entry.status == ActivityStatus.planned);
      final schedule = floating && entry.endTime != null
          ? zones.interval(
              DateTime.parse(entry.startTime!.localWallTime!),
              DateTime.parse(entry.endTime!.localWallTime!),
              zones.deviceId,
              TimeMode.localWallTime,
            )
          : null;
      final start =
          schedule?.start.instant ??
          (floating ? zones.effectiveTime(entry.startTime!) : entry.start);
      final end =
          schedule?.end.instant ??
          entry.end ??
          start.add(const Duration(microseconds: 1));
      final buffer =
          entry.kind == CalendarEntryKind.workSession ||
              entry.kind == CalendarEntryKind.routine
          ? profile?.defaultBuffer ?? Duration.zero
          : Duration.zero;
      final projected = _Entry(
        start: start,
        end: end,
        title: entry.title,
        id: entry.id,
        other: entry,
        before: buffer,
        after: buffer,
      );
      if (overlaps(projected)) result.add(projected);
    }
    final tracking = routineDays.where((row) => row.schedule == null).toList();
    if (tracking.isNotEmpty) {
      final routines = {
        for (final row in await data.routines.all()) row.id: row,
      };
      for (final row in tracking) {
        final routine = routines[row.routineId];
        if (routine == null) continue;
        final day = civilDate(DateTime.parse(row.day.value));
        final entry = CalendarEntry(
          kind: CalendarEntryKind.routine,
          id: row.id,
          obligationId: row.id,
          title: routine.title,
          start: zones.instant(day, zones.displayId),
          end: zones.instant(day.add(const Duration(days: 1)), zones.displayId),
          status: row.status,
          categoryId: routine.categoryId,
          availability: EventAvailability.allDayFree,
        );
        final projected = _Entry(
          id: row.id,
          title: routine.title,
          start: entry.start,
          end: entry.end!,
          other: entry,
        );
        if (overlaps(projected)) result.add(projected);
      }
    }
    return result;
  }

  EventOccurrence _find(_Snapshot snapshot, PreviewEvent entry) {
    final stored = snapshot.active[entry.id];
    if (stored != null) return stored;
    final series = snapshot.series[entry.series];
    final key = entry.recurrenceKey;
    if (series?.template == null ||
        key == null ||
        snapshot.all.any(
          (item) => item.seriesId == entry.series && item.recurrenceKey == key,
        )) {
      throw StaleRecord(entry.id);
    }
    if (series!.endsBefore case final end? when key.compareTo(end.value) >= 0) {
      throw StaleRecord(entry.id);
    }
    final template = _SeriesTemplate.decode(series.template!);
    if (template.excluded.contains(key)) throw StaleRecord(entry.id);
    final day = DateTime.parse(key);
    final until = civilDate(day).add(const Duration(days: 1));
    if (EventRecurrence.decode(
      series.recurrenceRule,
    ).dates(template.start, day, until).isEmpty) {
      throw StaleRecord(entry.id);
    }
    final virtual = template.occurrence(series, day, zones);
    if (virtual.id != entry.id) throw StaleRecord(entry.id);
    return virtual;
  }

  _Branch _branch(
    _Snapshot snapshot,
    EventOccurrence event,
    SeriesScope scope,
  ) {
    final series = snapshot.series[event.seriesId];
    if (series?.template == null || event.recurrenceKey == null) {
      throw StaleRecord(event.id);
    }
    final template = _SeriesTemplate.decode(series!.template!);
    final zone = series.timeMode == TimeMode.originalZone
        ? series.zoneId
        : zones.deviceId;
    final current = now().toUtc();
    final origin = zones.wall(
      current,
      template.availability == EventAvailability.timed ? zone : zones.displayId,
    );
    var lower = civilDate(origin);
    final picked = civilDate(DateTime.parse(event.recurrenceKey!));
    if (scope == SeriesScope.following && picked.isAfter(lower)) lower = picked;
    final upper = series.endsBefore == null
        ? lower.add(const Duration(days: 366 * 32))
        : civilDate(DateTime.parse(series.endsBefore!.value));
    final rule = EventRecurrence.decode(series.recurrenceRule);
    for (final date in rule.dates(template.start, lower, upper)) {
      if (!_project(
        template.occurrence(series, date, zones),
      ).start.isBefore(current)) {
        return _Branch(series, date);
      }
    }
    throw StateError('Tidak ada kejadian mendatang pada cakupan ini.');
  }

  _Plan _plan(_Snapshot snapshot, PreviewEvent draft, SeriesScope? scope) {
    final previous = draft.id.isEmpty ? null : _find(snapshot, draft);
    final recurring = previous?.seriesId != null;
    if (previous != null &&
        previous.status != ActivityStatus.planned &&
        (!recurring || scope == null || scope == SeriesScope.occurrence)) {
      throw StateError('Riwayat kegiatan ini sudah dikonfirmasi.');
    }
    final branch = recurring && scope != null && scope != SeriesScope.occurrence
        ? _branch(snapshot, previous!, scope)
        : null;
    final rule = recurring && branch == null ? null : draft.options.rule;
    var start = civilTime(draft.start);
    var end = civilTime(draft.end);
    var shift = Duration.zero;
    if (branch != null && rule != null) {
      final oldSelected = civilDate(DateTime.parse(previous!.recurrenceKey!));
      final removedOffset = branch.cut.difference(oldSelected);
      start = start.add(removedOffset);
      end = end.add(removedOffset);
      shift = civilDate(start).difference(branch.cut);
    }
    if (rule?.until != null &&
        civilDate(rule!.until!).isBefore(civilDate(start))) {
      throw const FormatException(
        'Tanggal akhir pengulangan harus sama atau setelah tanggal mulai.',
      );
    }
    final replaced = draft.supersedesId == null
        ? null
        : snapshot.active[draft.supersedesId];
    if (draft.supersedesId != null &&
        (replaced == null ||
            (replaced.status != ActivityStatus.postponed &&
                replaced.status != ActivityStatus.skipped))) {
      throw StateError('Jadwal asal pengganti tidak tersedia.');
    }
    final options = draft.options;
    final mode =
        options.timeMode ??
        previous?.schedule.start.mode ??
        profile?.preferences.eventTimeMode ??
        TimeMode.originalZone;
    final zone = mode == TimeMode.localWallTime
        ? zones.deviceId
        : options.zoneId ?? previous?.schedule.start.zoneId ?? zones.displayId;
    final availability =
        EventAvailability.values[draft.options.availability.index];
    final categorized = categories
        .where((category) => category.name == options.category)
        .firstOrNull;
    final before = options.before;
    final after = options.after;
    if (draft.title.trim().isEmpty ||
        !start.isBefore(end) ||
        before < 0 ||
        after < 0) {
      throw const FormatException(
        'Lengkapi judul dan rentang kegiatan yang valid.',
      );
    }
    final schedule = zones.interval(start, end, zone, mode);
    final event = EventOccurrence(
      branch == null
          ? previous?.metadata ?? RecordMetadata.create()
          : RecordMetadata.create(),
      title: draft.title.trim(),
      schedule: schedule,
      availability: availability,
      categoryId: categorized?.id,
      seriesId: branch == null ? previous?.seriesId : null,
      recurrenceKey: branch == null ? previous?.recurrenceKey : null,
      supersedesId: previous?.supersedesId ?? replaced?.id,
      routineOccurrenceId: previous?.routineOccurrenceId,
      allDayStart: draft.allDay ? LocalDate.parse(civilKey(start)) : null,
      allDayEndExclusive: draft.allDay ? LocalDate.parse(civilKey(end)) : null,
      description: options.description,
      bufferBefore: Duration(minutes: before),
      bufferAfter: Duration(minutes: after),
      details: EventDetails(
        location: options.location,
        note: options.note,
        link: options.link,
        color: options.categoryColor,
        reminders: options.reminders,
        isException: recurring && branch == null,
      ),
    );
    final excluded = <String>{};
    if (branch != null) {
      final old = _SeriesTemplate.decode(branch.series.template!);
      final keys = [
        ...old.excluded,
        for (final row in snapshot.all)
          if (row.seriesId == branch.series.id && row.recurrenceKey != null)
            row.recurrenceKey!,
      ];
      for (final key in keys.where(
        (key) => key.compareTo(civilKey(branch.cut)) >= 0,
      )) {
        excluded.add(civilKey(DateTime.parse(key).add(shift)));
      }
    }
    return _Plan(event, previous, branch, rule, excluded);
  }

  Future<List<ScheduleWarning>> _warnings(
    PlannerData data,
    _Snapshot snapshot,
    _Plan plan,
  ) async {
    if (plan.event.availability == EventAvailability.allDayFree) {
      return const [];
    }
    final candidates = <_Entry>[];
    if (plan.rule case final rule?) {
      final template = _SeriesTemplate.fromEvent(plan.event, plan.excluded);
      final series = EventSeries(
        RecordMetadata(id: 'proposed'),
        title: plan.event.title,
        recurrenceRule: rule.encode(),
        zoneId: plan.event.schedule.start.zoneId,
        timeMode: plan.event.schedule.start.mode,
      );
      final first = civilDate(template.start);
      for (final day in rule.dates(
        template.start,
        first,
        first.add(const Duration(days: conflictHorizonDays)),
      )) {
        if (!plan.excluded.contains(civilKey(day))) {
          candidates.add(_project(template.occurrence(series, day, zones)));
        }
      }
    } else {
      candidates.add(_project(plan.event));
    }
    if (candidates.isEmpty) return const [];

    final start = candidates.first.start;
    final end = candidates.last.end;
    final found = await _paddedEntries(
      data,
      snapshot,
      start,
      end,
      Duration(
        microseconds: math.max(
          plan.event.bufferBefore?.inMicroseconds ?? 0,
          plan.event.bufferAfter?.inMicroseconds ?? 0,
        ),
      ),
    );
    final existing = found.where((item) {
      if (item.id == plan.previous?.id && plan.branch == null) return false;
      final branch = plan.branch;
      return branch == null ||
          item.event?.seriesId != branch.series.id ||
          item.event!.recurrenceKey!.compareTo(civilKey(branch.cut)) < 0 ||
          snapshot.active.containsKey(item.id);
    }).toList();

    final warnings = <ScheduleWarning>{};
    for (final candidate in candidates) {
      warnings.addAll(_warningsFor(candidate, existing));
      existing.add(candidate);
    }
    return ScheduleWarning.values.where(warnings.contains).toList();
  }

  Future<List<_Entry>> _paddedEntries(
    PlannerData data,
    _Snapshot snapshot,
    DateTime start,
    DateTime end,
    Duration requestedBuffer,
  ) {
    final parsedBuffers = [
      profile?.defaultBuffer?.inMicroseconds ?? 0,
      requestedBuffer.inMicroseconds,
      for (final row in snapshot.active.values)
        math.max(
          row.bufferAfter?.inMicroseconds ?? 0,
          row.bufferBefore?.inMicroseconds ?? 0,
        ),
      for (final series in snapshot.series.values)
        if (series.template case final template?)
          Duration(
            minutes: _SeriesTemplate.decode(template).maxBuffer,
          ).inMicroseconds,
    ];
    final padding = Duration(microseconds: parsedBuffers.reduce(math.max) * 2);
    return _entries(
      data,
      snapshot,
      start.subtract(padding),
      end.add(padding),
      instants: true,
    );
  }

  Future<List<BusyInterval>> busyIntervals(
    PlannerData data,
    DateTime start,
    DateTime end, {
    required Duration sessionBuffer,
  }) async => [
    for (final entry in await _paddedEntries(
      data,
      await _snapshot(data),
      start,
      end,
      sessionBuffer,
    ))
      if (entry.blocks) entry.busy,
  ];

  Set<ScheduleWarning> _warningsFor(
    _Entry proposed,
    Iterable<_Entry> existing,
  ) {
    final warnings = <ScheduleWarning>{};
    for (final entry in existing) {
      if (!entry.blocks) continue;
      if (proposed.start.isBefore(entry.end) &&
          entry.start.isBefore(proposed.end)) {
        warnings.add(ScheduleWarning.overlap);
      } else if (overlapsSlot(
        proposed.busy.slot,
        bufferedSlot(
          entry.busy,
          before: proposed.before,
          after: proposed.after,
        ),
      )) {
        warnings.add(ScheduleWarning.buffer);
      }
    }
    if (proposed.event == null ||
        proposed.event!.availability == EventAvailability.timed) {
      final start = zones.wall(proposed.start, zones.deviceId);
      final end = zones.wall(proposed.end, zones.deviceId);
      for (
        var day = civilDate(start);
        day.isBefore(end);
        day = day.add(const Duration(days: 1))
      ) {
        final hours = profile?.activeHours[day.weekday];
        if (hours == null) continue;
        final segStart = start.isAfter(day) ? start : day;
        final tomorrow = day.add(const Duration(days: 1));
        final segEnd = end.isBefore(tomorrow) ? end : tomorrow;
        if (segStart.isBefore(day.add(Duration(minutes: hours.start))) ||
            segEnd.isAfter(day.add(Duration(minutes: hours.end)))) {
          warnings.add(ScheduleWarning.activeHours);
        }
      }
    }
    return warnings;
  }

  ScheduledInterval? _floatingSchedule(EventOccurrence event) {
    final schedule = event.schedule;
    if (schedule.start.mode != TimeMode.localWallTime ||
        event.status != ActivityStatus.planned ||
        event.availability != EventAvailability.timed) {
      return null;
    }
    return zones.interval(
      DateTime.parse(schedule.start.localWallTime!),
      DateTime.parse(schedule.end.localWallTime!),
      zones.deviceId,
      TimeMode.localWallTime,
    );
  }

  _Entry _project(EventOccurrence event) {
    final schedule = _floatingSchedule(event) ?? event.schedule;
    final allDay = event.availability != EventAvailability.timed;
    final start = allDay
        ? zones.instant(
            DateTime.parse(event.allDayStart!.value),
            zones.displayId,
          )
        : schedule.start.instant;
    final end = allDay
        ? zones.instant(
            DateTime.parse(event.allDayEndExclusive!.value),
            zones.displayId,
          )
        : schedule.end.instant;
    final fallback = profile?.defaultBuffer ?? Duration.zero;
    return _Entry(
      id: event.id,
      title: event.title,
      start: start,
      end: end,
      event: event,
      before: event.bufferBefore ?? fallback,
      after: event.bufferAfter ?? fallback,
    );
  }

  PreviewEvent _present(
    _Entry entry,
    Map<String, EventSeries> series,
    DateTime current, {
    ScheduleWarning? warningOverride,
  }) {
    final event = entry.event;
    final other = entry.other;
    final owner = series[event?.seriesId];
    final category = categories
        .where(
          (item) =>
              item.id ==
              (event?.categoryId ?? (event == null ? other?.categoryId : null)),
        )
        .firstOrNull;
    final status = event?.status ?? other!.status;
    final state = switch (status) {
      ActivityStatus.completed => PreviewEventState.done,
      ActivityStatus.postponed => PreviewEventState.postponed,
      ActivityStatus.skipped ||
      ActivityStatus.cancelled => PreviewEventState.skipped,
      ActivityStatus.planned =>
        !entry.end.isAfter(current)
            ? PreviewEventState.pending
            : !entry.start.isAfter(current)
            ? PreviewEventState.active
            : PreviewEventState.upcoming,
    };
    final rule = owner == null
        ? null
        : EventRecurrence.decode(owner.recurrenceRule);
    final schedule = event?.schedule;
    final mode = schedule?.start.mode ?? other?.startTime?.mode;
    final zone = mode == TimeMode.localWallTime
        ? zones.deviceId
        : schedule?.start.zoneId ?? other?.startTime?.zoneId ?? zones.displayId;
    final warning = ScheduleWarning.values
        .where((item) => event?.details.warnings.contains(item.name) ?? false)
        .firstOrNull;
    final availability =
        event?.availability ?? other?.availability ?? EventAvailability.timed;
    final allDay = availability != EventAvailability.timed;
    DateTime editorWall(ZonedTime value) =>
        allDay || value.localWallTime != null
        ? civilTime(
            DateTime.parse(
              value.localWallTime ??
                  zones.wall(value.instant, zone).toIso8601String(),
            ),
          )
        : zones.wall(value.instant, zone);
    return PreviewEvent(
      id: entry.id,
      title: entry.title,
      start: zones.wall(entry.start, zones.displayId),
      end: zones.wall(entry.end, zones.displayId),
      state: state,
      kind: switch (other?.kind) {
        CalendarEntryKind.deadline => PreviewKind.deadline,
        CalendarEntryKind.workSession => PreviewKind.session,
        CalendarEntryKind.routine => PreviewKind.routine,
        _ => PreviewKind.activity,
      },
      series: event?.seriesId,
      recurrenceKey: event?.recurrenceKey,
      supersedesId: event?.supersedesId,
      isException: event?.details.isException ?? false,
      obligationId: event?.routineOccurrenceId ?? other?.obligationId,
      warning: warningOverride ?? warning,
      options: EventOptions(
        availability: DayAvailability.values[availability.index],
        category: category?.name ?? '',
        categoryColor: event?.details.color ?? 'Biru',
        description: event?.description ?? '',
        location: event?.details.location ?? '',
        note: event?.details.note ?? '',
        link: event?.details.link ?? '',
        reminders: event?.details.reminders ?? const [],
        recurrence: rule == null ? 'Sekali' : repeatLabel(rule),
        rule: rule,
        before: entry.before.inMinutes,
        after: entry.after.inMinutes,
        timeMode: mode,
        zoneId: zone,
        editorStart: schedule == null ? null : editorWall(schedule.start),
        editorEnd: schedule == null ? null : editorWall(schedule.end),
        zone: mode == TimeMode.localWallTime ? 'Ikuti jam lokal · $zone' : zone,
      ),
    );
  }
}

String repeatLabel(EventRecurrence rule) {
  final unit = switch (rule.frequency) {
    RepeatFrequency.daily => ('Harian', 'hari'),
    RepeatFrequency.weekly => ('Mingguan', 'minggu'),
    RepeatFrequency.monthly => ('Bulanan', 'bulan'),
  };
  return rule.interval == 1 ? unit.$1 : 'Setiap ${rule.interval} ${unit.$2}';
}

class _Snapshot {
  const _Snapshot(this.series, this.active, this.all);
  final Map<String, EventSeries> series;
  final Map<String, EventOccurrence> active;
  final List<EventOccurrence> all;
}

class _Entry {
  const _Entry({
    required this.start,
    required this.end,
    required this.id,
    required this.title,
    this.before = Duration.zero,
    this.after = Duration.zero,
    this.event,
    this.other,
  });
  final DateTime start, end;
  final String id, title;
  final Duration before, after;
  final EventOccurrence? event;
  final CalendarEntry? other;
  ActivityStatus? get status => event?.status ?? other?.status;
  bool get allDay =>
      (event?.availability ?? other?.availability ?? EventAvailability.timed) !=
      EventAvailability.timed;
  bool get deviceTime =>
      allDay ||
      (event?.schedule.start.mode ?? other?.startTime?.mode) ==
          TimeMode.localWallTime;
  String? get routineLink =>
      event?.routineOccurrenceId ??
      (other?.kind == CalendarEntryKind.routine ? id : null);

  bool get blocks {
    return other?.kind != CalendarEntryKind.deadline &&
        (event?.availability ?? other?.availability) !=
            EventAvailability.allDayFree &&
        status != ActivityStatus.cancelled &&
        status != ActivityStatus.skipped &&
        status != ActivityStatus.postponed;
  }

  BusyInterval get busy => (
    id: id,
    title: title,
    slot: (start: start, end: end),
    before: before,
    after: after,
  );
}

class _Branch {
  const _Branch(this.series, this.cut);
  final EventSeries series;
  final DateTime cut;
}

class _Plan {
  const _Plan(this.event, this.previous, this.branch, this.rule, this.excluded);
  final EventOccurrence event;
  final EventOccurrence? previous;
  final _Branch? branch;
  final EventRecurrence? rule;
  final Set<String> excluded;
}

EventSeries _shortened(EventSeries value, DateTime before) => EventSeries(
  value.metadata,
  title: value.title,
  recurrenceRule: value.recurrenceRule,
  zoneId: value.zoneId,
  timeMode: value.timeMode,
  categoryId: value.categoryId,
  splitFromId: value.splitFromId,
  template: value.template,
  endsBefore: LocalDate.parse(civilKey(before)),
);

EventOccurrence _copyOccurrence(
  EventOccurrence value, {
  RecordMetadata? metadata,
  ScheduledInterval? schedule,
  ActivityStatus? status,
  String? seriesId,
  String? recurrenceKey,
  EventDetails? details,
  bool? override,
}) => EventOccurrence(
  metadata ?? value.metadata,
  title: value.title,
  schedule: schedule ?? value.schedule,
  availability: value.availability,
  status: status ?? value.status,
  categoryId: value.categoryId,
  seriesId: seriesId ?? value.seriesId,
  recurrenceKey: recurrenceKey ?? value.recurrenceKey,
  supersedesId: value.supersedesId,
  routineOccurrenceId: value.routineOccurrenceId,
  allDayStart: value.allDayStart,
  allDayEndExclusive: value.allDayEndExclusive,
  description: value.description,
  bufferBefore: value.bufferBefore,
  bufferAfter: value.bufferAfter,
  details:
      details ??
      (override == null
          ? value.details
          : EventDetails(
              location: value.details.location,
              note: value.details.note,
              link: value.details.link,
              reminders: value.details.reminders,
              color: value.details.color,
              warnings: value.details.warnings,
              isException: override,
            )),
);

EventOccurrence _withWarnings(
  EventOccurrence event,
  Iterable<ScheduleWarning> warnings,
) => _copyOccurrence(
  event,
  details: EventDetails(
    location: event.details.location,
    note: event.details.note,
    link: event.details.link,
    color: event.details.color,
    reminders: event.details.reminders,
    isException: event.details.isException,
    warnings: warnings.map((warning) => warning.name).toList(),
  ),
);

class _SeriesTemplate {
  const _SeriesTemplate(
    this.start,
    this.end,
    this.availability,
    this.before,
    this.after,
    this.description,
    this.details,
    this.excluded,
    this.routineOccurrenceId,
  );

  factory _SeriesTemplate.fromEvent(
    EventOccurrence value,
    Set<String> excluded,
  ) => _SeriesTemplate(
    DateTime.parse(value.schedule.start.localWallTime!),
    DateTime.parse(value.schedule.end.localWallTime!),
    value.availability,
    value.bufferBefore?.inMinutes ?? 0,
    value.bufferAfter?.inMinutes ?? 0,
    value.description ?? '',
    value.details,
    excluded,
    value.routineOccurrenceId,
  );

  final DateTime start, end;
  final EventAvailability availability;
  final int before, after;
  final String description;
  final EventDetails details;
  final Set<String> excluded;
  final String? routineOccurrenceId;

  int get maxBuffer => math.max(before, after);

  String encode() => jsonEncode({
    'start': civilTime(start).toIso8601String(),
    'end': civilTime(end).toIso8601String(),
    'availability': availability.name,
    'before': before,
    'after': after,
    'description': description,
    'location': details.location,
    'note': details.note,
    'link': details.link,
    'color': details.color,
    'reminders': details.reminders,
    'warnings': details.warnings,
    'excluded': excluded.toList(),
    'routineOccurrenceId': routineOccurrenceId,
  });

  factory _SeriesTemplate.decode(String encoded) {
    final map = jsonDecode(encoded) as Map<String, dynamic>;
    return _SeriesTemplate(
      DateTime.parse(map['start'] as String),
      DateTime.parse(map['end'] as String),
      EventAvailability.values.byName(map['availability'] as String),
      map['before'] as int,
      map['after'] as int,
      map['description'] as String,
      EventDetails(
        location: map['location'] as String,
        note: map['note'] as String,
        link: map['link'] as String,
        color: map['color'] as String,
        reminders: (map['reminders'] as List<dynamic>).cast<String>(),
        warnings: (map['warnings'] as List<dynamic>).cast<String>(),
      ),
      (map['excluded'] as List<dynamic>).cast<String>().toSet(),
      map['routineOccurrenceId'] as String?,
    );
  }

  EventOccurrence occurrence(
    EventSeries series,
    DateTime day,
    CalendarZones zones,
  ) {
    final shift = civilDate(day).difference(civilDate(start));
    final from = civilTime(start).add(shift);
    final to = civilTime(end).add(shift);
    final zone = series.timeMode == TimeMode.originalZone
        ? series.zoneId
        : zones.deviceId;
    final key = civilKey(day);
    final allDay = availability != EventAvailability.timed;
    return EventOccurrence(
      RecordMetadata(id: '${series.id}@$key'),
      title: series.title,
      schedule: zones.interval(from, to, zone, series.timeMode),
      availability: availability,
      categoryId: series.categoryId,
      seriesId: series.id,
      recurrenceKey: key,
      routineOccurrenceId: routineOccurrenceId,
      allDayStart: allDay ? LocalDate.parse(civilKey(from)) : null,
      allDayEndExclusive: allDay ? LocalDate.parse(civilKey(to)) : null,
      description: description,
      bufferBefore: Duration(minutes: before),
      bufferAfter: Duration(minutes: after),
      details: details,
    );
  }
}
