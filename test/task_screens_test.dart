import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/data/stored_planner_profile.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/presentation/app.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/tasks/task_detail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 35)),
    );
    await tester.pump(const Duration(milliseconds: 175));
  }
}

Future<void> tap(WidgetTester tester, Finder widget) async {
  for (var attempt = 0; attempt < 3 && widget.evaluate().isEmpty; attempt++) {
    await settle(tester);
  }
  expect(widget, findsOneWidget);
  await tester.ensureVisible(widget);
  await tester.tap(widget);
  await settle(tester);
}

Future<T?> readStore<T>(WidgetTester tester, Future<T> Function() read) =>
    tester.runAsync(() async {
      var finished = false;
      final result = read().timeout(const Duration(seconds: 5)).whenComplete(
        () {
          finished = true;
        },
      );
      // Widget-initiated SQLite transactions resume on the fake frame clock.
      // Keep pumping while the independent real-async assertion waits on them.
      Future<void> pumpPendingFrames() async {
        while (!finished) {
          await tester.pump(const Duration(milliseconds: 16));
          await Future<void>.delayed(const Duration(milliseconds: 16));
        }
      }

      final (value, _) = await (result, pumpPendingFrames()).wait;
      return value;
    });

void main() {
  late Directory directory;
  late SqlitePlannerStore store;
  late StoredPlannerProfile repository;
  final now = DateTime.utc(2026, 11, 16, 8);

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('routina-task-ui-');
    store = await SqlitePlannerStore.open(
      factory: databaseFactoryFfi,
      path: '${directory.path}/tasks.db',
    );
    repository = StoredPlannerProfile(
      today: now,
      now: () => now,
      openStore: () async => store,
      readDeviceZone: () async => 'UTC',
    );
    await repository.saveProfile(PreviewProfile(name: 'Nara'));
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RoutinaApp(repository: repository));
    await settle(tester);
    await tap(tester, find.bySemanticsLabel(RegExp(r'^To-Do List, Tab')));
  }

  testWidgets(
    'Quick Add preserves the title, date and time in Full Form and saves to SQLite',
    (tester) async {
      await mount(tester);
      await tap(tester, find.text('Tambah tugas'));
      await tester.enterText(
        find.byType(TextFormField).first,
        'Tugas dari Quick Add',
      );
      await tap(tester, find.text('Pilih tanggal'));
      await tap(
        tester,
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('17'),
        ),
      );
      await tap(
        tester,
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.widgetWithText(TextButton, 'Pilih tanggal'),
        ),
      );
      await tap(tester, find.text('Pilih jam'));
      await tap(
        tester,
        find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.widgetWithText(TextButton, 'Pilih jam'),
        ),
      );
      await tap(tester, find.text('Buka Form Lengkap'));
      expect(find.text('Form lengkap tugas'), findsOneWidget);
      expect(find.text('Tugas dari Quick Add'), findsOneWidget);
      expect(find.textContaining('17 November 2026'), findsOneWidget);
      expect(find.text('12.00'), findsOneWidget);
      await tap(tester, find.text('Tambah subtugas'));
      await tester.enterText(
        find.descendant(
          of: find.byType(NeoBottomSheet),
          matching: find.byType(TextFormField),
        ),
        'Langkah pertama',
      );
      await tap(
        tester,
        find.descendant(
          of: find.byType(NeoBottomSheet),
          matching: find.text('Simpan'),
        ),
      );
      await tap(tester, find.text('Simpan tugas'));
      final row = (await readStore(tester, store.tasks.all))!.single;
      expect(row.title, 'Tugas dari Quick Add');
      expect(row.deadline!.instant, DateTime.utc(2026, 11, 17, 12));
      expect(
        (await readStore(tester, store.subtasks.all))!.single.title,
        'Langkah pertama',
      );
      expect(find.text('Tugas dari Quick Add'), findsOneWidget);
    },
  );

  testWidgets(
    'real task list search and checklist keep explicit completion with a choice for future sessions',
    (tester) async {
      final workspace = repository.taskWorkspace;
      final due = workspace.zones.atWall(
        DateTime.utc(2026, 11, 17, 18),
        'UTC',
        TimeMode.originalZone,
      );
      final task = (await tester.runAsync(
        () => workspace.save(
          title: 'Susun laporan',
          deadline: due,
          priority: 'Tinggi',
          subtasks: const [(existing: null, title: 'Siapkan grafik')],
        ),
      ))!;
      final work = (await tester.runAsync(
        () => workspace.saveSession(
          task.id,
          DateTime.utc(2026, 11, 17, 11),
          DateTime.utc(2026, 11, 17, 12),
        ),
      ))!;
      await tester.runAsync(
        () =>
            workspace.save(title: 'Belajar', deadline: due, subtasks: const []),
      );
      await mount(tester);
      await tester.enterText(find.byType(TextFormField).first, 'tidak ada');
      await settle(tester);
      expect(find.text('Tugas tidak ditemukan'), findsOneWidget);
      await tap(tester, find.text('Hapus filter'));
      await tester.enterText(find.byType(TextFormField).first, 'laporan');
      await settle(tester);
      expect(find.text('Belajar'), findsNothing);
      await tap(tester, find.text('Susun laporan'));
      expect(find.byType(TaskDetail), findsOneWidget);
      await tap(tester, find.text('Siapkan grafik'));
      expect(find.text('Checklist 100%'), findsOneWidget);
      expect(
        (await readStore(tester, () => store.tasks.find(task.id)))!.status,
        ActivityStatus.planned,
      );
      await tap(tester, find.text('Tandai Tugas Selesai'));
      expect(find.text('Selesai, pertahankan sesi'), findsOneWidget);
      await tap(tester, find.text('Selesai, batalkan sesi mendatang'));
      expect(
        (await readStore(tester, () => store.tasks.find(task.id)))!.status,
        ActivityStatus.completed,
      );
      expect(
        (await readStore(
          tester,
          () => store.workSessions.find(work.id),
        ))!.status,
        ActivityStatus.cancelled,
      );
    },
  );
}
