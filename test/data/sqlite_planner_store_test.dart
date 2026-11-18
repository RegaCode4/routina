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

final base = DateTime.utc(2026, 11, 16);
const asiaJakarta = 'Asia/Jakarta';

ZonedTime at(int hours, {String zone = asiaJakarta}) => ZonedTime(
  instant: base.add(Duration(hours: hours)),
  zoneId: zone,
  mode: TimeMode.originalZone,
);

ScheduledInterval during(int from, int to) =>
    ScheduledInterval(at(from), at(to));
RecordRef ref(RecordKind kind, PlannerRecord record) =>
    (kind: kind, id: record.id);

void main() {
  setUpAll(sqfliteFfiInit);
  late Directory directory;
  late String path;
  final factory = databaseFactoryFfi;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('routina-sqlite-');
    path = '${directory.path}${Platform.pathSeparator}planner.db';
  });

  tearDown(() async => directory.delete(recursive: true));

  Future<SqlitePlannerStore> open() async {
    final store = await SqlitePlannerStore.open(
      factory: factory,
      path: path,
      now: () => base,
    );
    addTearDown(store.close);
    return store;
  }

  test(
    'all 13 models survive reopening the database with stable identities',
    () async {
      final s = await open();
      final profile = await s.profiles.save(
        Profile(
          RecordMetadata.create(),
          name: 'Nara',
          weekStartsOn: DateTime.sunday,
          quietHours: (startMinute: 1320, endMinute: 420),
          activeHours: {DateTime.monday: (startMinute: 480, endMinute: 1260)},
          activityPreferences: {'study': 'Sore'},
        ),
      );
      final category = await s.categories.save(
        Category(RecordMetadata.create(), name: 'Belajar', color: 0xff537bff),
      );
      final series = await s.eventSeries.save(
        EventSeries(
          RecordMetadata.create(),
          title: 'Kelas',
          recurrenceRule: 'FREQ=WEEKLY',
          zoneId: asiaJakarta,
          timeMode: TimeMode.originalZone,
          categoryId: category.id,
        ),
      );
      final routine = await s.routines.save(
        Routine(
          RecordMetadata.create(),
          title: 'Belajar Flutter',
          targetType: RoutineTargetType.duration,
          targetDuration: const Duration(minutes: 30),
          categoryId: category.id,
        ),
      );
      final occurrence = await s.routineOccurrences.save(
        RoutineOccurrence(
          RecordMetadata.create(),
          routineId: routine.id,
          day: LocalDate(2026, 11, 16),
          schedule: during(7, 8),
          recordedCount: 1,
        ),
      );
      final event = await s.events.save(
        EventOccurrence(
          RecordMetadata.create(),
          title: 'Kelas',
          schedule: during(7, 8),
          seriesId: series.id,
          recurrenceKey: '2026-11-16T14:00',
          routineOccurrenceId: occurrence.id,
        ),
      );
      final task = await s.tasks.save(
        Task(
          RecordMetadata.create(),
          title: 'Laporan',
          categoryId: category.id,
          deadline: at(12),
          initialEstimate: const Duration(hours: 2),
          confirmedRemainingEstimate: const Duration(minutes: 45),
          remainingConfirmedAt: base,
        ),
      );
      final subtask = await s.subtasks.save(
        Subtask(
          RecordMetadata.create(),
          taskId: task.id,
          title: 'Cari data',
          checked: true,
        ),
      );
      final session = await s.workSessions.save(
        WorkSession(
          RecordMetadata.create(),
          taskId: task.id,
          schedule: during(9, 10),
          routineOccurrenceId: occurrence.id,
        ),
      );
      final log = await s.timeLogs.save(
        TimeLog(
          RecordMetadata.create(),
          target: ref(RecordKind.workSession, session),
          actualDuration: const Duration(minutes: 12, seconds: 23),
          recordedAt: base,
          source: TimeLogSource.manual,
        ),
      );
      final rule = await s.reminderRules.save(
        ReminderRule(
          RecordMetadata.create(),
          target: ref(RecordKind.task, task),
          anchor: ReminderAnchor.deadline,
          offset: const Duration(minutes: -15),
          enabled: true,
        ),
      );
      final replacement = await s.transaction((tx) async {
        final next = await tx.events.save(
          EventOccurrence(
            RecordMetadata.create(),
            title: event.title,
            schedule: during(14, 15),
            supersedesId: event.id,
          ),
        );
        await tx.events.save(
          EventOccurrence(
            event.metadata,
            title: event.title,
            schedule: event.schedule,
            seriesId: series.id,
            recurrenceKey: event.recurrenceKey,
            routineOccurrenceId: occurrence.id,
            status: ActivityStatus.postponed,
          ),
        );
        return next;
      });
      final history = (await s.statusHistory.all()).single;
      final trash = await s.softDelete(ref(RecordKind.subtask, subtask));
      await s.close();

      final fresh = await open();
      expect(
        (await fresh.profiles.find(
          profile.id,
        ))!.activeHours[DateTime.monday]?.endMinute,
        1260,
      );
      expect((await fresh.categories.find(category.id))!.color, 0xff537bff);
      expect(
        (await fresh.eventSeries.find(series.id))!.recurrenceRule,
        'FREQ=WEEKLY',
      );
      expect(
        (await fresh.routines.find(routine.id))!.targetDuration,
        const Duration(minutes: 30),
      );
      expect(
        (await fresh.routineOccurrences.find(occurrence.id))!.day.value,
        '2026-11-16',
      );
      expect(
        (await fresh.events.find(event.id))!.status,
        ActivityStatus.postponed,
      );
      expect((await fresh.events.find(replacement.id))!.supersedesId, event.id);
      expect(
        (await fresh.tasks.find(task.id))!.deadline!.instant,
        at(12).instant,
      );
      expect(
        (await fresh.tasks.find(task.id))!.confirmedRemainingEstimate,
        const Duration(minutes: 45),
      );
      expect((await fresh.tasks.find(task.id))!.status, ActivityStatus.planned);
      expect(await fresh.subtasks.find(subtask.id), isNull);
      expect(
        (await fresh.subtasks.find(subtask.id, includeDeleted: true))!.checked,
        isTrue,
      );
      expect(
        (await fresh.workSessions.find(session.id))!.scheduledDuration,
        const Duration(hours: 1),
      );
      expect(
        (await fresh.timeLogs.find(log.id))!.actualDuration,
        const Duration(minutes: 12, seconds: 23),
      );
      expect(
        (await fresh.reminderRules.find(rule.id))!.offset,
        const Duration(minutes: -15),
      );
      expect(
        (await fresh.statusHistory.find(history.id))!.replacement?.id,
        replacement.id,
      );
      expect((await fresh.trashEntries.find(trash.id))!.target.id, subtask.id);
      expect(
        task.id,
        matches(
          RegExp(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
          ),
        ),
      );
      await fresh.restore(trash.id);
      expect((await fresh.subtasks.find(subtask.id))!.metadata.revision, 3);
      expect((await fresh.trashEntries.find(trash.id))!.restoredAt, base);
    },
  );

  test(
    'wall time and forecast confirmation are persisted as separate fields',
    () async {
      final store = await open();
      final metadata = RecordMetadata.create();
      final time = ZonedTime(
        instant: at(9).instant,
        zoneId: asiaJakarta,
        mode: TimeMode.localWallTime,
        localWallTime: '2026-11-16T16:00',
      );
      await expectLater(
        store.tasks.save(
          Task(
            metadata,
            title: 'Konfirmasi nanti',
            deadline: time,
            confirmedRemainingEstimate: const Duration(minutes: 10),
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );
      final record = await store.tasks.save(
        Task(
          metadata,
          title: 'Konfirmasi sekarang',
          deadline: time,
          confirmedRemainingEstimate: const Duration(minutes: 10),
          remainingConfirmedAt: base,
        ),
      );
      expect(record.deadline!.mode, TimeMode.localWallTime);
      expect(record.deadline!.localWallTime, '2026-11-16T16:00');
      expect(record.deadline!.instant, at(9).instant);
      expect(record.remainingConfirmedAt, base);
      await expectLater(
        store.tasks.save(
          Task(
            record.metadata,
            title: record.title,
            deadline: ZonedTime(
              instant: time.instant,
              zoneId: time.zoneId,
              mode: time.mode,
              localWallTime: '2026-02-30T16:00',
            ),
          ),
        ),
        throwsArgumentError,
      );
      expect((await store.tasks.find(record.id))!.metadata.revision, 1);
    },
  );

  test(
    'calendar uses half-open overlap and separate deadline points',
    () async {
      final s = await open();
      final task = await s.tasks.save(
        Task(RecordMetadata.create(), title: 'Laporan', deadline: at(8)),
      );
      final session = await s.workSessions.save(
        WorkSession(
          RecordMetadata.create(),
          taskId: task.id,
          schedule: during(6, 10),
        ),
      );
      final crossing = await s.events.save(
        EventOccurrence(
          RecordMetadata.create(),
          title: 'Lintas hari',
          schedule: during(-2, 9),
        ),
      );
      await s.events.save(
        EventOccurrence(
          RecordMetadata.create(),
          title: 'Berakhir tepat pada batas',
          schedule: during(4, 8),
        ),
      );
      await s.events.save(
        EventOccurrence(
          RecordMetadata.create(),
          title: 'Mulai di batas akhir',
          schedule: during(12, 13),
        ),
      );
      await s.tasks.save(
        Task(
          RecordMetadata.create(),
          title: 'Deadline di batas akhir',
          deadline: at(12),
        ),
      );
      final allDay = await s.events.save(
        EventOccurrence(
          RecordMetadata.create(),
          title: 'Info sepanjang hari',
          schedule: during(-7, 17),
          availability: EventAvailability.allDayFree,
          allDayStart: LocalDate(2026, 11, 16),
          allDayEndExclusive: LocalDate(2026, 11, 17),
        ),
      );

      final items = await s.calendar(at(8).instant, at(12).instant);
      expect(items.map((item) => item.id), [
        allDay.id,
        crossing.id,
        session.id,
        task.id,
      ]);
      expect(items.first.availability, EventAvailability.allDayFree);
      expect(items.last.kind, CalendarEntryKind.deadline);
      expect(items.last.end, isNull);
      expect(items[2].obligationId, task.id);

      final deleted = await s.softDelete(ref(RecordKind.task, task));
      expect(await s.workSessions.find(session.id), isNull);
      expect(
        (await s.calendar(
          at(8).instant,
          at(12).instant,
        )).map((item) => item.id),
        [allDay.id, crossing.id],
      );
      expect((await s.softDelete(ref(RecordKind.task, task))).id, deleted.id);
      await s.restore(deleted.id);
      expect(
        (await s.calendar(
          at(8).instant,
          at(12).instant,
        )).map((item) => item.id),
        [allDay.id, crossing.id, session.id, task.id],
      );
    },
  );

  test(
    'typed foreign keys, singleton and optimistic updates protect record identity',
    () async {
      final s = await open();
      final task = await s.tasks.save(
        Task(RecordMetadata.create(), title: 'Pertama'),
      );
      await expectLater(
        s.subtasks.save(
          Subtask(RecordMetadata.create(), taskId: 'missing', title: 'Orphan'),
        ),
        throwsA(isA<StaleRecord>()),
      );
      await expectLater(
        s.tasks.save(
          Task(
            RecordMetadata.create(),
            title: 'Salah kategori',
            categoryId: task.id,
          ),
        ),
        throwsA(
          isA<DatabaseException>().having(
            (error) => error.toString(),
            'SQLite error',
            contains('FOREIGN KEY'),
          ),
        ),
      );
      await expectLater(
        s.categories.save(
          Category(RecordMetadata(id: task.id), name: 'ID sama', color: 0),
        ),
        throwsA(isA<DatabaseException>()),
      );
      await s.profiles.save(Profile(RecordMetadata.create(), name: 'Pertama'));
      await expectLater(
        s.profiles.save(Profile(RecordMetadata.create(), name: 'Kedua')),
        throwsA(isA<DatabaseException>()),
      );
      final updated = await s.tasks.save(Task(task.metadata, title: 'Diubah'));
      expect(updated.metadata.revision, 2);
      await expectLater(
        s.tasks.save(Task(task.metadata, title: 'Versi usang')),
        throwsA(isA<StaleRecord>()),
      );
      expect((await s.tasks.find(task.id))!.title, 'Diubah');
    },
  );

  test(
    'soft delete cascades visibility to reminders and logs while category reassignment is explicit',
    () async {
      final s = await open();
      final category = await s.categories.save(
        Category(RecordMetadata.create(), name: 'Pekerjaan', color: 1),
      );
      final task = await s.tasks.save(
        Task(RecordMetadata.create(), title: 'Tugas', categoryId: category.id),
      );
      final session = await s.workSessions.save(
        WorkSession(
          RecordMetadata.create(),
          taskId: task.id,
          schedule: during(8, 9),
        ),
      );
      final log = await s.timeLogs.save(
        TimeLog(
          RecordMetadata.create(),
          target: ref(RecordKind.workSession, session),
          actualDuration: const Duration(minutes: 15),
          recordedAt: base,
          source: TimeLogSource.timer,
        ),
      );
      final rule = await s.reminderRules.save(
        ReminderRule(
          RecordMetadata.create(),
          target: ref(RecordKind.workSession, session),
          anchor: ReminderAnchor.start,
          offset: Duration.zero,
          enabled: true,
        ),
      );
      await expectLater(
        s.softDelete(ref(RecordKind.category, category)),
        throwsStateError,
      );
      await s.transaction((tx) async {
        await tx.tasks.save(Task(task.metadata, title: task.title));
        await tx.softDelete(ref(RecordKind.category, category));
      });
      expect(await s.categories.find(category.id), isNull);
      expect((await s.tasks.find(task.id))!.categoryId, isNull);
      final trash = await s.softDelete(ref(RecordKind.task, task));
      expect(await s.timeLogs.find(log.id), isNull);
      expect(await s.reminderRules.find(rule.id), isNull);
      expect(await s.timeLogs.find(log.id, includeDeleted: true), isNotNull);
      await s.restore(trash.id);
      expect(await s.timeLogs.find(log.id), isNotNull);
      expect(await s.reminderRules.find(rule.id), isNotNull);
    },
  );

  test(
    'invalid second write rolls back the entire transaction even if caught inside',
    () async {
      final s = await open();
      final task = Task(RecordMetadata.create(), title: 'Atomik');
      final reused = RecordMetadata.create();
      final invalid = Subtask(reused, taskId: task.id, title: '   ');
      await expectLater(
        s.transaction((tx) async {
          await tx.tasks.save(task);
          try {
            await tx.subtasks.save(invalid);
          } on DatabaseException {
            expect(await tx.tasks.find(task.id), isNotNull);
          }
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect(await s.tasks.find(task.id), isNull);
      expect(await s.subtasks.all(includeDeleted: true), isEmpty);
      await s.transaction((tx) async {
        await tx.tasks.save(task);
        await tx.subtasks.save(
          Subtask(reused, taskId: task.id, title: 'Valid'),
        );
      });
      expect((await s.subtasks.all()).single.id, reused.id);
    },
  );

  test(
    'occurrence identity and actual duration survive future rescheduling attempts',
    () async {
      final s = await open();
      final task = await s.tasks.save(
        Task(RecordMetadata.create(), title: 'Riset'),
      );
      final session = await s.workSessions.save(
        WorkSession(
          RecordMetadata.create(),
          taskId: task.id,
          schedule: during(8, 9),
        ),
      );
      final log = await s.timeLogs.save(
        TimeLog(
          RecordMetadata.create(),
          target: ref(RecordKind.workSession, session),
          actualDuration: const Duration(minutes: 15),
          recordedAt: base,
          source: TimeLogSource.manual,
        ),
      );
      await expectLater(
        s.workSessions.save(
          WorkSession(
            session.metadata,
            taskId: task.id,
            schedule: during(9, 10),
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        s.timeLogs.save(
          TimeLog(
            log.metadata,
            target: log.target,
            actualDuration: const Duration(minutes: 30),
            recordedAt: base,
            source: TimeLogSource.manual,
          ),
        ),
        throwsStateError,
      );
      final series = await s.eventSeries.save(
        EventSeries(
          RecordMetadata.create(),
          title: 'Rutin',
          recurrenceRule: 'FREQ=DAILY',
          zoneId: asiaJakarta,
          timeMode: TimeMode.originalZone,
        ),
      );
      Future<EventOccurrence> generate() => s.events.save(
        EventOccurrence(
          RecordMetadata.create(),
          title: 'Rutin',
          schedule: during(6, 7),
          seriesId: series.id,
          recurrenceKey: '2026-11-16T13:00',
        ),
      );
      await generate();
      await expectLater(generate(), throwsA(isA<DatabaseException>()));
      expect(
        (await s.workSessions.find(session.id))!.schedule.start.instant,
        at(8).instant,
      );
      expect(
        (await s.timeLogs.find(log.id))!.actualDuration,
        const Duration(minutes: 15),
      );
      expect((await s.tasks.find(task.id))!.status, ActivityStatus.planned);
    },
  );

  test(
    'migrates schema 1 to current, retaining deadline and references',
    () async {
      final old = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) => createPlannerSchemaV1(db),
        ),
      );
      final created = base.microsecondsSinceEpoch;
      for (final (id, kind) in [
        ('category-v1', 'category'),
        ('task-v1', 'task'),
      ]) {
        await old.insert('records', {
          'id': id,
          'kind': kind,
          'revision': 1,
          'created_at_us': created,
          'updated_at_us': created,
        });
      }
      await old.insert('categories', {
        'id': 'category-v1',
        'name': 'Belajar',
        'color': 0,
      });
      await old.insert('tasks', {
        'id': 'task-v1',
        'title': 'Tugas lama',
        'category_id': 'category-v1',
        'status': 'planned',
        'deadline_us': at(9).instant.microsecondsSinceEpoch,
        'deadline_zone': asiaJakarta,
        'deadline_mode': 'originalZone',
      });
      await old.close();

      final migrated = await open();
      final task = (await migrated.tasks.find('task-v1'))!;
      expect(task.categoryId, 'category-v1');
      expect(task.deadline!.zoneId, asiaJakarta);
      expect(task.confirmedRemainingEstimate, isNull);
      final updated = await migrated.tasks.save(
        Task(
          task.metadata,
          title: task.title,
          deadline: task.deadline,
          categoryId: task.categoryId,
          confirmedRemainingEstimate: const Duration(minutes: 25),
          remainingConfirmedAt: base,
        ),
      );
      expect(updated.confirmedRemainingEstimate, const Duration(minutes: 25));
      await migrated.close();
      final inspect = await factory.openDatabase(path);
      addTearDown(inspect.close);
      expect(await inspect.getVersion(), plannerSchemaVersion);
      expect(await inspect.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      final plan = await inspect.rawQuery(
        'EXPLAIN QUERY PLAN SELECT id FROM tasks WHERE deadline_us >= ? AND deadline_us < ?',
        [created, at(24).instant.microsecondsSinceEpoch],
      );
      expect(plan.toString(), contains('tasks_deadline'));
    },
  );

  test(
    'schema 9 upgrade preserves rows and the active timer in schema 10',
    () async {
      final legacy = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 9,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, version) async {
            await createPlannerSchemaV1(db);
            await migratePlannerSchema(db, 1, version);
          },
        ),
      );
      for (final (id, kind, parent) in [
        ('routine-v9', 'routine', null),
        ('day-v9', 'routineOccurrence', 'routine-v9'),
        ('task-v9', 'task', null),
      ]) {
        await legacy.insert('records', {
          'id': id,
          'kind': kind,
          'parent_id': parent,
          'revision': 2,
          'created_at_us': 1,
          'updated_at_us': 2,
        });
      }
      await legacy.insert('routines', {
        'id': 'routine-v9',
        'title': 'Timer sebelum update',
        'target_type': 'duration',
        'target_duration_us': const Duration(minutes: 30).inMicroseconds,
        'checklist': '[]',
      });
      await legacy.insert('routine_occurrences', {
        'id': 'day-v9',
        'routine_id': 'routine-v9',
        'local_day': '2026-11-16',
        'status': 'planned',
        'checked_items': '[]',
      });
      await legacy.insert('routine_timers', {
        'occurrence_id': 'day-v9',
        'id': 'timer-v9',
        'accumulated_us': const Duration(minutes: 4).inMicroseconds,
        'running_since_us': base.microsecondsSinceEpoch,
      });
      await legacy.insert('tasks', {
        'id': 'task-v9',
        'title': 'Tugas sebelum update',
        'status': 'planned',
        'deadline_us': at(9).instant.microsecondsSinceEpoch,
        'deadline_zone': asiaJakarta,
        'deadline_mode': 'originalZone',
      });
      await legacy.insert('reminder_progress', {
        'id': 'reminder-v9',
        'first_seen_us': base.microsecondsSinceEpoch,
      });
      final tables = await legacy.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
      );
      final before = <String, List<Map<String, Object?>>>{};
      for (final row in tables) {
        final name = row['name']! as String;
        before[name] = await legacy.query(name);
      }
      await legacy.close();

      final migrated = await open();
      final timer = (await migrated.routineTimers()).single;
      expect(timer.id, 'timer-v9');
      expect(timer.accumulated, const Duration(minutes: 4));
      expect(timer.runningSince, base);
      expect(timer.startedOnDevice, isNull);
      expect(
        (await migrated.tasks.find('task-v9'))!.deadline!.zoneId,
        asiaJakarta,
      );
      await migrated.close();

      final inspect = await factory.openDatabase(path);
      try {
        expect(await inspect.getVersion(), 10);
        expect(await inspect.rawQuery('PRAGMA integrity_check'), [
          {'integrity_check': 'ok'},
        ]);
        expect(await inspect.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        for (final entry in before.entries) {
          expect(
            await inspect.query(entry.key),
            entry.value,
            reason: entry.key,
          );
        }
        expect(await inspect.query('routine_timer_clocks'), isEmpty);
      } finally {
        await inspect.close();
      }
    },
  );

  test('failed migration and newer version leave database intact', () async {
    final old = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await createPlannerSchemaV1(db);
          await db.execute('CREATE INDEX tasks_deadline ON tasks(deadline_us)');
        },
      ),
    );
    await old.close();
    await expectLater(
      SqlitePlannerStore.open(factory: factory, path: path),
      throwsA(isA<DatabaseException>()),
    );
    final inspect = await factory.openDatabase(path);
    expect(await inspect.getVersion(), 1);
    final columns = await inspect.rawQuery('PRAGMA table_info(tasks)');
    expect(
      columns.map((row) => row['name']),
      isNot(contains('confirmed_remaining_us')),
    );
    await inspect.setVersion(99);
    await inspect.close();

    await expectLater(
      SqlitePlannerStore.open(factory: factory, path: path),
      throwsStateError,
    );
    final newer = await factory.openDatabase(path);
    addTearDown(newer.close);
    expect(await newer.getVersion(), 99);
    expect(
      await newer.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = 'tasks'",
      ),
      hasLength(1),
    );
  });

  test(
    'normal startup adapter reloads a saved profile across app instances',
    () async {
      final firstStore = await open();
      final first = StoredPlannerProfile(
        today: base,
        openStore: () async => firstStore,
      );
      await first.load(PreviewSurface.startup);
      expect(first.profile, isNull);
      await first.saveProfile(
        PreviewProfile(
          name: 'Nara Offline',
          sundayFirst: true,
          notifications: false,
          study: 'Siang',
          workout: 'Malam',
          activeHours: {DateTime.monday: const ActiveInterval(600, 1140)},
        ),
      );
      await firstStore.close();

      final secondStore = await open();
      final second = StoredPlannerProfile(
        today: base,
        openStore: () async => secondStore,
      );
      await second.load(PreviewSurface.startup);
      expect(second.profile!.name, 'Nara Offline');
      expect(second.profile!.sundayFirst, isTrue);
      expect(second.profile!.notifications, isFalse);
      expect(second.profile!.study, 'Siang');
      expect(second.profile!.workout, 'Malam');
      expect(second.profile!.activeHours[DateTime.monday]?.start, 600);
      expect(await secondStore.events.all(), isEmpty);
    },
  );
}
