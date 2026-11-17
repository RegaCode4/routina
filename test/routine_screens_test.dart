import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/data/stored_planner_profile.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/app.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 7; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 180));
  }
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await settle(tester);
}

void main() {
  late Directory directory;
  late String path;
  late SqlitePlannerStore store;
  late DateTime now;
  late StoredPlannerProfile repository;

  Future<void> reopen() async {
    store = await SqlitePlannerStore.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    repository = StoredPlannerProfile(
      today: now,
      now: () => now,
      openStore: () async => store,
      readDeviceZone: () async => 'UTC',
    );
  }

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('routina-routine-ui-');
    path = '${directory.path}/planner.db';
    now = DateTime.utc(2026, 11, 16, 8);
    await reopen();
    await repository.saveProfile(PreviewProfile(name: 'Nara'));
  });

  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester, {
    bool small = false,
    bool routines = true,
  }) async {
    tester.view.physicalSize = small
        ? const Size(320, 640)
        : const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    if (small) tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(RoutinaApp(repository: repository));
    await settle(tester);
    if (routines) {
      await tap(tester, find.bySemanticsLabel(RegExp(r'^Rutinitas, Tab')));
    }
  }

  testWidgets('main app tabs stay labeled and navigable at 320 dp and 200%', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await mount(tester, small: true, routines: false);
    for (final tab in [
      'Home',
      'Kalender',
      'To-Do List',
      'Rutinitas',
      'Profil',
    ]) {
      final target = find.bySemanticsLabel(RegExp('^$tab, Tab'));
      expect(target, findsOneWidget);
      expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      await tap(tester, target);
      expect(
        tester
            .getSemantics(target)
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(tester.takeException(), isNull);
    }
    semantics.dispose();
  });

  testWidgets('scaled timer exposes elapsed duration with spoken units', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final routine = (await tester.runAsync(
      () => repository.routineWorkspace.save(
        Routine(
          RecordMetadata.create(),
          title: 'Rutinitas dengan nama panjang untuk menguji ruang',
          targetType: RoutineTargetType.duration,
          targetDuration: const Duration(minutes: 2),
          frequencyRule: 'FREQ=DAILY',
        ),
      ),
    ))!;
    await mount(tester, small: true);
    await tap(tester, find.text(routine.title));
    final duration = tester.getSemantics(
      find.bySemanticsLabel('Durasi aktual sesi'),
    );
    expect(duration.value, '0 jam 0 menit 0 detik');
    expect(find.byTooltip('Pilih tanggal rutinitas'), findsOneWidget);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quick Add preserves routine name, target and frequency', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, find.text('Tambah rutinitas'));
    await tester.enterText(find.byType(TextFormField).first, 'Rutinitas lokal');
    await tap(tester, find.text('Pilih jenis target'));
    await tap(tester, find.text('Durasi'));
    await tester.enterText(find.byType(TextFormField).at(1), '25');
    await tap(tester, find.text('Pilih frekuensi'));
    await tap(tester, find.text('Setiap hari'));
    await tap(tester, find.text('Buka Form Lengkap'));
    expect(find.text('Form lengkap rutinitas'), findsOneWidget);
    expect(find.text('Rutinitas lokal'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('Setiap hari'), findsOneWidget);
    await tap(tester, find.text('Simpan rutinitas'));
    final saved = (await tester.runAsync(store.routines.all))!.single;
    expect(saved.title, 'Rutinitas lokal');
    expect(saved.targetDuration, const Duration(minutes: 25));
    expect(saved.frequencyRule, 'FREQ=DAILY');
  });

  testWidgets(
    'timer recovers across lifecycle, pause, stop and app reopening',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final routine = (await tester.runAsync(
        () => repository.routineWorkspace.save(
          Routine(
            RecordMetadata.create(),
            title: 'Latihan fokus',
            targetType: RoutineTargetType.duration,
            targetDuration: const Duration(minutes: 2),
            frequencyRule: 'FREQ=DAILY',
          ),
        ),
      ))!;
      await mount(tester);
      await tap(tester, find.text(routine.title));
      final timerText = find.byKey(const ValueKey('routine-timer-clock'));
      String? timerLabel() => tester.widget<Text>(timerText).data;

      await tap(tester, find.text('Mulai'));
      expect(timerLabel(), '00:00:00');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 67));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(timerLabel(), '00:01:07');
      expect(find.text('Timer dipulihkan'), findsOneWidget);

      await tap(tester, find.text('Jeda'));
      now = now.add(const Duration(minutes: 5));
      await settle(tester);
      expect(timerLabel(), '00:01:07');
      await tap(tester, find.text('Lanjutkan'));
      now = now.add(const Duration(seconds: 60));
      await settle(tester);
      expect(timerLabel(), '00:02:07');
      expect(find.text('Target tercapai'), findsOneWidget);
      expect(find.text('Tandai Rutinitas Selesai'), findsOneWidget);
      await tap(tester, find.text('Hentikan'));
      await tap(tester, find.text('Simpan durasi'));
      final actual = (await tester.runAsync(store.timeLogs.all))!.single;
      expect(actual.actualDuration.inSeconds, 127);
      expect(
        (await tester.runAsync(store.routineOccurrences.all))!.single.status,
        ActivityStatus.planned,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await settle(tester);
      await tester.runAsync(() async {
        await store.close();
        await reopen();
      });
      await mount(tester);
      await tap(tester, find.text(routine.title));
      await tap(tester, find.text('Riwayat aktivitas'));
      expect(find.textContaining('Latihan fokus'), findsOneWidget);
      expect(find.textContaining('00:02:07 · Timer'), findsOneWidget);
    },
  );
}
