import 'dart:async';

import 'package:flutter/material.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/domain/planner_records.dart';
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
import 'package:routina/presentation/planner/productivity_statistics.dart';
import 'package:routina/presentation/planner/preview_ui.dart';
import 'package:routina/presentation/demo/demo_session.dart';
import 'package:routina/presentation/demo/demo_widgets.dart';
import 'package:routina/presentation/demo/routines.dart';
import 'package:routina/presentation/demo/settings.dart';
import 'package:routina/presentation/demo/statistics.dart';
import 'package:routina/presentation/demo/tasks.dart';
import 'package:routina/presentation/routines/routine_editor.dart';
import 'package:routina/presentation/routines/routine_screens.dart';
import 'package:routina/presentation/tasks/task_detail.dart';
import 'package:routina/presentation/tasks/task_editor.dart';
import 'package:routina/presentation/tasks/task_list.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.repository,
    this.previewScenario = '',
    super.key,
  });
  final PlannerPreviewRepository repository;
  final String previewScenario;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  RoutinaTab _tab = RoutinaTab.home;
  bool _addOpen = false;
  DateTime? _requestedDay;
  CalendarView _requestedView = CalendarView.month;
  int _calendarSelection = 0;
  int _revision = 0;
  Timer? _ticker;
  AppLifecycleListener? _lifecycle;
  late final _demo = DemoSession(widget.repository, widget.previewScenario)
    ..addListener(_refresh);

  void _refresh() {
    if (mounted) setState(() => _revision++);
  }

  void _refreshClock() {
    final reminders = widget.repository.localReminders;
    if (reminders != null) unawaited(reminders.refresh());
    _refresh();
  }

  @override
  void initState() {
    super.initState();
    if (widget.repository.usesStoredCalendar) {
      final reminders = widget.repository.localReminders;
      if (reminders != null) unawaited(reminders.refresh());
      _ticker = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _refreshClock(),
      );
      _lifecycle = AppLifecycleListener(onResume: _refreshClock);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _lifecycle?.dispose();
    _demo.dispose();
    super.dispose();
  }

  void _calendar(DateTime day, {CalendarView view = CalendarView.month}) =>
      setState(() {
        _requestedDay = day;
        _requestedView = view;
        _calendarSelection++;
        _tab = RoutinaTab.calendar;
      });

  Future<void> _open(PreviewEvent entry) async {
    if (widget.repository.routineWorkspace case final workspace?
        when entry.kind == PreviewKind.routine) {
      try {
        final selected = await workspace.openOccurrence(entry.id);
        if (mounted && selected != null) {
          await _openRoutine(selected.routineId, selected.day);
        }
      } catch (_) {
        if (mounted) demoFeedback(context, 'Rutinitas tidak dapat dibuka.');
      }
      return;
    }
    if (widget.repository.taskWorkspace != null &&
        (entry.kind == PreviewKind.deadline ||
            entry.kind == PreviewKind.session)) {
      await _openTask(
        entry.obligationId ?? entry.id,
        sessionId: entry.kind == PreviewKind.session ? entry.id : null,
      );
      return;
    }
    final task = _demo.taskFor(entry.id);
    final routine = _demo.routines
        .where((routine) => routine.id == entry.id)
        .firstOrNull;
    if (task != null) {
      await openDemo<void>(context, DemoTaskDetail(_demo, task.id));
    } else if (routine != null) {
      await openDemo<void>(context, DemoRoutineDetail(_demo, routine.id));
    } else if (entry.kind != PreviewKind.activity) {
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
          builder: (_) => EventDetail(
            repository: widget.repository,
            id: entry.id,
            initial: widget.repository.usesStoredCalendar ? entry : null,
            categories: _demo.eventCategories,
          ),
        ),
      );
    }
    _refresh();
  }

  Future<void> _confirm(PreviewEvent entry) async {
    if (entry.kind == PreviewKind.deadline ||
        entry.kind == PreviewKind.session ||
        entry.kind == PreviewKind.routine ||
        _demo.taskFor(entry.id) != null ||
        _demo.routines.any((item) => item.id == entry.id)) {
      await _open(entry);
      return;
    }
    final result = await previewChoices(context, 'Bagaimana hasilnya?', [
      PreviewEventState.done,
      PreviewEventState.postponed,
      PreviewEventState.skipped,
    ], (value) => badgeFor(value)!.label);
    if (!mounted || result == null) return;
    try {
      final updated = await widget.repository.changeActivity(entry, result);
      if (!mounted) return;
      _refresh();
      if (result != PreviewEventState.done) await _open(updated);
    } catch (_) {
      if (mounted) {
        demoFeedback(context, 'Hasil kegiatan belum dapat disimpan.');
      }
    }
  }

  void _stats() {
    final reader = widget.repository.productivityReader;
    openDemo<void>(
      context,
      reader == null
          ? DemoStatistics(_demo)
          : ProductivityStatistics(read: reader),
      route: '/statistik',
    );
  }

  Future<void> _openTask(String id, {String? sessionId}) async {
    final workspace = widget.repository.taskWorkspace;
    if (workspace == null) return;
    await openDemo<void>(
      context,
      TaskDetail(
        repository: widget.repository,
        workspace: workspace,
        id: id,
        onChanged: _refresh,
        initialSessionId: sessionId,
      ),
    );
  }

  Future<void> _addTask() async {
    final workspace = widget.repository.taskWorkspace;
    if (workspace == null) {
      await openDemo<void>(context, DemoTaskEditor(_demo, DemoTask()));
      return;
    }
    final saved = await openDemo<Task>(
      context,
      TaskEditor(repository: widget.repository, workspace: workspace),
    );
    if (mounted && saved != null) {
      setState(() {
        _tab = RoutinaTab.tasks;
        _revision++;
      });
      demoFeedback(context, 'Tugas tersimpan.');
    }
  }

  Future<void> _openRoutine(String id, DateTime day) async {
    final workspace = widget.repository.routineWorkspace;
    if (workspace == null) return;
    await openDemo<void>(
      context,
      RoutineDetail(
        repository: widget.repository,
        workspace: workspace,
        id: id,
        day: day,
        onChanged: _refresh,
      ),
    );
  }

  Future<void> _addRoutine() async {
    final workspace = widget.repository.routineWorkspace;
    if (workspace == null) {
      await openDemo<void>(context, DemoRoutineEditor(_demo, DemoRoutine()));
      return;
    }
    final saved = await openDemo<Routine>(
      context,
      RoutineEditor(repository: widget.repository, workspace: workspace),
    );
    if (mounted && saved != null) {
      setState(() {
        _tab = RoutinaTab.routines;
        _revision++;
      });
      demoFeedback(context, 'Rutinitas tersimpan.');
    }
  }

  Future<void> _activity([DateTime? day]) async {
    final saved = await Navigator.of(context).push<PreviewEvent>(
      MaterialPageRoute(
        builder: (_) => EventEditor(
          repository: widget.repository,
          draft: EventDraft(
            date: day,
            zone: timeModeLabel(_demo.preferences.eventTimeMode),
            timeMode: _demo.preferences.eventTimeMode,
            before: _demo.buffer,
            after: _demo.buffer,
          ),
          categories: _demo.eventCategories,
        ),
      ),
    );
    if (mounted && saved != null) {
      _refresh();
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
      switch (option) {
        case _AddOption.activity:
          await _activity();
        case _AddOption.task:
          await _addTask();
        case _AddOption.routine:
          await _addRoutine();
      }
    } finally {
      if (mounted) setState(() => _addOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab.index,
          children: [
            PlannerHome(
              repository: widget.repository,
              revision: _revision,
              onOpen: _open,
              onConfirm: _confirm,
              onCalendar: () => _calendar(widget.repository.today),
              onStats: _stats,
              onOpenRoutine: _openRoutine,
              onAdd: _openAdd,
            ),
            PlannerCalendar(
              repository: widget.repository,
              revision: _revision,
              requestedDay: _requestedDay,
              requestedView: _requestedView,
              selection: _calendarSelection,
              onOpen: _open,
              onAdd: _activity,
            ),
            if (widget.repository.taskWorkspace case final workspace?)
              TaskList(
                repository: widget.repository,
                workspace: workspace,
                revision: _revision,
                onOpen: _openTask,
                onAdd: _addTask,
              )
            else
              DemoTasks(_demo),
            if (widget.repository.routineWorkspace case final workspace?)
              RoutineBoard(
                repository: widget.repository,
                workspace: workspace,
                revision: _revision,
                onOpen: _openRoutine,
                onAdd: _addRoutine,
              )
            else
              DemoRoutines(_demo),
            DemoProfile(_demo, onStatistics: _stats),
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
