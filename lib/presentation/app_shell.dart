import 'package:flutter/material.dart';
import 'package:routina/application/read_today.dart';
import 'package:routina/domain/result.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_navigation.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.readToday, super.key});

  final ReadToday readToday;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  RoutinaTab _tab = RoutinaTab.home;
  bool _addOpen = false;
  late Result<DateTime> _today;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _today = widget.readToday();
    _lifecycle = AppLifecycleListener(onResume: _refreshToday);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _refreshToday() => setState(() => _today = widget.readToday());

  Future<void> _openAdd() async {
    if (_addOpen) return;
    setState(() => _addOpen = true);

    try {
      final option = await showNeoBottomSheet<_AddOption>(
        context,
        builder: (_) => const _AddOptions(),
      );
      if (!mounted || option == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Formulir ${option.title} belum tersedia.')),
      );
    } finally {
      if (mounted) setState(() => _addOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(title: _tab.label),
            Expanded(
              child: IndexedStack(
                index: _tab.index,
                children: [
                  _HomeContent(today: _today, onRetry: _refreshToday),
                  for (final _ in RoutinaTab.values.skip(1))
                    const _UnavailableContent(hasFab: true),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: RoutinaBottomNavigation(
        selected: _tab,
        onSelected: (tab) => setState(() => _tab = tab),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsetsDirectional.only(end: NeoSpace.xs),
        child: NeoFabAdd(
          onPressed: _addOpen ? null : _openAdd,
          expanded: _addOpen,
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.today, required this.onRetry});

  final Result<DateTime> today;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NeoSpace.page,
        NeoSpace.md,
        NeoSpace.page,
        NeoSize.fab + NeoSpace.section,
      ),
      children: [
        switch (today) {
          Success(:final value) => Text(
            MaterialLocalizations.of(context).formatFullDate(value),
            style: NeoType.caption.copyWith(color: NeoColors.muted),
          ),
          Failure() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tanggal perangkat belum dapat ditampilkan.'),
              const SizedBox(height: NeoSpace.xs),
              NeoButton(
                label: 'Coba lagi',
                variant: NeoButtonVariant.secondary,
                onPressed: onRetry,
              ),
            ],
          ),
        },
        const SizedBox(height: NeoSpace.md),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: NeoButton(
            icon: Icons.bar_chart,
            label: 'Statistik',
            variant: NeoButtonVariant.secondary,
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/statistik'),
                builder: (_) => const Scaffold(
                  body: SafeArea(
                    child: Column(
                      children: [
                        AppHeader(title: 'Statistik', showBack: true),
                        Expanded(child: _UnavailableContent()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UnavailableContent extends StatelessWidget {
  const _UnavailableContent({this.hasFab = false});

  final bool hasFab;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        NeoSpace.page,
        NeoSpace.md,
        NeoSpace.page,
        hasFab ? NeoSize.fab + NeoSpace.section : NeoSpace.page,
      ),
      children: const [Text('Fitur halaman ini belum tersedia.')],
    );
  }
}

enum _AddOption {
  activity(
    'Kegiatan',
    'Judul, tanggal, dan waktu.',
    Icons.event,
    NeoColors.blue,
  ),
  task(
    'Tugas',
    'Judul dan tenggat.',
    Icons.fact_check_outlined,
    NeoColors.yellow,
  ),
  routine(
    'Rutinitas',
    'Nama, jenis target, dan frekuensi.',
    Icons.repeat,
    NeoColors.coral,
  );

  const _AddOption(this.title, this.description, this.icon, this.color);

  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

class _AddOptions extends StatelessWidget {
  const _AddOptions();

  @override
  Widget build(BuildContext context) {
    return NeoBottomSheet(
      title: 'Tambah aktivitas',
      description: 'Pilih jenis yang ingin kamu tambahkan.',
      showClose: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in _AddOption.values) ...[
            NeoCard(
              dense: true,
              onTap: () => Navigator.of(context).pop(option),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: option.color,
                        borderRadius: NeoRadius.input,
                      ),
                      child: SizedBox.square(
                        dimension: NeoSize.cardIcon,
                        child: Icon(option.icon, color: NeoColors.ink),
                      ),
                    ),
                  ),
                  const SizedBox(width: NeoSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tambah ${option.title}', style: NeoType.item),
                        Text(
                          option.description,
                          style: NeoType.caption.copyWith(
                            color: NeoColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const ExcludeSemantics(child: Icon(Icons.chevron_right)),
                ],
              ),
            ),
            const SizedBox(height: NeoSpace.xs),
          ],
          const SizedBox(height: NeoSpace.md),
          NeoButton(
            label: 'Batal',
            variant: NeoButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
