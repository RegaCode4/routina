import 'package:routina/application/activity_calendar.dart';
import 'package:routina/application/calendar_zones.dart';
import 'package:routina/application/planner_preview.dart' show ActivityWarnings;
import 'package:routina/application/routine_cadence.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';
import 'package:routina/domain/preview_event.dart';

class RoutineIssue implements Exception {
  const RoutineIssue(this.message);
  final String message;
}

enum RoutineStatus {
  notStarted('Belum dimulai'),
  active('Berlangsung'),
  pending('Menunggu konfirmasi'),
  completed('Selesai'),
  skipped('Dilewatkan'),
  missed('Terlewat');

  const RoutineStatus(this.label);
  final String label;
}

class RoutineView {
  const RoutineView({
    required this.routine,
    required this.day,
    required this.occurrence,
    required this.logs,
    required this.timer,
    required this.weeklyCount,
    required this.activeDay,
    this.timerClock,
  });

  final Routine routine;
  final DateTime day;
  final RoutineOccurrence? occurrence;
  final List<TimeLog> logs;
  final RoutineTimer? timer;
  final int weeklyCount;
  final LocalDate? activeDay;
  final TimerClockSample? timerClock;

  RoutineGoal get goal => occurrence?.goal ?? routine.goal;
  bool get completed => occurrence?.status == ActivityStatus.completed;
  Duration get recorded =>
      logs.fold(Duration.zero, (total, log) => total + log.actualDuration);
  Duration timerElapsedAt(DateTime now, {TimerClockSample? clock}) =>
      timer?.elapsedAt(now, clock ?? timerClock) ?? Duration.zero;
  Duration actualAt(DateTime now, {TimerClockSample? clock}) =>
      recorded + timerElapsedAt(now, clock: clock);

  int get target => switch (goal.type) {
    RoutineTargetType.duration => goal.duration?.inMicroseconds ?? 0,
    RoutineTargetType.checklist => goal.checklist.length,
    RoutineTargetType.count || RoutineTargetType.frequency => goal.amount ?? 0,
  };

  int achievedAt(DateTime now, {TimerClockSample? clock}) =>
      switch (goal.type) {
        RoutineTargetType.duration => actualAt(
          now,
          clock: clock,
        ).inMicroseconds,
        RoutineTargetType.checklist =>
          goal.checklist
              .where((item) => occurrence?.checkedItems.contains(item) ?? false)
              .length,
        RoutineTargetType.count => occurrence?.recordedCount ?? 0,
        RoutineTargetType.frequency => weeklyCount,
      };

  bool goalReachedAt(DateTime now, {TimerClockSample? clock}) =>
      target > 0 && achievedAt(now, clock: clock) >= target;
  double progressAt(DateTime now, {TimerClockSample? clock}) => target == 0
      ? 0
      : (achievedAt(now, clock: clock) / target).clamp(0.0, 1.0).toDouble();

  RoutineStatus statusAt(DateTime now, {TimerClockSample? clock}) {
    if (completed) return RoutineStatus.completed;
    if (occurrence?.status == ActivityStatus.skipped) {
      return RoutineStatus.skipped;
    }
    if (goalReachedAt(now, clock: clock)) return RoutineStatus.pending;
    if (timer?.runningSince != null) return RoutineStatus.active;
    final end = occurrence?.schedule?.end.instant;
    return end != null && now.isAfter(end)
        ? RoutineStatus.missed
        : RoutineStatus.notStarted;
  }
}

class RoutineWorkspace {
  const RoutineWorkspace({
    required this.openStore,
    required this.openCalendar,
    required this.readZones,
    required this.sundayFirst,
    required this.now,
    this.readTimerClock,
  });

  final Future<PlannerStore> Function() openStore;
  final Future<ActivityCalendar> Function() openCalendar;
  final CalendarZones Function() readZones;
  final bool Function() sundayFirst;
  final DateTime Function() now;
  final Future<TimerClockSample?> Function()? readTimerClock;
  Future<TimerClockSample?> sampleTimerClock() async => readTimerClock?.call();

  CalendarZones get zones => readZones();
  DateTime get today => civilDate(zones.wall(now(), zones.displayId));
  DateTime weekStart(DateTime day) =>
      civilWeekStart(day, sundayFirst: sundayFirst());

  Future<List<RoutineView>> list(
    DateTime day, {
    bool onDateOnly = false,
  }) async => (await openStore()).transaction((data) async {
    final records = await _RoutineData.read(data);
    final clock = records.timers.isEmpty ? null : await sampleTimerClock();
    final date = civilDate(day);
    final key = civilKey(date);
    final recorded = onDateOnly
        ? {
            for (final row in await data.routineOccurrences.all(
              includeDeleted: true,
            ))
              if (row.day.value == key) row.routineId,
          }
        : const <String>{};
    final displayZones = zones;
    final rows = [
      for (final routine in await data.routines.all())
        _view(routine, date, records, clock),
    ];
    return [
      for (final row in rows)
        if (!onDateOnly ||
            row.occurrence != null ||
            (!recorded.contains(row.routine.id) &&
                matchesRoutineCadence(
                  routineCadenceHistory(row.routine, displayZones),
                  date,
                )))
          row,
    ];
  });

  Future<RoutineView?> read(String id, DateTime day) async =>
      (await openStore()).transaction((data) async {
        final routine = await data.routines.find(id);
        if (routine == null) return null;
        final records = await _RoutineData.read(data);
        final clock = records.timers.isEmpty ? null : await sampleTimerClock();
        return _view(routine, civilDate(day), records, clock);
      });

  Future<({String routineId, DateTime day})?> openOccurrence(String id) async {
    final row = await (await openStore()).routineOccurrences.find(id);
    return row == null
        ? null
        : (
            routineId: row.routineId,
            day: civilDate(DateTime.parse(row.day.value)),
          );
  }

  Future<List<RoutineView>> history(String? id) async =>
      (await openStore()).transaction((data) async {
        final records = await _RoutineData.read(data);
        final clock = records.timers.isEmpty ? null : await sampleTimerClock();
        final routines = {
          for (final routine in await data.routines.all())
            if (id == null || routine.id == id) routine.id: routine,
        };
        final rows = [
          for (final row in records.occurrences)
            if (routines[row.routineId] case final routine?)
              _view(
                routine,
                civilDate(DateTime.parse(row.day.value)),
                records,
                clock,
              ),
        ];
        rows.sort((a, b) => b.day.compareTo(a.day));
        return rows;
      });

  RoutineView _view(
    Routine routine,
    DateTime day,
    _RoutineData records,
    TimerClockSample? clock,
  ) {
    final key = civilKey(day);
    final weekStartKey = civilKey(weekStart(day));
    final endKey = civilKey(weekStart(day).add(const Duration(days: 7)));
    RoutineOccurrence? occurrence;
    var weeklyCount = 0;
    LocalDate? activeDay;
    for (final row in records.occurrences.where(
      (row) => row.routineId == routine.id,
    )) {
      final date = row.day.value;
      if (date == key) occurrence = row;
      if ((row.goal?.type ?? routine.targetType) ==
              RoutineTargetType.frequency &&
          date.compareTo(weekStartKey) >= 0 &&
          date.compareTo(endKey) < 0) {
        weeklyCount += row.recordedCount ?? 0;
      }
      if (records.timers.containsKey(row.id) &&
          (activeDay == null || date.compareTo(activeDay.value) > 0)) {
        activeDay = row.day;
      }
    }
    return RoutineView(
      routine: routine,
      day: day,
      occurrence: occurrence,
      logs: records.logs[occurrence?.id] ?? const [],
      timer: records.timers[occurrence?.id],
      weeklyCount: weeklyCount,
      activeDay: activeDay,
      timerClock: clock,
    );
  }

  Future<Routine> save(
    Routine configuration, {
    Set<Duration>? reminders,
  }) async => (await openStore()).transaction((data) async {
    final goal = configuration.goal;
    final names = goal.checklist.map((name) => name.trim()).toList();
    final invalid = switch (goal.type) {
      RoutineTargetType.duration =>
        (goal.duration ?? Duration.zero) <= Duration.zero,
      RoutineTargetType.checklist =>
        names.isEmpty ||
            names.any((name) => name.isEmpty) ||
            names.map((name) => name.toLowerCase()).toSet().length !=
                names.length,
      RoutineTargetType.count ||
      RoutineTargetType.frequency => (goal.amount ?? 0) <= 0,
    };
    if (configuration.title.trim().isEmpty || invalid) {
      throw const RoutineIssue('Isi nama dan target rutinitas yang valid.');
    }
    final previous = await data.routines.find(configuration.id);
    final history = <RoutineCadence>[...?previous?.cadenceHistory];
    if (history.isEmpty && previous?.metadata.createdAt != null) {
      final zone = zones;
      history.add(
        RoutineCadence(
          LocalDate.parse(
            civilKey(zone.wall(previous!.metadata.createdAt!, zone.displayId)),
          ),
          previous.frequencyRule,
        ),
      );
    }
    if (previous == null ||
        previous.frequencyRule != configuration.frequencyRule) {
      final from = LocalDate.parse(civilKey(today));
      history.removeWhere(
        (version) => version.from.value.compareTo(from.value) >= 0,
      );
      history.add(RoutineCadence(from, configuration.frequencyRule));
    }
    final saved = await data.routines.save(
      Routine(
        configuration.metadata,
        title: configuration.title.trim(),
        targetType: goal.type,
        targetAmount:
            goal.type == RoutineTargetType.count ||
                goal.type == RoutineTargetType.frequency
            ? goal.amount
            : null,
        targetDuration: goal.type == RoutineTargetType.duration
            ? goal.duration
            : null,
        checklist: goal.type == RoutineTargetType.checklist ? names : const [],
        categoryId: configuration.categoryId,
        frequencyRule: configuration.frequencyRule,
        cadenceHistory: history,
        preferredTime: configuration.preferredTime,
        timeMode: configuration.timeMode,
      ),
    );
    if (reminders != null) await _saveReminders(data, saved.id, reminders);
    return saved;
  });

  Future<List<ReminderRule>> reminders(String id) async =>
      _routineReminders(await openStore(), id);

  Future<List<ReminderRule>> _routineReminders(
    PlannerData data,
    String id,
  ) async => (await data.reminderRules.all())
      .where(
        (row) =>
            row.target == (kind: RecordKind.routine, id: id) &&
            row.anchor == ReminderAnchor.start,
      )
      .toList();

  Future<void> _saveReminders(
    PlannerData data,
    String id,
    Set<Duration> values,
  ) async {
    final left = {...values};
    final target = (kind: RecordKind.routine, id: id);
    for (final rule in await _routineReminders(data, id)) {
      if (!left.remove(rule.offset)) {
        await data.softDelete((kind: RecordKind.reminderRule, id: rule.id));
      } else if (!rule.enabled) {
        await data.reminderRules.save(
          ReminderRule(
            rule.metadata,
            target: target,
            anchor: ReminderAnchor.start,
            offset: rule.offset,
            enabled: true,
          ),
        );
      }
    }
    for (final offset in left) {
      await data.reminderRules.save(
        ReminderRule(
          RecordMetadata.create(),
          target: target,
          anchor: ReminderAnchor.start,
          offset: offset,
          enabled: true,
        ),
      );
    }
  }

  Future<RoutineOccurrence> schedule(
    String id,
    DateTime date,
    DateTime start,
    DateTime end, {
    TimeMode mode = TimeMode.localWallTime,
    Set<ScheduleWarning> approved = const {},
  }) async {
    if (!civilTime(start).isBefore(civilTime(end))) {
      throw const RoutineIssue('Waktu selesai harus setelah waktu mulai.');
    }
    final calendar = await openCalendar();
    final zone = calendar.zones;
    final selectedZone = mode == TimeMode.localWallTime
        ? zone.deviceId
        : zone.displayId;
    final schedule = zone.interval(start, end, selectedZone, mode);
    return (await openStore()).transaction((data) async {
      final row = await _occurrence(data, id, date);
      final records = await _RoutineData.read(data);
      if (row.status != ActivityStatus.planned ||
          records.logs.containsKey(row.id) ||
          records.timers.containsKey(row.id) ||
          (row.schedule != null &&
              !_effective(row.schedule!).start.instant.isAfter(now()))) {
        throw const RoutineIssue(
          'Jadwal dengan progres atau riwayat sudah dikunci.',
        );
      }
      final warnings = await calendar.intervalWarnings(
        data,
        schedule,
        excludeId: row.id,
      );
      if (!approved.containsAll(warnings)) {
        throw ActivityWarnings(warnings.toList());
      }
      return data.routineOccurrences.save(
        _copyOccurrence(row, schedule: schedule),
      );
    });
  }

  ScheduledInterval _effective(ScheduledInterval schedule) {
    if (schedule.start.mode == TimeMode.originalZone) return schedule;
    final zone = zones;
    return zone.interval(
      DateTime.parse(schedule.start.localWallTime!),
      DateTime.parse(schedule.end.localWallTime!),
      zone.deviceId,
      TimeMode.localWallTime,
    );
  }

  Future<void> check(
    String id,
    DateTime day,
    String item,
    bool checked,
  ) async => (await openStore()).transaction((data) async {
    _requireActualDay(day);
    final row = await _occurrence(data, id, day);
    final goal = row.goal!;
    if (goal.type != RoutineTargetType.checklist ||
        !goal.checklist.contains(item)) {
      throw const RoutineIssue('Item checklist tidak tersedia.');
    }
    final items = {...row.checkedItems};
    if (checked) {
      items.add(item);
    } else {
      items.remove(item);
    }
    await data.routineOccurrences.save(
      _copyOccurrence(row, checked: items.toList()),
    );
  });

  Future<void> setCount(String id, DateTime day, int count) async =>
      (await openStore()).transaction((data) async {
        _requireActualDay(day);
        final row = await _occurrence(data, id, day);
        final type = row.goal!.type;
        if ((type != RoutineTargetType.count &&
                type != RoutineTargetType.frequency) ||
            count < 0) {
          throw const RoutineIssue('Masukkan jumlah aktual yang valid.');
        }
        await data.routineOccurrences.save(_copyOccurrence(row, count: count));
      });

  Future<void> recordDuration(
    String id,
    DateTime day,
    Duration duration,
  ) async => (await openStore()).transaction((data) async {
    _requireActualDay(day);
    final row = await _occurrence(data, id, day);
    if (duration <= Duration.zero ||
        row.goal!.type != RoutineTargetType.duration) {
      throw const RoutineIssue('Masukkan durasi aktual lebih dari nol.');
    }
    final current = now().toUtc();
    await data.timeLogs.save(
      TimeLog(
        RecordMetadata.create(),
        target: _target(row),
        actualDuration: duration,
        recordedAt: current,
        source: TimeLogSource.manual,
      ),
    );
    final records = await _RoutineData.read(data);
    await _syncGoal(
      data,
      row,
      records.timers[row.id],
      records,
      current,
      await sampleTimerClock(),
    );
  });

  Future<void> confirm(String id, DateTime day, ActivityStatus status) async =>
      (await openStore()).transaction((data) async {
        _requireActualDay(day);
        final row = await _occurrence(data, id, day);
        if (status != ActivityStatus.completed &&
            status != ActivityStatus.skipped) {
          throw const RoutineIssue('Status rutinitas tidak tersedia.');
        }
        if (row.status != ActivityStatus.planned) throw StaleRecord(row.id);
        await data.routineOccurrences.save(
          _copyOccurrence(row, status: status),
        );
      });

  Future<void> start(String id, DateTime day, {String? resumeId}) async =>
      (await openStore()).transaction((data) async {
        if (resumeId == null && civilDate(day) != today) {
          throw const RoutineIssue('Mulai timer pada tanggal hari ini.');
        }
        final row = await _occurrence(data, id, day);
        if (row.goal!.type != RoutineTargetType.duration) {
          throw const RoutineIssue('Timer tersedia untuk target durasi.');
        }
        final records = await _RoutineData.read(data);
        final current = now().toUtc();
        final previous = records.timers[row.id];
        if (resumeId != null && previous?.id != resumeId) {
          throw StaleRecord(row.id);
        }
        if (previous?.runningSince != null) return;
        final clock = await sampleTimerClock();
        final timer = RoutineTimer(
          id: previous?.id ?? RecordMetadata.create().id,
          occurrenceId: row.id,
          accumulated: previous?.accumulated ?? Duration.zero,
          runningSince: current,
          startedOnDevice: clock,
        );
        await data.saveRoutineTimer(timer);
        await _syncGoal(data, row, timer, records, current, clock);
      });

  Future<void> pause(RoutineTimer timer) async =>
      (await openStore()).transaction((data) async {
        final row = await data.routineOccurrences.find(timer.occurrenceId);
        final records = await _RoutineData.read(data);
        final active = records.timers[timer.occurrenceId];
        if (row == null || active == null || active.id != timer.id) {
          throw StaleRecord(timer.id);
        }
        if (active.runningSince == null) return;
        final current = now().toUtc();
        final clock = await sampleTimerClock();
        final paused = RoutineTimer(
          id: active.id,
          occurrenceId: active.occurrenceId,
          accumulated: active.elapsedAt(current, clock),
        );
        await data.saveRoutineTimer(paused);
        await _syncGoal(data, row, paused, records, current, clock);
      });

  Future<void> stop(RoutineTimer timer) async =>
      (await openStore()).transaction((data) async {
        final row = await data.routineOccurrences.find(timer.occurrenceId);
        final records = await _RoutineData.read(data);
        final active = records.timers[timer.occurrenceId];
        if (active == null) return;
        if (row == null || active.id != timer.id) throw StaleRecord(timer.id);
        await _finishTimer(data, row, active, records, now().toUtc());
      });

  Future<void> _finishTimer(
    PlannerData data,
    RoutineOccurrence row,
    RoutineTimer active,
    _RoutineData records,
    DateTime current,
  ) async {
    final clock = await sampleTimerClock();
    await _syncGoal(data, row, active, records, current, clock);
    final elapsed = active.elapsedAt(current, clock);
    if (elapsed > Duration.zero) {
      await data.timeLogs.save(
        TimeLog(
          RecordMetadata(id: active.id),
          target: _target(row),
          actualDuration: elapsed,
          recordedAt: current,
          source: TimeLogSource.timer,
        ),
      );
    }
    await data.removeRoutineTimer(row.id);
    if (records.goalEvents[row.id]?.reachedAt == null) {
      await data.removeRoutineGoalEvent(row.id);
    }
  }

  Future<void> delete(Routine routine) async =>
      (await openStore()).transaction((data) async {
        if ((await data.routines.find(routine.id))?.metadata.revision !=
            routine.metadata.revision) {
          throw StaleRecord(routine.id);
        }
        final records = await _RoutineData.read(data);
        final current = now().toUtc();
        for (final row in records.occurrences.where(
          (row) => row.routineId == routine.id,
        )) {
          if (records.timers[row.id] case final timer?) {
            await _finishTimer(data, row, timer, records, current);
          }
        }
        await data.softDelete((kind: RecordKind.routine, id: routine.id));
      });

  Future<List<({String title, DateTime deletedAt})>> trash() async =>
      (await openStore()).transaction((data) async {
        final deleted = {
          for (final row in await data.trashEntries.all())
            if (row.target.kind == RecordKind.routine && row.restoredAt == null)
              row.target.id: row.deletedAt,
        };
        return [
          for (final row in await data.routines.all(includeDeleted: true))
            if (deleted[row.id] case final deletedAt?)
              (title: row.title, deletedAt: deletedAt),
        ];
      });

  Future<List<RoutineGoalEvent>> reconcileGoals() async =>
      (await openStore()).transaction((data) async {
        final records = await _RoutineData.read(data);
        final current = now().toUtc();
        final clock = records.timers.isEmpty ? null : await sampleTimerClock();
        for (final row in records.occurrences) {
          final timer = records.timers[row.id];
          if (timer == null) continue;
          final aligned = timer.reanchorWallTime(current, clock);
          if (!identical(aligned, timer)) await data.saveRoutineTimer(aligned);
          if (records.goalEvents[row.id]?.reachedAt == null) {
            await _syncGoal(data, row, aligned, records, current, clock);
          }
        }
        return records.goalEvents.values.toList();
      });

  Future<void> _syncGoal(
    PlannerData data,
    RoutineOccurrence row,
    RoutineTimer? timer,
    _RoutineData records,
    DateTime current,
    TimerClockSample? clock,
  ) async {
    final target = row.goal?.duration;
    if (row.goal?.type != RoutineTargetType.duration || target == null) return;
    final existing = records.goalEvents[row.id];
    if (existing?.reachedAt != null) return;
    final logged = (records.logs[row.id] ?? const <TimeLog>[]).fold<Duration>(
      Duration.zero,
      (total, log) => total + log.actualDuration,
    );
    final remaining =
        target - logged - (timer?.elapsedAt(current, clock) ?? Duration.zero);
    final runningSince = timer?.runningSince;
    final DateTime due;
    if (remaining <= Duration.zero) {
      final projected = runningSince == null ? current : current.add(remaining);
      due =
          existing != null &&
              !existing.dueAt.isAfter(current) &&
              (runningSince == null ||
                  existing.dueAt.difference(projected).abs() <
                      const Duration(seconds: 1))
          ? existing.dueAt
          : projected;
    } else if (runningSince != null) {
      due = current.add(remaining);
    } else {
      if (existing != null) {
        await data.removeRoutineGoalEvent(row.id);
        records.goalEvents.remove(row.id);
      }
      return;
    }
    final reached = !due.isAfter(current) ? current : null;
    if (reached == null &&
        existing != null &&
        due.difference(existing.dueAt).abs() < const Duration(seconds: 1)) {
      return;
    }
    final event = RoutineGoalEvent(row.id, due, reachedAt: reached);
    await data.saveRoutineGoalEvent(event);
    records.goalEvents[row.id] = event;
  }

  void _requireActualDay(DateTime day) {
    if (civilDate(day).isAfter(today)) {
      throw const RoutineIssue(
        'Progres aktual belum bisa dicatat untuk tanggal mendatang.',
      );
    }
  }

  Future<RoutineOccurrence> _occurrence(
    PlannerData data,
    String id,
    DateTime day,
  ) async {
    final routine = await data.routines.find(id);
    if (routine == null) throw StaleRecord(id);
    final key = civilKey(day);
    final row = (await data.routineOccurrences.all())
        .where((row) => row.routineId == id && row.day.value == key)
        .firstOrNull;
    if (row != null) {
      return row.goal == null
          ? data.routineOccurrences.save(
              _copyOccurrence(row, goal: routine.goal),
            )
          : row;
    }
    return data.routineOccurrences.save(
      RoutineOccurrence(
        RecordMetadata.create(),
        routineId: id,
        day: LocalDate.parse(key),
        goal: routine.goal,
      ),
    );
  }
}

RecordRef _target(RoutineOccurrence row) =>
    (kind: RecordKind.routineOccurrence, id: row.id);

RoutineOccurrence _copyOccurrence(
  RoutineOccurrence row, {
  RoutineGoal? goal,
  ScheduledInterval? schedule,
  ActivityStatus? status,
  int? count,
  List<String>? checked,
}) => RoutineOccurrence(
  row.metadata,
  routineId: row.routineId,
  day: row.day,
  goal: goal ?? row.goal,
  schedule: schedule ?? row.schedule,
  status: status ?? row.status,
  recordedCount: count ?? row.recordedCount,
  checkedItems: checked ?? row.checkedItems,
);

class _RoutineData {
  _RoutineData(this.occurrences, this.timers, this.logs, this.goalEvents);
  final List<RoutineOccurrence> occurrences;
  final Map<String, RoutineTimer> timers;
  final Map<String, List<TimeLog>> logs;
  final Map<String, RoutineGoalEvent> goalEvents;

  static Future<_RoutineData> read(PlannerData data) async {
    final logs = <String, List<TimeLog>>{};
    for (final log in await data.timeLogs.all()) {
      if (log.target.kind == RecordKind.routineOccurrence) {
        (logs[log.target.id] ??= []).add(log);
      }
    }
    return _RoutineData(
      await data.routineOccurrences.all(),
      {for (final row in await data.routineTimers()) row.occurrenceId: row},
      logs,
      {for (final row in await data.routineGoalEvents()) row.occurrenceId: row},
    );
  }
}
