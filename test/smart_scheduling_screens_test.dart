import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/data/stored_planner_profile.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/app.dart';
import 'package:routina/presentation/tasks/task_detail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'task_screens_test.dart' show settle, tap;

void main() {
  final now = DateTime.utc(2026, 11, 16, 8);
  late Directory directory;
  late SqlitePlannerStore store;
  late StoredPlannerProfile planner;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('routina-smart-ui-');
    store = await SqlitePlannerStore.open(
      factory: databaseFactoryFfi,
      path: '${directory.path}/planner.db',
      now: () => now,
    );
    planner = StoredPlannerProfile(
      today: now,
      now: () => now,
      openStore: () async => store,
      readDeviceZone: () async => 'UTC',
    );
    await planner.saveProfile(
      PreviewProfile(
        name: 'Nara',
        activeHours: const {
          DateTime.monday: ActiveInterval(540, 600),
          DateTime.tuesday: ActiveInterval(540, 660),
          DateTime.wednesday: ActiveInterval(540, 600),
        },
        preferences: const PlannerPreferences(
          sessionLimits: (minimumMinutes: 30, maximumSessions: 3),
        ),
      ),
    );
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<Task> mount(
    WidgetTester tester, {
    int estimate = 150,
    bool withSession = false,
  }) async {
    final workspace = planner.taskWorkspace;
    final deadline = DateTime.utc(2026, 11, 18, 10);
    final task = (await tester.runAsync(() async {
      final saved = await workspace.save(
        title: 'Siapkan laporan',
        deadline: workspace.zones.atWall(
          deadline,
          'UTC',
          TimeMode.originalZone,
        ),
        estimate: Duration(minutes: estimate),
        subtasks: const [],
      );
      if (withSession) {
        await workspace.saveSession(
          saved.id,
          DateTime.utc(2026, 11, 16, 9),
          DateTime.utc(2026, 11, 16, 10),
        );
      }
      return saved;
    }))!;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RoutinaApp(repository: planner));
    await settle(tester);
    await tap(tester, find.bySemanticsLabel(RegExp(r'^To-Do List, Tab')));
    await tap(tester, find.text('Siapkan laporan'));
    expect(find.byType(TaskDetail), findsOneWidget);
    return task;
  }

  Future<void> bookMeeting(WidgetTester tester) async {
    await tester.runAsync(
      () => planner.saveActivity(
        PreviewEvent(
          id: '',
          title: 'Rapat kalender',
          start: DateTime.utc(2026, 11, 16, 9),
          end: DateTime.utc(2026, 11, 16, 10),
        ),
        approved: {ScheduleWarning.overlap},
      ),
    );
  }

  testWidgets(
    'split review can be cancelled, detects stale calendar, and saves after approval',
    (tester) async {
      final task = await mount(tester);
      await tap(tester, find.text('Cari slot'));
      expect(find.text('Cari waktu untuk fokus'), findsOneWidget);
      await tap(tester, find.text('Konfirmasi estimasi'));
      await tap(tester, find.text('Cari slot'));
      expect(find.text('Usulan · belum tersimpan'), findsOneWidget);
      expect(find.textContaining('Sesi usulan'), findsNWidgets(2));
      await tap(tester, find.text('Pilih rencana ini'));
      await tap(tester, find.text('Batal'));
      expect(await tester.runAsync(store.workSessions.all), isEmpty);

      await tap(tester, find.text('Pilih rencana ini'));
      await bookMeeting(tester);
      await tap(tester, find.text('Setujui & Simpan Sesi'));
      expect(find.text('Usulan perlu diperbarui'), findsOneWidget);
      expect(await tester.runAsync(store.workSessions.all), isEmpty);

      await tap(tester, find.text('Periksa ulang jadwal'));
      await tap(tester, find.text('Cari slot'));
      await tap(tester, find.text('Pilih rencana ini'));
      await tap(tester, find.text('Setujui & Simpan Sesi'));
      expect(find.byType(TaskDetail), findsOneWidget);
      expect(await tester.runAsync(store.workSessions.all), hasLength(2));
      expect(
        (await tester.runAsync(
          () => store.tasks.find(task.id),
        ))!.deadline!.instant,
        task.deadline!.instant,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('no solution offers explicit adjustments and manual scheduling', (
    tester,
  ) async {
    await mount(tester, estimate: 400);
    await tap(tester, find.text('Cari slot'));
    await tap(tester, find.text('Konfirmasi estimasi'));
    await tap(tester, find.text('Cari slot'));
    expect(find.text('Kendala pencarian'), findsOneWidget);
    expect(
      find.textContaining('Total waktu yang bisa dipakai'),
      findsOneWidget,
    );
    expect(find.text('Jadwalkan secara manual'), findsOneWidget);
    await tap(tester, find.text('Sesuaikan batas sesi'));
    expect(find.text('Durasi minimum per sesi'), findsOneWidget);
    expect(await tester.runAsync(store.workSessions.all), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'conflict scope and Q80 keep preserve the old plan at large text size',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await mount(tester, estimate: 120, withSession: true);
      await tap(tester, find.text('Bandingkan alokasi'));
      await tap(tester, find.text('Konfirmasi estimasi'));
      expect(find.text('Kurang 1 jam'), findsOneWidget);
      expect(find.text('Tambahkan sesi'), findsOneWidget);
      await tap(tester, find.text('Pertahankan rencana'));
      expect(find.text('Kurang 1 jam'), findsOneWidget);
      final scheduled = (await tester.runAsync(store.workSessions.all))!.single;

      await bookMeeting(tester);
      // The same lifecycle refresh used when returning from editing Calendar.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      await tap(tester, find.text('Tinjau konflik'));
      expect(find.textContaining('Bentrok · Rapat kalender'), findsOneWidget);
      await tap(tester, find.text('Tinjau opsi penjadwalan ulang'));
      expect(find.text('Seluruh sesi mendatang'), findsOneWidget);
      await tap(tester, find.text('Hanya sesi bentrok'));
      expect(find.text('Sesi yang akan dibatalkan'), findsOneWidget);
      expect(
        (await tester.runAsync(
          store.workSessions.all,
        ))!.single.metadata.revision,
        scheduled.metadata.revision,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
