import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routina/data/memory_planner_preview.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/app.dart';
import 'package:routina/presentation/demo/demo_session.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_navigation.dart';

final today = DateTime(2026, 11, 16);

Future<MemoryPlannerPreview> launch(
  WidgetTester tester, {
  String scenario = '',
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final repo = MemoryPlannerPreview(
    today: today,
    latency: Duration.zero,
    profile: PreviewProfile(
      name: 'Nara',
      activeHours: {
        for (var i = 1; i <= 7; i++) i: const ActiveInterval(480, 1260),
      },
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: RoutinaApp(repository: repo, previewScenario: scenario),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Finder button(String label) => find.widgetWithText(NeoButton, label);
Future<void> touch(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final scroll = find.byType(Scrollable);
    await tester.scrollUntilVisible(target, 260, scrollable: scroll.last);
  }
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> tab(WidgetTester tester, String title) async {
  final bar = find.byType(RoutinaBottomNavigation);
  await touch(tester, find.descendant(of: bar, matching: find.text(title)));
}

Future<void> task(WidgetTester tester) async {
  await tab(tester, 'To-Do List');
  await touch(tester, find.text('Mengerjakan Laporan E-Commerce'));
}

void main() {
  test(
    'deadline, completion, category move and restored sessions keep their own identities',
    () {
      final repo = MemoryPlannerPreview(
        today: today,
        fixture: PreviewFixture.empty,
      );
      final demo = DemoSession(repo, 'tasks-empty');
      addTearDown(demo.dispose);
      final task = DemoTask(
        title: 'Review',
        date: today,
        time: 1080,
        category: 'Belajar',
      );
      demo.saveTask(task);
      demo.applySlots(task, [
        DemoSlot(today.add(const Duration(hours: 14)), 30),
      ]);
      final deadline = repo.events.singleWhere(
        (entry) => entry.kind == PreviewKind.deadline,
      );
      final session = repo.events.singleWhere(
        (entry) => entry.kind == PreviewKind.session,
      );
      expect(deadline.start.hour, 18);
      expect(session.start.hour, 14);
      demo.deleteCategory(
        demo.categories.singleWhere((item) => item.name == 'Belajar'),
        'Pekerjaan',
      );
      expect(task.category, 'Pekerjaan');
      expect(
        repo.events.map((entry) => entry.options.category),
        everyElement('Pekerjaan'),
      );
      demo.discardTask(task);
      expect(
        repo.events.map((entry) => entry.state),
        everyElement(PreviewEventState.trashed),
      );
      demo.restore(demo.bin.singleWhere((item) => item.id == task.id));
      expect(repo.events.map((entry) => entry.id), [deadline.id, session.id]);
      expect(
        repo.events.map((entry) => entry.state),
        everyElement(PreviewEventState.upcoming),
      );
    },
  );

  testWidgets(
    'SC-11/12 checklist 100 percent keeps status and deadline separate from sessions',
    (tester) async {
      final repo = await launch(tester);
      await task(tester);
      expect(find.text('Deadline tugas'), findsOneWidget);
      await touch(tester, find.text('Tulis rangkuman'));
      expect(find.text('Checklist 100%'), findsOneWidget);
      expect(
        repo.events.singleWhere((entry) => entry.id == 'deadline').state,
        isNot(PreviewEventState.done),
      );
      await touch(tester, button('Tandai Tugas Selesai'));
      expect(button('Selesai, batalkan sesi mendatang'), findsOneWidget);
      await touch(tester, button('Batal'));
      expect(button('Tandai Tugas Selesai'), findsOneWidget);
      await touch(tester, button('Tandai Tugas Selesai'));
      await touch(tester, button('Selesai, pertahankan sesi'));
      expect(
        repo.events.singleWhere((entry) => entry.id == 'deadline').state,
        PreviewEventState.done,
      );
      expect(button('Tandai Tugas Selesai'), findsNothing);
    },
  );

  testWidgets(
    'SC-13 Quick Add draft remains in Form Lengkap and requires a deadline',
    (tester) async {
      final repo = await launch(tester);
      await touch(tester, find.byType(NeoFabAdd));
      await touch(tester, find.text('Tambah Tugas'));
      await tester.enterText(find.byType(TextFormField), 'Susun roadmap');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await touch(tester, button('Form lengkap'));
      expect(find.text('Form lengkap tugas'), findsOneWidget);
      expect(find.text('Susun roadmap'), findsOneWidget);
      await touch(tester, button('Simpan tugas'));
      expect(find.text('Lengkapi tanggal dan jam deadline.'), findsOneWidget);
      expect(
        repo.events.any((entry) => entry.title == 'Susun roadmap'),
        isFalse,
      );
    },
  );

  testWidgets(
    'SC-14/16 timer pause, restoration, manual progress and completion are separate',
    (tester) async {
      await launch(tester, scenario: 'routine-restored');
      await tab(tester, 'Rutinitas');
      await touch(tester, find.text('Belajar Flutter'));
      expect(
        find.text('Timer dipulihkan dalam sesi pratinjau ini.'),
        findsOneWidget,
      );
      await touch(tester, button('Jeda'));
      expect(find.text('Timer dijeda'), findsOneWidget);
      await touch(tester, button('Akhiri timer'));
      await touch(tester, button('Simpan durasi'));
      await touch(tester, button('Catat manual'));
      await tester.enterText(find.byType(TextFormField), '20');
      await touch(tester, button('Terapkan'));
      expect(find.text('Target tercapai'), findsOneWidget);
      expect(button('Tandai Rutinitas Selesai'), findsOneWidget);
    },
  );

  testWidgets(
    'SC-17/18 proposal does not mutate before approval and stale proposals can recheck',
    (tester) async {
      final repo = await launch(tester, scenario: 'smart-stale');
      await task(tester);
      await touch(tester, button('Cari slot'));
      final baseline = repo.events
          .where((entry) => entry.kind == PreviewKind.session)
          .length;
      await touch(tester, button('Konfirmasi estimasi'));
      await touch(tester, button('Konfirmasi estimasi').last);
      await tester.pumpAndSettle();
      expect(find.text('Usulan · belum tersimpan'), findsOneWidget);
      expect(
        repo.events.where((entry) => entry.kind == PreviewKind.session),
        hasLength(baseline),
      );
      await touch(tester, button('Tinjau dan setujui'));
      await touch(tester, button('Setujui dan simpan jadwal'));
      expect(find.text('Usulan sudah kedaluwarsa'), findsOneWidget);
      expect(
        repo.events.where((entry) => entry.kind == PreviewKind.session),
        hasLength(baseline),
      );
      await touch(tester, button('Hitung ulang'));
      await touch(tester, button('Tinjau dan setujui'));
      await touch(tester, button('Setujui dan simpan jadwal'));
      expect(
        repo.events.where((entry) => entry.kind == PreviewKind.session),
        hasLength(baseline + 1),
      );
    },
  );

  testWidgets(
    'SC-22/23/25/26 navigate settings and keep notification denial non-blocking',
    (tester) async {
      await launch(tester, scenario: 'notifications-off');
      await tab(tester, 'Profil');
      await touch(tester, find.text('Buka pengaturan notifikasi'));
      await touch(tester, button('Buka Pengaturan Sistem'));
      expect(find.text('Izin notifikasi ditolak'), findsOneWidget);
      await touch(tester, button('Batal'));
      await touch(tester, find.byTooltip('Kembali'));
      await touch(tester, find.text('Kategori'));
      expect(find.text('Kategori bersama'), findsOneWidget);
      await touch(tester, find.byTooltip('Kembali'));
      await touch(tester, find.text('Statistik'));
      await touch(tester, find.text('Hari'));
      await touch(tester, find.text('Bandingkan periode sebelumnya'));
      expect(find.text('Pembanding · 1 hari'), findsOneWidget);
    },
  );

  testWidgets(
    'SC-27/28 Replace cancel and Merge unresolved are safe, choices drive review',
    (tester) async {
      final repo = await launch(tester);
      await tab(tester, 'Profil');
      await touch(tester, find.text('Backup & Restore'));
      await touch(tester, find.text('Pulihkan dari backup'));
      await touch(tester, find.text('Belum ada file dipilih'));
      await touch(tester, button('Backup dengan satu konflik'));
      await tester.enterText(find.byType(TextFormField), 'salah');
      await touch(tester, button('Validasi backup'));
      expect(find.text('Backup tidak dapat dibuka'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'routina');
      await touch(tester, button('Validasi backup'));
      final snapshot = repo.events;
      await touch(tester, find.text('Ganti Semua'));
      expect(find.text('Ganti semua data lokal?'), findsOneWidget);
      await touch(tester, button('Batal'));
      await touch(tester, find.text('Gabungkan'));
      expect(
        tester.widget<NeoButton>(button('Tinjau gabungan')).onPressed,
        isNull,
      );
      await touch(tester, find.text('Pilih versi Backup'));
      await touch(tester, button('Tinjau gabungan'));
      await touch(tester, button('Pulihkan gabungan'));
      expect(find.text('Simulasi pemulihan selesai'), findsOneWidget);
      expect(repo.events, snapshot);
    },
  );

  testWidgets(
    'SC-29 expired and confirmation states at compact text-scaled layout',
    (tester) async {
      await launch(
        tester,
        scenario: 'trash-expired',
        size: const Size(360, 800),
        scale: 1.25,
      );
      await tab(tester, 'Profil');
      await touch(tester, find.text('Tempat Sampah'));
      expect(find.text('Retensi kedaluwarsa'), findsOneWidget);
      await touch(tester, button('Hapus Permanen').first);
      expect(find.text('Hapus item secara permanen?'), findsOneWidget);
      await touch(tester, button('Batal'));
      expect(find.text('Draf rencana bulanan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
