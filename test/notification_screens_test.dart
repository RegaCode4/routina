import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/local_reminders.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/data/stored_planner_profile.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/app.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/planner/home_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_notifications.dart';
import 'task_screens_test.dart' show readStore, settle, tap;

void main() {
  final now = DateTime.utc(2026, 11, 16, 8);
  late Directory directory;
  late SqlitePlannerStore store;
  late StoredPlannerProfile repository;
  late FakeNotifications platform;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('routina-notif-ui-');
    store = await SqlitePlannerStore.open(
      factory: databaseFactoryFfi,
      path: '${directory.path}/data.db',
      now: () => now,
    );
    platform = FakeNotifications();
    repository = StoredPlannerProfile(
      today: now,
      now: () => now,
      openStore: () async => store,
      readDeviceZone: () async => 'UTC',
      notificationPlatform: platform,
    );
  });
  tearDown(() async {
    await store.close();
    repository.localReminders!.dispose();
    await directory.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RoutinaApp(repository: repository));
    await settle(tester);
  }

  Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
    for (var attempt = 0; attempt < 8 && !ready(); attempt++) {
      await settle(tester);
    }
    expect(ready(), isTrue);
  }

  testWidgets(
    'denied delivery exposes system settings and pending reminders in Home',
    (tester) async {
      platform.access = NotificationPermission.denied;
      await tester.runAsync(() async {
        await repository.saveProfile(PreviewProfile(name: 'Rana'));
        await repository.saveActivity(
          PreviewEvent(
            id: '',
            title: 'Kelas daring',
            start: now.add(const Duration(hours: 1)),
            end: now.add(const Duration(hours: 2)),
            options: const EventOptions(reminders: ['Saat mulai']),
          ),
        );
      });
      await mount(tester);
      expect(find.text('Notifikasi nonaktif di perangkat'), findsOneWidget);
      expect(platform.requests, 0);
      final homeList = find.descendant(
        of: find.byType(PlannerHome),
        matching: find.byType(ListView),
      );
      await tester.drag(homeList, const Offset(0, -330));
      await settle(tester);
      final settings = find.text('Buka Pengaturan Sistem');
      await tester.tap(settings);
      await settle(tester);
      expect(platform.settingsOpens, 1);
      final inbox = find.text('Lihat pengingat');
      await tap(tester, inbox);
      final sheet = find.byType(NeoBottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Kegiatan dimulai')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Kelas daring')),
        findsWidgets,
      );
      expect(platform.queued, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'enabling local reminders requests permission and Quiet Hours exceptions persist',
    (tester) async {
      platform.access = NotificationPermission.notDetermined;
      platform.answer = NotificationPermission.authorized;
      await tester.runAsync(
        () => repository.saveProfile(
          PreviewProfile(name: 'Rana', notifications: false),
        ),
      );
      await mount(tester);
      expect(platform.requests, 0);
      await tap(tester, find.bySemanticsLabel(RegExp(r'^Profil, Tab')));
      await tap(tester, find.text('Notifikasi & Quiet Hours'));
      expect(find.text('Izin notifikasi belum diminta'), findsOneWidget);
      await tap(tester, find.text('Pengingat lokal'));
      await waitFor(tester, () => platform.requests == 1);
      await waitFor(
        tester,
        () => find.text('Izin notifikasi aktif').evaluate().isNotEmpty,
      );
      expect(platform.requests, 1);
      expect(find.text('Izin notifikasi aktif'), findsOneWidget);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();
      await tap(tester, find.text('Jam Tenang'));
      await tap(tester, find.text('Aktifkan Jam Tenang'));
      await waitFor(tester, () => find.text('Jam mulai').evaluate().isNotEmpty);
      expect(find.text('Jam mulai'), findsOneWidget);
      expect(find.text('Jam selesai'), findsOneWidget);
      await tap(tester, find.text('Tenggat tugas'));
      await waitFor(
        tester,
        () =>
            platform.quiet?.exceptions.contains(ReminderKind.deadline) ?? false,
      );
      final profile = (await readStore(tester, store.profiles.all))!.single;
      expect(profile.preferences.quietEnabled, isTrue);
      expect(profile.preferences.quietExceptions, {ReminderKind.deadline});
      expect(platform.quiet?.exceptions, {ReminderKind.deadline});
      // Unmount listeners before draining SQLite work initiated by refreshes.
      await tester.pumpWidget(const SizedBox.shrink());
      await readStore(tester, store.profiles.all);
      await settle(tester);
      expect(tester.takeException(), isNull);
    },
  );
}
