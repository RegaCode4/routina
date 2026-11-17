import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:routina/application/backup_workspace.dart';
import 'package:routina/data/backup_files.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/domain/backup.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:sqflite/sqflite.dart';

import '../test/support/backup_vectors.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('legacy v1 and write failure preserve native SQLite integrity', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'routina-integrity-',
    );
    final path = '${directory.path}${Platform.pathSeparator}planner.db';
    final now = DateTime.utc(2026, 11, 17, 12);
    final store = await SqlitePlannerStore.open(path: path, now: () => now);
    addTearDown(() async {
      await store.close();
      await directory.delete(recursive: true);
    });
    await store.profiles.save(
      Profile(RecordMetadata(id: 'native-profile'), name: 'Profil perangkat'),
    );
    await store.tasks.save(
      const Task(
        RecordMetadata(id: 'native-task'),
        title: 'Tugas yang dilindungi',
      ),
    );
    final work = BackupWorkspace(openStore: () async => store, now: () => now);
    final legacy = portableBytes(legacyV1);
    final before = await store.readBackup();
    final damaged = Uint8List.fromList(legacy)..[legacy.length - 1] ^= 1;
    await expectLater(
      work.openEncrypted(damaged, portablePassword),
      throwsA(BackupIssue.authentication),
    );
    expect((await store.readBackup()).sameAs(before), isTrue);
    final plan = await work.review(
      await work.openEncrypted(legacy, portablePassword),
      RestoreMode.replace,
    );

    final inspection = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    try {
      await inspection.execute('''
        CREATE TRIGGER backup_test_abort BEFORE INSERT ON tasks
        WHEN NEW.id = 'fixture-task'
        BEGIN SELECT RAISE(ABORT, 'test rollback'); END
      ''');
      await expectLater(work.apply(plan, {}), throwsA(BackupIssue.applyFailed));
      expect((await store.readBackup()).sameAs(before), isTrue);
      expect(await inspection.rawQuery('PRAGMA foreign_key_check'), isEmpty);

      await inspection.execute('DROP TRIGGER backup_test_abort');
      await work.apply(plan, {});
      expect(
        (await store.readBackup()).sameAs(plan.backup.archive.snapshot),
        isTrue,
      );
      final task = (await store.tasks.find('fixture-task'))!;
      expect(task.title, 'Catatan cafe\u0301 ☕');
      expect(task.deadline!.instant, DateTime.utc(2026, 11, 17, 15, 30));
      expect(task.deadline!.mode, TimeMode.localWallTime);
      final reexported = await work.export(portablePassword);
      final reopened = await work.openEncrypted(reexported, portablePassword);
      final merge = await work.review(reopened, RestoreMode.merge);
      expect(merge.conflicts, isEmpty);
      await work.apply(merge, {});
      expect(
        (await store.readBackup()).sameAs(plan.backup.archive.snapshot),
        isTrue,
      );
    } finally {
      await inspection.close();
    }
  });

  // The device operator chooses the named synthetic files from Downloads.
  // The default integration run has no external picker interaction.
  if (const bool.fromEnvironment('ROUTINA_SYSTEM_BACKUP_PICKER')) {
    testWidgets(
      'native picker reads a v1 fixture and rejects oversized input',
      (tester) async {
        final read = await const SystemBackupFiles().pick();
        expect(read?.name, 'routina-v1-test.routina');
        expect(read?.bytes, portableBytes(legacyV1));
        await expectLater(
          const SystemBackupFiles().pick(),
          throwsA(BackupIssue.tooLarge),
        );
        expect(await const SystemBackupFiles().pick(), isNull);
      },
    );
  }
}
