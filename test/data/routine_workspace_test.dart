import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/activity_calendar.dart';
import 'package:routina/application/calendar_zones.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/application/routine_workspace.dart';
import 'package:routina/data/local/planner_schema.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DateTime date(int day, [int hour = 0, int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

void main() {
  setUpAll(sqfliteFfiInit);
  late Directory folder;
  late String path;
  late SqlitePlannerStore database;
  late CalendarZones zones;
  late DateTime now;
  late bool sundayFirst;
  late RoutineWorkspace workspace;

  ActivityCalendar calendar() =>
      ActivityCalendar(database, zones, now: () => now);

  Future<void> open() async {
    database = await SqlitePlannerStore.open(
      factory: databaseFactoryFfi,
      path: path,
    );
  }

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('routina-routines-');
    path = '${folder.path}/planner.db';
    await open();
    zones = CalendarZones(deviceZoneId: 'UTC');
    now = date(16, 8);
    sundayFirst = false;
    workspace = RoutineWorkspace(
      openStore: () async => database,
      openCalendar: () async => calendar(),
      readZones: () => zones,
      sundayFirst: () => sundayFirst,
      now: () => now,
    );
  });

  tearDown(() async {
    await database.close();
    await folder.delete(recursive: true);
  });

  Future<Routine> duration() => workspace.save(
    Routine(
      RecordMetadata.create(),
      title: 'Belajar Flutter',
      frequencyRule: 'FREQ=DAILY',
      targetType: RoutineTargetType.duration,
      targetDuration: const Duration(minutes: 20),
    ),
  );

  test(
    'the date filter reads historical cadence and suppresses deleted occurrences',
    () async {
      final routine = await duration();
      expect(await workspace.list(date(15), onDateOnly: true), isEmpty);
      expect(
        (await workspace.list(date(16), onDateOnly: true)).single.routine.id,
        routine.id,
      );
      final occurrence = await database.routineOccurrences.save(
        RoutineOccurrence(
          RecordMetadata.create(),
          routineId: routine.id,
          day: LocalDate.parse('2026-11-16'),
        ),
      );
      await database.softDelete((
        kind: RecordKind.routineOccurrence,
        id: occurrence.id,
      ));
      expect(await workspace.list(date(16), onDateOnly: true), isEmpty);
      expect((await workspace.list(date(16))).single.occurrence, isNull);

      now = date(17, 8);
      await workspace.save(
        Routine(
          routine.metadata,
          title: routine.title,
          targetType: routine.targetType,
          targetDuration: routine.targetDuration,
          frequencyRule: 'FREQ=DAILY;BYDAY=SA,SU',
        ),
      );
      expect(await workspace.list(date(17), onDateOnly: true), isEmpty);
      expect(
        (await workspace.list(date(21), onDateOnly: true)).single.routine.id,
        routine.id,
      );
    },
  );

  test(
    'manual checklist, counts and frequency survive a restart and week setting changes',
    () async {
      final checklist = await workspace.save(
        Routine(
          RecordMetadata.create(),
          title: 'Checklist pagi',
          targetType: RoutineTargetType.checklist,
          checklist: ['Minum', 'Regang'],
        ),
      );
      final count = await workspace.save(
        Routine(
          RecordMetadata.create(),
          title: 'Baca artikel',
          targetType: RoutineTargetType.count,
          targetAmount: 2,
        ),
      );
      final weekly = await workspace.save(
        Routine(
          RecordMetadata.create(),
          title: 'Latihan',
          targetType: RoutineTargetType.frequency,
          targetAmount: 5,
        ),
      );
      await workspace.check(checklist.id, date(16), 'Minum', true);
      await workspace.check(checklist.id, date(16), 'Regang', true);
      await workspace.setCount(count.id, date(16), 3);
      await workspace.setCount(weekly.id, date(15), 2);
      await workspace.setCount(weekly.id, date(16), 3);
      await database.close();
      await open();

      final checked = (await workspace.read(checklist.id, date(16)))!;
      expect(checked.goalReachedAt(now), isTrue);
      expect(checked.completed, isFalse);
      expect((await workspace.read(count.id, date(16)))!.achievedAt(now), 3);
      final monday = (await workspace.read(weekly.id, date(16)))!;
      expect(monday.weeklyCount, 3);
      expect(monday.goalReachedAt(now), isFalse);
      final previous = (await workspace.read(weekly.id, date(15)))!;
      expect(previous.occurrence!.recordedCount, 2);
      sundayFirst = true;
      final sunday = (await workspace.read(weekly.id, date(16)))!;
      expect(sunday.weeklyCount, 5);
      expect(sunday.goalReachedAt(now), isTrue);
      expect(sunday.completed, isFalse);
      expect(sunday.occurrence!.id, monday.occurrence!.id);

      await workspace.confirm(checklist.id, date(16), ActivityStatus.completed);
      expect((await workspace.read(checklist.id, date(16)))!.completed, isTrue);
      expect((await workspace.history(weekly.id)).map((row) => row.day), [
        date(16),
        date(15),
      ]);
      expect(
        (await database.statusHistory.all()).single.target.id,
        checked.occurrence!.id,
      );
    },
  );

  test(
    'timer accumulates only running segments across close, pause, resume and duplicate stop',
    () async {
      final routine = await duration();
      await workspace.start(routine.id, date(16));
      final first = (await workspace.read(routine.id, date(16)))!.timer!;
      expect(
        (await database.routineGoalEvents()).single.dueAt,
        date(16, 8, 20),
      );
      await database.close();
      now = now.add(const Duration(minutes: 7, seconds: 13));
      await open();

      final restored = (await workspace.read(routine.id, date(16)))!;
      expect(restored.timer!.id, first.id);
      expect(restored.actualAt(now), const Duration(minutes: 7, seconds: 13));
      expect(restored.recorded, Duration.zero);
      await workspace.pause(restored.timer!);
      expect(await database.routineGoalEvents(), isEmpty);
      await database.close();
      now = now.add(const Duration(hours: 1));
      await open();

      final paused = (await workspace.read(routine.id, date(16)))!.timer!;
      expect(paused.runningSince, isNull);
      expect(paused.elapsedAt(now), const Duration(minutes: 7, seconds: 13));
      await workspace.start(routine.id, date(16), resumeId: paused.id);
      final resumed = (await workspace.read(routine.id, date(16)))!.timer!;
      expect(resumed.id, first.id);
      final due = (await database.routineGoalEvents()).single.dueAt;
      expect(due, now.add(const Duration(minutes: 12, seconds: 47)));

      now = now.add(const Duration(minutes: 14));
      expect((await workspace.reconcileGoals()).single.reachedAt, now);
      await workspace.stop(resumed);
      await workspace.stop(resumed);
      final results = (await workspace.read(routine.id, date(16)))!;
      expect(results.timer, isNull);
      expect(results.logs.single.source, TimeLogSource.timer);
      expect(results.logs.single.id, first.id);
      expect(results.recorded, const Duration(minutes: 21, seconds: 13));
      expect(results.goalReachedAt(now), isTrue);
      expect(results.completed, isFalse);
      expect((await database.routineGoalEvents()).single.dueAt, due);
      await database.close();
      await open();
      expect(
        (await workspace.history(routine.id)).single.recorded,
        results.recorded,
      );
    },
  );

  test(
    'scheduled intervals, recorded actuals and linked KPI obligation stay independent',
    () async {
      final routine = await duration();
      final plan = await workspace.schedule(
        routine.id,
        date(16),
        date(16, 9),
        date(16, 10),
      );
      final agenda = await calendar().read(date(16), date(17));
      expect(agenda.single.kind, PreviewKind.routine);
      expect(agenda.single.start, date(16, 9));
      expect(agenda.single.end, date(16, 10));
      expect(
        (await workspace.read(routine.id, date(16)))!.recorded,
        Duration.zero,
      );

      await database.events.save(
        EventOccurrence(
          RecordMetadata.create(),
          title: 'Blok belajar',
          schedule: plan.schedule!,
          routineOccurrenceId: plan.id,
          status: ActivityStatus.completed,
        ),
      );
      await workspace.recordDuration(
        routine.id,
        date(16),
        const Duration(minutes: 12),
      );
      expect(await database.routineGoalEvents(), isEmpty);
      await workspace.recordDuration(
        routine.id,
        date(16),
        const Duration(minutes: 8),
      );
      await workspace.recordDuration(
        routine.id,
        date(16),
        const Duration(minutes: 1),
      );
      final progress = (await workspace.read(routine.id, date(16)))!;
      expect(progress.recorded, const Duration(minutes: 21));
      expect(progress.occurrence!.schedule!.duration, const Duration(hours: 1));
      expect(progress.completed, isFalse);
      expect((await workspace.reconcileGoals()).single.reachedAt, now);

      final projections = await calendar().read(date(16), date(17));
      expect(
        projections.map((entry) => entry.obligationId),
        everyElement(plan.id),
      );
      final kpi = DailyPreview(projections, date(16));
      expect(kpi.total, 1);
      expect(kpi.completed, 0);
      await workspace.confirm(routine.id, date(16), ActivityStatus.completed);
      expect(
        DailyPreview(
          await calendar().read(date(16), date(17)),
          date(16),
        ).completed,
        1,
      );
    },
  );

  test(
    'unscheduled progress is a nonblocking calendar entry and archive finalizes timer',
    () async {
      final routine = await duration();
      await workspace.start(routine.id, date(16));
      final tracked = (await calendar().read(date(16), date(17))).single;
      expect(tracked.kind, PreviewKind.routine);
      expect(tracked.options.availability, DayAvailability.free);
      final event = await calendar().save(
        PreviewEvent(
          id: '',
          title: 'Pertemuan bebas',
          start: date(16, 9),
          end: date(16, 10),
        ),
      );
      now = now.add(const Duration(minutes: 31));
      await workspace.delete(routine);
      expect(await workspace.list(date(16)), isEmpty);
      expect((await workspace.trash()).single.title, routine.title);
      expect((await calendar().read(date(16), date(17))).single.id, event.id);
      expect(await database.routineTimers(), isEmpty);
      expect(await database.routineGoalEvents(), isEmpty);
      final saved = (await database.timeLogs.all(includeDeleted: true)).single;
      expect(saved.actualDuration, const Duration(minutes: 31));
      expect(saved.target.id, tracked.id);
    },
  );

  test('edits preserve an occurrence goal snapshot and date history', () async {
    final routine = await duration();
    await workspace.recordDuration(
      routine.id,
      date(16),
      const Duration(minutes: 19),
    );
    final goalBefore = (await workspace.read(routine.id, date(16)))!.goal;
    await workspace.save(
      Routine(
        routine.metadata,
        title: 'Belajar lebih lama',
        targetType: RoutineTargetType.duration,
        targetDuration: const Duration(minutes: 40),
        frequencyRule: 'FREQ=WEEKLY',
        preferredTime: 'Sore',
        timeMode: TimeMode.originalZone,
      ),
      reminders: {const Duration(minutes: 10)},
    );
    final today = (await workspace.read(routine.id, date(16)))!;
    final tomorrow = (await workspace.read(routine.id, date(17)))!;
    expect(today.goal.duration, goalBefore.duration);
    expect(today.recorded, const Duration(minutes: 19));
    expect(tomorrow.goal.duration, const Duration(minutes: 40));
    expect(tomorrow.routine.preferredTime, 'Sore');
    expect(
      (await workspace.reminders(routine.id)).single.offset,
      const Duration(minutes: 10),
    );
  });

  test(
    'v4 migration keeps routine progress and snapshots the stored target',
    () async {
      final oldPath = '${folder.path}/legacy.db';
      final old = await databaseFactoryFfi.openDatabase(
        oldPath,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: (db, version) async {
            await createPlannerSchemaV1(db);
            await migratePlannerSchema(db, 1, version);
          },
        ),
      );
      await old.insert('records', {
        'id': 'old-routine',
        'kind': 'routine',
        'revision': 1,
        'created_at_us': 1,
        'updated_at_us': 1,
      });
      await old.insert('routines', {
        'id': 'old-routine',
        'title': 'Checklist lama',
        'target_type': 'checklist',
        'checklist': '["Satu","Dua"]',
      });
      await old.insert('records', {
        'id': 'old-day',
        'kind': 'routineOccurrence',
        'parent_id': 'old-routine',
        'revision': 1,
        'created_at_us': 2,
        'updated_at_us': 2,
      });
      await old.insert('routine_occurrences', {
        'id': 'old-day',
        'routine_id': 'old-routine',
        'local_day': '2026-11-16',
        'status': 'planned',
        'checked_items': '["Satu"]',
      });
      await old.close();
      final migrated = await SqlitePlannerStore.open(
        factory: databaseFactoryFfi,
        path: oldPath,
      );
      try {
        final row = (await migrated.routineOccurrences.find('old-day'))!;
        expect(row.checkedItems, ['Satu']);
        expect(row.goal!.checklist, ['Satu', 'Dua']);
        expect(await migrated.routineTimers(), isEmpty);
        expect(await migrated.routineGoalEvents(), isEmpty);
      } finally {
        await migrated.close();
      }
    },
  );
}
