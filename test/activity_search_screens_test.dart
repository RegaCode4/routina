import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/presentation/design_system/neo_theme.dart';
import 'package:routina/presentation/planner/calendar_screen.dart';
import 'package:routina/presentation/routines/routine_screens.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/search_scenario.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  Future<SearchScenario> mount(
    WidgetTester tester, {
    bool routines = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final repository = (await tester.runAsync(() async {
      final store = await SqlitePlannerStore.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
        now: () => searchNow,
      );
      addTearDown(store.close);
      final repository = await seedSearchScenario(store);
      await repository.load(PreviewSurface.startup);
      return repository;
    }))!;

    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 32)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: buildNeoTheme(),
        locale: const Locale('id'),
        supportedLocales: const [Locale('id')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: routines
              ? RoutineBoard(
                  repository: repository,
                  workspace: repository.routineWorkspace,
                  revision: 0,
                  onAdd: () {},
                  onOpen: (_, _) {},
                )
              : PlannerCalendar(
                  repository: repository,
                  requestedDay: searchNow,
                  requestedView: CalendarView.month,
                  selection: 0,
                  onOpen: (_) {},
                  onAdd: (_) {},
                ),
        ),
      ),
    );
    await settle();
    return SearchScenario(tester, settle);
  }

  testWidgets(
    'calendar combines date, title, category, status and time order',
    (tester) async {
      final flow = await mount(tester);
      await flow.action('Cari dan filter kalender');
      await flow.enter('  RAPAT ');
      await flow.reveal('Rapat Besok');
      expect(find.text('Rapat Besok'), findsOneWidget);
      expect(find.text('Rapat Arsip'), findsNothing);
      tester
          .widget<ListView>(find.byType(ListView).first)
          .controller!
          .jumpTo(0);
      await flow.settle();
      await flow.filterCurrentDate();
      expect(find.text('Rapat Besok'), findsNothing);
      await flow.text('Kategori');
      await flow.text('Proyek');
      expect(find.text('Rapat Tim Lain'), findsNothing);
      await flow.text('Status');
      await flow.text('Selesai');
      expect(find.text('Rapat Belum Selesai'), findsNothing);
      await flow.text('Urutkan');
      await flow.text('Waktu terakhir');
      flow.expectOrder('Rapat Sore', 'Rapat Pagi');
      expect(find.text('Prioritas'), findsNothing);
      await flow.enter('Tidak ada di agenda');
      expect(find.text('Aktivitas tidak ditemukan'), findsOneWidget);
      await flow.text('Bersihkan filter');
      expect(find.text('Rapat Besok'), findsOneWidget);
      await flow.action('Tutup pencarian kalender');
      expect(find.text('Lihat hari'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await flow.settle();
    },
  );

  testWidgets(
    'routine search keeps cadence, occurrence status and default view',
    (tester) async {
      final flow = await mount(tester, routines: true);
      await flow.action('Cari dan filter rutinitas');
      await flow.enter('LaTiHaN');
      expect(find.text('Latihan Akhir Pekan'), findsOneWidget);
      await flow.filterCurrentDate();
      expect(find.text('Latihan Akhir Pekan'), findsNothing);
      expect(find.text('Latihan Tanpa Jam'), findsOneWidget);
      await flow.text('Kategori');
      await flow.text('Proyek');
      await flow.text('Status');
      await flow.text('Selesai');
      expect(find.text('Latihan Tanpa Jam'), findsNothing);
      await flow.text('Urutkan');
      await flow.text('Waktu terakhir');
      flow.expectOrder('Latihan Kardio', 'Latihan Mobilitas');
      expect(find.text('Prioritas'), findsNothing);
      await flow.enter('Tidak ada di rutinitas');
      expect(find.text('Rutinitas tidak ditemukan'), findsOneWidget);
      await flow.text('Bersihkan filter');
      expect(find.text('Latihan Akhir Pekan'), findsOneWidget);
      await flow.action('Tutup pencarian rutinitas');
      expect(find.text('Rutinitas hari ini'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await flow.settle();
    },
  );
}
