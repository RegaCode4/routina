import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routina/presentation/design_system/neo_badges.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_form_field.dart';
import 'package:routina/presentation/design_system/neo_navigation.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_theme.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/design_system/widget_gallery.dart';

void main() {
  test('palette and disabled labels meet 4.5:1 for normal text', () {
    for (final surface in [
      NeoColors.blue,
      NeoColors.yellow,
      NeoColors.coral,
      NeoColors.cream,
      NeoColors.paper,
      NeoColors.blueTint,
      NeoColors.yellowTint,
      NeoColors.coralTint,
      NeoColors.greenTint,
    ]) {
      expect(_contrast(NeoColors.ink, surface), greaterThanOrEqualTo(4.5));
    }
    expect(
      _contrast(NeoColors.muted, NeoColors.disabled),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(NeoColors.muted, NeoColors.cream),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(NeoColors.errorText, NeoColors.cream),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets(
    'button variants provide hover, pressed, focused and disabled states',
    (tester) async {
      var presses = 0;
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              NeoButton(label: 'Lanjutkan', onPressed: () => presses++),
              const NeoButton(label: 'Nonaktif', onPressed: null),
              NeoButton(
                label: 'Simpan',
                loading: true,
                onPressed: () => presses++,
              ),
            ],
          ),
        ),
      );

      final button = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Lanjutkan'),
          matching: find.byType(TextButton),
        ),
      );
      final style = button.style!;
      final hovered = style.overlayColor!.resolve({WidgetState.hovered});
      final pressed = style.overlayColor!.resolve({WidgetState.pressed});
      expect(hovered, NeoColors.accentHover);
      expect(pressed, NeoColors.accentPressed);
      expect(style.side!.resolve({WidgetState.focused}), NeoLine.focus);
      expect(
        style.backgroundColor!.resolve({WidgetState.disabled}),
        NeoColors.disabled,
      );
      expect(
        _contrast(NeoColors.ink, Color.alphaBlend(pressed!, NeoColors.blue)),
        greaterThanOrEqualTo(4.5),
      );

      await tester.tap(find.text('Lanjutkan'));
      await tester.tap(find.text('Nonaktif'), warnIfMissed: false);
      await tester.tap(find.text('Simpan · Memuat'), warnIfMissed: false);
      expect(presses, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets('interactive controls expose labels and 48 dp tap targets', (
    tester,
  ) async {
    bool? chipSelection;
    RoutinaTab? tabSelection;
    await tester.pumpWidget(
      _host(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NeoFabAdd(onPressed: () {}),
            NeoIconButton(
              icon: Icons.notifications_none,
              label: 'Pengingat',
              indicator: true,
              onPressed: () {},
            ),
            NeoButton(label: 'Tinjau', onPressed: () {}),
            CategoryChip(
              label: 'Belajar',
              onSelected: (value) => chipSelection = value,
            ),
            const StatusBadge(status: NeoStatus.overdue),
            RoutinaBottomNavigation(
              selected: RoutinaTab.home,
              onSelected: (tab) => tabSelection = tab,
            ),
          ],
        ),
      ),
    );

    expect(find.bySemanticsLabel('Tambah aktivitas'), findsWidgets);
    expect(find.bySemanticsLabel('Pengingat · Ada pembaruan'), findsWidgets);
    expect(find.bySemanticsLabel('Overdue'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await tester.tap(find.text('Belajar'));
    await tester.tap(find.text('Kalender'));
    expect(chipSelection, true);
    expect(tabSelection, RoutinaTab.calendar);
  });

  testWidgets('form applies validation and exposes the focused input', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _host(
        Form(
          key: form,
          child: NeoFormField(
            label: 'Judul kegiatan',
            focusNode: focus,
            validator: (value) =>
                value == null || value.isEmpty ? 'Judul wajib diisi.' : null,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    expect(focus.hasFocus, true);
    expect(form.currentState!.validate(), false);
    await tester.pump();
    expect(find.text('Judul wajib diisi.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Belajar Flutter');
    expect(form.currentState!.validate(), true);
    await tester.pump();
    expect(find.text('Judul wajib diisi.'), findsNothing);
  });

  testWidgets(
    'destructive dialog confirms or cancels at 200 percent text scale',
    (tester) async {
      _viewport(tester, const Size(320, 640), 2);
      final results = <bool?>[];
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => NeoButton(
              label: 'Tinjau',
              onPressed: () async => results.add(
                await showNeoDialog(
                  context,
                  title: 'Hapus aktivitas ini?',
                  message: 'Aktivitas akan dihapus dari daftar contoh.',
                  confirmLabel: 'Hapus aktivitas',
                  danger: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tinjau'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus aktivitas ini?'), findsOneWidget);
      await tester.ensureVisible(find.text('Batal'));
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(results, [false]);

      await tester.tap(find.text('Tinjau'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Hapus aktivitas'));
      await tester.tap(find.text('Hapus aktivitas'));
      await tester.pumpAndSettle();
      expect(results, [false, true]);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets('gallery fits ${size.width.toInt()} dp at ${scale}x', (
      tester,
    ) async {
      _viewport(tester, size, scale);
      await tester.pumpWidget(const RoutinaGalleryApp());
      await tester.pump(const Duration(milliseconds: 250));

      final scrollable = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      for (final label in [
        'Tombol',
        'Permukaan kartu dan KPI',
        'Kegiatan, tugas, dan rutinitas',
        'Status dan kategori',
        'Formulir',
        'Dialog dan bottom sheet',
        'Navigasi dan tombol tambah',
        if (scale == 1) 'To-Do List' else 'To-Do\nList',
      ]) {
        final target = find.text(label);
        await tester.scrollUntilVisible(target, 220, scrollable: scrollable);
        expect(target, findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
}

Widget _host(Widget child) {
  return MaterialApp(
    theme: buildNeoTheme(),
    home: Scaffold(body: child),
  );
}

void _viewport(WidgetTester tester, Size size, double scale) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

double _contrast(Color dark, Color light) {
  return (light.computeLuminance() + 0.05) / (dark.computeLuminance() + 0.05);
}
