import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/activity_calendar.dart';
import 'package:routina/application/calendar_zones.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/application/trash_workspace.dart';
import 'package:routina/data/local/planner_schema.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/data/stored_planner_profile.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/fake_notifications.dart';

DateTime at(int day, [int hour = 0, int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

void main() {
  setUpAll(sqfliteFfiInit);
  final zones = CalendarZones(deviceZoneId: 'UTC');
  late DateTime now;
  late Directory folder;
  late String path;
  late SqlitePlannerStore store;
  late StoredPlannerProfile repository;
  late FakeNotifications reminders;

  Future<void> open() async {
    store = await SqlitePlannerStore.open(
      factory: databaseFactoryFfi,
      path: path,
      now: () => now,
    );
    repository = StoredPlannerProfile(
      today: now,
      now: () => now,
      openStore: () async => store,
      readDeviceZone: () async => 'UTC',
      notificationPlatform: reminders,
    );
  }

  setUp(() async {
    now = at(16, 8);
    folder = await Directory.systemTemp.createTemp('routina-trash-');
    path = '${folder.path}/planner.db';
    reminders = FakeNotifications();
    await open();
    await repository.saveProfile(
      PreviewProfile(name: 'Nara', notifications: true),
    );
  });
  tearDown(() async {
    await store.close();
    repository.localReminders!.dispose();
    await folder.delete(recursive: true);
  });

  TrashWorkspace trash() => repository.trashWorkspace;
  ActivityCalendar calendar() => ActivityCalendar(store, zones, now: () => now);
  ScheduledInterval interval(DateTime start, DateTime end) =>
      zones.interval(start, end, 'UTC', TimeMode.originalZone);

  Future<TrashItem> item(String target) async => (await trash().list()).items
      .singleWhere((row) => row.entry.target.id == target);

  Future<EventOccurrence> event(
    String title,
    DateTime start,
    DateTime end, {
    String? category,
    String? occurrence,
    String? replaces,
    ActivityStatus status = ActivityStatus.planned,
  }) => store.events.save(
    EventOccurrence(
      RecordMetadata.create(),
      title: title,
      schedule: interval(start, end),
      categoryId: category,
      routineOccurrenceId: occurrence,
      supersedesId: replaces,
      status: status,
      details: const EventDetails(reminders: ['Saat mulai']),
    ),
  );

  Future<PreviewEvent> series() => repository.saveActivity(
    PreviewEvent(
      id: '',
      title: 'Seri harian',
      start: at(16, 10),
      end: at(16, 11),
      options: EventOptions(
        rule: EventRecurrence(RepeatFrequency.daily, until: at(25)),
        reminders: const ['Saat mulai'],
        zoneId: 'UTC',
      ),
    ),
    approved: ScheduleWarning.values.toSet(),
  );

  Future<void> foreignKeys() async {
    final check = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    try {
      expect(await check.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    } finally {
      await check.close();
    }
  }

  test(
    'v8 migration retains the original deletion and writes its expiration',
    () async {
      final legacyPath = '${folder.path}/legacy.db';
      final legacy = await databaseFactoryFfi.openDatabase(
        legacyPath,
        options: OpenDatabaseOptions(
          version: 8,
          onCreate: (db, _) async {
            await createPlannerSchemaV1(db);
            await migratePlannerSchema(db, 1, 8);
          },
        ),
      );
      final deleted = at(16, 3);
      final micros = deleted.microsecondsSinceEpoch;
      for (final (id, kind) in [
        ('legacy-task', 'task'),
        ('legacy-trash', 'trashEntry'),
      ]) {
        await legacy.insert('records', {
          'id': id,
          'kind': kind,
          'revision': 1,
          'created_at_us': micros,
          'updated_at_us': micros,
        });
      }
      await legacy.insert('tasks', {
        'id': 'legacy-task',
        'title': 'Arsip lama',
        'status': 'planned',
      });
      await legacy.insert('trash_entries', {
        'id': 'legacy-trash',
        'target_id': 'legacy-task',
        'target_kind': 'task',
        'deleted_at_us': micros,
      });
      await legacy.close();
      now = deleted.add(TrashEntry.retention);
      final migrated = await SqlitePlannerStore.open(
        factory: databaseFactoryFfi,
        path: legacyPath,
        now: () => now,
      );
      try {
        final entry = (await migrated.trashEntries.all()).single;
        expect(entry.deletedAt, deleted);
        expect(entry.expiresAt, now);
        expect(await migrated.tasks.find('legacy-task'), isNull);
        expect(
          await migrated.tasks.find('legacy-task', includeDeleted: true),
          isNotNull,
        );
        await expectLater(
          migrated.restore(entry.id),
          throwsA(TrashProblem.expired),
        );
      } finally {
        await migrated.close();
      }
    },
  );

  test(
    'UTC retention is exact, review rolls back, repeated deletion refreshes revision only after restore',
    () async {
      final original = await event('Tersimpan', at(16, 10), at(16, 11));
      final ref = (kind: RecordKind.eventOccurrence, id: original.id);
      final first = await store.softDelete(ref);
      expect(first.deletedAt, now);
      expect(first.expiresAt, now.add(const Duration(hours: 720)));
      now = first.expiresAt.subtract(const Duration(microseconds: 1));
      expect((await store.softDelete(ref)).deletedAt, first.deletedAt);
      final pending = await trash().review(await item(original.id));
      expect(await store.events.find(original.id), isNull);
      expect(
        (await store.events.find(
          original.id,
          includeDeleted: true,
        ))!.schedule.start.instant,
        at(16, 10),
      );

      now = first.expiresAt;
      await expectLater(
        trash().approve(pending),
        throwsA(TrashProblem.expired),
      );
      expect((await item(original.id)).entry.canRestoreAt(now), isFalse);
      expect(
        await store.events.find(original.id, includeDeleted: true),
        isNotNull,
      );
      now = first.expiresAt.subtract(const Duration(seconds: 1));
      await trash().approve(await trash().review(await item(original.id)));
      expect(await store.events.find(original.id), isNotNull);
      now = now.add(const Duration(minutes: 1));
      final second = await store.softDelete(ref);
      expect(second.id, first.id);
      expect(second.deletedAt, now);
      await expectLater(trash().approve(pending), throwsA(isA<StaleRecord>()));
      await foreignKeys();
    },
  );

  test(
    'task trash secludes sessions, KPI and reminders and restores owned data but keeps independent trash',
    () async {
      final task = await store.tasks.save(
        Task(
          RecordMetadata.create(),
          title: 'Tugas diuji',
          deadline: zones.atWall(at(16, 16), 'UTC', TimeMode.originalZone),
        ),
      );
      final sub = await store.subtasks.save(
        Subtask(
          RecordMetadata.create(),
          taskId: task.id,
          title: 'Item terpisah',
        ),
      );
      await store.softDelete((kind: RecordKind.subtask, id: sub.id));
      final session = await store.workSessions.save(
        WorkSession(
          RecordMetadata.create(),
          taskId: task.id,
          schedule: interval(at(16, 10), at(16, 11)),
        ),
      );
      final log = await store.timeLogs.save(
        TimeLog(
          RecordMetadata.create(),
          target: (kind: RecordKind.workSession, id: session.id),
          actualDuration: const Duration(minutes: 15),
          recordedAt: now,
          source: TimeLogSource.manual,
        ),
      );
      final rule = await store.reminderRules.save(
        ReminderRule(
          RecordMetadata.create(),
          target: (kind: RecordKind.task, id: task.id),
          anchor: ReminderAnchor.deadline,
          offset: Duration.zero,
          enabled: true,
        ),
      );
      expect(reminders.queued.map((row) => row.body), contains(task.title));
      await repository.load(PreviewSurface.home);
      expect(repository.homeProductivity!.tally.total, 1);
      await repository.taskWorkspace.delete(task);
      expect(await store.tasks.all(), isEmpty);
      expect(await store.workSessions.all(), isEmpty);
      expect(await store.timeLogs.all(), isEmpty);
      expect(await store.reminderRules.all(), isEmpty);
      expect(
        reminders.queued.map((row) => row.body),
        isNot(contains(task.title)),
      );
      expect(
        await calendar().busyIntervals(
          store,
          at(16),
          at(17),
          sessionBuffer: Duration.zero,
        ),
        isEmpty,
      );
      await repository.load(PreviewSurface.home);
      expect(repository.homeProductivity!.tally.ratio, isNull);

      final blocker = await event(
        'Jadwal pengisi',
        at(16, 10, 30),
        at(16, 11, 30),
      );
      final proposal = await trash().review(await item(task.id));
      expect(proposal.check.conflicts.single.existingId, blocker.id);
      await trash().approve(proposal);
      expect((await store.workSessions.all()).single.id, session.id);
      expect((await store.timeLogs.all()).single.id, log.id);
      expect((await store.reminderRules.all()).single.id, rule.id);
      expect(await store.subtasks.all(), isEmpty);
      expect(reminders.queued.map((row) => row.body), contains(task.title));
      expect(
        (await store.events.find(blocker.id))!.metadata.revision,
        blocker.metadata.revision,
      );
      await foreignKeys();

      await repository.taskWorkspace.delete((await store.tasks.find(task.id))!);
      final bin = await item(task.id);
      now = bin.entry.expiresAt.add(const Duration(seconds: 1));
      await trash().permanentlyDelete(bin);
      expect(await store.tasks.find(task.id, includeDeleted: true), isNull);
      expect(await store.subtasks.find(sub.id, includeDeleted: true), isNull);
      expect(await store.timeLogs.find(log.id, includeDeleted: true), isNull);
      expect(await store.trashEntries.find(bin.entry.id), isNull);
      expect(await store.events.find(blocker.id), isNotNull);
      await foreignKeys();
    },
  );

  test(
    'new overlap invalidates approval without commit and moving a planned event retains identity',
    () async {
      final original = await event('Asal', at(16, 10), at(16, 11));
      await store.softDelete((
        kind: RecordKind.eventOccurrence,
        id: original.id,
      ));
      final bin = await item(original.id);
      final n = reminders.synchronizations;
      final clean = await trash().review(bin);
      expect(clean.check.conflicts, isEmpty);
      expect(reminders.synchronizations, n);
      final existing = await event('Pesaing', at(16, 10, 30), at(16, 11, 30));
      await expectLater(trash().approve(clean), throwsA(isA<StaleRecord>()));
      expect(await store.events.find(original.id), isNull);
      expect(
        (await item(original.id)).entry.metadata.revision,
        bin.entry.metadata.revision,
      );
      expect(
        (await trash().review(bin)).check.conflicts.single.warning,
        ScheduleWarning.overlap,
      );
      final moved = await trash().review(bin, moveTo: at(17));
      expect(moved.check.conflicts, isEmpty);
      expect(await store.events.find(original.id), isNull);
      await trash().approve(moved);
      final active = (await store.events.find(original.id))!;
      expect(active.schedule.start.instant, at(17, 10));
      expect(active.schedule.duration, original.schedule.duration);
      expect(
        (await store.events.find(existing.id))!.schedule.start.instant,
        at(16, 10, 30),
      );
      await foreignKeys();
    },
  );

  test(
    'restore requires a visible routine occurrence and routine links disappear together',
    () async {
      final task = await store.tasks.save(
        Task(RecordMetadata.create(), title: 'Tugas lain'),
      );
      final routine = await repository.routineWorkspace.save(
        Routine(
          RecordMetadata.create(),
          title: 'Rutinitas',
          targetType: RoutineTargetType.count,
          targetAmount: 1,
        ),
      );
      final occurrence = await repository.routineWorkspace.schedule(
        routine.id,
        at(16),
        at(16, 12),
        at(16, 13),
      );
      final block = await event(
        'Blok rutinitas',
        at(16, 12),
        at(16, 13),
        occurrence: occurrence.id,
      );
      final separate = await event(
        'Blok sudah dibuang',
        at(16, 11),
        at(16, 12),
        occurrence: occurrence.id,
      );
      final session = await store.workSessions.save(
        WorkSession(
          RecordMetadata.create(),
          taskId: task.id,
          routineOccurrenceId: occurrence.id,
          schedule: interval(at(16, 12), at(16, 13)),
        ),
      );
      await store.softDelete((
        kind: RecordKind.eventOccurrence,
        id: separate.id,
      ));
      await repository.routineWorkspace.delete(routine);
      expect(await store.events.find(block.id), isNull);
      expect(await store.workSessions.find(session.id), isNull);
      expect(await store.tasks.find(task.id), isNotNull);
      expect(
        reminders.queued.map((row) => row.body),
        isNot(contains(block.title)),
      );
      expect(
        await calendar().busyIntervals(
          store,
          at(16),
          at(17),
          sessionBuffer: Duration.zero,
        ),
        isEmpty,
      );
      await expectLater(
        trash().review(await item(separate.id)),
        throwsA(TrashProblem.unavailableParent),
      );
      final parent = await item(routine.id);
      await expectLater(
        trash().permanentlyDelete(parent),
        throwsA(TrashProblem.referenced),
      );
      expect(await store.routines.find(routine.id), isNull);
      final recovered = await trash().review(parent);
      expect(recovered.check.conflicts, isEmpty);
      await trash().approve(recovered);
      expect((await store.events.all()).single.id, block.id);
      expect((await store.workSessions.all()).single.id, session.id);
      expect((await trash().list()).items.single.entry.target.id, separate.id);
      await foreignKeys();
    },
  );

  test(
    'review explains a missing category and approval only repairs the recovered reference',
    () async {
      final category = await store.categories.save(
        Category(RecordMetadata.create(), name: 'Dulu', color: 0),
      );
      final original = await event(
        'Berkategori',
        at(16, 10),
        at(16, 11),
        category: category.id,
      );
      await store.softDelete((
        kind: RecordKind.eventOccurrence,
        id: original.id,
      ));
      await store.softDelete((kind: RecordKind.category, id: category.id));
      final proposal = await trash().review(await item(original.id));
      expect(proposal.check.removedCategories, {'Dulu'});
      expect(
        (await store.events.find(
          original.id,
          includeDeleted: true,
        ))!.categoryId,
        category.id,
      );
      await trash().approve(proposal);
      expect((await store.events.find(original.id))!.categoryId, isNull);
      expect(await store.categories.find(category.id), isNull);
      await foreignKeys();
    },
  );

  test(
    'recurring range archives virtual and stored occurrences together and checks restored slots',
    () async {
      final first = await series();
      final dates = await repository.readCalendar(at(16), at(24));
      final skipped = dates.singleWhere((row) => row.start.day == 18);
      await repository.changeActivity(
        skipped,
        PreviewEventState.trashed,
        scope: SeriesScope.occurrence,
      );
      final projected = dates.singleWhere((row) => row.start.day == 20);
      final materialized = await repository.saveActivity(
        projected,
        scope: SeriesScope.occurrence,
        approved: ScheduleWarning.values.toSet(),
      );
      await repository.changeActivity(
        dates.singleWhere((row) => row.start.day == 17),
        PreviewEventState.trashed,
        scope: SeriesScope.following,
      );
      expect(
        (await repository.readCalendar(
          at(16),
          at(24),
        )).map((row) => row.start.day),
        [16],
      );
      expect((await trash().list()).items.map((row) => row.kind).toSet(), {
        TrashKind.event,
        TrashKind.series,
      });
      final archived = await item(first.series!);
      expect(archived.entry.seriesCut!.value, '2026-11-17');
      expect(await store.events.find(materialized.id), isNull);
      expect(
        reminders.queued
            .where(
              (row) =>
                  row.body == first.title &&
                  row.kind == ReminderKind.eventStart,
            )
            .map((row) => row.at.day),
        [16],
      );
      await expectLater(
        trash().review(await item(skipped.id)),
        throwsA(TrashProblem.unavailableParent),
      );
      final blocker = await event('Jadwal baru', at(19, 10), at(19, 11));
      final proposal = await trash().review(archived);
      expect(proposal.check.checksRecurring, isTrue);
      expect(proposal.check.conflicts.single.existingId, blocker.id);
      expect(await store.events.find(materialized.id), isNull);
      await trash().approve(proposal);
      expect(await store.events.find(materialized.id), isNotNull);
      expect(
        (await repository.readCalendar(at(16), at(24)))
            .where((row) => row.series == first.series)
            .map((row) => row.start.day),
        [16, 17, 19, 20, 21, 22, 23],
      );
      expect((await trash().list()).items.single.entry.target.id, skipped.id);
      await foreignKeys();
    },
  );

  test(
    'permanent delete preserves recurrence exclusions over reopen and keeps past series history',
    () async {
      final first = await series();
      final row = (await repository.readCalendar(at(18), at(19))).single;
      await repository.changeActivity(
        row,
        PreviewEventState.trashed,
        scope: SeriesScope.occurrence,
      );
      await trash().permanentlyDelete(await item(row.id));
      expect(await store.events.find(row.id, includeDeleted: true), isNull);
      final day20 = (await repository.readCalendar(at(20), at(21))).single;
      await repository.changeActivity(
        day20,
        PreviewEventState.trashed,
        scope: SeriesScope.following,
      );
      await trash().permanentlyDelete(await item(first.series!));
      expect((await trash().list()).items, isEmpty);
      await store.close();
      repository.localReminders!.dispose();
      await open();
      final rows = await repository.readCalendar(at(16), at(26));
      expect(rows.map((row) => row.start.day), [16, 17, 19]);
      expect(rows.every((row) => row.series == first.series), isTrue);
      await foreignKeys();
    },
  );

  test(
    'entire range archives a future exception after the rule ended without hiding past dates',
    () async {
      final first = await repository.saveActivity(
        PreviewEvent(
          id: '',
          title: 'Seri selesai',
          start: at(14, 10),
          end: at(14, 11),
          options: EventOptions(
            rule: EventRecurrence(RepeatFrequency.daily, until: at(15)),
          ),
        ),
      );
      final moved = await repository.saveActivity(
        PreviewEvent(
          id: first.id,
          series: first.series,
          recurrenceKey: first.recurrenceKey,
          title: first.title,
          start: at(20, 10),
          end: at(20, 11),
          options: first.options,
        ),
        scope: SeriesScope.occurrence,
      );
      await repository.changeActivity(
        moved,
        PreviewEventState.trashed,
        scope: SeriesScope.entire,
      );
      expect(
        (await repository.readCalendar(at(15), at(16))).single.start,
        at(15, 10),
      );
      expect(await repository.readCalendar(at(20), at(21)), isEmpty);
      await trash().approve(await trash().review(await item(first.series!)));
      expect(
        (await repository.readCalendar(at(20), at(21))).single.id,
        moved.id,
      );
      await foreignKeys();
    },
  );

  test(
    'permanent deletion of a referenced source rolls back and preserves replacement history',
    () async {
      final original = await event(
        'Kegiatan asal',
        at(15, 10),
        at(15, 11),
        status: ActivityStatus.postponed,
      );
      final replacement = await event(
        'Kegiatan pengganti',
        at(16, 14),
        at(16, 15),
        replaces: original.id,
      );
      await store.softDelete((
        kind: RecordKind.eventOccurrence,
        id: original.id,
      ));
      await expectLater(
        trash().permanentlyDelete(await item(original.id)),
        throwsA(TrashProblem.referenced),
      );
      expect(await store.events.find(original.id), isNull);
      expect(
        (await store.events.find(original.id, includeDeleted: true))!.status,
        ActivityStatus.postponed,
      );
      expect(
        (await store.events.find(replacement.id))!.supersedesId,
        original.id,
      );
      await foreignKeys();
    },
  );
}
