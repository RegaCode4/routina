import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/data/memory_planner_preview.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/app.dart';
import 'package:routina/presentation/design_system/neo_form_field.dart';
import 'package:routina/presentation/design_system/neo_navigation.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_theme.dart';
import 'package:routina/presentation/planner/event_detail.dart';
import 'package:routina/presentation/planner/event_editor.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

final _today = DateTime(2026, 11, 15);
PreviewProfile get _profile => PreviewProfile(
  name: 'Nara',
  activeHours: {
    for (var day = 1; day <= 7; day++)
      day: ActiveInterval(8 * 60, (day < 6 ? 21 : 20) * 60),
  },
);

MemoryPlannerPreview _repo({
  bool ready = true,
  PreviewFixture fixture = PreviewFixture.standard,
  Set<PreviewSurface> failOnce = const {},
  int step = 0,
}) => MemoryPlannerPreview(
  today: _today,
  profile: ready ? _profile : null,
  fixture: fixture,
  failOnce: failOnce,
  onboardingStep: step,
  latency: const Duration(milliseconds: 100),
);

Future<void> _app(WidgetTester tester, MemoryPlannerPreview repository) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(RoutinaApp(repository: repository));
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, String label) async => _tap(
  tester,
  find.descendant(
    of: find.byType(RoutinaBottomNavigation),
    matching: find.text(label),
  ),
);

Widget _route(Widget body) => MaterialApp(
  locale: const Locale('id'),
  supportedLocales: const [Locale('id')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: buildNeoTheme(),
  home: body,
);

void main() {
  testWidgets('SC-01 shows startup load, error and retry', (tester) async {
    final repo = _repo(ready: false, failOnce: {PreviewSurface.startup});
    await tester.pumpWidget(RoutinaApp(repository: repo));
    expect(find.bySemanticsLabel('Memuat Routina'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Data lokal belum terbaca'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Mulai'), findsOneWidget);
  });

  testWidgets(
    'SC-02 and SC-03 support resume, optional name, hour validation and permission preview',
    (tester) async {
      final repo = _repo(ready: false, step: 1);
      await _app(tester, repo);
      expect(find.text('Lanjutkan penyiapan'), findsOneWidget);
      await _tap(tester, find.text('Lanjutkan'));
      expect(find.text('Langkah 2 dari 3'), findsOneWidget);
      await _tap(tester, find.byTooltip('Kembali'));
      expect(find.text('Langkah 1 dari 3'), findsOneWidget);
      await _tap(tester, find.text('Lanjut'));
      await _tap(tester, find.text('Lanjut'));
      expect(find.text('Langkah 3 dari 3'), findsOneWidget);
      await _tap(tester, find.text('Siapkan profil'));
      expect(find.text('Nama tampilan (opsional)'), findsOneWidget);
      await _tap(tester, find.text('Atur jam aktif'));
      await _tap(tester, find.text('Simpan dan buka Home'));
      await tester.scrollUntilVisible(
        find.text('Lengkapi rentang jam aktif untuk semua hari.'),
        220,
      );
      expect(repo.profile, isNull);
      await tester.scrollUntilVisible(find.text('Pakai rentang contoh'), 220);
      await _tap(tester, find.text('Pakai rentang contoh'));
      await _tap(tester, find.text('Simpan dan buka Home'));
      expect(find.text('Profil tersimpan'), findsOneWidget);
      await _tap(tester, find.text('Buka Home'));
      expect(find.text('Aktifkan pengingat?'), findsOneWidget);
      await _tap(tester, find.text('Lanjut ke Home'));
      expect(find.text('Halo!'), findsOneWidget);
      expect(find.text('Notifikasi nonaktif'), findsOneWidget);
      expect(repo.profile!.name, isEmpty);
      expect(repo.profile!.activeHours.length, 7);
      expect(repo.profile!.notifications, false);
      expect(_repo(ready: false).profile, isNull);
    },
  );

  testWidgets(
    'SC-04 shows five KPIs, status confirmation, and Statistics back',
    (tester) async {
      final repo = _repo();
      await _app(tester, repo);
      expect(find.text('Halo, Nara.'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Belum selesai'), findsOneWidget);
      expect(find.text('KEGIATAN TERDEKAT'), findsOneWidget);
      await _tap(tester, find.text('Statistik'));
      expect(find.byType(RoutinaBottomNavigation), findsNothing);
      await _tap(tester, find.byTooltip('Kembali'));
      await _tap(tester, find.text('Review brief tugas').first);
      expect(find.text('Bagaimana hasilnya?'), findsOneWidget);
      await _tap(
        tester,
        find.descendant(
          of: find.byType(NeoBottomSheet),
          matching: find.text('Selesai'),
        ),
      );
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('Menunggu Konfirmasi'), findsNothing);
    },
  );

  testWidgets('Home error retries into a genuine empty KPI and empty agenda', (
    tester,
  ) async {
    final repo = _repo(
      fixture: PreviewFixture.empty,
      failOnce: {PreviewSurface.home},
    );
    await _app(tester, repo);
    expect(find.text('Agenda belum tersedia'), findsOneWidget);
    await _tap(tester, find.text('Muat ulang'));
    expect(find.text('Tidak Ada Aktivitas'), findsOneWidget);
    expect(find.text('Agenda masih kosong'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('SC-05 to SC-07 navigate periods, grid, timeline and detail', (
    tester,
  ) async {
    await _app(tester, _repo());
    await _tab(tester, 'Kalender');
    expect(find.text('November 2026'), findsOneWidget);
    await _tap(tester, find.byTooltip('Periode berikutnya'));
    expect(find.text('Desember 2026'), findsOneWidget);
    await _tap(tester, find.byTooltip('Periode sebelumnya'));
    await _tap(tester, find.byTooltip('Pilih tanggal kalender'));
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await _tap(tester, find.text('Batal'));
    expect(find.byType(DatePickerDialog), findsNothing);
    await _tap(tester, find.text('Minggu'));
    expect(find.text('WIB · Minggu dimulai Senin'), findsOneWidget);
    await _tap(tester, find.text('WIB · Minggu dimulai Senin'));
    await _tap(tester, find.text('WITA (UTC+8)'));
    expect(find.text('Zona tampilan · WITA (UTC+8)'), findsOneWidget);
    await _tap(tester, find.text('Hari'));
    await _tap(tester, find.byTooltip('Pilih tanggal kalender'));
    await _tap(tester, find.text('17').last);
    await _tap(
      tester,
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.widgetWithText(TextButton, 'Pilih tanggal'),
      ),
    );
    expect(find.text('LINIMASA'), findsOneWidget);
    expect(find.text('Pekan Kewirausahaan'), findsOneWidget);
    await _tap(
      tester,
      find.bySemanticsLabel(RegExp(r'^Kuliah E-Commerce.*14\.00')),
    );
    expect(find.text('Detail kegiatan'), findsOneWidget);
    expect(find.text('13.00–16.00'), findsOneWidget);
  });

  testWidgets(
    'SC-08 recurring edit and trash need explicit scope and approval',
    (tester) async {
      final repo = _repo();
      await tester.pumpWidget(
        _route(EventDetail(repository: repo, id: 'course')),
      );
      await _tap(tester, find.text('Edit kegiatan'));
      await _tap(tester, find.text('Hanya kejadian ini'));
      expect(find.text('Cakupan perubahan'), findsOneWidget);
      await _tap(tester, find.byTooltip('Kembali'));
      await _tap(tester, find.text('Hapus kegiatan'));
      await _tap(tester, find.text('Hanya kejadian ini'));
      expect(find.text('Pindahkan ke Tempat Sampah?'), findsOneWidget);
      await _tap(
        tester,
        find.descendant(
          of: find.byType(NeoBottomSheet),
          matching: find.text('Hapus kegiatan'),
        ),
      );
      expect(find.text('Di Tempat Sampah'), findsOneWidget);
      expect(
        repo.events.firstWhere((event) => event.id == 'course-next').state,
        PreviewEventState.upcoming,
      );
    },
  );

  testWidgets('FAB routes to blank SC-09 with no default times', (
    tester,
  ) async {
    await _app(tester, _repo());
    await _tap(tester, find.byTooltip('Tambah aktivitas'));
    expect(find.text('Tambah Tugas'), findsOneWidget);
    expect(find.text('Tambah Rutinitas'), findsOneWidget);
    await _tap(tester, find.text('Tambah Kegiatan'));
    expect(find.text('Quick Add'), findsOneWidget);
    expect(find.text('Pilih jam'), findsNWidgets(2));
    expect(find.text('Pilih tanggal'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Kegiatan tanpa jam');
    await tester.pump();
    await _tap(tester, find.text('Simpan kegiatan'));
    expect(find.text('Jadwal belum lengkap'), findsOneWidget);
  });

  testWidgets(
    'Quick Add keeps entered title, selected date, start and end in Full Form',
    (tester) async {
      final draft = EventDraft(date: _today)
        ..start = 9 * 60
        ..end = 10 * 60;
      await tester.pumpWidget(
        _route(EventEditor(repository: _repo(), draft: draft)),
      );
      await tester.enterText(find.byType(TextFormField), 'Belajar bersama');
      await _tap(tester, find.text('Buka Form Lengkap'));
      expect(find.text('FORM LENGKAP'), findsOneWidget);
      expect(find.text('Belajar bersama'), findsOneWidget);
      expect(find.text('Min, 15 November 2026'), findsNWidgets(2));
      expect(find.text('09.00'), findsOneWidget);
      expect(find.text('10.00'), findsOneWidget);
    },
  );

  testWidgets(
    'overlap and active-hours warnings do not mutate until confirmed',
    (tester) async {
      final repo = _repo();
      final draft = EventDraft(date: _today, title: 'Tambahan malam')
        ..start = 19 * 60 + 30
        ..end = 20 * 60 + 30;
      await tester.pumpWidget(
        _route(EventEditor(repository: repo, draft: draft)),
      );
      expect(find.text('Jadwal bertabrakan'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Di luar jam aktif'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Di luar jam aktif'), findsOneWidget);
      await _tap(tester, find.text('Simpan kegiatan'));
      await _tap(tester, find.text('Batal'));
      expect(
        repo.events.any((entry) => entry.title == 'Tambahan malam'),
        false,
      );
      await _tap(tester, find.text('Simpan kegiatan'));
      await _tap(tester, find.text('Simpan dengan peringatan'));
      expect(find.text('Kegiatan tersimpan'), findsOneWidget);
      expect(repo.events.any((entry) => entry.title == 'Tambahan malam'), true);
      expect(
        _repo().events.any((entry) => entry.title == 'Tambahan malam'),
        false,
      );
    },
  );

  testWidgets('calendar retry and empty day are reachable', (tester) async {
    await _app(
      tester,
      _repo(fixture: PreviewFixture.empty, failOnce: {PreviewSurface.calendar}),
    );
    await _tab(tester, 'Kalender');
    expect(find.text('Kalender belum tersedia'), findsOneWidget);
    await _tap(tester, find.text('Muat ulang kalender'));
    await _tap(tester, find.text('Hari'));
    expect(find.text('Tidak Ada Aktivitas'), findsOneWidget);
    expect(find.text('Tambah kegiatan'), findsOneWidget);
  });

  testWidgets(
    'SC-10 exposes all-day availability, multiple reminders, custom cycle and link validation',
    (tester) async {
      final repo = _repo();
      final draft = EventDraft.fromEvent(
        repo.events.firstWhere((event) => event.id == 'course'),
      );
      await tester.pumpWidget(
        _route(EventEditor(repository: repo, draft: draft, full: true)),
      );
      final scrollable = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      Future<void> reach(Finder target) async {
        await tester.scrollUntilVisible(target, 280, scrollable: scrollable);
        await _tap(tester, target);
      }

      await reach(find.text('Kegiatan sepanjang hari'));
      expect(find.text('Sibuk · memblokir rekomendasi'), findsOneWidget);
      await _tap(tester, find.text('Tersedia'));
      expect(draft.availability, DayAvailability.free);
      final pattern = find.widgetWithText(PreviewField, 'Pola');
      await tester.scrollUntilVisible(pattern, 220, scrollable: scrollable);
      await _tap(
        tester,
        find.descendant(of: pattern, matching: find.text('Mingguan · Selasa')),
      );
      await _tap(tester, find.text('Kustom bulanan'));
      await _tap(tester, find.text('Terapkan pengulangan'));
      expect(draft.recurrence, 'Setiap 2 bulan');
      final reminders = find.widgetWithText(PreviewField, 'Pengingat lokal');
      await tester.scrollUntilVisible(reminders, 220, scrollable: scrollable);
      await _tap(
        tester,
        find.descendant(
          of: reminders,
          matching: find.text('30 menit sebelumnya'),
        ),
      );
      await _tap(tester, find.text('1 hari sebelumnya'));
      await _tap(tester, find.text('Saat mulai'));
      await _tap(tester, find.text('Terapkan pengingat'));
      expect(draft.reminders, hasLength(3));
      final link = find.widgetWithText(NeoFormField, 'Tautan (opsional)');
      await tester.scrollUntilVisible(link, 250, scrollable: scrollable);
      final field = find.descendant(
        of: link,
        matching: find.byType(TextFormField),
      );
      await tester.enterText(field, 'tautan yang keliru');
      await tester.pumpAndSettle();
      expect(
        find.text('Gunakan tautan HTTP atau HTTPS yang valid.'),
        findsOneWidget,
      );
      await tester.enterText(field, 'https://example.com/kegiatan');
      await tester.pumpAndSettle();
      expect(find.text('Format tautan valid.'), findsOneWidget);
    },
  );

  test('preview separates buffer, overlap, and cross-midnight KPI', () {
    final repo = _repo(fixture: PreviewFixture.crossMidnight);
    final draft = EventDraft(date: _today, title: 'Jeda contoh')
      ..start = 20 * 60 + 5
      ..end = 20 * 60 + 30
      ..before = 10;
    expect(previewWarnings(repo, draft.candidate()!), [
      ScheduleWarning.buffer,
      ScheduleWarning.activeHours,
    ]);
    final daily = DailyPreview(repo.events, _today);
    expect(daily.agenda.any((event) => event.id == 'cross-demo'), true);
    expect(daily.total, 5);
    expect(daily.completed, 3);
  });
}
