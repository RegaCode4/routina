import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/calendar_zones.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/data/stored_planner_profile.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/domain/productivity.dart';
import 'package:routina/presentation/app.dart';
import 'package:routina/presentation/design_system/planner_cards.dart';
import 'package:routina/presentation/planner/productivity_statistics.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DateTime date(int day, [int hour = 0]) => DateTime.utc(2026, 11, day, hour);

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30 && finder.evaluate().isEmpty; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> click(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> reveal(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 250, scrollable: find.byType(Scrollable).first);

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets(
    'Home opens real statistics with chart, filters, comparison and history',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = date(17, 8);
      final utc = CalendarZones(deviceZoneId: 'UTC');
      final repository = (await tester.runAsync(() async {
        final store = await SqlitePlannerStore.open(
          factory: databaseFactoryFfi,
          path: inMemoryDatabasePath,
          now: () => now,
        );
        addTearDown(store.close);
        final repository = StoredPlannerProfile(
          today: now,
          now: () => now,
          openStore: () async => store,
          readDeviceZone: () async => 'UTC',
        );
        await repository.saveProfile(PreviewProfile(name: 'Nara'));
        final work = await repository.saveCategory(
          Category(RecordMetadata.create(), name: 'Kerja', color: 0xFF537BFF),
        );
        await repository.saveCategory(
          Category(RecordMetadata.create(), name: 'Rumah', color: 0xFFFFE65B),
        );
        for (final (day, hour, name, status, category) in [
          (
            4,
            9,
            'Selesai pembanding manual',
            ActivityStatus.completed,
            work.id,
          ),
          (9, 9, 'Selesai pekan lalu', ActivityStatus.completed, work.id),
          (10, 9, 'Lewat pekan lalu', ActivityStatus.skipped, work.id),
          (
            11,
            9,
            'Di luar pembanding setara',
            ActivityStatus.completed,
            work.id,
          ),
          (16, 9, 'Selesai hari Senin', ActivityStatus.completed, work.id),
          (17, 6, 'Selesai hari Selasa', ActivityStatus.completed, work.id),
          (17, 14, 'Kegiatan berikutnya', ActivityStatus.planned, null),
        ]) {
          await store.events.save(
            EventOccurrence(
              RecordMetadata.create(),
              title: name,
              status: status,
              categoryId: category,
              schedule: utc.interval(
                date(day, hour),
                date(day, hour + 1),
                'UTC',
                TimeMode.originalZone,
              ),
            ),
          );
        }
        return repository;
      }))!;

      await tester.pumpWidget(RoutinaApp(repository: repository));
      await waitFor(tester, find.text('1 dari 2 selesai'));
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('KEGIATAN TERDEKAT'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ActivityCard &&
              widget.highlighted &&
              widget.title == 'Kegiatan berikutnya',
        ),
        findsOneWidget,
      );

      await click(tester, find.text('Statistik'));
      await waitFor(tester, find.text('Penyelesaian total'));
      expect(find.text('66,7%'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.textContaining('Awal minggu Senin'), findsOneWidget);
      expect(find.textContaining('Tanggal mendatang'), findsOneWidget);

      await click(tester, find.text('Bandingkan'));
      await click(tester, find.text('Periode sebelumnya'));
      await waitFor(tester, find.text('Penyelesaian total'));
      await reveal(tester, find.text('Perbandingan 2 hari'));
      expect(find.text('16–17 November 2026 · 2 hari'), findsOneWidget);
      expect(find.text('9–10 November 2026 · 2 hari'), findsOneWidget);
      expect(find.text('50%'), findsWidgets);

      await reveal(tester, find.text('Ubah periode pembanding'));
      await click(tester, find.text('Ubah periode pembanding'));
      await click(tester, find.text('Pilih periode manual'));
      final calendar = find.byType(DatePickerDialog);
      await waitFor(tester, calendar);
      await click(
        tester,
        find.descendant(of: calendar, matching: find.text('4')),
      );
      final localizations = MaterialLocalizations.of(tester.element(calendar));
      await click(
        tester,
        find.descendant(
          of: calendar,
          matching: find.text(localizations.okButtonLabel),
        ),
      );
      await waitFor(tester, find.text('Penyelesaian total'));
      await reveal(tester, find.text('Periode pembanding manual'));
      expect(find.text('2–3 November 2026 · 2 hari'), findsOneWidget);
      await reveal(tester, find.text('Ubah periode pembanding'));
      await click(tester, find.text('Ubah periode pembanding'));
      await click(tester, find.text('Matikan perbandingan'));
      await waitFor(tester, find.text('Penyelesaian total'));

      await click(tester, find.text('Kategori'));
      await click(tester, find.text('Rumah'));
      await waitFor(tester, find.text('Tidak Ada Aktivitas'));
      expect(find.text('Penyelesaian total'), findsNothing);
      await click(tester, find.text('Rumah'));
      await click(tester, find.text('Semua kategori'));
      await waitFor(tester, find.text('Penyelesaian total'));
      await click(tester, find.text('Jenis aktivitas'));
      await click(tester, find.text('Tugas'));
      await waitFor(tester, find.text('Tidak Ada Aktivitas'));
      await click(tester, find.text('Tugas'));
      await click(tester, find.text('Kegiatan'));
      await waitFor(tester, find.text('Penyelesaian total'));

      await click(tester, find.text('Hari'));
      await waitFor(tester, find.text('Penyelesaian per jenis'));
      expect(find.text('Rata-rata harian'), findsNothing);
      await click(tester, find.text('Bulan'));
      await waitFor(tester, find.text('Penyelesaian per kelompok tanggal'));
      expect(find.text('Rata-rata harian'), findsOneWidget);
      final details = find.text('Lihat rincian aktivitas');
      await reveal(tester, details);
      await click(tester, details);
      expect(find.text('Riwayat'), findsOneWidget);
      expect(find.text('Kegiatan berikutnya'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'SC-22 retries after a read error and renders an empty period at 200% text',
    (tester) async {
      final first = Completer<ProductivityReport>();
      final second = Completer<ProductivityReport>();
      var reads = 0;
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ProductivityStatistics(
            read: (_) => ++reads == 1 ? first.future : second.future,
          ),
        ),
      );
      expect(find.text('Memuat statistik'), findsOneWidget);
      first.completeError(StateError('fixture read failure'));
      await tester.pump();
      expect(find.text('Statistik belum tersedia'), findsOneWidget);
      await click(tester, find.text('Muat ulang'));
      expect(find.text('Memuat statistik'), findsOneWidget);
      second.complete(
        ProductivityReport(
          windows: ProductivityWindows(
            const ProductivityQuery(),
            date(17),
            sundayFirst: true,
          ),
          today: date(17),
          zone: 'UTC',
          sundayFirst: true,
          categories: const [],
          filter: const ProductivityFilter(),
          items: const [],
        ),
      );
      await tester.pump();
      expect(find.textContaining('Awal minggu Minggu'), findsOneWidget);
      await reveal(tester, find.text('Tidak Ada Aktivitas'));
      expect(find.text('Tidak Ada Aktivitas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
