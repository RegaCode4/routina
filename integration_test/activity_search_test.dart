import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/presentation/app.dart';

import '../test/support/search_scenario.dart';

import 'support/startup_wait.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const capture = bool.fromEnvironment('ROUTINA_CAPTURE');

  testWidgets('calendar and routine filters read the native SQLite database', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp('routina-search-');
    final store = await SqlitePlannerStore.open(
      path: '${directory.path}${Platform.pathSeparator}routina.db',
      now: () => searchNow,
    );
    addTearDown(() async {
      await store.close();
      await directory.delete(recursive: true);
    });
    final repository = await seedSearchScenario(store);
    if (capture && Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }
    final flow = SearchScenario(tester, () async => tester.pumpAndSettle());
    await tester.pumpWidget(RoutinaApp(repository: repository));
    await waitForPlannerStartup(tester);
    await flow.settle();

    await flow.tab('Kalender');
    await flow.action('Cari dan filter kalender');
    await flow.enter('RAPAT');
    await flow.filterCurrentDate();
    await flow.text('Kategori');
    await flow.text('Proyek');
    await flow.text('Status');
    await flow.text('Selesai');
    await flow.text('Urutkan');
    await flow.text('Waktu terakhir');
    flow.expectOrder('Rapat Sore', 'Rapat Pagi');
    for (final title in [
      'Rapat Tim Lain',
      'Rapat Arsip',
      'Rapat Besok',
      'Rapat Belum Selesai',
    ]) {
      expect(find.text(title), findsNothing);
    }
    if (capture) await binding.takeScreenshot('f16-kalender-pencarian');
    await flow.enter('bukan agenda');
    await flow.reveal('Aktivitas tidak ditemukan');
    expect(find.text('Aktivitas tidak ditemukan'), findsOneWidget);
    if (capture) await binding.takeScreenshot('f16-kalender-kosong');

    await flow.tab('Rutinitas');
    await flow.action('Cari dan filter rutinitas');
    await flow.enter('latihan');
    await flow.filterCurrentDate();
    expect(find.text('Latihan Akhir Pekan'), findsNothing);
    expect(find.text('Latihan Tanpa Jam'), findsOneWidget);
    await flow.text('Kategori');
    await flow.text('Proyek');
    await flow.text('Status');
    await flow.text('Selesai');
    await flow.text('Urutkan');
    await flow.text('Waktu terakhir');
    flow.expectOrder('Latihan Kardio', 'Latihan Mobilitas');
    expect(find.text('Latihan Tanpa Jam'), findsNothing);
    if (capture) await binding.takeScreenshot('f16-rutinitas-pencarian');
    await flow.text('Latihan Kardio');
    expect(find.text('Detail rutinitas'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await flow.settle();
  });
}
