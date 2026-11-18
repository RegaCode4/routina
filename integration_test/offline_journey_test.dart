import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:routina/data/device_notifications.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/data/stored_planner_profile.dart';
import 'package:routina/presentation/app.dart';
import 'package:routina/presentation/design_system/neo_navigation.dart';
import 'package:routina/presentation/planner/productivity_statistics.dart';

import 'support/startup_wait.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const capture = bool.fromEnvironment('ROUTINA_CAPTURE');

  testWidgets('offline setup, task entry, reload and live statistics', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp('routina-journey-');
    final path = '${directory.path}${Platform.pathSeparator}routina.db';
    final now = DateTime.utc(2026, 11, 17, 9);
    SqlitePlannerStore? store;
    addTearDown(() async {
      await store?.close();
      await directory.delete(recursive: true);
    });

    Future<void> launch() async {
      store = await SqlitePlannerStore.open(path: path, now: () => now);
      await tester.pumpWidget(
        RoutinaApp(
          repository: StoredPlannerProfile(
            today: now,
            openStore: () async => store!,
            readDeviceZone: () async => 'UTC',
            now: () => now,
            notificationPlatform: const DeviceNotifications(),
          ),
        ),
      );
      await waitForPlannerStartup(tester);
      await tester.pumpAndSettle();
    }

    Future<void> screenshot(String name) async {
      if (capture) {
        await tester.pumpAndSettle();
        await binding.takeScreenshot(name);
      }
    }

    if (capture && Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }
    await launch();
    await _tap(tester, find.text('Mulai'));
    await _tap(tester, find.text('Lanjut'));
    await _tap(tester, find.text('Lanjut'));
    await _tap(tester, find.text('Siapkan profil'));
    await tester.enterText(find.byType(TextFormField), 'Rana');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _tap(tester, find.text('Atur jam aktif'));
    await tester.scrollUntilVisible(find.text('Pakai rentang contoh'), 180);
    await _tap(tester, find.text('Pakai rentang contoh'));
    await _tap(tester, find.text('Simpan dan buka Home'));
    await _tap(tester, find.text('Buka Home'));
    await _tap(tester, find.text('Lanjut ke Home'));
    expect(find.text('Halo, Rana.'), findsOneWidget);
    expect(find.byTooltip('Pengingat'), findsOneWidget);

    await _tap(tester, find.byTooltip('Tambah aktivitas'));
    await screenshot('f15-sc30-tambah-aktivitas');
    await _tap(tester, find.text('Tambah Tugas'));
    const title = 'Tugas dari penggunaan offline';
    await tester.enterText(find.byType(TextFormField), title);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _tap(tester, find.text('Pilih tanggal'));
    final dateDialog = find.byType(DatePickerDialog);
    await _tap(
      tester,
      find.descendant(of: dateDialog, matching: find.text('17')),
    );
    await _tap(
      tester,
      find.descendant(
        of: dateDialog,
        matching: find.widgetWithText(TextButton, 'Pilih tanggal'),
      ),
    );
    await _tap(tester, find.text('Pilih jam'));
    await _tap(
      tester,
      find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.widgetWithText(TextButton, 'Pilih jam'),
      ),
    );
    await _tap(tester, find.text('Buka Form Lengkap'));
    expect(find.text(title), findsOneWidget);
    await _tap(tester, find.text('Simpan tugas'));
    expect((await store!.tasks.all()).single.title, title);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await store!.close();
    store = null;
    await launch();
    expect(find.text('Halo, Rana.'), findsOneWidget);
    await screenshot('f15-sc04-home');

    Future<void> checkStatistics() async {
      expect(find.byType(ProductivityStatistics), findsOneWidget);
      expect(find.text('Penyelesaian per hari'), findsOneWidget);
      expect(find.text('0 / 1 aktivitas selesai'), findsOneWidget);
      await _scrollTo(tester, find.text('Lihat rincian aktivitas'));
      await _tap(tester, find.text('Lihat rincian aktivitas'));
      await _scrollTo(tester, find.text(title));
      expect(find.text(title), findsOneWidget);
      await _tap(tester, find.byTooltip('Kembali'));
      await _tap(tester, find.byTooltip('Kembali'));
    }

    await _tap(tester, find.text('Statistik'));
    await screenshot('f15-sc22-statistik');
    await checkStatistics();
    await _tap(
      tester,
      find.descendant(
        of: find.byType(RoutinaBottomNavigation),
        matching: find.text('Profil'),
      ),
    );
    await screenshot('f15-sc23-profil');
    await _scrollTo(tester, find.text('Statistik'));
    await _tap(tester, find.text('Statistik'));
    await checkStatistics();

    await _tap(tester, find.text('Backup & Restore'));
    await _tap(tester, find.text('Ekspor backup'));
    expect(find.text('Simpan password dengan aman'), findsOneWidget);
    await screenshot('f15-sc27-ekspor');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (target.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  expect(target, findsWidgets, reason: 'Wait for asynchronous native storage.');
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  final vertical = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );
  await tester.scrollUntilVisible(target, 180, scrollable: vertical.first);
}
