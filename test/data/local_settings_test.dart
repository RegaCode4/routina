import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/data/local/planner_schema.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/data/stored_planner_profile.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _today = DateTime.utc(2026, 11, 16);
ZonedTime _at(int hour) => ZonedTime(
  instant: _today.add(Duration(hours: hour)),
  zoneId: 'Asia/Jakarta',
  mode: TimeMode.originalZone,
);

void main() {
  setUpAll(sqfliteFfiInit);
  late Directory directory;
  late String path;
  final factory = databaseFactoryFfi;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('routina-settings-');
    path = '${directory.path}${Platform.pathSeparator}settings.db';
  });
  tearDown(() async => directory.delete(recursive: true));

  Future<SqlitePlannerStore> open() async {
    final store = await SqlitePlannerStore.open(factory: factory, path: path);
    addTearDown(store.close);
    return store;
  }

  StoredPlannerProfile adapter(PlannerStore store) =>
      StoredPlannerProfile(today: _today, openStore: () async => store);

  test(
    'unfinished onboarding resumes the saved step and completed setup reopens Home',
    () async {
      final firstStore = await open();
      final first = adapter(firstStore);
      await first.load(PreviewSurface.startup);
      expect(first.profile, isNull);
      await first.rememberStep(1);
      await first.rememberStep(2);
      final draft = (await firstStore.profiles.all()).single;
      expect(draft.onboardingCompleted, isFalse);
      expect(draft.onboardingStep, 2);
      await firstStore.close();

      final secondStore = await open();
      final second = adapter(secondStore);
      await second.load(PreviewSurface.startup);
      expect(second.profile, isNull);
      expect(second.onboardingStep, 2);
      await second.rememberStep(1);
      await second.saveProfile(
        PreviewProfile(
          activeHours: {
            1: const ActiveInterval(480, 900),
            2: const ActiveInterval(600, 1200),
          },
          study: 'Siang',
          workout: 'Pagi',
          other: 'Malam',
          sundayFirst: true,
          notifications: false,
        ),
      );
      expect((await secondStore.profiles.all()).single.id, draft.id);
      await secondStore.close();

      final lastStore = await open();
      final last = adapter(lastStore);
      await last.load(PreviewSurface.startup);
      await last.rememberStep(2);
      expect(last.onboardingStep, 0);
      expect(last.profile!.name, isEmpty);
      expect(last.profile!.activeHours[1]!.start, 480);
      expect(last.profile!.activeHours[2]!.start, 600);
      expect(last.profile!.other, 'Malam');
      expect(last.profile!.sundayFirst, isTrue);
      expect(last.profile!.notifications, isFalse);
    },
  );

  test(
    'zone, notification preferences and category retain independently chosen values after reopening',
    () async {
      final firstStore = await open();
      final repo = adapter(firstStore);
      await repo.load(PreviewSurface.startup);
      expect(repo.categories, isEmpty);
      expect(
        const PlannerPreferences().deadlineTimeMode,
        TimeMode.originalZone,
      );
      final created = await repo.saveCategory(
        Category(
          RecordMetadata.create(),
          name: ' Belajar ',
          color: 0xff537bff,
          icon: 'study',
        ),
      );
      final revised = await repo.saveCategory(
        Category(
          created.metadata,
          name: 'Membaca',
          color: 0xffffe65b,
          icon: 'favorite',
        ),
      );
      expect(revised.id, created.id);
      expect(revised.metadata.revision, 2);
      await expectLater(
        repo.saveCategory(
          Category(RecordMetadata.create(), name: ' membaca ', color: 0),
        ),
        throwsFormatException,
      );
      await repo.saveProfile(
        PreviewProfile(
          defaultBuffer: const Duration(minutes: 15),
          quietHours: (startMinute: 1260, endMinute: 390),
          categoryTimes: {created.id: 'Sore'},
          preferences: const PlannerPreferences(
            calendarZoneId: 'Asia/Makassar',
            eventTimeMode: TimeMode.localWallTime,
            routineTimeMode: TimeMode.originalZone,
            quietEnabled: false,
            quietExceptionsEnabled: true,
            quietExceptions: {ReminderKind.deadline},
            reminderTypes: {ReminderKind.routine: false},
            backupReminderDays: 14,
          ),
        ),
      );
      await repo.saveProfile(repo.profile!.copyWith(name: 'Nama terbaru'));
      await firstStore.close();

      final secondStore = await open();
      final fresh = adapter(secondStore);
      await fresh.load(PreviewSurface.startup);
      final profile = fresh.profile!;
      expect(profile.name, 'Nama terbaru');
      expect(profile.defaultBuffer, const Duration(minutes: 15));
      expect(profile.quietHours, (startMinute: 1260, endMinute: 390));
      expect(profile.categoryTimes, {revised.id: 'Sore'});
      expect(profile.preferences.calendarZoneId, 'Asia/Makassar');
      expect(profile.preferences.eventTimeMode, TimeMode.localWallTime);
      expect(profile.preferences.routineTimeMode, TimeMode.originalZone);
      expect(profile.preferences.deadlineTimeMode, TimeMode.originalZone);
      expect(profile.preferences.quietEnabled, isFalse);
      expect(profile.preferences.quietExceptionsEnabled, isTrue);
      expect(profile.preferences.quietExceptions, {ReminderKind.deadline});
      expect(profile.preferences.reminderTypes, {ReminderKind.routine: false});
      expect(profile.preferences.backupReminderDays, 14);
      expect(fresh.categories.single.name, 'Membaca');
      expect(fresh.categories.single.color, 0xffffe65b);
      expect(fresh.categories.single.icon, 'favorite');
    },
  );

  test(
    'reassignment updates active and archived references and rolls back on mid-transaction failure',
    () async {
      final store = await open();
      final old = await store.categories.save(
        Category(RecordMetadata.create(), name: 'Asal', color: 0),
      );
      final next = await store.categories.save(
        Category(RecordMetadata.create(), name: 'Tujuan', color: 1),
      );
      final series = await store.eventSeries.save(
        EventSeries(
          RecordMetadata.create(),
          title: 'Seri',
          recurrenceRule: 'FREQ=WEEKLY',
          zoneId: 'Asia/Jakarta',
          timeMode: TimeMode.originalZone,
          categoryId: old.id,
        ),
      );
      final interval = ScheduledInterval(_at(8), _at(9));
      final event = await store.events.save(
        EventOccurrence(
          RecordMetadata.create(),
          title: 'Kegiatan',
          schedule: interval,
          categoryId: old.id,
          seriesId: series.id,
          recurrenceKey: '2026-11-16T15:00',
        ),
      );
      final task = await store.tasks.save(
        Task(
          RecordMetadata.create(),
          title: 'Tugas',
          categoryId: old.id,
          deadline: _at(12),
        ),
      );
      final session = await store.workSessions.save(
        WorkSession(
          RecordMetadata.create(),
          taskId: task.id,
          schedule: interval,
        ),
      );
      final routine = await store.routines.save(
        Routine(
          RecordMetadata.create(),
          title: 'Rutinitas',
          targetType: RoutineTargetType.count,
          targetAmount: 1,
          categoryId: old.id,
        ),
      );
      final archived = await store.softDelete((
        kind: RecordKind.routine,
        id: routine.id,
      ));

      await expectLater(
        store.deleteCategory(old.id, replacementId: 'missing'),
        throwsA(isA<StaleRecord>()),
      );
      final inspect = await factory.openDatabase(path);
      addTearDown(inspect.close);
      await inspect.execute("""
      CREATE TRIGGER fail_category_move BEFORE UPDATE OF category_id ON tasks
      BEGIN SELECT RAISE(ABORT, 'test rollback'); END
    """);
      await expectLater(
        store.deleteCategory(old.id, replacementId: next.id),
        throwsA(isA<DatabaseException>()),
      );
      expect((await store.eventSeries.find(series.id))!.categoryId, old.id);
      expect(
        (await store.events.find(event.id))!.metadata.revision,
        event.metadata.revision,
      );
      expect(await store.categories.find(old.id), isNotNull);

      await inspect.execute('DROP TRIGGER fail_category_move');
      await store.deleteCategory(old.id, replacementId: next.id);
      expect(await store.categories.find(old.id), isNull);
      expect((await store.eventSeries.find(series.id))!.categoryId, next.id);
      expect((await store.events.find(event.id))!.categoryId, next.id);
      expect((await store.tasks.find(task.id))!.categoryId, next.id);
      expect((await store.workSessions.find(session.id))!.taskId, task.id);
      expect(await store.routines.find(routine.id), isNull);
      expect(
        (await store.routines.find(
          routine.id,
          includeDeleted: true,
        ))!.categoryId,
        next.id,
      );

      await store.deleteCategory(next.id);
      await store.restore(archived.id);
      expect((await store.eventSeries.find(series.id))!.categoryId, isNull);
      expect((await store.events.find(event.id))!.categoryId, isNull);
      expect((await store.tasks.find(task.id))!.categoryId, isNull);
      expect((await store.routines.find(routine.id))!.categoryId, isNull);
      expect(await inspect.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'v2 local profile migrates as completed and keeps legacy data',
    () async {
      final old = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await createPlannerSchemaV1(db);
            await migratePlannerSchema(db, 1, version);
          },
        ),
      );
      await old.insert('records', {
        'id': 'legacy',
        'kind': 'profile',
        'revision': 1,
        'created_at_us': 0,
        'updated_at_us': 0,
      });
      await old.insert('profiles', {
        'id': 'legacy',
        'name': 'Nara lama',
        'week_starts_on': 7,
        'quiet_start_min': 1320,
        'quiet_end_min': 420,
        'active_hours': '{"1":[480,1200]}',
        'activity_preferences': '{"study":"Siang"}',
      });
      await old.close();

      final store = await open();
      final repo = adapter(store);
      await repo.load(PreviewSurface.startup);
      expect((await store.profiles.all()).single.onboardingCompleted, isTrue);
      expect(repo.profile!.name, 'Nara lama');
      expect(repo.profile!.sundayFirst, isTrue);
      expect(repo.profile!.study, 'Siang');
      expect(repo.profile!.quietHours, (startMinute: 1320, endMinute: 420));
    },
  );
}
