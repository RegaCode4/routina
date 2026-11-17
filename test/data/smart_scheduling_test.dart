import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/smart_scheduling.dart';
import 'package:routina/application/task_workspace.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/data/stored_planner_profile.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late SqlitePlannerStore store;
  late StoredPlannerProfile planner;
  late SmartScheduling scheduling;
  late DateTime current;
  late String zone;
  DateTime day(int date, [int hour = 0, int minute = 0]) =>
      DateTime.utc(2026, 11, date, hour, minute);
  Duration minutes(int value) => Duration(minutes: value);
  const limits = (minimumMinutes: 30, maximumSessions: 4);

  Future<void> profile({
    Map<int, ActiveInterval> hours = const {
      DateTime.monday: ActiveInterval(9 * 60, 11 * 60),
      DateTime.tuesday: ActiveInterval(9 * 60, 11 * 60),
      DateTime.wednesday: ActiveInterval(9 * 60, 11 * 60),
    },
    int buffer = 0,
    Map<String, String> categoryTimes = const {},
  }) => planner.saveProfile(
    PreviewProfile(
      activeHours: hours,
      defaultBuffer: minutes(buffer),
      categoryTimes: categoryTimes,
      preferences: const PlannerPreferences(sessionLimits: limits),
    ),
  );

  Future<Task> createTask({
    DateTime? deadline,
    int estimate = 180,
    String? categoryId,
    TimeMode mode = TimeMode.originalZone,
  }) => planner.taskWorkspace.save(
    title: 'Laporan',
    categoryId: categoryId,
    deadline: planner.taskWorkspace.zones.atWall(
      deadline ?? day(18, 11),
      'UTC',
      mode,
    ),
    estimate: minutes(estimate),
    subtasks: const [],
  );

  Future<SchedulingReview> confirm(Task task, int remaining) async {
    await scheduling.confirmRemaining(
      await scheduling.review(task.id),
      minutes(remaining),
    );
    return scheduling.review(task.id);
  }

  Future<PreviewEvent> placeEvent(
    DateTime start,
    DateTime end, {
    DayAvailability availability = DayAvailability.timed,
    EventRecurrence? rule,
    int before = 0,
    int after = 0,
  }) => planner.saveActivity(
    PreviewEvent(
      id: '',
      title: 'Rapat',
      start: start,
      end: end,
      options: EventOptions(
        availability: availability,
        rule: rule,
        before: before,
        after: after,
      ),
    ),
    approved: ScheduleWarning.values.toSet(),
  );

  Future<WorkSession> work(Task task, DateTime start, DateTime end) =>
      planner.taskWorkspace.saveSession(task.id, start, end);

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('routina-smart-');
    current = day(16, 8);
    zone = 'UTC';
    store = await SqlitePlannerStore.open(
      factory: databaseFactoryFfi,
      path: '${directory.path}/planner.db',
      now: () => current,
    );
    planner = StoredPlannerProfile(
      today: current,
      openStore: () async => store,
      now: () => current,
      readDeviceZone: () async => zone,
    );
    scheduling = planner.taskWorkspace.scheduling;
    await profile();
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  test(
    'search is read-only, checks current blockers and atomically saves split sessions once',
    () async {
      final task = await createTask();
      var review = await scheduling.review(task.id);
      await expectLater(
        scheduling.propose(review, ScheduleAction.add, null),
        throwsA(
          isA<SchedulingInput>().having(
            (error) => error.problem,
            'problem',
            SchedulingProblem.estimate,
          ),
        ),
      );
      review = await confirm(task, 180);
      final first = (await scheduling.propose(
        review,
        ScheduleAction.add,
        null,
      )).proposal!;
      expect(first.additions, hasLength(2));
      expect(await store.workSessions.all(), isEmpty);
      expect(
        (await store.tasks.find(task.id))!.metadata.revision,
        review.task.metadata.revision,
      );

      final slot = first.additions.first;
      await placeEvent(slot.start, slot.end);
      await expectLater(scheduling.approve(first), throwsA(isA<StaleRecord>()));
      expect(await store.workSessions.all(), isEmpty);

      final latest = await scheduling.review(task.id);
      const custom = (minimumMinutes: 45, maximumSessions: 2);
      final updated = (await scheduling.propose(
        latest,
        ScheduleAction.add,
        custom,
      )).proposal!;
      await scheduling.approve(updated);
      final rows = await store.workSessions.all();
      expect(rows, hasLength(2));
      expect(
        rows
            .map((row) => row.schedule.end.instant)
            .every((end) => !end.isAfter(day(18, 11))),
        isTrue,
      );
      final after = (await store.tasks.find(task.id))!;
      expect(after.deadline!.instant, task.deadline!.instant);
      expect(after.sessionLimits, custom);
      await expectLater(
        scheduling.approve(updated),
        throwsA(isA<StaleRecord>()),
      );
      expect(await store.workSessions.all(), hasLength(2));
    },
  );

  test(
    'calendar changes that do not invalidate the proposal can be revalidated',
    () async {
      final task = await createTask(estimate: 30);
      final proposal = (await scheduling.propose(
        await confirm(task, 30),
        ScheduleAction.add,
        null,
      )).proposal!;
      await placeEvent(day(17, 10), day(17, 11));
      await scheduling.approve(proposal);
      expect(
        (await store.workSessions.all()).single.schedule.start.instant,
        day(16, 9),
      );
    },
  );

  test(
    'recurring Busy, free all-day events, and buffer are respected beyond a week',
    () async {
      await profile(
        hours: const {DateTime.monday: ActiveInterval(9 * 60, 12 * 60)},
        buffer: 5,
      );
      await placeEvent(day(16), day(17), availability: DayAvailability.busy);
      await placeEvent(day(23), day(24), availability: DayAvailability.free);
      await placeEvent(
        day(16, 9),
        day(16, 10),
        before: 30,
        after: 15,
        rule: EventRecurrence(RepeatFrequency.weekly),
      );
      final task = await createTask(deadline: day(23, 12), estimate: 100);
      final proposal = (await scheduling.propose(
        await confirm(task, 100),
        ScheduleAction.add,
        null,
      )).proposal!;
      expect(proposal.additions.single, (
        start: day(23, 10, 20),
        end: day(23, 12),
      ));
      await scheduling.approve(proposal);
      expect(
        (await store.workSessions.all()).single.scheduledDuration,
        minutes(100),
      );
    },
  );

  test(
    'latest stored active hours, buffer and device zone are checked on approval',
    () async {
      final task = await createTask(estimate: 30);
      final confirmed = await confirm(task, 30);
      final first = (await scheduling.propose(
        confirmed,
        ScheduleAction.add,
        null,
      )).proposal!;
      await profile(
        hours: const {DateTime.wednesday: ActiveInterval(9 * 60, 11 * 60)},
      );
      await expectLater(scheduling.approve(first), throwsA(isA<StaleRecord>()));
      final second = (await scheduling.propose(
        await scheduling.review(task.id),
        ScheduleAction.add,
        null,
      )).proposal!;
      await placeEvent(day(18, 8), day(18, 8, 56));
      await profile(
        hours: const {DateTime.wednesday: ActiveInterval(9 * 60, 11 * 60)},
        buffer: 5,
      );
      await expectLater(
        scheduling.approve(second),
        throwsA(isA<StaleRecord>()),
      );
      final third = (await scheduling.propose(
        await scheduling.review(task.id),
        ScheduleAction.add,
        null,
      )).proposal!;
      zone = 'Asia/Jakarta';
      await expectLater(scheduling.approve(third), throwsA(isA<StaleRecord>()));
      expect(await store.workSessions.all(), isEmpty);
      expect(
        (await scheduling.review(task.id)).deadline,
        task.deadline!.instant,
      );

      zone = 'UTC';
      await scheduling.review(task.id);
      final floating = await createTask(mode: TimeMode.localWallTime);
      zone = 'Asia/Jakarta';
      expect((await scheduling.review(floating.id)).deadline, day(18, 4));
    },
  );

  test(
    'category preference ranks valid slots without restricting fallback',
    () async {
      final category = await store.categories.save(
        Category(
          RecordMetadata.create(),
          name: 'Kuliah',
          color: 0,
          icon: 'school',
        ),
      );
      await profile(
        hours: const {
          DateTime.monday: ActiveInterval(9 * 60, 11 * 60),
          DateTime.tuesday: ActiveInterval(15 * 60, 18 * 60),
        },
        categoryTimes: {category.id: 'Sore'},
      );
      final task = await createTask(estimate: 30, categoryId: category.id);
      final review = await confirm(task, 30);
      expect(
        (await scheduling.propose(
          review,
          ScheduleAction.add,
          null,
        )).proposal!.additions.single.start,
        day(17, 15),
      );
      await placeEvent(day(17, 15), day(17, 18));
      expect(
        (await scheduling.propose(
          review,
          ScheduleAction.add,
          null,
        )).proposal!.additions.single.start,
        day(16, 9),
      );
    },
  );

  test(
    'conflict-only and all-future scopes preserve completed sessions and time logs',
    () async {
      final task = await createTask();
      final history = await work(task, day(16, 9), day(16, 10));
      final collided = await work(task, day(17, 9), day(17, 10));
      final kept = await work(task, day(18, 10), day(18, 11));
      current = day(16, 10);
      await planner.taskWorkspace.markSessionHeld(history);
      await planner.taskWorkspace.logSessionTime(
        (await store.workSessions.find(history.id))!,
        minutes(45),
      );
      final historical = (await store.workSessions.find(history.id))!;
      final log = (await store.timeLogs.all()).single;
      await placeEvent(day(17, 9), day(17, 10));

      final review = await confirm(task, 120);
      expect(review.actual, minutes(45));
      expect(review.suggestedRemaining, minutes(135));
      expect(review.conflicts.keys, [collided.id]);
      final agenda = await planner.readCalendar(day(17), day(18));
      expect(
        agenda.singleWhere((row) => row.id == collided.id).warning,
        ScheduleWarning.overlap,
      );
      final onlyConflicted = (await scheduling.propose(
        review,
        ScheduleAction.replanConflicts,
        null,
      )).proposal!;
      final allFuture = (await scheduling.propose(
        review,
        ScheduleAction.replanAll,
        null,
      )).proposal!;
      expect(onlyConflicted.removals.map((row) => row.record.id), [
        collided.id,
      ]);
      expect(allFuture.removals.map((row) => row.record.id), [
        collided.id,
        kept.id,
      ]);
      await scheduling.approve(onlyConflicted);
      final replacement = (await store.workSessions.all()).singleWhere(
        (row) => row.supersedesId == collided.id,
      );
      expect(replacement.schedule.start.instant, day(17, 10));
      expect(
        (await store.workSessions.find(kept.id))!.metadata.revision,
        kept.metadata.revision,
      );
      expect(
        (await store.workSessions.find(history.id))!.metadata.revision,
        historical.metadata.revision,
      );
      expect((await store.timeLogs.find(log.id))!.actualDuration, minutes(45));
      expect((await scheduling.review(task.id)).conflicts, isEmpty);
      await expectLater(
        scheduling.approve(allFuture),
        throwsA(isA<StaleRecord>()),
      );
      final freshAll = (await scheduling.propose(
        await scheduling.review(task.id),
        ScheduleAction.replanAll,
        null,
      )).proposal!;
      await scheduling.approve(freshAll);
      expect((await scheduling.review(task.id)).upcoming.single.slot, (
        start: day(18, 9),
        end: day(18, 11),
      ));
      expect(
        (await store.workSessions.find(history.id))!.metadata.revision,
        historical.metadata.revision,
      );
    },
  );

  test(
    'Q80 adds only the shortage, trims surplus, and invalidates estimates after new logs',
    () async {
      final task = await createTask(estimate: 150);
      final history = await work(task, day(16, 9), day(16, 10));
      final existing = await work(task, day(17, 9), day(17, 10));
      current = day(16, 10);
      await planner.taskWorkspace.logSessionTime(history, minutes(30));
      final shortage = await confirm(task, 120);
      expect(shortage.scheduled, minutes(60));
      final addition = (await scheduling.propose(
        shortage,
        ScheduleAction.add,
        null,
      )).proposal!;
      expect(addition.removals, isEmpty);
      await scheduling.approve(addition);
      expect((await scheduling.review(task.id)).scheduled, minutes(120));
      expect(
        (await store.workSessions.find(existing.id))!.metadata.revision,
        existing.metadata.revision,
      );

      final surplus = await confirm(task, 90);
      final reduction = (await scheduling.propose(
        surplus,
        ScheduleAction.reduce,
        null,
      )).proposal!;
      expect(reduction.total, minutes(90));
      expect((await scheduling.review(task.id)).scheduled, minutes(120));
      await planner.taskWorkspace.logSessionTime(history, minutes(10));
      await expectLater(
        scheduling.approve(reduction),
        throwsA(isA<StaleRecord>()),
      );
      final reconsider = await scheduling.review(task.id);
      expect(reconsider.confirmedRemaining, isNull);
      expect(reconsider.suggestedRemaining, minutes(110));
      final updated = await confirm(task, 90);
      await scheduling.approve(
        (await scheduling.propose(
          updated,
          ScheduleAction.reduce,
          null,
        )).proposal!,
      );
      expect((await scheduling.review(task.id)).scheduled, minutes(90));
      expect(await store.timeLogs.all(), hasLength(2));
    },
  );

  test(
    'the whole approval rolls back if a reviewed slot expires during writes',
    () async {
      final task = await createTask(estimate: 30);
      final review = await confirm(task, 30);
      final proposal = (await scheduling.propose(
        review,
        ScheduleAction.add,
        null,
      )).proposal!;
      var clockReads = 0;
      final racing = SmartScheduling(
        openStore: scheduling.openStore,
        openCalendar: scheduling.openCalendar,
        now: () => ++clockReads >= 3 ? proposal.additions.first.start : current,
      );
      await expectLater(racing.approve(proposal), throwsA(isA<StaleRecord>()));
      expect(clockReads, 3);
      expect(await store.workSessions.all(), isEmpty);
      expect(
        (await store.tasks.find(task.id))!.metadata.revision,
        review.task.metadata.revision,
      );
    },
  );

  test(
    'reducing a plan can keep one valid overlapping session and rechecks it on approval',
    () async {
      final task = await createTask(estimate: 60);
      final first = await work(task, day(17, 9), day(17, 10));
      final second = await planner.taskWorkspace.saveSession(
        task.id,
        day(17, 9, 30),
        day(17, 10, 30),
        approved: const SessionWarnings({ScheduleWarning.overlap}),
      );
      final review = await confirm(task, 60);
      final proposal = (await scheduling.propose(
        review,
        ScheduleAction.reduce,
        (minimumMinutes: 45, maximumSessions: 4),
      )).proposal!;
      expect(proposal.additions, isEmpty);
      expect(proposal.removals.single.record.id, second.id);
      await placeEvent(day(17, 9), day(17, 9, 30));
      await expectLater(
        scheduling.approve(proposal),
        throwsA(isA<StaleRecord>()),
      );
      expect(
        (await store.workSessions.find(first.id))!.metadata.revision,
        first.metadata.revision,
      );
      expect(
        (await store.workSessions.find(second.id))!.metadata.revision,
        second.metadata.revision,
      );
    },
  );

  test(
    'activity replacement rechecks its slot and preserves the original outcome',
    () async {
      final original = await placeEvent(day(16, 9), day(16, 10));
      current = day(16, 10);
      final postponed = await planner.changeActivity(
        original,
        PreviewEventState.postponed,
      );
      final stale = (await planner.suggestReplacement(postponed))!;
      expect(await store.events.all(), hasLength(1));
      await placeEvent(stale.slot.start, stale.slot.end);
      await expectLater(
        planner.approveReplacement(stale),
        throwsA(isA<StaleRecord>()),
      );
      expect(
        (await store.events.all()).where(
          (row) => row.supersedesId == original.id,
        ),
        isEmpty,
      );
      final fresh = (await planner.suggestReplacement(postponed))!;
      final saved = await planner.approveReplacement(fresh);
      expect(saved.supersedesId, original.id);
      expect(
        (await store.events.find(original.id))!.status,
        ActivityStatus.postponed,
      );
      expect(
        (await store.events.find(saved.id))!.schedule.duration,
        minutes(60),
      );
      await expectLater(
        planner.approveReplacement(fresh),
        throwsA(isA<StaleRecord>()),
      );
    },
  );
}
