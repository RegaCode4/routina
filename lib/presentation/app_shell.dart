import 'package:flutter/material.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_navigation.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/calendar_screen.dart';
import 'package:routina/presentation/planner/event_detail.dart';
import 'package:routina/presentation/planner/event_editor.dart';
import 'package:routina/presentation/planner/home_screen.dart';
import 'package:routina/presentation/planner/preview_ui.dart';
import 'package:routina/presentation/planner/setup_screens.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.repository, super.key});
  final PlannerPreviewRepository repository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  RoutinaTab _tab = RoutinaTab.home;
  bool _addOpen = false;
  DateTime? _requestedDay;
  CalendarView _requestedView = CalendarView.month;
  int _calendarSelection = 0;

  void _calendar(DateTime day, {CalendarView view = CalendarView.month}) =>
      setState(() {
        _requestedDay = day;
        _requestedView = view;
        _calendarSelection++;
        _tab = RoutinaTab.calendar;
      });

  Future<void> _open(PreviewEvent entry) async {
    if (entry.kind != PreviewKind.activity) {
      await showNeoBottomSheet<void>(
        context,
        builder: (_) => NeoBottomSheet(
          title: entry.title,
          description: eventTime(entry),
          child: Text(
            entry.kind == PreviewKind.deadline
                ? entry.options.zone
                : entry.options.category,
          ),
        ),
      );
    } else {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              EventDetail(repository: widget.repository, id: entry.id),
        ),
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _confirm(PreviewEvent entry) async {
    final result = await previewChoices(context, 'Bagaimana hasilnya?', [
      PreviewEventState.done,
      PreviewEventState.postponed,
      PreviewEventState.skipped,
    ], (value) => badgeFor(value)!.label);
    if (!mounted || result == null) return;
    setState(() => widget.repository.setEventState(entry.id, result));
    if (result != PreviewEventState.done) await _open(entry);
  }

  void _stats() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/statistik'),
      builder: (_) =>
          const PreviewPage(title: 'Statistik', body: _Unavailable()),
    ),
  );

  Future<void> _profile() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlannerProfileSetup(repository: widget.repository),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _activity([DateTime? day]) async {
    final saved = await Navigator.of(context).push<PreviewEvent>(
      MaterialPageRoute(
        builder: (_) => EventEditor(
          repository: widget.repository,
          draft: EventDraft(date: day),
        ),
      ),
    );
    if (mounted && saved != null) {
      _calendar(dateOnly(saved.start), view: CalendarView.day);
    }
  }

  Future<void> _openAdd() async {
    if (_addOpen) return;
    setState(() => _addOpen = true);
    try {
      final option = await showNeoBottomSheet<_AddOption>(
        context,
        builder: (_) => const _AddOptions(),
      );
      if (!mounted || option == null) return;
      if (option == _AddOption.activity) {
        await _activity();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Formulir ${option.title} belum tersedia.')),
        );
      }
    } finally {
      if (mounted) setState(() => _addOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.repository.profile!;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab.index,
          children: [
            PlannerHome(
              repository: widget.repository,
              onOpen: _open,
              onConfirm: _confirm,
              onCalendar: () => _calendar(widget.repository.today),
              onStats: _stats,
              onAdd: _openAdd,
            ),
            PlannerCalendar(
              repository: widget.repository,
              requestedDay: _requestedDay,
              requestedView: _requestedView,
              selection: _calendarSelection,
              onOpen: _open,
              onAdd: _activity,
            ),
            const Column(
              children: [
                AppHeader(title: 'To-Do List'),
                Expanded(child: _Unavailable()),
              ],
            ),
            const Column(
              children: [
                AppHeader(title: 'Rutinitas'),
                Expanded(child: _Unavailable()),
              ],
            ),
            Column(
              children: [
                const AppHeader(title: 'Profil'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(NeoSpace.page),
                    children: [
                      NeoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name.isEmpty
                                  ? 'Profil lokal'
                                  : profile.name,
                              style: NeoType.title,
                            ),
                            const SizedBox(height: NeoSpace.xs),
                            Text(
                              'Awal minggu · ${profile.sundayFirst ? 'Minggu' : 'Senin'}',
                            ),
                            Text(
                              'Pengingat · ${profile.notifications ? 'Aktif pada pratinjau' : 'Nonaktif'}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: NeoSpace.md),
                      NeoButton(
                        label: 'Ubah profil dan preferensi',
                        onPressed: _profile,
                      ),
                    ],
                  ),
                ),
              ],
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

class _Unavailable extends StatelessWidget {
  const _Unavailable();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(NeoSpace.page),
    children: const [Text('Fitur halaman ini belum tersedia.')],
  );
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
  Widget build(BuildContext context) => NeoBottomSheet(
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
                        style: NeoType.caption.copyWith(color: NeoColors.muted),
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
