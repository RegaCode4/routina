import 'dart:async';

import 'package:flutter/material.dart';
import 'package:routina/application/activity_search.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/application/routine_workspace.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/demo/demo_widgets.dart';
import 'package:routina/presentation/design_system/neo_badges.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_navigation.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/design_system/planner_cards.dart';
import 'package:routina/presentation/planner/activity_search_controls.dart';
import 'package:routina/presentation/planner/preview_ui.dart';
import 'package:routina/presentation/routines/routine_editor.dart';

typedef OpenRoutine = void Function(String id, DateTime day);

String routineClock(Duration elapsed) => [
  elapsed.inHours,
  elapsed.inMinutes.remainder(60),
  elapsed.inSeconds.remainder(60),
].map((part) => part.toString().padLeft(2, '0')).join(':');

String _target(RoutineView view) => switch (view.goal.type) {
  RoutineTargetType.duration => '${view.goal.duration?.inMinutes ?? 0} menit',
  RoutineTargetType.checklist => '${view.target} item',
  RoutineTargetType.count => '${view.target} kali',
  RoutineTargetType.frequency => '${view.target} kali per minggu',
};

String _actual(RoutineView view, DateTime now) => switch (view.goal.type) {
  RoutineTargetType.duration => routineClock(view.actualAt(now)),
  RoutineTargetType.checklist => '${view.achievedAt(now)}/${view.target} item',
  RoutineTargetType.count => '${view.achievedAt(now)} kali',
  RoutineTargetType.frequency => '${view.weeklyCount} kali minggu ini',
};

NeoStatus? _badge(RoutineView view, DateTime now, {TimerClockSample? clock}) =>
    switch (view.statusAt(now, clock: clock)) {
      RoutineStatus.notStarted => null,
      RoutineStatus.active => NeoStatus.active,
      RoutineStatus.pending => NeoStatus.pending,
      RoutineStatus.completed => NeoStatus.completed,
      RoutineStatus.skipped => NeoStatus.skipped,
      RoutineStatus.missed => NeoStatus.missed,
    };

class RoutineBoard extends StatefulWidget {
  const RoutineBoard({
    required this.repository,
    required this.workspace,
    required this.revision,
    required this.onAdd,
    required this.onOpen,
    super.key,
  });

  final PlannerPreviewRepository repository;
  final RoutineWorkspace workspace;
  final int revision;
  final VoidCallback onAdd;
  final OpenRoutine onOpen;

  @override
  State<RoutineBoard> createState() => _RoutineBoardState();
}

class _RoutineBoardState extends State<RoutineBoard> {
  final _query = TextEditingController();
  bool _searching = false;
  bool _dateFiltered = false;
  String? _categoryId;
  RoutineStatus? _status;
  AgendaOrder? _order;
  DateTime? _selected;
  late Future<List<RoutineView>> _read = _load();
  DateTime get _day => _selected ?? widget.workspace.today;

  Future<List<RoutineView>> _load() async {
    await widget.workspace.reconcileGoals();
    return widget.workspace.list(_day, onDateOnly: _dateFiltered);
  }

  @override
  void didUpdateWidget(covariant RoutineBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != oldWidget.revision) _read = _load();
    if (_categoryId?.isNotEmpty == true &&
        !widget.repository.categories.any((row) => row.id == _categoryId)) {
      _categoryId = null;
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _query.clear();
    _categoryId = null;
    _status = null;
    _order = null;
    if (_dateFiltered) {
      _dateFiltered = false;
      _read = _load();
    }
  }

  void _toggleSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = !_searching;
      if (!_searching) _clearSearch();
    });
  }

  Future<void> _date({bool filter = false}) async {
    final date = await pickPreviewDate(
      context,
      widget.workspace.today,
      selected: _day,
    );
    if (mounted && date != null) {
      setState(() {
        _selected = civilDate(date);
        if (filter) _dateFiltered = true;
        _read = _load();
      });
    }
  }

  Future<void> _pickDateFilter() async {
    FocusScope.of(context).unfocus();
    final filter = await previewChoices(
      context,
      'Tanggal rutinitas',
      [true, false],
      (filter) => filter ? 'Pilih tanggal' : 'Semua rutinitas',
    );
    if (!mounted || filter == null) return;
    if (filter) {
      await _date(filter: true);
    } else if (_dateFiltered) {
      setState(() {
        _dateFiltered = false;
        _read = _load();
      });
    }
  }

  Widget _searchControls() => ActivitySearchControls(
    label: 'Cari rutinitas',
    controller: _query,
    onChanged: (_) => setState(() {}),
    chips: [
      CategoryChip(
        label: _dateFiltered ? dateLabel(_day) : 'Tanggal',
        selected: _dateFiltered,
        onSelected: (_) => _pickDateFilter(),
      ),
      SearchCategoryChip(
        categories: widget.repository.categories,
        selectedId: _categoryId,
        onSelected: (value) => setState(() => _categoryId = value),
      ),
      CategoryChip(
        label: _status?.label ?? 'Status',
        selected: _status != null,
        onSelected: (_) async {
          FocusScope.of(context).unfocus();
          final choices = [
            'Semua status',
            ...RoutineStatus.values.map((s) => s.label),
          ];
          final pick = await previewChoices(
            context,
            'Status rutinitas',
            choices,
            (label) => label,
          );
          if (mounted && pick != null) {
            setState(
              () => _status = RoutineStatus.values
                  .where((s) => s.label == pick)
                  .firstOrNull,
            );
          }
        },
      ),
      CategoryChip(
        label: _order?.label ?? 'Urutkan',
        selected: _order != null,
        onSelected: (_) async {
          FocusScope.of(context).unfocus();
          final values = [
            'Urutan bawaan',
            ...AgendaOrder.values.map((order) => order.label),
          ];
          final pick = await previewChoices(
            context,
            'Urutkan jadwal rutinitas',
            values,
            (label) => label,
          );
          if (mounted && pick != null) {
            setState(
              () => _order = AgendaOrder.values
                  .where((order) => order.label == pick)
                  .firstOrNull,
            );
          }
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppHeader(
        title: 'Rutinitas',
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeoIconButton(
              label: _searching
                  ? 'Tutup pencarian rutinitas'
                  : 'Cari dan filter rutinitas',
              icon: _searching ? Icons.close : Icons.search,
              onPressed: _toggleSearch,
            ),
            const SizedBox(width: NeoSpace.xxs),
            NeoIconButton(
              label: 'Pilih tanggal rutinitas',
              icon: Icons.calendar_today_outlined,
              onPressed: _date,
            ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<List<RoutineView>>(
          future: _read,
          builder: (context, snapshot) {
            final all = snapshot.data ?? const <RoutineView>[];
            final week = widget.workspace.weekStart(_day);
            final finish = week.add(const Duration(days: 6));
            final now = widget.workspace.now();
            final rows = _searching
                ? searchRoutines(
                    all,
                    title: _query.text,
                    zones: widget.workspace.zones,
                    now: now,
                    categoryId: _categoryId,
                    status: _status,
                    order: _order,
                  )
                : all;
            final weekly = all
                .where((view) => view.goal.type == RoutineTargetType.frequency)
                .toList();
            final reached = weekly
                .where((view) => view.goalReachedAt(now))
                .length;
            return DemoList(key: ValueKey(_searching), tab: true, [
              DemoHeading(
                'Jaga ritmemu',
                subtitle:
                    'Minggu ini · ${dateLabel(week)} – ${dateLabel(finish, year: true)}',
              ),
              if (_searching) _searchControls(),
              if (!_searching && weekly.isNotEmpty)
                NeoCard(
                  tone: NeoCardTone.yellow,
                  emphasis: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Target mingguan tercapai',
                        style: NeoType.item,
                      ),
                      Text(
                        '$reached / ${weekly.length}',
                        style: NeoType.display,
                      ),
                      NeoProgressBar(
                        value: reached / weekly.length,
                        label: 'Target mingguan tercapai',
                        onAccent: true,
                      ),
                    ],
                  ),
                ),
              if (snapshot.hasError)
                PreviewNotice(
                  title: 'Rutinitas gagal dimuat',
                  message: 'Coba baca lagi data lokal.',
                  button: NeoButton(
                    label: 'Coba lagi',
                    onPressed: () => setState(() {
                      _read = _load();
                    }),
                  ),
                )
              else if (snapshot.connectionState == ConnectionState.waiting &&
                  (_searching || !snapshot.hasData))
                const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Memuat rutinitas',
                  ),
                )
              else if (rows.isEmpty && _searching)
                ActivitySearchEmpty(
                  title: 'Rutinitas tidak ditemukan',
                  onClear: () => setState(_clearSearch),
                )
              else if (rows.isEmpty)
                PreviewNotice(
                  title: 'Belum ada rutinitas',
                  message: 'Tambahkan rutinitas untuk mencatat progres aktual.',
                  icon: Icons.repeat,
                  button: NeoButton(
                    label: 'Tambah rutinitas',
                    onPressed: widget.onAdd,
                  ),
                )
              else ...[
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _day == widget.workspace.today
                          ? (_searching
                                ? 'Hasil · Hari ini'
                                : 'Rutinitas hari ini')
                          : (_searching
                                ? 'Hasil · ${dateLabel(_day)}'
                                : dateLabel(_day)),
                      style: NeoType.section,
                    ),
                    TextButton(
                      onPressed: () => openDemo<void>(
                        context,
                        RoutineHistory(
                          workspace: widget.workspace,
                          onOpen: widget.onOpen,
                        ),
                      ),
                      child: const Text('Riwayat'),
                    ),
                  ],
                ),
                for (final view in rows) ...[
                  RoutineCard(
                    title: view.routine.title,
                    target: [
                      _target(view),
                      routineCadenceLabel(view.routine.frequencyRule),
                      ...widget.repository.categories
                          .where((row) => row.id == view.routine.categoryId)
                          .map((row) => row.name),
                    ].join(' · '),
                    actual: _actual(view, now),
                    progress: view.target > 0 ? view.progressAt(now) : null,
                    timer: view.timer == null
                        ? null
                        : view.timer!.runningSince == null
                        ? 'Timer dijeda'
                        : 'Timer berjalan',
                    status: _badge(view, now),
                    onTap: () => widget.onOpen(view.routine.id, _day),
                  ),
                  if (view.activeDay case final active?
                      when active.value != civilKey(_day))
                    TextButton(
                      onPressed: () => widget.onOpen(
                        view.routine.id,
                        DateTime.parse(active.value),
                      ),
                      child: Text(
                        'Buka timer · ${dateLabel(DateTime.parse(active.value))}',
                      ),
                    ),
                ],
              ],
            ]);
          },
        ),
      ),
    ],
  );
}

class RoutineDetail extends StatefulWidget {
  const RoutineDetail({
    required this.repository,
    required this.workspace,
    required this.id,
    required this.day,
    required this.onChanged,
    super.key,
  });

  final PlannerPreviewRepository repository;
  final RoutineWorkspace workspace;
  final String id;
  final DateTime day;
  final VoidCallback onChanged;

  @override
  State<RoutineDetail> createState() => _RoutineDetailState();
}

class _RoutineDetailState extends State<RoutineDetail> {
  RoutineWorkspace get _workspace => widget.workspace;
  late DateTime _day = civilDate(widget.day);
  late Future<RoutineView?> _read = _workspace.read(widget.id, _day);
  Timer? _ticker;
  TimerClockSample? _clock;
  bool _samplingClock = false;
  AppLifecycleListener? _lifecycle;
  bool _foreground = true;
  bool _recovering = true;
  bool _busy = false;
  String? _reportedTimer;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _foreground = true;
        _recovering = true;
        _reload(reconcile: true);
      },
      onPause: () {
        _foreground = false;
        _ticker?.cancel();
        _ticker = null;
      },
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  void _reload({bool reconcile = false}) {
    final date = _day;
    Future<RoutineView?> load() async {
      if (reconcile) await _workspace.reconcileGoals();
      return _workspace.read(widget.id, date);
    }

    setState(() {
      _clock = null;
      _read = load();
    });
  }

  void _watch(RoutineView? view) {
    if (!_foreground || view?.timer?.runningSince == null) {
      _ticker?.cancel();
      _ticker = null;
    } else {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) async {
        if (_samplingClock) return;
        _samplingClock = true;
        final visibleRead = _read;
        try {
          final clock = await _workspace.sampleTimerClock();
          if (mounted && _foreground && identical(visibleRead, _read)) {
            setState(() => _clock = clock);
          }
        } finally {
          _samplingClock = false;
        }
      });
    }
  }

  Future<void> _emitGoalOnce(String id) async {
    try {
      await _workspace.reconcileGoals();
    } catch (_) {
      if (_reportedTimer == id) _reportedTimer = null;
    }
  }

  Future<void> _change(
    Future<void> Function() action, {
    bool closing = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      _recovering = false;
      widget.onChanged();
      if (closing && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      } else {
        _reload();
      }
    } on RoutineIssue catch (issue) {
      if (mounted) demoFeedback(context, issue.message);
    } catch (_) {
      if (mounted) {
        demoFeedback(context, 'Perubahan belum dapat disimpan. Coba lagi.');
        _reload();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _select(DateTime date) {
    _day = civilDate(date);
    _recovering = true;
    _reload();
  }

  Future<void> _date() async {
    final date = await pickPreviewDate(
      context,
      _workspace.today,
      selected: _day,
    );
    if (mounted && date != null) _select(date);
  }

  Future<void> _history() async {
    final date = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(
        builder: (_) => RoutineHistory(
          workspace: _workspace,
          id: widget.id,
          onOpen: (_, day) => Navigator.of(context).pop(day),
        ),
      ),
    );
    if (mounted && date != null) _select(date);
  }

  Future<void> _stop(RoutineTimer timer) async {
    final yes = await showNeoDialog(
      context,
      title: 'Hentikan timer?',
      message: 'Durasi sesi disimpan sebagai catatan aktual.',
      confirmLabel: 'Simpan durasi',
    );
    if (mounted && yes == true) await _change(() => _workspace.stop(timer));
  }

  Future<void> _manual(RoutineView view) async {
    final duration = view.goal.type == RoutineTargetType.duration;
    final value = await demoNumber(
      context,
      duration ? 'Durasi aktual (menit)' : 'Jumlah aktual pada tanggal ini',
      min: duration ? 1 : 0,
      max: duration
          ? const Duration(microseconds: 0x7FFFFFFFFFFFFFFF).inMinutes
          : 0x7FFFFFFFFFFFFFFF,
      value: duration ? null : view.occurrence?.recordedCount,
    );
    if (!mounted || value == null) return;
    await _change(
      () => duration
          ? _workspace.recordDuration(
              widget.id,
              view.day,
              Duration(minutes: value),
            )
          : _workspace.setCount(widget.id, view.day, value),
    );
  }

  Future<void> _confirm(RoutineView view, ActivityStatus result) async {
    final done = result == ActivityStatus.completed;
    final yes = await showNeoDialog(
      context,
      title: done
          ? 'Tandai rutinitas selesai?'
          : 'Tandai rutinitas dilewatkan?',
      message: 'Status untuk ${dateLabel(view.day)} akan dicatat.',
      confirmLabel: done ? 'Tandai selesai' : 'Tandai dilewatkan',
    );
    if (mounted && yes == true) {
      await _change(() => _workspace.confirm(widget.id, view.day, result));
    }
  }

  Future<void> _manage(RoutineView view) async {
    final actions = [
      'Edit rutinitas',
      'Jadwalkan tanggal ini',
      if (!view.day.isAfter(_workspace.today) &&
          (view.occurrence?.status ?? ActivityStatus.planned) ==
              ActivityStatus.planned)
        'Tandai dilewatkan',
      'Pindah ke Tempat Sampah',
    ];
    final action = await previewChoices(
      context,
      'Tindakan rutinitas',
      actions,
      (value) => value,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'Edit rutinitas':
        try {
          final reminders = await _workspace.reminders(widget.id);
          if (!mounted) return;
          final saved = await openDemo<Routine>(
            context,
            RoutineEditor(
              repository: widget.repository,
              workspace: _workspace,
              initial: view.routine,
              reminders: reminders,
            ),
          );
          if (mounted && saved != null) {
            widget.onChanged();
            _reload();
          }
        } catch (_) {
          if (mounted) {
            demoFeedback(context, 'Pengaturan rutinitas belum dapat dimuat.');
          }
        }
      case 'Jadwalkan tanggal ini':
        await _plan(view);
      case 'Tandai dilewatkan':
        await _confirm(view, ActivityStatus.skipped);
      case 'Pindah ke Tempat Sampah':
        final yes = await showNeoDialog(
          context,
          title: 'Pindahkan rutinitas?',
          message:
              'Aktivitas di kalender disembunyikan. Durasi timer dan riwayat tetap tersimpan.',
          confirmLabel: 'Pindahkan',
          danger: true,
        );
        if (mounted && yes == true) {
          await _change(() => _workspace.delete(view.routine), closing: true);
        }
    }
  }

  Future<void> _plan(RoutineView view) async {
    final mode =
        view.routine.timeMode ??
        widget.repository.profile?.preferences.routineTimeMode ??
        TimeMode.localWallTime;
    final timeZone = mode == TimeMode.localWallTime
        ? _workspace.zones.deviceId
        : _workspace.zones.displayId;
    final schedule = view.occurrence?.schedule;
    int? existing(ZonedTime? time) => time == null
        ? null
        : minutesAt(
            _workspace.zones.wall(
              _workspace.zones.effectiveTime(time),
              timeZone,
            ),
          );
    final start = await pickPreviewTime(
      context,
      initial: existing(schedule?.start),
    );
    if (!mounted || start == null) return;
    final end = await pickPreviewTime(
      context,
      initial: existing(schedule?.end),
    );
    if (!mounted || end == null) return;
    if (end <= start) {
      demoFeedback(
        context,
        'Jam selesai harus setelah jam mulai pada tanggal ini.',
      );
      return;
    }
    final yes = await showNeoDialog(
      context,
      title: 'Simpan jadwal rutinitas?',
      message:
          '${dateLabel(view.day)} · ${clockLabel(start)}–${clockLabel(end)} · $timeZone',
      confirmLabel: 'Simpan jadwal',
    );
    if (!mounted || yes != true) return;
    await _change(() async {
      var approved = <ScheduleWarning>{};
      while (mounted) {
        try {
          final day = civilDate(view.day);
          await _workspace.schedule(
            widget.id,
            day,
            day.add(Duration(minutes: start)),
            day.add(Duration(minutes: end)),
            mode: mode,
            approved: approved,
          );
          return;
        } on ActivityWarnings catch (warnings) {
          if (!mounted) return;
          final answer = await showNeoDialog(
            context,
            title: 'Simpan jadwal dengan peringatan?',
            message: warnings.warnings.map(warningBody).join('\n'),
            confirmLabel: 'Simpan dengan peringatan',
          );
          if (!mounted || answer != true) return;
          approved = warnings.warnings.toSet();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<RoutineView?>(
    future: _read,
    builder: (context, snapshot) {
      final view = snapshot.data;
      _watch(view);
      if (view == null || snapshot.hasError) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        return PreviewPage(
          title: 'Detail rutinitas',
          body: loading
              ? const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Memuat detail rutinitas',
                  ),
                )
              : DemoList([
                  PreviewNotice(
                    title: snapshot.hasError
                        ? 'Rutinitas gagal dimuat'
                        : 'Rutinitas tidak tersedia',
                    message: snapshot.hasError
                        ? 'Coba baca kembali data lokal.'
                        : 'Kembali ke daftar rutinitas.',
                    button: snapshot.hasError
                        ? NeoButton(label: 'Coba lagi', onPressed: _reload)
                        : null,
                  ),
                ]),
        );
      }
      final now = _workspace.now();
      final reached = view.goalReachedAt(now, clock: _clock);
      final timer = view.timer;
      final elapsed = view.timerElapsedAt(now, clock: _clock);
      if (_foreground &&
          timer?.runningSince != null &&
          reached &&
          _reportedTimer != timer!.id) {
        _reportedTimer = timer.id;
        unawaited(_emitGoalOnce(timer.id));
      }
      final duration = view.goal.type == RoutineTargetType.duration;
      final count =
          view.goal.type == RoutineTargetType.count ||
          view.goal.type == RoutineTargetType.frequency;
      final actualDay = !view.day.isAfter(_workspace.today);
      final planned =
          (view.occurrence?.status ?? ActivityStatus.planned) ==
          ActivityStatus.planned;
      final schedule = view.occurrence?.schedule;
      final badge = _badge(view, now, clock: _clock);
      final zones = _workspace.zones;
      final category = widget.repository.categories
          .where((row) => row.id == view.routine.categoryId)
          .firstOrNull;
      return PreviewPage(
        title: 'Detail rutinitas',
        action: NeoIconButton(
          label: 'Pilih tanggal rutinitas',
          icon: Icons.calendar_today_outlined,
          onPressed: _date,
        ),
        body: DemoList([
          DemoHeading(
            view.routine.title,
            subtitle:
                '${dateLabel(view.day, year: true)} · Target ${_target(view)}',
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: NeoSpace.sm,
            children: [
              Text(
                category?.name ??
                    routineCadenceLabel(view.routine.frequencyRule),
              ),
              TextButton(
                onPressed: _busy ? null : () => _manage(view),
                child: const Text('Tindakan rutinitas'),
              ),
            ],
          ),
          if (duration)
            NeoCard(
              tone: timer?.runningSince == null
                  ? NeoCardTone.yellow
                  : NeoCardTone.accent,
              emphasis: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      timer == null
                          ? 'Timer siap'
                          : timer.runningSince == null
                          ? 'Timer dijeda'
                          : 'Sedang berlangsung',
                      style: NeoType.item,
                    ),
                  ),
                  const SizedBox(height: NeoSpace.sm),
                  Semantics(
                    label: 'Durasi aktual sesi',
                    value:
                        '${elapsed.inHours} jam '
                        '${elapsed.inMinutes.remainder(60)} menit '
                        '${elapsed.inSeconds.remainder(60)} detik',
                    excludeSemantics: true,
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            routineClock(elapsed),
                            style: NeoType.metric,
                            key: const ValueKey('routine-timer-clock'),
                          ),
                        ),
                        const Text(
                          'Durasi aktual sesi',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: NeoSpace.md),
                  NeoProgressBar(
                    value: view.progressAt(now, clock: _clock),
                    label: 'Progres durasi rutinitas',
                    onAccent: true,
                  ),
                  Text('Target · ${_target(view)}'),
                ],
              ),
            )
          else
            NeoCard(
              tone: NeoCardTone.highlighted,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_actual(view, now), style: NeoType.item),
                  const SizedBox(height: NeoSpace.xs),
                  NeoProgressBar(
                    value: view.progressAt(now),
                    label: 'Progres rutinitas',
                  ),
                ],
              ),
            ),
          if (timer != null && _recovering)
            const PreviewNotice(
              title: 'Timer dipulihkan',
              message: 'Durasi sesi dilanjutkan dari data tersimpan.',
            ),
          if (reached && planned)
            const PreviewNotice(
              title: 'Target tercapai',
              message: 'Konfirmasi hasil rutinitas saat siap.',
            ),
          if (badge != null &&
              !(reached && planned) &&
              !(duration && badge == NeoStatus.active))
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusBadge(status: badge),
            ),
          DemoRow('Riwayat aktivitas', icon: Icons.history, onTap: _history),
          if (duration && (timer != null || view.day == _workspace.today))
            if (timer == null)
              NeoButton(
                label: 'Mulai',
                icon: Icons.play_arrow,
                onPressed: _busy
                    ? null
                    : () =>
                          _change(() => _workspace.start(widget.id, view.day)),
              )
            else
              DemoPair(
                NeoButton(
                  label: timer.runningSince == null ? 'Lanjutkan' : 'Jeda',
                  onPressed: _busy
                      ? null
                      : () => _change(
                          () => timer.runningSince == null
                              ? _workspace.start(
                                  widget.id,
                                  view.day,
                                  resumeId: timer.id,
                                )
                              : _workspace.pause(timer),
                        ),
                ),
                NeoButton(
                  label: 'Hentikan',
                  variant: NeoButtonVariant.secondary,
                  onPressed: _busy ? null : () => _stop(timer),
                ),
              ),
          if (actualDay && (duration || count))
            NeoButton(
              label: 'Masukkan progres manual',
              variant: NeoButtonVariant.secondary,
              onPressed: _busy ? null : () => _manual(view),
            ),
          if (view.goal.type == RoutineTargetType.checklist)
            for (final item in view.goal.checklist)
              NeoCard(
                dense: true,
                child: CheckboxListTile(
                  title: Text(item),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: view.occurrence?.checkedItems.contains(item) ?? false,
                  onChanged: !actualDay || _busy
                      ? null
                      : (value) => _change(
                          () => _workspace.check(
                            widget.id,
                            view.day,
                            item,
                            value!,
                          ),
                        ),
                ),
              ),
          DemoFacts([
            (
              'Durasi terjadwal',
              schedule == null
                  ? 'Belum dijadwalkan'
                  : '${schedule.duration.inMinutes} menit',
            ),
            if (schedule != null)
              (
                'Jadwal kalender',
                '${clockLabel(minutesAt(zones.wall(zones.effectiveTime(schedule.start), zones.displayId)))}–${clockLabel(minutesAt(zones.wall(zones.effectiveTime(schedule.end), zones.displayId)))}',
              ),
            if (duration)
              ('Durasi aktual tercatat', routineClock(view.recorded)),
          ]),
          if (duration &&
              reached &&
              widget.repository.profile?.notifications != true)
            const Text(
              'Notifikasi nonaktif. Pencapaian tersedia di halaman ini.',
            ),
          if (actualDay && planned)
            NeoButton(
              label: 'Tandai Rutinitas Selesai',
              variant: NeoButtonVariant.secondary,
              onPressed: _busy
                  ? null
                  : () => _confirm(view, ActivityStatus.completed),
            ),
        ]),
      );
    },
  );
}

class RoutineHistory extends StatefulWidget {
  const RoutineHistory({
    required this.workspace,
    required this.onOpen,
    this.id,
    super.key,
  });
  final RoutineWorkspace workspace;
  final OpenRoutine onOpen;
  final String? id;

  @override
  State<RoutineHistory> createState() => _RoutineHistoryState();
}

class _RoutineHistoryState extends State<RoutineHistory> {
  late Future<List<RoutineView>> _read = widget.workspace.history(widget.id);

  @override
  Widget build(BuildContext context) => PreviewPage(
    title: 'Riwayat rutinitas',
    body: FutureBuilder<List<RoutineView>>(
      future: _read,
      builder: (context, snapshot) {
        final now = widget.workspace.now();
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Memuat riwayat rutinitas',
            ),
          );
        }
        final views = snapshot.data ?? const <RoutineView>[];
        return DemoList([
          if (snapshot.hasError)
            PreviewNotice(
              title: 'Riwayat belum dapat dimuat',
              message: 'Coba baca lagi data lokal.',
              button: NeoButton(
                label: 'Coba lagi',
                onPressed: () => setState(() {
                  _read = widget.workspace.history(widget.id);
                }),
              ),
            )
          else if (views.isEmpty)
            const PreviewNotice(
              title: 'Riwayat masih kosong',
              message:
                  'Progres dan status rutinitas akan muncul sesuai tanggal pencatatan.',
            )
          else
            for (final view in views)
              RoutineCard(
                title:
                    '${dateLabel(view.day, year: true)} · ${view.routine.title}',
                target: _target(view),
                actual: [
                  _actual(view, now),
                  ...view.logs
                      .map(
                        (log) => log.source == TimeLogSource.timer
                            ? 'Timer'
                            : 'Manual',
                      )
                      .toSet(),
                ].join(' · '),
                progress: view.progressAt(now),
                status: _badge(view, now),
                onTap: () => widget.onOpen(view.routine.id, view.day),
              ),
        ]);
      },
    ),
  );
}
