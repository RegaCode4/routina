import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/backup_workspace.dart';
import 'package:routina/data/backup_files.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/planner/backup_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Files implements BackupFiles {
  PickedBackup? file;
  bool cancelSave = true;

  @override
  Future<PickedBackup?> pick() async => file;

  @override
  Future<bool> save(String name, Uint8List bytes) async {
    if (cancelSave) return false;
    file = (name: name, bytes: bytes);
    return true;
  }

  @override
  Future<bool> share(String name, Uint8List bytes, Rect origin) async => false;
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 480 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsWidgets);
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets(
    'SC-27 and SC-28 encrypt, open and require explicit merge choices',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.utc(2026, 11, 17, 10);
      final (store, old) = (await tester.runAsync(() async {
        final db = await SqlitePlannerStore.open(
          factory: databaseFactoryFfi,
          path: inMemoryDatabasePath,
          now: () => now,
        );
        addTearDown(db.close);
        await db.profiles.save(Profile(RecordMetadata.create(), name: 'Nara'));
        final save = await db.tasks.save(
          Task(RecordMetadata.create(), title: 'Sebelum backup'),
        );
        return (db, save);
      }))!;
      final workspace = BackupWorkspace(
        openStore: () async => store,
        now: () => now,
      );
      final files = _Files();
      await tester.pumpWidget(
        MaterialApp(
          home: BackupScreen(
            workspace: workspace,
            files: files,
            onChanged: () async {},
          ),
        ),
      );
      await _waitFor(tester, find.text('Ekspor backup'));
      await _tap(tester, find.text('Ekspor backup'));
      final fields = find.byType(TextFormField);
      final encrypt = find.widgetWithText(NeoButton, 'Enkripsi dan lanjut');
      expect(tester.widget<NeoButton>(encrypt).onPressed, isNull);
      const password = 'sandi widget 🔐';
      await tester.enterText(fields.at(0), password);
      await tester.enterText(fields.at(1), 'lain');
      await tester.pump();
      expect(find.text('Password berbeda.'), findsOneWidget);
      expect(tester.widget<NeoButton>(encrypt).onPressed, isNull);
      await tester.enterText(fields.at(1), password);
      await tester.pump();
      await _tap(tester, encrypt);
      await _waitFor(tester, find.text('Simpan ke perangkat'));
      expect(find.byType(TextFormField), findsNothing);
      await _tap(tester, find.text('Simpan ke perangkat'));
      await _waitFor(tester, find.text('Penyimpanan dibatalkan.'));
      expect(
        (await tester.runAsync(workspace.summary))!.preferences.lastBackupAt,
        isNull,
      );
      files.cancelSave = false;
      await _tap(tester, find.text('Simpan ke perangkat'));
      await _waitFor(tester, find.text('File backup tersimpan.'));
      await _waitFor(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is NeoButton &&
              widget.label == 'Selesai' &&
              widget.onPressed != null,
        ),
      );
      expect(files.file!.bytes.sublist(0, 8), 'ROUTBKUP'.codeUnits);
      expect(
        (await tester.runAsync(workspace.summary))!.preferences.lastBackupAt,
        now,
      );
      await _tap(tester, find.text('Selesai'));
      await _waitFor(tester, find.text('Impor dan pulihkan'));
      await tester.runAsync(() async {
        await store.tasks.save(Task(old.metadata, title: 'Perubahan lokal'));
      });

      await _tap(tester, find.text('Impor dan pulihkan'));
      await _tap(tester, find.text('Pilih file'));
      await _waitFor(tester, find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), 'keliru');
      await tester.pump();
      await _tap(tester, find.text('Validasi backup'));
      await _waitFor(
        tester,
        find.textContaining('File tidak bisa diautentikasi.'),
      );
      expect(
        (await tester.runAsync(() => store.tasks.find(old.id)))!.title,
        'Perubahan lokal',
      );

      await tester.enterText(find.byType(TextFormField), password);
      await tester.pump();
      await _tap(tester, find.text('Validasi backup'));
      await _waitFor(tester, find.text('Tinjau penggabungan'));
      await _tap(tester, find.text('Tinjau penggabungan'));
      await _waitFor(tester, find.text('Konflik 1 dari 2'));
      final next = find.widgetWithText(
        NeoButton,
        'Lanjut ke konflik berikutnya',
      );
      expect(tester.widget<NeoButton>(next).onPressed, isNull);
      await _tap(
        tester,
        find.text('Pilih lokal').first,
      ); // Keep the recorded export in the profile.
      await _tap(tester, next);
      expect(find.text('Konflik 2 dari 2'), findsOneWidget);
      await _tap(tester, find.text('Pilih backup').first);
      await _tap(tester, find.text('Konfirmasi Gabungkan'));
      final dialog = find.byType(NeoDialog);
      await _tap(
        tester,
        find.descendant(of: dialog, matching: find.text('Batal')),
      );
      expect(
        (await tester.runAsync(() => store.tasks.find(old.id)))!.title,
        'Perubahan lokal',
      );
      await _tap(tester, find.text('Konfirmasi Gabungkan'));
      await _tap(
        tester,
        find.descendant(of: dialog, matching: find.text('Gabungkan')),
      );
      await _waitFor(tester, find.text('Data dipulihkan'));
      expect(
        (await tester.runAsync(() => store.tasks.find(old.id)))!.title,
        'Sebelum backup',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
