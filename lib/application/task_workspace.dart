import 'package:routina/application/activity_calendar.dart';
import 'package:routina/application/calendar_zones.dart';
import 'package:routina/application/smart_scheduling.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';
import 'package:routina/domain/preview_event.dart';

class TaskView {
  const TaskView({
    required this.task,
    required this.subtasks,
    required this.sessions,
    required this.logs,
    required this.reminders,
    required this.deadline,
    required this.displayDeadline,
    required this.upcoming,
    required this.overdue,
  });

  final Task task;
  final List<Subtask> subtasks;
  final List<WorkSession> sessions;
  final List<TimeLog> logs;
  final List<ReminderRule> reminders;
  final DateTime? deadline;
  final DateTime? displayDeadline;
  final List<WorkSession> upcoming;
  final bool overdue;

  bool get completed => task.status == ActivityStatus.completed;
  int get checked => subtasks.where((row) => row.checked).length;
  double? get progress => subtasks.isEmpty ? null : checked / subtasks.length;
  Duration get planned => sessions
      .where((row) => row.status != ActivityStatus.cancelled)
      .fold(Duration.zero, (sum, row) => sum + row.scheduledDuration);
  Duration? get actual => logs.isEmpty
      ? null
      : logs.fold<Duration>(
          Duration.zero,
          (sum, row) => sum + row.actualDuration,
        );
}

typedef SubtaskEdit = ({Subtask? existing, String title});

class TaskIssue implements Exception {
  const TaskIssue(this.message);
  final String message;
}

class PastTaskDeadline implements Exception {
  const PastTaskDeadline();
}

class SessionWarnings implements Exception {
  const SessionWarnings(this.schedule, {this.afterDeadline = false});
  final Set<ScheduleWarning> schedule;
  final bool afterDeadline;

  bool covers(SessionWarnings latest) =>
      (!latest.afterDeadline || afterDeadline) &&
      schedule.containsAll(latest.schedule);
}

class TaskWorkspace {
  const TaskWorkspace({
    required this.openStore,
    required this.openCalendar,
    required this.readZones,
    required this.now,
  });

  final Future<PlannerStore> Function() openStore;
  final Future<ActivityCalendar> Function() openCalendar;
  final CalendarZones Function() readZones;
  final DateTime Function() now;

  SmartScheduling get scheduling => SmartScheduling(
    openStore: openStore,
    openCalendar: openCalendar,
    now: now,
  );

  CalendarZones get zones => readZones();
  DateTime get today => civilDate(zones.wall(now(), zones.displayId));

  DateTime? deadlineInstant(Task task) {
    final time = task.deadline;
    if (time == null) return null;
    return task.status != ActivityStatus.completed
        ? zones.effectiveTime(time)
        : time.instant;
  }

  ScheduledInterval effectiveSession(WorkSession session) {
    final schedule = session.schedule;
    if (session.status != ActivityStatus.planned ||
        schedule.start.mode != TimeMode.localWallTime) {
      return schedule;
    }
    final zone = zones;
    return zone.interval(
      DateTime.parse(schedule.start.localWallTime!),
      DateTime.parse(schedule.end.localWallTime!),
      zone.deviceId,
      TimeMode.localWallTime,
    );
  }

  bool canMove(WorkSession session, Iterable<TimeLog> logs) =>
      session.status == ActivityStatus.planned &&
      effectiveSession(session).start.instant.isAfter(now()) &&
      !logs.any((row) => row.target.id == session.id);

  Future<List<TaskView>> list() async =>
      (await openStore()).transaction((data) async {
        final tasks = await data.tasks.all();
        final subtasks = await data.subtasks.all();
        final sessions = await data.workSessions.all();
        final children = <String, List<Subtask>>{};
        final schedules = <String, List<WorkSession>>{};
        for (final row in subtasks) {
          (children[row.taskId] ??= []).add(row);
        }
        for (final row in sessions) {
          (schedules[row.taskId] ??= []).add(row);
        }
        return [
          for (final row in tasks)
            _view(row, children[row.id] ?? [], schedules[row.id] ?? []),
        ];
      });

  Future<TaskView?> read(String id) async =>
      (await openStore()).transaction((data) async {
        final task = await data.tasks.find(id);
        if (task == null) return null;
        final sessions = await _sessions(data, id);
        final sessionIds = sessions.map((row) => row.id).toSet();
        return _view(
          task,
          await _subtasks(data, id),
          sessions,
          logs: (await data.timeLogs.all())
              .where(
                (row) =>
                    row.target.kind == RecordKind.workSession &&
                    sessionIds.contains(row.target.id),
              )
              .toList(),
          reminders: (await data.reminderRules.all())
              .where(
                (row) =>
                    row.target == (kind: RecordKind.task, id: id) &&
                    row.anchor == ReminderAnchor.deadline,
              )
              .toList(),
        );
      });

  Future<List<({String title, DateTime deletedAt})>> trash() async =>
      (await openStore()).transaction((data) async {
        final deleted = {
          for (final row in await data.trashEntries.all())
            if (row.target.kind == RecordKind.task && row.restoredAt == null)
              row.target.id: row.deletedAt,
        };
        return [
          for (final task in await data.tasks.all(includeDeleted: true))
            if (deleted[task.id] case final deletedAt?)
              (title: task.title, deletedAt: deletedAt),
        ];
      });

  RecordRef _target(Task task) => (kind: RecordKind.task, id: task.id);

  TaskView _view(
    Task task,
    List<Subtask> subtasks,
    List<WorkSession> sessions, {
    List<TimeLog> logs = const [],
    List<ReminderRule> reminders = const [],
  }) {
    final current = now().toUtc();
    final deadline = deadlineInstant(task);
    final zone = zones;
    subtasks.sort((a, b) => a.order.compareTo(b.order));
    sessions.sort(
      (a, b) => effectiveSession(
        a,
      ).start.instant.compareTo(effectiveSession(b).start.instant),
    );
    return TaskView(
      task: task,
      subtasks: subtasks,
      sessions: sessions,
      logs: logs,
      reminders: reminders,
      deadline: deadline,
      displayDeadline: deadline == null
          ? null
          : zone.wall(deadline, zone.displayId),
      upcoming: [
        for (final row in sessions)
          if (row.status == ActivityStatus.planned &&
              effectiveSession(row).start.instant.isAfter(current))
            row,
      ],
      overdue:
          task.status != ActivityStatus.completed &&
          deadline != null &&
          deadline.isBefore(current),
    );
  }

  Future<Task> save({
    Task? previous,
    required String title,
    required ZonedTime deadline,
    String? categoryId,
    String? description,
    String? priority,
    Duration? estimate,
    required List<SubtaskEdit> subtasks,
    Set<Duration>? reminders,
    bool acceptPast = false,
  }) async => (await openStore()).transaction((data) async {
    if (title.trim().isEmpty ||
        subtasks.any((row) => row.title.trim().isEmpty) ||
        (estimate != null && estimate <= Duration.zero)) {
      throw const TaskIssue('Periksa judul, subtugas, dan estimasi tugas.');
    }
    _checkDeadline(deadline, previous?.deadline, acceptPast);
    final saved = await data.tasks.save(
      Task(
        previous?.metadata ?? RecordMetadata.create(),
        title: title.trim(),
        deadline: deadline,
        categoryId: categoryId,
        description: description?.trim(),
        priority: priority,
        initialEstimate: estimate,
        status: previous?.status ?? ActivityStatus.planned,
        confirmedRemainingEstimate: previous?.initialEstimate == estimate
            ? previous?.confirmedRemainingEstimate
            : null,
        remainingConfirmedAt: previous?.initialEstimate == estimate
            ? previous?.remainingConfirmedAt
            : null,
        remainingActualAtConfirmation: previous?.initialEstimate == estimate
            ? previous?.remainingActualAtConfirmation
            : null,
        sessionLimits: previous?.sessionLimits,
      ),
    );
    final submittedIds = <String>{};
    for (final (order, field) in subtasks.indexed) {
      final old = field.existing;
      if (old != null &&
          (old.taskId != saved.id || !submittedIds.add(old.id))) {
        throw const TaskIssue('Subtugas yang dipilih tidak tersedia.');
      }
      final name = field.title.trim();
      if (old == null || old.title != name || old.order != order) {
        final savedSubtask = await data.subtasks.save(
          Subtask(
            old?.metadata ?? RecordMetadata.create(),
            taskId: saved.id,
            title: name,
            order: order,
            checked: old?.checked ?? false,
          ),
        );
        submittedIds.add(savedSubtask.id);
      }
    }
    if (previous != null) {
      for (final old in await _subtasks(data, saved.id)) {
        if (!submittedIds.contains(old.id)) {
          await data.softDelete((kind: RecordKind.subtask, id: old.id));
        }
      }
    }
    if (reminders != null) {
      final target = _target(saved);
      final rules = (await data.reminderRules.all()).where(
        (row) => row.target == target && row.anchor == ReminderAnchor.deadline,
      );
      final unprocessed = {...reminders};
      for (final rule in rules) {
        if (!unprocessed.remove(rule.offset)) {
          await data.softDelete((kind: RecordKind.reminderRule, id: rule.id));
        } else if (!rule.enabled) {
          await data.reminderRules.save(
            ReminderRule(
              rule.metadata,
              target: target,
              anchor: ReminderAnchor.deadline,
              offset: rule.offset,
              enabled: true,
            ),
          );
        }
      }
      for (final offset in unprocessed) {
        await data.reminderRules.save(
          ReminderRule(
            RecordMetadata.create(),
            target: target,
            anchor: ReminderAnchor.deadline,
            offset: offset,
            enabled: true,
          ),
        );
      }
    }
    return saved;
  });

  void _checkDeadline(ZonedTime deadline, ZonedTime? old, bool acceptPast) {
    final unchanged =
        old != null &&
        old.instant == deadline.instant &&
        old.mode == deadline.mode &&
        old.zoneId == deadline.zoneId &&
        old.localWallTime == deadline.localWallTime;
    if (!unchanged &&
        !acceptPast &&
        zones.effectiveTime(deadline).isBefore(now())) {
      throw const PastTaskDeadline();
    }
  }

  Future<Task> moveDeadline(
    Task previous,
    ZonedTime deadline, {
    bool acceptPast = false,
  }) async => (await openStore()).transaction((data) async {
    _checkDeadline(deadline, previous.deadline, acceptPast);
    return data.tasks.save(_copyTask(previous, deadline: deadline));
  });

  Future<void> toggle(Subtask row, bool checked) async =>
      (await openStore()).transaction((data) async {
        final task = await data.tasks.find(row.taskId);
        if (task == null || task.status == ActivityStatus.completed) {
          throw StaleRecord(row.taskId);
        }
        await data.subtasks.save(
          Subtask(
            row.metadata,
            taskId: row.taskId,
            title: row.title,
            order: row.order,
            checked: checked,
          ),
        );
      });

  Future<void> delete(Task task) async =>
      (await openStore()).transaction((data) async {
        await _requireTask(data, task);
        await data.softDelete(_target(task));
      });

  Future<void> complete(
    Task task, {
    required Set<String> reviewedFutureIds,
    required bool cancelFuture,
  }) async => (await openStore()).transaction((data) async {
    await _requireTask(data, task);
    if (task.status == ActivityStatus.completed) return;
    final current = now().toUtc();
    final future = (await _sessions(data, task.id)).where(
      (row) =>
          row.status == ActivityStatus.planned &&
          effectiveSession(row).start.instant.isAfter(current),
    );
    if (!reviewedFutureIds.containsAll(future.map((row) => row.id))) {
      throw const TaskIssue(
        'Sesi mendatang berubah. Tinjau kembali sebelum menyelesaikan tugas.',
      );
    }
    if (cancelFuture) {
      final logged = (await data.timeLogs.all())
          .where((row) => row.target.kind == RecordKind.workSession)
          .map((row) => row.target.id)
          .toSet();
      for (final row in future) {
        if (logged.contains(row.id)) continue;
        await data.workSessions.save(
          _copySession(row, status: ActivityStatus.cancelled),
        );
      }
    }
    final original = task.deadline;
    final effective = deadlineInstant(task);
    await data.tasks.save(
      _copyTask(
        task,
        status: ActivityStatus.completed,
        deadline:
            original == null ||
                effective == null ||
                original.mode == TimeMode.originalZone
            ? original
            : ZonedTime(
                instant: effective,
                zoneId: zones.deviceId,
                mode: original.mode,
                localWallTime: original.localWallTime,
              ),
      ),
    );
  });

  Future<WorkSession> saveSession(
    String taskId,
    DateTime start,
    DateTime end, {
    WorkSession? previous,
    SessionWarnings approved = const SessionWarnings({}),
  }) async {
    final calendar = await openCalendar();
    final zone = calendar.zones;
    if (!civilTime(start).isBefore(civilTime(end))) {
      throw const TaskIssue('Waktu selesai harus setelah waktu mulai.');
    }
    final schedule = zone.interval(
      start,
      end,
      zone.displayId,
      TimeMode.originalZone,
    );
    return (await openStore()).transaction((data) async {
      final task = await data.tasks.find(taskId);
      if (task == null ||
          (previous == null && task.status == ActivityStatus.completed)) {
        throw StaleRecord(taskId);
      }
      if (!schedule.start.instant.isAfter(now())) {
        throw const TaskIssue('Pilih waktu mulai yang masih akan datang.');
      }
      if (previous != null) {
        await _requireMovableSession(data, taskId, previous);
      }
      final deadline = deadlineInstant(task);
      final warnings = SessionWarnings(
        await calendar.intervalWarnings(
          data,
          schedule,
          excludeId: previous?.id,
        ),
        afterDeadline:
            deadline != null && schedule.end.instant.isAfter(deadline),
      );
      if (!approved.covers(warnings)) throw warnings;
      return data.workSessions.save(
        previous == null
            ? WorkSession(
                RecordMetadata.create(),
                taskId: taskId,
                schedule: schedule,
              )
            : _copySession(previous, schedule: schedule),
      );
    });
  }

  Future<void> cancelSession(WorkSession session) async =>
      (await openStore()).transaction((data) async {
        await _requireMovableSession(data, session.taskId, session);
        await data.workSessions.save(
          _copySession(session, status: ActivityStatus.cancelled),
        );
      });

  Future<void> markSessionHeld(WorkSession session) async =>
      (await openStore()).transaction((data) async {
        final logged = (await data.timeLogs.all()).any(
          (row) => row.target == (kind: RecordKind.workSession, id: session.id),
        );
        final schedule = logged ? session.schedule : effectiveSession(session);
        if (session.status != ActivityStatus.planned ||
            schedule.end.instant.isAfter(now())) {
          throw const TaskIssue('Sesi belum berakhir.');
        }
        await data.workSessions.save(
          _copySession(
            session,
            schedule: schedule,
            status: ActivityStatus.completed,
          ),
        );
      });

  Future<void> logSessionTime(WorkSession previous, Duration duration) async =>
      (await openStore()).transaction((data) async {
        final row = await data.workSessions.find(previous.id);
        if (row == null ||
            row.metadata.revision != previous.metadata.revision) {
          throw StaleRecord(previous.id);
        }
        final current = now().toUtc();
        if (duration <= Duration.zero ||
            (row.status != ActivityStatus.planned &&
                row.status != ActivityStatus.completed) ||
            effectiveSession(row).end.instant.isAfter(current)) {
          throw const TaskIssue('Catat durasi positif setelah sesi berakhir.');
        }
        await data.timeLogs.save(
          TimeLog(
            RecordMetadata.create(),
            target: (kind: RecordKind.workSession, id: row.id),
            actualDuration: duration,
            recordedAt: current,
            source: TimeLogSource.manual,
          ),
        );
      });

  Future<void> _requireMovableSession(
    PlannerData data,
    String taskId,
    WorkSession previous,
  ) async {
    final session = await data.workSessions.find(previous.id);
    if (session == null ||
        session.taskId != taskId ||
        session.metadata.revision != previous.metadata.revision ||
        !canMove(session, await data.timeLogs.all())) {
      throw const TaskIssue(
        'Sesi sudah berubah, berlangsung, atau memiliki riwayat.',
      );
    }
  }

  Future<void> _requireTask(PlannerData data, Task task) async {
    if ((await data.tasks.find(task.id))?.metadata.revision !=
        task.metadata.revision) {
      throw StaleRecord(task.id);
    }
  }
}

Future<List<Subtask>> _subtasks(PlannerData data, String id) async =>
    (await data.subtasks.all()).where((row) => row.taskId == id).toList();

Future<List<WorkSession>> _sessions(PlannerData data, String id) async =>
    (await data.workSessions.all()).where((row) => row.taskId == id).toList();

Task _copyTask(Task task, {ZonedTime? deadline, ActivityStatus? status}) =>
    Task(
      task.metadata,
      title: task.title,
      description: task.description,
      deadline: deadline ?? task.deadline,
      categoryId: task.categoryId,
      priority: task.priority,
      status: status ?? task.status,
      initialEstimate: task.initialEstimate,
      confirmedRemainingEstimate: task.confirmedRemainingEstimate,
      remainingConfirmedAt: task.remainingConfirmedAt,
      remainingActualAtConfirmation: task.remainingActualAtConfirmation,
      sessionLimits: task.sessionLimits,
    );

WorkSession _copySession(
  WorkSession row, {
  ActivityStatus? status,
  ScheduledInterval? schedule,
}) => WorkSession(
  row.metadata,
  taskId: row.taskId,
  schedule: schedule ?? row.schedule,
  status: status ?? row.status,
  supersedesId: row.supersedesId,
  routineOccurrenceId: row.routineOccurrenceId,
);
