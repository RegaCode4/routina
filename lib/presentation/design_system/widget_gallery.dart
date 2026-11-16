import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:routina/presentation/design_system/neo_badges.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_form_field.dart';
import 'package:routina/presentation/design_system/neo_navigation.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_theme.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/design_system/planner_cards.dart';

void main() => runApp(const RoutinaGalleryApp());

class RoutinaGalleryApp extends StatelessWidget {
  const RoutinaGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galeri Routina',
      locale: const Locale('id'),
      supportedLocales: const [Locale('id')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildNeoTheme(),
      debugShowCheckedModeBanner: false,
      home: const WidgetGallery(),
    );
  }
}

class WidgetGallery extends StatefulWidget {
  const WidgetGallery({super.key});

  @override
  State<WidgetGallery> createState() => _WidgetGalleryState();
}

class _WidgetGalleryState extends State<WidgetGallery> {
  RoutinaTab _tab = RoutinaTab.home;
  bool _selected = false;
  bool _expanded = false;

  void _notice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showDialog({required bool danger}) async {
    final confirmed = await showNeoDialog(
      context,
      title: danger ? 'Hapus aktivitas ini?' : 'Simpan pilihan?',
      message: danger
          ? 'Konfirmasi tindakan berisiko pada aktivitas contoh.'
          : 'Pilihan contoh akan ditampilkan dalam galeri.',
      confirmLabel: danger ? 'Hapus aktivitas' : 'Simpan pilihan',
      danger: danger,
    );
    if (mounted && confirmed == true) _notice('Pilihan dikonfirmasi');
  }

  Future<void> _showSheet() async {
    final option = await showNeoBottomSheet<String>(
      context,
      builder: (context) => NeoBottomSheet(
        title: 'Cakupan pengulangan',
        description: 'Pilih aktivitas yang akan diubah.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final label in [
              'Hanya kejadian ini',
              'Ini dan berikutnya',
            ]) ...[
              NeoButton(
                label: label,
                variant: NeoButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(label),
              ),
              const SizedBox(height: NeoSpace.xs),
            ],
          ],
        ),
      ),
    );
    if (mounted && option != null) _notice(option);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Galeri Routina',
              action: NeoIconButton(
                icon: Icons.notifications_none,
                label: 'Pengingat',
                indicator: true,
                onPressed: () => _notice('Ada pengingat contoh'),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(NeoSpace.page),
                children: [
                  const _GallerySection(
                    title: 'Palet dan tipografi',
                    children: [
                      Wrap(
                        spacing: NeoSpace.xs,
                        runSpacing: NeoSpace.xs,
                        children: [
                          _Swatch('Blue', NeoColors.blue),
                          _Swatch('Yellow', NeoColors.yellow),
                          _Swatch('Coral', NeoColors.coral),
                          _Swatch('Cream', NeoColors.cream),
                          _Swatch('Ink', NeoColors.ink),
                        ],
                      ),
                      Text('Rencanakan fokus', style: NeoType.display),
                      Text('Jaga ritmemu setiap hari.', style: NeoType.body),
                      Text('19.00–20.00', style: NeoType.numericCaption),
                    ],
                  ),
                  _GallerySection(
                    title: 'Tombol',
                    children: [
                      NeoButton(
                        label: 'Lanjutkan',
                        onPressed: () => _notice('Tombol utama ditekan'),
                      ),
                      NeoButton(
                        label: 'Tinjau',
                        variant: NeoButtonVariant.secondary,
                        onPressed: () => _notice('Tombol sekunder ditekan'),
                      ),
                      NeoButton(
                        label: 'Hapus permanen',
                        variant: NeoButtonVariant.danger,
                        onPressed: () => _showDialog(danger: true),
                      ),
                      const NeoButton(label: 'Nonaktif', onPressed: null),
                      NeoButton(
                        label: 'Menyimpan',
                        loading: true,
                        onPressed: () => _notice('Tersimpan'),
                      ),
                    ],
                  ),
                  _GallerySection(
                    title: 'Permukaan kartu dan KPI',
                    children: [
                      for (final variant in NeoCardTone.values)
                        NeoCard(
                          tone: variant,
                          emphasis: variant == NeoCardTone.accent,
                          onTap: variant == NeoCardTone.selected
                              ? () => _notice('Kartu terpilih')
                              : null,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: NeoSize.cardSample - 2 * NeoSpace.md,
                            ),
                            child: Text(switch (variant) {
                              NeoCardTone.plain => 'Kartu standar',
                              NeoCardTone.highlighted => 'Kartu sorotan',
                              NeoCardTone.warning => 'Kartu peringatan',
                              NeoCardTone.selected => 'Kartu terpilih',
                              NeoCardTone.accent => 'Kartu utama',
                            }, style: NeoType.item),
                          ),
                        ),
                      KpiTile(
                        label: 'Penyelesaian hari ini',
                        value: '60%',
                        description: '3 dari 5 aktivitas selesai',
                        progress: 0.6,
                        onTap: () => _notice('Ringkasan aktivitas contoh'),
                      ),
                      const KpiTile(label: 'Penyelesaian tanpa data'),
                    ],
                  ),
                  _GallerySection(
                    title: 'Kegiatan, tugas, dan rutinitas',
                    children: [
                      ActivityCard(
                        title: 'Rapat Kelompok',
                        time: '19.00–20.00 WIB',
                        category: 'Kegiatan',
                        highlighted: true,
                        onTap: () => _notice('Contoh kegiatan'),
                      ),
                      const ActivityCard(
                        title: 'Review brief tugas',
                        time: '08.30–09.15 WIB',
                        recurring: true,
                        status: NeoStatus.conflicted,
                      ),
                      const TaskCard(
                        title: 'Mengerjakan Laporan E-Commerce',
                        due: 'Jum, 20 Nov · 23.59 WIB',
                        priority: 'Prioritas tinggi',
                        subtasks: '2/3 subtugas · 67%',
                        subtaskProgress: 0.67,
                        sessions: '1 sesi dijadwalkan',
                      ),
                      const TaskCard(
                        title: 'Unggah ringkasan',
                        due: 'Sab, 14 Nov · 23.59 WIB',
                        status: NeoStatus.overdue,
                      ),
                      const RoutineCard(
                        title: 'Belajar Flutter',
                        target: '30 menit',
                        actual: '20 menit',
                        progress: 2 / 3,
                        timer: 'Timer berjalan · 00:20:00',
                      ),
                      const RoutineCard(
                        title: 'Workout Pagi',
                        target: '30 menit',
                        actual: '0 menit',
                        status: NeoStatus.missed,
                      ),
                    ],
                  ),
                  _GallerySection(
                    title: 'Status dan kategori',
                    children: [
                      Wrap(
                        spacing: NeoSpace.xs,
                        runSpacing: NeoSpace.xs,
                        children: [
                          for (final status in NeoStatus.values)
                            StatusBadge(status: status),
                        ],
                      ),
                      Wrap(
                        spacing: NeoSpace.xs,
                        runSpacing: NeoSpace.xs,
                        children: [
                          CategoryChip(
                            label: 'Belajar',
                            color: NeoColors.blue,
                            icon: Icons.auto_awesome_outlined,
                            selected: _selected,
                            onSelected: (value) =>
                                setState(() => _selected = value),
                          ),
                          const CategoryChip(
                            label: 'Kesehatan',
                            icon: Icons.favorite_outline,
                            color: NeoColors.coral,
                            selected: true,
                          ),
                          const CategoryChip(),
                        ],
                      ),
                    ],
                  ),
                  const _GallerySection(
                    title: 'Formulir',
                    children: [
                      NeoFormField(
                        label: 'Judul kegiatan',
                        hint: 'Isi judul kegiatan',
                        helper: 'Judul muncul di kalender.',
                        icon: Icons.event_outlined,
                      ),
                      NeoFormField(
                        label: 'Tenggat',
                        errorText: 'Masukkan tanggal tenggat yang valid.',
                      ),
                      NeoFormField(label: 'Arsip', enabled: false),
                      NeoFormField(label: 'Kata sandi', obscureText: true),
                    ],
                  ),
                  _GallerySection(
                    title: 'Dialog dan bottom sheet',
                    children: [
                      NeoButton(
                        label: 'Buka dialog konfirmasi',
                        onPressed: () => _showDialog(danger: false),
                      ),
                      NeoButton(
                        label: 'Buka bottom sheet',
                        variant: NeoButtonVariant.secondary,
                        onPressed: _showSheet,
                      ),
                    ],
                  ),
                  _GallerySection(
                    title: 'Navigasi dan tombol tambah',
                    children: [
                      RoutinaBottomNavigation(
                        selected: _tab,
                        onSelected: (tab) => setState(() => _tab = tab),
                      ),
                      Wrap(
                        spacing: NeoSpace.md,
                        runSpacing: NeoSpace.md,
                        children: [
                          NeoFabAdd(
                            expanded: _expanded,
                            onPressed: () =>
                                setState(() => _expanded = !_expanded),
                          ),
                          const NeoFabAdd(onPressed: null),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GallerySection extends StatelessWidget {
  const _GallerySection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NeoSpace.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(title, style: NeoType.section)),
          for (final item in children) ...[
            const SizedBox(height: NeoSpace.sm),
            item,
          ],
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hex = color.toARGB32().toRadixString(16).substring(2).toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: NeoRadius.small,
        border: const Border.fromBorderSide(NeoLine.thin),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NeoSpace.xs),
        child: Text(
          '$label\n#$hex',
          style: NeoType.caption.copyWith(
            color: color == NeoColors.ink ? NeoColors.paper : NeoColors.ink,
          ),
        ),
      ),
    );
  }
}
