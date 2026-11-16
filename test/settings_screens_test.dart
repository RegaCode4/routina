import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routina/data/memory_planner_preview.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/app.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

import 'phase04_screens_test.dart' as ui;

Future<void> _label(WidgetTester tester, String label) =>
    ui.touch(tester, find.text(label).last);
Future<void> _press(WidgetTester tester, String label) =>
    ui.touch(tester, ui.button(label).last);

void main() {
  testWidgets(
    'week start and timezone are independently editable, with confirmation',
    (tester) async {
      final repo = await ui.launch(tester);
      final events = repo.events;
      await ui.tab(tester, 'Profil');
      await _label(tester, 'Kalender & zona waktu');
      await _label(tester, 'Senin');
      await _press(tester, 'Minggu');
      await _press(tester, 'Batal');
      expect(repo.profile!.sundayFirst, isFalse);

      await _label(tester, 'Senin');
      await _press(tester, 'Minggu');
      await _press(tester, 'Ubah awal minggu');
      expect(repo.profile!.sundayFirst, isTrue);
      await _label(tester, 'Ikuti zona perangkat');
      await _press(tester, 'Asia/Makassar');
      await _press(tester, 'Ubah preferensi');
      expect(repo.profile!.preferences.calendarZoneId, 'Asia/Makassar');
      expect(repo.profile!.preferences.deadlineTimeMode, TimeMode.originalZone);

      await ui.touch(
        tester,
        find.descendant(
          of: find.widgetWithText(PreviewField, 'Mode waktu deadline'),
          matching: find.text('Pertahankan zona asal'),
        ),
      );
      await _press(tester, 'Ikuti jam lokal');
      expect(
        repo.profile!.preferences.deadlineTimeMode,
        TimeMode.localWallTime,
      );
      expect(repo.events, events);
    },
  );

  testWidgets(
    'category form validates duplicates and reassignment requires confirmation',
    (tester) async {
      final repo = await ui.launch(tester);
      await ui.tab(tester, 'Profil');
      await _label(tester, 'Kategori');
      await _press(tester, 'Tambah kategori');
      await tester.enterText(find.byType(TextFormField), ' belajar ');
      await _press(tester, 'Simpan kategori');
      expect(
        find.text('Nama ini sudah dipakai. Pilih nama lain.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField), 'Fokus');
      await _label(tester, 'Koral');
      await _label(tester, 'Favorit');
      await _press(tester, 'Simpan kategori');
      final focus = repo.categories.singleWhere((item) => item.name == 'Fokus');
      expect(focus.color, 0xffff8c82);
      expect(focus.icon, 'favorite');

      final ids = repo.events.map((event) => event.id).toList();
      await _label(tester, 'Belajar');
      await _press(tester, 'Hapus kategori');
      await _press(tester, 'Pindahkan ke Fokus');
      await _press(tester, 'Batal');
      expect(repo.categories.any((item) => item.name == 'Belajar'), isTrue);
      await _label(tester, 'Belajar');
      await _press(tester, 'Hapus kategori');
      await _press(tester, 'Pindahkan ke Fokus');
      await _press(tester, 'Pindahkan dan hapus kategori');
      expect(repo.categories.any((item) => item.name == 'Belajar'), isFalse);
      expect(repo.events.map((event) => event.id), ids);
      expect(
        repo.events.any((event) => event.options.category == 'Fokus'),
        isTrue,
      );
    },
  );

  testWidgets(
    'active hours rejects an incomplete or zero-length per-day interval',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final repo = MemoryPlannerPreview(
        today: DateTime(2026, 11, 16),
        profile: PreviewProfile(name: 'Nara'),
        latency: Duration.zero,
      );
      await tester.pumpWidget(RoutinaApp(repository: repo));
      await tester.pumpAndSettle();
      await ui.tab(tester, 'Profil');
      await _label(tester, 'Jam aktif & preferensi');
      await _label(tester, 'Jumat');
      await _press(tester, 'Simpan rentang');
      expect(find.text('Lengkapi waktu mulai dan selesai.'), findsOneWidget);

      for (final label in ['Mulai', 'Selesai']) {
        await ui.touch(
          tester,
          find.descendant(
            of: find.widgetWithText(PreviewField, label),
            matching: find.text('Pilih jam'),
          ),
        );
        await ui.touch(
          tester,
          find.descendant(
            of: find.byType(TimePickerDialog),
            matching: find.text('Pilih jam'),
          ),
        );
      }
      await _press(tester, 'Simpan rentang');
      expect(
        find.text('Waktu selesai harus sesudah waktu mulai.'),
        findsOneWidget,
      );
      expect(repo.profile!.activeHours[DateTime.friday], isNull);
    },
  );
}
