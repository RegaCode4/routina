import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/activity_calendar.dart';
import 'package:routina/application/backup_workspace.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/application/calendar_zones.dart';
import 'package:routina/data/backup_cipher.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/data/stored_planner_profile.dart';
import 'package:routina/domain/backup.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/fake_notifications.dart';
import '../support/backup_vectors.dart';

const password = 'frasa uji backup 🔐';
const cipher = BackupCipher();

void main() {
  setUpAll(sqfliteFfiInit);
  late Directory folder;
  late List<SqlitePlannerStore> databases;
  late DateTime now;
  final utc = CalendarZones(deviceZoneId: 'UTC');

  setUp(() async {
    now = DateTime.utc(2026, 11, 17, 8);
    folder = await Directory.systemTemp.createTemp('routina-backup-');
    databases = [];
  });
  tearDown(() async {
    for (final database in databases.reversed) {
      await database.close();
    }
    await folder.delete(recursive: true);
  });

  Future<SqlitePlannerStore> database(String name) async {
    final store = await SqlitePlannerStore.open(
      factory: databaseFactoryFfi,
      path: '${folder.path}/$name.db',
      now: () => now,
    );
    databases.add(store);
    await store.profiles.save(
      Profile(
        RecordMetadata(id: 'profile-$name'),
        name: 'Profil $name',
        weekStartsOn: DateTime.sunday,
        notificationsEnabled: true,
        preferences: const PlannerPreferences(backupReminderDays: 7),
      ),
    );
    return store;
  }

  BackupWorkspace service(SqlitePlannerStore db) =>
      BackupWorkspace(openStore: () async => db, now: () => now);

  ScheduledInterval schedule(int hour, int endHour) => utc.interval(
    DateTime.utc(2026, 11, 17, hour),
    DateTime.utc(2026, 11, 17, endHour),
    'UTC',
    TimeMode.originalZone,
  );

  test(
    'restores a legacy v1 fixture with an exact Unicode password and floating deadline',
    () async {
      final local = await database('legacy-reader');
      final workspace = service(local);
      final bytes = portableBytes(legacyV1);
      final before = await local.readBackup();
      await expectLater(
        workspace.openEncrypted(bytes, 'frasa uji é 🔐'),
        throwsA(BackupIssue.authentication),
      );
      expect((await local.readBackup()).sameAs(before), isTrue);
      final read = await workspace.openEncrypted(bytes, portablePassword);
      await workspace.apply(
        await workspace.review(read, RestoreMode.replace),
        {},
      );
      expect((await local.readBackup()).sameAs(read.archive.snapshot), isTrue);
      final task = (await local.tasks.find('fixture-task'))!;
      expect(task.title, 'Catatan cafe\u0301 ☕');
      expect(task.deadline?.instant, DateTime.utc(2026, 11, 17, 15, 30));
      expect(task.deadline?.zoneId, 'Asia/Jakarta');
      expect(task.deadline?.mode, TimeMode.localWallTime);
      final tokyo = CalendarZones(deviceZoneId: 'Asia/Tokyo');
      expect(
        tokyo.effectiveTime(task.deadline!),
        DateTime.utc(2026, 11, 17, 13, 30),
      );
      expect(
        (await local.profiles.all()).single.preferences.backupReminderDays,
        14,
      );
    },
  );

  test(
    'negative authenticated input leaves the active snapshot unchanged',
    () async {
      final local = await database('transaction-guard');
      final workspace = service(local);
      final current = await local.readBackup();
      final vector = portableBytes(legacyV1);
      final truncated = Uint8List.sublistView(vector, 0, vector.length - 3);
      final unsupported = await cipher.seal(
        BackupArchive(
          now,
          BackupSnapshot(current.schemaVersion - 1, current.entities.values),
        ),
        portablePassword,
      );
      for (final (bytes, issue) in [
        (truncated, BackupIssue.authentication),
        (portableBytes(incorrectManifestV1), BackupIssue.invalidData),
        (portableBytes(duplicateIdV1), BackupIssue.invalidData),
        (unsupported, BackupIssue.unsupportedSchema),
      ]) {
        await expectLater(
          workspace.openEncrypted(bytes, portablePassword),
          throwsA(issue),
        );
        expect((await local.readBackup()).sameAs(current), isTrue);
      }
    },
  );

  test(
    'rejects a backup that would hide the singleton profile in Trash',
    () async {
      final local = await database('hidden-profile');
      final workspace = service(local);
      final current = await local.readBackup();
      final profile = current.entities.values.single;
      final timestamp = now.microsecondsSinceEpoch;
      final trash = BackupEntity(
        record: {
          'id': 'profile-tombstone',
          'kind': 'trashEntry',
          'parent_id': null,
          'revision': 1,
          'created_at_us': timestamp,
          'updated_at_us': timestamp,
        },
        data: {
          'id': 'profile-tombstone',
          'target_id': profile.id,
          'target_kind': 'profile',
          'deleted_at_us': timestamp,
          'restored_at_us': null,
          'expires_at_us': now
              .add(const Duration(days: 30))
              .microsecondsSinceEpoch,
          'series_cut': null,
          'previous_series_end': null,
          'archive_id': null,
        },
      );
      final bytes = await cipher.seal(
        BackupArchive(
          now,
          BackupSnapshot(current.schemaVersion, [profile, trash]),
        ),
        password,
      );
      await expectLater(
        workspace.openEncrypted(bytes, password),
        throwsA(BackupIssue.invalidData),
      );
      expect((await local.readBackup()).sameAs(current), isTrue);
      expect((await local.profiles.all()).single.id, profile.id);
    },
  );

  test(
    'merge rejects divergent Trash state for a stable ID before review',
    () async {
      final local = await database('merge-active');
      final incoming = await database('merge-trash');
      final task = await local.tasks.save(
        const Task(RecordMetadata(id: 'shared-task'), title: 'Tugas aktif'),
      );
      final localActive = await local.readBackup();
      await incoming.commitBackup(await incoming.readBackup(), localActive);
      final reference = (kind: RecordKind.task, id: task.id);
      await incoming.softDelete(reference);
      final workspace = service(local);
      final archived = await workspace.openEncrypted(
        await service(incoming).export(password),
        password,
      );
      await expectLater(
        workspace.review(archived, RestoreMode.merge),
        throwsA(BackupIssue.trashConflict),
      );
      expect((await local.readBackup()).sameAs(localActive), isTrue);
      expect(await local.tasks.find(task.id), isNotNull);
      final incomingWorkspace = service(incoming);
      final live = await incomingWorkspace.openEncrypted(
        await workspace.export(password),
        password,
      );
      await expectLater(
        incomingWorkspace.review(live, RestoreMode.merge),
        throwsA(BackupIssue.trashConflict),
      );
      expect(await incoming.tasks.find(task.id), isNull);
    },
  );

  test(
    'repeated Merge is a no-op for unchanged rows and reminder progress',
    () async {
      final local = await database('merge-repeat');
      final workspace = service(local);
      final legacy = await workspace.openEncrypted(
        portableBytes(legacyV1),
        portablePassword,
      );
      final first = await workspace.review(legacy, RestoreMode.merge);
      await workspace.apply(first, {
        first.conflicts.single.key: BackupChoice.local,
      });
      final progress = {
        'test-reminder': (
          firstSeen: now,
          snoozedUntil: now.add(const Duration(minutes: 5)),
        ),
      };
      await local.saveReminderProgress(progress);
      final before = await local.readBackup();
      var commits = 0;
      local.afterCommit = () async {
        commits++;
      };
      for (var index = 0; index < 2; index++) {
        final review = await workspace.review(legacy, RestoreMode.merge);
        await workspace.apply(review, {
          review.conflicts.single.key: BackupChoice.local,
        });
      }
      expect(commits, 0);
      expect(await local.reminderProgress(), progress);
      expect((await local.readBackup()).sameAs(before), isTrue);
    },
  );

  test(
    'encrypted Replace All preserves IDs, types, trash, history and timer elapsed time',
    () async {
      final source = await database('asal');
      final destination = await database('tujuan');
      final otherTask = await destination.tasks.save(
        Task(RecordMetadata.create(), title: 'Akan diganti'),
      );
      await destination.saveReminderProgress({
        'old': (firstSeen: now, snoozedUntil: null),
      });
      final category = await source.categories.save(
        Category(RecordMetadata.create(), name: 'Kerja', color: 0xFF537BFF),
      );
      final task = await source.tasks.save(
        Task(
          RecordMetadata.create(),
          title: 'Tugas yang disalin',
          categoryId: category.id,
          deadline: schedule(15, 16).start,
        ),
      );
      final subtask = await source.subtasks.save(
        Subtask(
          RecordMetadata.create(),
          taskId: task.id,
          title: 'Checklist',
          checked: true,
        ),
      );
      final original = await source.workSessions.save(
        WorkSession(
          RecordMetadata.create(),
          taskId: task.id,
          schedule: schedule(6, 7),
        ),
      );
      final session = await source.workSessions.save(
        WorkSession(
          original.metadata,
          taskId: task.id,
          schedule: original.schedule,
          status: ActivityStatus.completed,
        ),
      );
      final log = await source.timeLogs.save(
        TimeLog(
          RecordMetadata.create(),
          target: (kind: RecordKind.workSession, id: session.id),
          actualDuration: const Duration(minutes: 42),
          recordedAt: now,
          source: TimeLogSource.manual,
        ),
      );
      final routine = await source.routines.save(
        Routine(
          RecordMetadata.create(),
          title: 'Rutinitas',
          categoryId: category.id,
          targetType: RoutineTargetType.duration,
          targetDuration: const Duration(minutes: 20),
        ),
      );
      final occurrence = await source.routineOccurrences.save(
        RoutineOccurrence(
          RecordMetadata.create(),
          routineId: routine.id,
          day: LocalDate.parse('2026-11-17'),
        ),
      );
      await source.saveRoutineTimer(
        RoutineTimer(
          id: 'timer-aktif',
          occurrenceId: occurrence.id,
          accumulated: const Duration(minutes: 2),
          runningSince: now.subtract(const Duration(minutes: 5)),
        ),
      );
      await source.saveRoutineGoalEvent(
        RoutineGoalEvent(occurrence.id, now.add(const Duration(minutes: 13))),
      );
      final reminder = await source.reminderRules.save(
        ReminderRule(
          RecordMetadata.create(),
          target: (kind: RecordKind.task, id: task.id),
          anchor: ReminderAnchor.deadline,
          offset: const Duration(minutes: 30),
          enabled: true,
        ),
      );
      final calendar = ActivityCalendar(source, utc, now: () => now);
      final event = await calendar.save(
        PreviewEvent(
          id: '',
          title: 'Seri berulang',
          start: DateTime.utc(2026, 11, 17, 12),
          end: DateTime.utc(2026, 11, 17, 13),
          options: EventOptions(
            rule: EventRecurrence(RepeatFrequency.daily),
            zoneId: 'UTC',
          ),
        ),
      );
      final later = (await calendar.read(
        now,
        now.add(const Duration(days: 2)),
      )).firstWhere((row) => row.start.day == 18 && row.series == event.series);
      await calendar.change(
        later,
        PreviewEventState.trashed,
        scope: SeriesScope.following,
      );
      await source.softDelete((kind: RecordKind.task, id: task.id));

      final bytes = await service(source).export(password);
      expect((await source.routineTimers()).single.runningSince, isNotNull);
      final verified = await service(
        destination,
      ).openEncrypted(bytes, password);
      final before = await destination.readBackup();
      final plan = await service(
        destination,
      ).review(verified, RestoreMode.replace);
      expect((await destination.readBackup()).sameAs(before), isTrue);
      var notifications = 0;
      destination.afterCommit = () async {
        notifications++;
        throw StateError('simulasi kegagalan rekonsiliasi setelah commit');
      };
      await service(destination).apply(plan, {});
      expect(notifications, 1);
      expect(
        (await destination.readBackup()).sameAs(verified.archive.snapshot),
        isTrue,
      );
      expect(
        await destination.tasks.find(otherTask.id, includeDeleted: true),
        isNull,
      );
      expect(await destination.tasks.find(task.id), isNull);
      expect(
        (await destination.subtasks.find(
          subtask.id,
          includeDeleted: true,
        ))!.checked,
        isTrue,
      );
      expect(
        (await destination.timeLogs.find(
          log.id,
          includeDeleted: true,
        ))!.actualDuration.inMinutes,
        42,
      );
      expect(
        await destination.reminderRules.find(reminder.id, includeDeleted: true),
        isNotNull,
      );
      expect(
        (await destination.statusHistory.all(
          includeDeleted: true,
        )).single.target.id,
        session.id,
      );
      expect(
        (await destination.trashEntries.all()).any(
          (row) => row.seriesCut?.value == '2026-11-18',
        ),
        isTrue,
      );
      final timer = (await destination.routineTimers()).single;
      expect(timer.accumulated, const Duration(minutes: 7));
      expect(timer.runningSince, isNull);
      expect(await destination.routineGoalEvents(), isEmpty);
      expect(await destination.reminderProgress(), isEmpty);
    },
  );

  test(
    'wrong password, modified tag and authenticated orphan contents leave the live database intact',
    () async {
      final store = await database('lokal');
      final category = await store.categories.save(
        Category(RecordMetadata.create(), name: 'Punya kategori', color: 0),
      );
      final task = await store.tasks.save(
        Task(
          RecordMetadata.create(),
          title: 'Tetap ada',
          categoryId: category.id,
        ),
      );
      final before = await store.readBackup();
      final workspace = service(store);
      final payload = await workspace.export(password);
      await expectLater(
        workspace.openEncrypted(payload, 'salah'),
        throwsA(BackupIssue.authentication),
      );
      final tampered = Uint8List.fromList(payload);
      tampered[tampered.length - 1] ^= 0x01;
      await expectLater(
        workspace.openEncrypted(tampered, password),
        throwsA(BackupIssue.authentication),
      );

      final orphan = BackupSnapshot(before.schemaVersion, [
        for (final entry in before.entities.values)
          if (entry.id == task.id)
            BackupEntity(
              record: entry.record,
              data: {...entry.data, 'category_id': 'tidak-ada'},
            )
          else
            entry,
      ]);
      final invalid = await cipher.seal(BackupArchive(now, orphan), password);
      await expectLater(
        workspace.openEncrypted(invalid, password),
        throwsA(BackupIssue.invalidData),
      );
      expect((await store.readBackup()).sameAs(before), isTrue);
    },
  );

  test(
    'merge requires explicit same-ID and singleton choices, distinct IDs with equal titles survive',
    () async {
      final source = await database('file');
      final local = await database('perangkat');
      final shared = await source.tasks.save(
        Task(const RecordMetadata(id: 'sama'), title: 'Versi backup'),
      );
      await local.tasks.save(
        const Task(RecordMetadata(id: 'sama'), title: 'Versi lokal'),
      );
      final child = await source.subtasks.save(
        Subtask(
          RecordMetadata.create(),
          taskId: shared.id,
          title: 'Anak dari backup',
          checked: true,
        ),
      );
      final duplicateA = await source.tasks.save(
        Task(RecordMetadata.create(), title: 'Judul kembar'),
      );
      final duplicateB = await local.tasks.save(
        Task(RecordMetadata.create(), title: 'Judul kembar'),
      );
      final available = await service(source).export(password);
      final workspace = service(local);
      final review = await workspace.review(
        await workspace.openEncrypted(available, password),
        RestoreMode.merge,
      );
      final before = await local.readBackup();
      expect(review.conflicts.map((e) => e.key).toSet(), {
        'sama',
        'profile-perangkat',
      });
      await expectLater(
        workspace.apply(review, {'sama': BackupChoice.backup}),
        throwsA(BackupIssue.incompleteChoices),
      );
      expect((await local.readBackup()).sameAs(before), isTrue);
      await workspace.apply(review, {
        'sama': BackupChoice.backup,
        'profile-perangkat': BackupChoice.local,
      });
      expect((await local.tasks.find(shared.id))!.title, 'Versi backup');
      expect((await local.subtasks.find(child.id))!.taskId, shared.id);
      expect(
        (await local.tasks.all())
            .where((row) => row.title == 'Judul kembar')
            .map((row) => row.id)
            .toSet(),
        {duplicateA.id, duplicateB.id},
      );
      expect((await local.profiles.all()).single.id, 'profile-perangkat');
    },
  );

  test('review becomes stale if data changes before confirmation', () async {
    final store = await database('lokal');
    final workspace = service(store);
    final file = await workspace.export(password);
    final verified = await workspace.openEncrypted(file, password);
    for (final mode in RestoreMode.values) {
      final review = await workspace.review(verified, mode);
      await store.tasks.save(
        Task(RecordMetadata.create(), title: 'Baru ditambahkan'),
      );
      final current = await store.readBackup();
      await expectLater(
        workspace.apply(review, {}),
        throwsA(BackupIssue.staleReview),
      );
      expect((await store.readBackup()).sameAs(current), isTrue);
    }
  });

  test(
    'merge refuses to attach retained actual logs and final outcomes to a different schedule',
    () async {
      final remote = await database('file');
      final local = await database('perangkat');
      for (final store in [remote, local]) {
        await store.tasks.save(
          const Task(RecordMetadata(id: 'tugas'), title: 'Tugas bersama'),
        );
      }
      await remote.workSessions.save(
        WorkSession(
          const RecordMetadata(id: 'sesi'),
          taskId: 'tugas',
          schedule: schedule(10, 11),
        ),
      );
      final beforeCompletion = await local.workSessions.save(
        WorkSession(
          const RecordMetadata(id: 'sesi'),
          taskId: 'tugas',
          schedule: schedule(6, 7),
        ),
      );
      await local.workSessions.save(
        WorkSession(
          beforeCompletion.metadata,
          taskId: 'tugas',
          schedule: beforeCompletion.schedule,
          status: ActivityStatus.completed,
        ),
      );
      await local.timeLogs.save(
        TimeLog(
          RecordMetadata.create(),
          target: (kind: RecordKind.workSession, id: 'sesi'),
          actualDuration: const Duration(minutes: 40),
          recordedAt: now,
          source: TimeLogSource.manual,
        ),
      );
      final workspace = service(local);
      final sealed = await service(remote).export(password);
      final review = await workspace.review(
        await workspace.openEncrypted(sealed, password),
        RestoreMode.merge,
      );
      final before = await local.readBackup();
      final choices = {
        for (final conflict in review.conflicts)
          conflict.key: BackupChoice.local,
      };
      expect(choices.keys, contains('sesi'));
      await expectLater(
        workspace.apply(review, {...choices, 'sesi': BackupChoice.backup}),
        throwsA(BackupIssue.incompatibleMerge),
      );
      expect((await local.readBackup()).sameAs(before), isTrue);
      await workspace.apply(review, choices);
      expect(
        (await local.workSessions.find('sesi'))!.status,
        ActivityStatus.completed,
      );
    },
  );

  test(
    'an incompatible unique slot during merge leaves both local identity and references unchanged',
    () async {
      final source = await database('file');
      final local = await database('perangkat');
      for (final store in [source, local]) {
        final routine = await store.routines.save(
          Routine(
            const RecordMetadata(id: 'rutinitas-sama'),
            title: 'Rutinitas',
            targetType: RoutineTargetType.count,
            targetAmount: 1,
          ),
        );
        await store.routineOccurrences.save(
          RoutineOccurrence(
            RecordMetadata.create(),
            routineId: routine.id,
            day: LocalDate.parse('2026-11-17'),
          ),
        );
      }
      final workspace = service(local);
      final file = await service(source).export(password);
      final review = await workspace.review(
        await workspace.openEncrypted(file, password),
        RestoreMode.merge,
      );
      final before = await local.readBackup();
      await expectLater(
        workspace.apply(review, {
          for (final conflict in review.conflicts)
            conflict.key: BackupChoice.local,
        }),
        throwsA(BackupIssue.incompatibleMerge),
      );
      expect((await local.readBackup()).sameAs(before), isTrue);
    },
  );

  test(
    'a failure during actual insertion rolls back deletions and earlier inserts',
    () async {
      final source = await database('file');
      final local = await database('perangkat');
      await source.categories.save(
        Category(RecordMetadata.create(), name: 'Masuk dulu', color: 0),
      );
      await source.tasks.save(
        const Task(
          RecordMetadata(id: 'disuntik-gagal'),
          title: 'Diblokir trigger',
        ),
      );
      await local.tasks.save(
        Task(RecordMetadata.create(), title: 'Harus tetap utuh'),
      );
      final workspace = service(local);
      final sealed = await service(source).export(password);
      final review = await workspace.review(
        await workspace.openEncrypted(sealed, password),
        RestoreMode.replace,
      );
      final raw = await databaseFactoryFfi.openDatabase(
        '${folder.path}/perangkat.db',
        options: OpenDatabaseOptions(singleInstance: false),
      );
      try {
        await raw.execute('''
        CREATE TRIGGER test_restore_failure BEFORE INSERT ON tasks
        WHEN NEW.id = 'disuntik-gagal' BEGIN SELECT RAISE(ABORT, 'test rollback'); END
      ''');
        final before = await local.readBackup();
        var commits = 0;
        local.afterCommit = () async {
          commits++;
        };
        await expectLater(
          workspace.apply(review, {}),
          throwsA(BackupIssue.applyFailed),
        );
        expect(commits, 0);
        expect((await local.readBackup()).sameAs(before), isTrue);
        expect(await raw.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      } finally {
        await raw.close();
      }
    },
  );

  test(
    'a recorded export resets the notification cadence without replacing other preferences',
    () async {
      final db = await database('pengingat');
      final platform = FakeNotifications();
      final repository = StoredPlannerProfile(
        today: now,
        now: () => now,
        openStore: () async => db,
        readDeviceZone: () async => 'UTC',
        notificationPlatform: platform,
      );
      addTearDown(repository.localReminders!.dispose);
      await repository.load(PreviewSurface.startup);
      final workspace = repository.backupWorkspace;
      await workspace.setReminder(14);
      final before = platform.queued
          .firstWhere((row) => row.kind == ReminderKind.backup)
          .at;
      expect(before, now.add(const Duration(days: 14)));
      now = now.add(const Duration(days: 2));
      await workspace.recordExport();
      expect(
        platform.queued.firstWhere((row) => row.kind == ReminderKind.backup).at,
        now.add(const Duration(days: 14)),
      );
      await workspace.setReminder(null);
      expect(
        platform.queued.where((row) => row.kind == ReminderKind.backup),
        isEmpty,
      );
      expect((await workspace.summary()).preferences.lastBackupAt, now);
      expect((await db.profiles.all()).single.weekStartsOn, DateTime.sunday);
    },
  );
}
