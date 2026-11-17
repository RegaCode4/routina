import 'package:flutter/foundation.dart' show mapEquals, setEquals;
import 'package:routina/application/activity_calendar.dart';
import 'package:routina/application/calendar_zones.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';
import 'package:routina/domain/scheduling_engine.dart';

enum ScheduleAction { add, reduce, replanConflicts, replanAll }

enum SchedulingProblem { estimate, deadline, limits, scope, adjustment }

class SchedulingInput implements Exception {
  const SchedulingInput(this.problem);
  final SchedulingProblem problem;
}

class SchedulingSession {
  const SchedulingSession(this.record, this.slot, {required this.movable});

  final WorkSession record;
  final SchedulingSlot slot;
  final bool movable;
}

class SchedulingReview {
  SchedulingReview._({
    required this.task,
    required this.zones,
    required this.deadline,
    required this.current,
    required this.hours,
    required this.preference,
    required this.limits,
    required this.buffer,
    required this.actual,
    required this.upcoming,
    required this.history,
    required this.conflicts,
    required this.logRevisions,
    required ActivityCalendar calendar,
  }) : _calendar = calendar;

  final Task task;
  final CalendarZones zones;
  final DateTime? deadline;
  final DateTime current;
  final Map<int, DailyHours> hours;
  final String preference;
  final SessionLimits? limits;
  final Duration buffer;
  final Duration actual;
  final List<SchedulingSession> upcoming;
  final List<SchedulingSession> history;
  final Map<String, List<BusyInterval>> conflicts;
  final Map<String, int> logRevisions;
  final ActivityCalendar _calendar;

  Duration? get suggestedRemaining {
    final initial = task.initialEstimate;
    if (initial == null) return null;
    final remaining = initial - actual;
    return remaining < Duration.zero ? Duration.zero : remaining;
  }

  Duration? get confirmedRemaining =>
      task.remainingActualAtConfirmation == actual
      ? task.confirmedRemainingEstimate
      : null;

  Duration get scheduled => totalSlotDuration(upcoming.map((row) => row.slot));
}

class SchedulingProposal {
  SchedulingProposal._(
    this.review,
    this.action,
    this.limits,
    List<SchedulingSession> removals,
    List<SchedulingSlot> additions,
    List<SchedulingSlot> suggested,
  ) : removals = List.unmodifiable(removals),
      additions = List.unmodifiable(additions),
      _suggested = List.unmodifiable(suggested);

  final SchedulingReview review;
  final ScheduleAction action;
  final SessionLimits limits;
  final List<SchedulingSession> removals;
  final List<SchedulingSlot> additions;
  final List<SchedulingSlot> _suggested;

  Duration get total =>
      review.scheduled -
      totalSlotDuration(removals.map((row) => row.slot)) +
      totalSlotDuration(additions);
}

typedef SchedulingOutcome = ({
  SchedulingProposal? proposal,
  SlotSearchResult result,
});

class SmartScheduling {
  const SmartScheduling({
    required this.openStore,
    required this.openCalendar,
    required this.now,
  });

  final Future<PlannerStore> Function() openStore;
  final Future<ActivityCalendar> Function() openCalendar;
  final DateTime Function() now;

  Future<SchedulingReview> review(String taskId) =>
      _transaction((data, calendar) => _review(data, calendar, taskId));

  Future<void> confirmRemaining(
    SchedulingReview reviewed,
    Duration remaining,
  ) => _transaction((data, calendar) async {
    if (remaining.isNegative) {
      throw const SchedulingInput(SchedulingProblem.estimate);
    }
    final latest = await _review(data, calendar, reviewed.task.id);
    _requireSameEstimate(reviewed, latest);
    await data.tasks.save(
      _updatedTask(
        latest.task,
        remaining: remaining,
        actual: latest.actual,
        confirmedAt: now().toUtc(),
      ),
    );
  });

  Future<SchedulingOutcome> propose(
    SchedulingReview reviewed,
    ScheduleAction action,
    SessionLimits? limits,
  ) => _transaction((data, calendar) async {
    final latest = await _review(data, calendar, reviewed.task.id);
    _requireSameEstimate(reviewed, latest);
    if (limits == null && reviewed.limits != latest.limits) {
      throw StaleRecord(reviewed.task.id);
    }
    if (action == ScheduleAction.replanConflicts &&
        !_sameSessions(reviewed.upcoming, latest.upcoming)) {
      throw StaleRecord(reviewed.task.id);
    }
    if (action == ScheduleAction.replanConflicts &&
        !setEquals(
          reviewed.conflicts.keys.toSet(),
          latest.conflicts.keys.toSet(),
        )) {
      throw StaleRecord(reviewed.task.id);
    }
    final effectiveLimits = limits ?? latest.limits;
    if (effectiveLimits == null ||
        effectiveLimits.minimumMinutes < 1 ||
        effectiveLimits.minimumMinutes > 1440 ||
        effectiveLimits.maximumSessions < 1) {
      throw const SchedulingInput(SchedulingProblem.limits);
    }
    return _find(data, latest, action, effectiveLimits);
  });

  Future<void> approve(SchedulingProposal proposal) => _transaction((
    data,
    calendar,
  ) async {
    final reviewed = proposal.review;
    final latest = await _review(data, calendar, reviewed.task.id);
    _requireSameEstimate(reviewed, latest);
    final deadline = latest.deadline;
    if (deadline == null ||
        !deadline.isAfter(latest.current) ||
        latest.deadline != reviewed.deadline ||
        latest.zones.deviceId != reviewed.zones.deviceId ||
        latest.zones.displayId != reviewed.zones.displayId ||
        latest.limits != reviewed.limits ||
        !_sameSessions(reviewed.upcoming, latest.upcoming)) {
      throw StaleRecord(reviewed.task.id);
    }
    final targets = _targets(latest, proposal.action);
    final reviewedTargets = _targets(reviewed, proposal.action);
    final removed = proposal.removals.map((row) => row.record.id).toSet();
    if (targets == null ||
        reviewedTargets == null ||
        !_sameSessions(reviewedTargets, targets) ||
        !targets.map((row) => row.record.id).toSet().containsAll(removed) ||
        latest.upcoming.length - removed.length + proposal.additions.length >
            proposal.limits.maximumSessions) {
      throw StaleRecord(reviewed.task.id);
    }
    final period = (start: nextSchedulingMinute(latest.current), end: deadline);
    final active = schedulingWindows(latest.zones, latest.hours, period);
    final busy = await _busy(
      data,
      latest,
      period,
      excluded: targets.map((row) => row.record.id).toSet(),
    );
    final minimum = Duration(minutes: proposal.limits.minimumMinutes);
    for (final slot in proposal._suggested) {
      if (slotDuration(slot) < minimum ||
          !active.any((window) => containsSlot(window, slot)) ||
          busy.any((entry) => _blocks(slot, entry, latest.buffer))) {
        throw StaleRecord(reviewed.task.id);
      }
      busy.add(_sessionBusy('', reviewed.task.title, slot, latest.buffer));
    }

    void requireFuture() {
      final current = now().toUtc();
      if (proposal._suggested.any((slot) => !slot.start.isAfter(current)) ||
          proposal.removals.any((row) => !row.slot.start.isAfter(current))) {
        throw StaleRecord(reviewed.task.id);
      }
    }

    requireFuture();
    final availablePredecessors = [...proposal.removals];
    for (final row in proposal.removals) {
      final old = row.record;
      await data.workSessions.save(
        WorkSession(
          old.metadata,
          taskId: old.taskId,
          schedule: old.schedule,
          status: ActivityStatus.cancelled,
          supersedesId: old.supersedesId,
          routineOccurrenceId: old.routineOccurrenceId,
        ),
      );
    }
    for (final slot in proposal.additions) {
      final corresponding = availablePredecessors.indexWhere(
        (row) => row.slot.start == slot.start,
      );
      final predecessor = corresponding >= 0
          ? availablePredecessors.removeAt(corresponding).record
          : proposal.action != ScheduleAction.reduce &&
                availablePredecessors.isNotEmpty
          ? availablePredecessors.removeAt(0).record
          : null;
      await data.workSessions.save(
        WorkSession(
          RecordMetadata.create(),
          taskId: latest.task.id,
          schedule: ScheduledInterval(
            ZonedTime(
              instant: slot.start,
              zoneId: latest.zones.displayId,
              mode: TimeMode.originalZone,
            ),
            ZonedTime(
              instant: slot.end,
              zoneId: latest.zones.displayId,
              mode: TimeMode.originalZone,
            ),
          ),
          supersedesId: predecessor?.id,
          routineOccurrenceId: predecessor?.routineOccurrenceId,
        ),
      );
    }
    // Advance the task revision for every successful approval, including
    // removal-only changes, so a proposal can never be replayed.
    await data.tasks.save(
      _updatedTask(
        latest.task,
        limits: proposal.limits == latest.limits ? null : proposal.limits,
      ),
    );
    requireFuture();
  });

  Future<SchedulingOutcome> _find(
    PlannerData data,
    SchedulingReview state,
    ScheduleAction action,
    SessionLimits limits,
  ) async {
    final remaining = state.confirmedRemaining;
    if (remaining == null) {
      throw const SchedulingInput(SchedulingProblem.estimate);
    }
    final deadline = state.deadline;
    if (deadline == null || !deadline.isAfter(state.current)) {
      throw const SchedulingInput(SchedulingProblem.deadline);
    }
    final targets = _targets(state, action);
    if (targets == null) {
      throw const SchedulingInput(SchedulingProblem.scope);
    }
    final replacedIds = targets.map((row) => row.record.id).toSet();
    final kept = state.upcoming.where(
      (row) => !replacedIds.contains(row.record.id),
    );
    final target = remaining - totalSlotDuration(kept.map((row) => row.slot));
    if ((action == ScheduleAction.add && target <= Duration.zero) ||
        (action == ScheduleAction.reduce && remaining >= state.scheduled) ||
        target.isNegative) {
      throw const SchedulingInput(SchedulingProblem.adjustment);
    }
    final maximum = limits.maximumSessions - kept.length;
    final minimum = Duration(minutes: limits.minimumMinutes);
    if (maximum < 0) {
      return (
        proposal: null,
        result: const SlotSearchResult(failure: SlotFailure.maximum),
      );
    }

    final period = (start: nextSchedulingMinute(state.current), end: deadline);
    final hours = schedulingWindows(state.zones, state.hours, period);
    final busy = await _busy(data, state, period, excluded: replacedIds);
    final SlotSearchResult result;
    if (action == ScheduleAction.reduce) {
      // A reduction may trim or drop a slot while preserving its start.
      final eligible = [
        for (final row in targets)
          ?_clearPrefix(row.slot, hours, busy, state.buffer),
      ];
      result = trimWorkSlots(
        windows: eligible,
        duration: target,
        minimum: minimum,
        maximum: maximum,
        separation: state.buffer * 2,
      );
    } else {
      result = findWorkSlots(
        active: hours,
        busy: busy,
        duration: target,
        minimum: minimum,
        maximum: maximum,
        before: state.buffer,
        after: state.buffer,
        preferred: preferredSchedulingWindows(
          state.zones,
          state.hours,
          state.preference,
          period,
        ),
      );
    }
    if (result.failure != null) return (proposal: null, result: result);
    final additions = [...result.slots];
    final removals = targets
        .where((row) => !additions.remove(row.slot))
        .toList();
    if (removals.isEmpty && additions.isEmpty) {
      throw const SchedulingInput(SchedulingProblem.adjustment);
    }
    return (
      proposal: SchedulingProposal._(
        state,
        action,
        limits,
        removals,
        additions,
        result.slots,
      ),
      result: result,
    );
  }

  List<SchedulingSession>? _targets(
    SchedulingReview state,
    ScheduleAction action,
  ) {
    final movable = state.upcoming.where((row) => row.movable);
    return switch (action) {
      ScheduleAction.add => const [],
      ScheduleAction.reduce || ScheduleAction.replanAll => movable.toList(),
      ScheduleAction.replanConflicts
          when state.conflicts.isEmpty ||
              state.upcoming.any(
                (row) =>
                    !row.movable && state.conflicts.containsKey(row.record.id),
              ) =>
        null,
      ScheduleAction.replanConflicts =>
        movable
            .where((row) => state.conflicts.containsKey(row.record.id))
            .toList(),
    };
  }

  Future<List<BusyInterval>> _busy(
    PlannerData data,
    SchedulingReview review,
    SchedulingSlot period, {
    Set<String> excluded = const {},
  }) async => [
    if (period.start.isBefore(period.end))
      for (final entry in await review._calendar.busyIntervals(
        data,
        period.start,
        period.end,
        sessionBuffer: review.buffer,
      ))
        if (!excluded.contains(entry.id)) entry,
  ];

  Future<SchedulingReview> _review(
    PlannerData data,
    ActivityCalendar source,
    String taskId,
  ) async {
    final task = await data.tasks.find(taskId);
    if (task == null) throw StaleRecord(taskId);
    final calendar = await source.withLatestProfile(data);
    final profile = calendar.profile;
    final zones = calendar.zones;
    final current = now().toUtc();
    final rows = (await data.workSessions.all()).where(
      (row) => row.taskId == taskId,
    );
    final ids = rows.map((row) => row.id).toSet();
    final logs = (await data.timeLogs.all())
        .where(
          (row) =>
              row.target.kind == RecordKind.workSession &&
              ids.contains(row.target.id),
        )
        .toList();
    final logTargets = logs.map((row) => row.target.id).toSet();
    final scheduled =
        [
          for (final row in rows)
            if (row.status != ActivityStatus.cancelled)
              _project(
                row,
                zones,
                current,
                logged: logTargets.contains(row.id),
              ),
        ]..sort((a, b) {
          final start = a.slot.start.compareTo(b.slot.start);
          return start == 0 ? a.record.id.compareTo(b.record.id) : start;
        });
    bool upcoming(SchedulingSession row) =>
        row.record.status == ActivityStatus.planned &&
        row.slot.start.isAfter(current);
    final future = scheduled.where(upcoming).toList();
    final buffer = profile?.defaultBuffer ?? Duration.zero;
    final busy = future.isEmpty
        ? const <BusyInterval>[]
        : await calendar.busyIntervals(
            data,
            future.first.slot.start,
            future
                .map((row) => row.slot.end)
                .reduce((a, b) => a.isAfter(b) ? a : b),
            sessionBuffer: buffer,
          );
    final conflicts = <String, List<BusyInterval>>{};
    for (final session in future) {
      final blockers =
          busy
              .where(
                (entry) =>
                    entry.id != session.record.id &&
                    _blocks(session.slot, entry, buffer),
              )
              .toList()
            ..sort((a, b) => a.slot.start.compareTo(b.slot.start));
      if (blockers.isNotEmpty) {
        conflicts[session.record.id] = List.unmodifiable(blockers);
      }
    }
    return SchedulingReview._(
      task: task,
      zones: zones,
      deadline: task.deadline == null
          ? null
          : zones.effectiveTime(task.deadline!),
      current: current,
      hours: Map.unmodifiable(calendar.schedulingHours),
      preference: calendar.schedulingPreference(task.categoryId),
      limits: task.sessionLimits ?? profile?.preferences.sessionLimits,
      buffer: buffer,
      actual: logs.fold(
        Duration.zero,
        (total, row) => total + row.actualDuration,
      ),
      upcoming: List.unmodifiable(future),
      history: List.unmodifiable(scheduled.where((row) => !upcoming(row))),
      conflicts: Map.unmodifiable(conflicts),
      logRevisions: Map.unmodifiable({
        for (final row in logs) row.id: row.metadata.revision,
      }),
      calendar: calendar,
    );
  }

  Future<T> _transaction<T>(
    Future<T> Function(PlannerData, ActivityCalendar) action,
  ) async {
    final store = await openStore();
    final calendar = await openCalendar();
    return store.transaction((data) => action(data, calendar));
  }
}

SchedulingSlot? _clearPrefix(
  SchedulingSlot slot,
  List<SchedulingSlot> hours,
  List<BusyInterval> busy,
  Duration buffer,
) {
  final window = hours
      .where(
        (row) =>
            !slot.start.isBefore(row.start) && slot.start.isBefore(row.end),
      )
      .firstOrNull;
  if (window == null) return null;
  var end = window.end.isBefore(slot.end) ? window.end : slot.end;
  for (final entry in busy) {
    final blocked = bufferedSlot(entry, before: buffer, after: buffer);
    if (blocked.end.isAfter(slot.start) && blocked.start.isBefore(end)) {
      end = blocked.start;
    }
  }
  return slot.start.isBefore(end) ? (start: slot.start, end: end) : null;
}

void _requireSameEstimate(SchedulingReview reviewed, SchedulingReview latest) {
  if (latest.task.status != ActivityStatus.planned ||
      latest.task.metadata.revision != reviewed.task.metadata.revision ||
      !mapEquals(latest.logRevisions, reviewed.logRevisions)) {
    throw StaleRecord(reviewed.task.id);
  }
}

bool _sameSessions(List<SchedulingSession> a, List<SchedulingSession> b) =>
    a.length == b.length &&
    a.indexed.every((entry) {
      final (i, row) = entry;
      return row.record.id == b[i].record.id &&
          row.record.metadata.revision == b[i].record.metadata.revision &&
          row.slot == b[i].slot &&
          row.movable == b[i].movable;
    });

SchedulingSession _project(
  WorkSession row,
  CalendarZones zones,
  DateTime current, {
  required bool logged,
}) {
  var schedule = row.schedule;
  if (row.status == ActivityStatus.planned &&
      !logged &&
      schedule.start.mode == TimeMode.localWallTime) {
    schedule = zones.interval(
      DateTime.parse(schedule.start.localWallTime!),
      DateTime.parse(schedule.end.localWallTime!),
      zones.deviceId,
      TimeMode.localWallTime,
    );
  }
  final slot = (start: schedule.start.instant, end: schedule.end.instant);
  return SchedulingSession(
    row,
    slot,
    movable:
        row.status == ActivityStatus.planned &&
        !logged &&
        slot.start.isAfter(current),
  );
}

bool _blocks(SchedulingSlot slot, BusyInterval entry, Duration buffer) =>
    overlapsSlot(slot, bufferedSlot(entry, before: buffer, after: buffer));

BusyInterval _sessionBusy(
  String id,
  String title,
  SchedulingSlot slot,
  Duration buffer,
) => (id: id, title: title, slot: slot, before: buffer, after: buffer);

Task _updatedTask(
  Task task, {
  Duration? remaining,
  Duration? actual,
  DateTime? confirmedAt,
  SessionLimits? limits,
}) => Task(
  task.metadata,
  title: task.title,
  description: task.description,
  deadline: task.deadline,
  categoryId: task.categoryId,
  priority: task.priority,
  status: task.status,
  initialEstimate: task.initialEstimate,
  confirmedRemainingEstimate: remaining ?? task.confirmedRemainingEstimate,
  remainingConfirmedAt: confirmedAt ?? task.remainingConfirmedAt,
  remainingActualAtConfirmation: actual ?? task.remainingActualAtConfirmation,
  sessionLimits: limits ?? task.sessionLimits,
);
