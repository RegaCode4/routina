import 'dart:async';

import 'package:flutter/material.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/application/task_workspace.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/demo/demo_widgets.dart';
import 'package:routina/presentation/design_system/neo_badges.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/preview_ui.dart';
import 'package:routina/presentation/tasks/session_editor.dart';
import 'package:routina/presentation/tasks/task_editor.dart';

class TaskDetail extends StatefulWidget {
  const TaskDetail({
    required this.repository,
    required this.workspace,
    required this.id,
    required this.onChanged,
    this.initialSessionId,
    super.key,
  });

  final PlannerPreviewRepository repository;
  final TaskWorkspace workspace;
  final String id;
  final VoidCallback onChanged;
  final String? initialSessionId;

  @override
  State<TaskDetail> createState() => _TaskDetailState();
}

class _TaskDetailState extends State<TaskDetail> {
  TaskWorkspace get _workspace => widget.workspace;
  late Future<TaskView?> _read = _workspace.read(widget.id);
  bool _busy = false;
  Timer? _clock;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => _reload());
    _lifecycle = AppLifecycleListener(onResume: _reload);
  }

  @override
  void dispose() {
    _clock?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  void _reload() {
    final pending = _workspace.read(widget.id);
    setState(() {
      _read = pending;
    });
  }

  Future<void> _change(
    Future<void> Function() action, {
    bool close = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      widget.onChanged();
      if (close) {
        Navigator.pop(context);
      } else {
        _reload();
      }
    } on TaskIssue catch (issue) {
      if (mounted) {
        demoFeedback(context, issue.message);
        _reload();
      }
    } catch (_) {
      if (mounted) {
        demoFeedback(
          context,
          'Perubahan belum dapat disimpan. Muat ulang dan coba lagi.',
        );
        _reload();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDone(TaskView view) async {
    final future = view.upcoming;
    final decision = await demoSheet<bool>(
      context,
      'Tandai tugas selesai?',
      (sheet) => [
        NeoButton(
          label: future.isEmpty
              ? 'Tandai selesai'
              : 'Selesai, pertahankan sesi',
          onPressed: () => Navigator.pop(sheet, false),
        ),
        if (future.isNotEmpty)
          NeoButton(
            label: 'Selesai, batalkan sesi mendatang',
            variant: NeoButtonVariant.danger,
            onPressed: () => Navigator.pop(sheet, true),
          ),
        NeoButton(
          label: 'Batal',
          variant: NeoButtonVariant.secondary,
          onPressed: () => Navigator.pop(sheet),
        ),
      ],
      description: future.isEmpty
          ? 'Status tugas akan disimpan sebagai Selesai.'
          : '${future.length} sesi mendatang dapat dipertahankan atau dibatalkan.',
    );
    if (!mounted || decision == null) return;
    await _change(
      () => _workspace.complete(
        view.task,
        reviewedFutureIds: future.map((row) => row.id).toSet(),
        cancelFuture: decision,
      ),
    );
  }

  Future<void> _more(TaskView view) async {
    final action = await previewChoices(context, 'Tindakan tugas', [
      'Edit tugas',
      'Ubah tenggat',
      'Pindah ke Tempat Sampah',
    ], (value) => value);
    if (!mounted || action == null) return;
    if (action != 'Pindah ke Tempat Sampah') {
      await _edit(view, deadlineOnly: action == 'Ubah tenggat');
      return;
    }
    final confirm = await showNeoDialog(
      context,
      title: 'Pindahkan tugas?',
      message:
          'Tugas, subtugas, dan sesi terkait disembunyikan dari daftar aktif dan kalender.',
      confirmLabel: 'Pindahkan',
      danger: true,
    );
    if (mounted && confirm == true) {
      await _change(() => _workspace.delete(view.task), close: true);
    }
  }

  Future<void> _edit(TaskView view, {bool deadlineOnly = false}) async {
    final saved = await openDemo<Task>(
      context,
      TaskEditor(
        repository: widget.repository,
        workspace: _workspace,
        initial: view,
        deadlineOnly: deadlineOnly,
      ),
    );
    if (mounted && saved != null) {
      widget.onChanged();
      _reload();
    }
  }

  Future<void> _session(
    TaskView view, {
    WorkSession? existing,
    WorkSlot? proposal,
  }) async {
    final saved = await openDemo<WorkSession>(
      context,
      SessionEditor(
        workspace: _workspace,
        task: view,
        previous: existing,
        proposal: proposal,
      ),
    );
    if (mounted && saved != null) {
      widget.onChanged();
      _reload();
    }
  }

  Future<void> _findSlot(TaskView view) async {
    final estimate =
        view.task.confirmedRemainingEstimate ?? view.task.initialEstimate;
    final minutes = await demoNumber(
      context,
      'Durasi sesi (menit)',
      value:
          estimate == null ||
              estimate.inMinutes < 1 ||
              estimate.inMinutes > 1440
          ? null
          : estimate.inMinutes,
    );
    if (!mounted || minutes == null) return;
    setState(() => _busy = true);
    WorkSlot? proposal;
    try {
      proposal = await _workspace.suggest(
        view.task,
        Duration(minutes: minutes),
      );
    } catch (_) {
      if (mounted) {
        demoFeedback(context, 'Slot belum dapat diperiksa. Coba lagi.');
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (proposal == null) {
      await showNeoDialog(
        context,
        title: 'Slot belum ditemukan',
        message:
            'Tidak ada slot yang sesuai sebelum tenggat dalam tujuh hari ke depan.',
        confirmLabel: 'Tutup',
      );
      return;
    }
    await _session(view, proposal: proposal);
  }

  Future<void> _sessionMenu(TaskView view, WorkSession row) async {
    final movable = _workspace.canMove(row, view.logs);
    final held =
        row.status == ActivityStatus.planned &&
        !_workspace.effectiveSession(row).end.instant.isAfter(_workspace.now());
    if (!movable && !held) return;
    final action = await previewChoices(context, 'Tindakan sesi', [
      if (movable) ...['Pindah sesi', 'Batalkan sesi'],
      if (held) 'Tandai sesi terlaksana',
    ], (value) => value);
    if (!mounted || action == null) return;
    if (action == 'Pindah sesi') {
      await _session(view, existing: row);
      return;
    }
    final cancel = action == 'Batalkan sesi';
    final approved = await showNeoDialog(
      context,
      title: cancel ? 'Batalkan sesi?' : 'Catat sesi terlaksana?',
      message: cancel
          ? 'Sesi dibatalkan dan riwayatnya tetap tersimpan.'
          : 'Status sesi akan dicatat. Durasi aktual tetap mengikuti TimeLog.',
      confirmLabel: cancel ? 'Batalkan sesi' : 'Tandai terlaksana',
      danger: cancel,
    );
    if (!mounted || approved != true) return;
    await _change(
      () => cancel
          ? _workspace.cancelSession(row)
          : _workspace.markSessionHeld(row),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TaskView?>(
    future: _read,
    builder: (context, snapshot) {
      final view = snapshot.data;
      if (view == null || snapshot.hasError) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        return PreviewPage(
          title: 'Detail tugas',
          body: loading
              ? const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Memuat tugas',
                  ),
                )
              : DemoList([
                  PreviewNotice(
                    title: snapshot.hasError
                        ? 'Tugas gagal dimuat'
                        : 'Tugas tidak tersedia',
                    message: snapshot.hasError
                        ? 'Coba baca lagi data lokal.'
                        : 'Kembali ke daftar tugas.',
                    button: snapshot.hasError
                        ? NeoButton(label: 'Coba lagi', onPressed: _reload)
                        : null,
                  ),
                ]),
        );
      }
      final task = view.task;
      final category = widget.repository.categories
          .where((row) => row.id == task.categoryId)
          .firstOrNull;
      return PreviewPage(
        title: 'Detail tugas',
        action: NeoIconButton(
          icon: Icons.more_horiz,
          label: 'Tindakan tugas',
          onPressed: _busy ? null : () => _more(view),
        ),
        footer: view.completed
            ? null
            : DemoActions([
                NeoButton(
                  label: 'Cari slot',
                  onPressed: _busy || view.deadline == null
                      ? null
                      : () => _findSlot(view),
                ),
                NeoButton(
                  label: 'Tandai Tugas Selesai',
                  variant: NeoButtonVariant.secondary,
                  onPressed: _busy ? null : () => _confirmDone(view),
                ),
              ]),
        body: DemoList([
          Wrap(
            spacing: NeoSpace.xs,
            runSpacing: NeoSpace.xxs,
            children: [
              if (view.completed || view.overdue)
                StatusBadge(
                  status: view.completed
                      ? NeoStatus.completed
                      : NeoStatus.overdue,
                )
              else
                const CategoryChip(label: 'Belum selesai', selected: true),
              if (category != null) CategoryChip(label: category.name),
              if (task.priority case final priority?)
                CategoryChip(label: 'Prioritas $priority'),
            ],
          ),
          DemoHeading(
            task.title,
            subtitle: task.description?.isNotEmpty == true
                ? task.description
                : null,
          ),
          NeoCard(
            tone: NeoCardTone.highlighted,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tenggat tugas', style: NeoType.item),
                const SizedBox(height: NeoSpace.xxs),
                Text(
                  view.displayDeadline == null
                      ? 'Belum ditentukan'
                      : '${taskTime(view.displayDeadline!)} · ${_workspace.zones.displayId}',
                  style: NeoType.body,
                ),
                if (task.deadline case final deadline?)
                  Text(
                    deadline.mode == TimeMode.originalZone
                        ? 'Zona asal · ${deadline.zoneId}'
                        : 'Mengikuti jam lokal',
                    style: NeoType.caption,
                  ),
                if (!view.completed)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _edit(view, deadlineOnly: true),
                    child: const Text('Ubah tenggat'),
                  ),
              ],
            ),
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Checklist', style: NeoType.section),
              TextButton(
                onPressed: _busy ? null : () => _edit(view),
                child: const Text('Edit checklist'),
              ),
            ],
          ),
          if (view.progress case final progress?) ...[
            NeoProgressBar(value: progress, label: 'Progres subtugas'),
            Text(
              '${view.checked}/${view.subtasks.length} subtugas · ${(progress * 100).round()}%',
            ),
            for (final subtask in view.subtasks)
              NeoCard(
                dense: true,
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: subtask.checked,
                  title: Text(subtask.title),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: _busy || view.completed
                      ? null
                      : (value) =>
                            _change(() => _workspace.toggle(subtask, value!)),
                ),
              ),
          ] else
            const Text('Belum ada subtugas.'),
          if (view.progress == 1 && !view.completed)
            const PreviewNotice(
              title: 'Checklist 100%',
              message: 'Konfirmasi tugas selesai setelah pekerjaan beres.',
            ),
          const Text('Sesi pengerjaan', style: NeoType.section),
          DemoFacts([
            ('Sesi mendatang', '${view.upcoming.length}'),
            ('Durasi terjadwal', _minutes(view.planned)),
            ('Durasi aktual', _minutes(view.actual, empty: 'Belum tercatat')),
            (
              'Estimasi pekerjaan',
              _minutes(task.initialEstimate, empty: 'Belum diisi'),
            ),
            (
              'Estimasi sisa disetujui',
              _minutes(task.confirmedRemainingEstimate),
            ),
          ]),
          if (view.sessions.isEmpty) const Text('Belum ada sesi pengerjaan.'),
          if (view.sessions.any((row) => row.id == widget.initialSessionId))
            _sessionCard(
              view,
              view.sessions.firstWhere(
                (row) => row.id == widget.initialSessionId,
              ),
              selected: true,
            ),
          for (final row in view.sessions)
            if (row.id != widget.initialSessionId) _sessionCard(view, row),
          if (!view.completed)
            NeoButton(
              label: 'Tambah sesi manual',
              variant: NeoButtonVariant.secondary,
              onPressed: _busy ? null : () => _session(view),
            ),
        ]),
      );
    },
  );

  Widget _sessionCard(TaskView view, WorkSession row, {bool selected = false}) {
    final schedule = _workspace.effectiveSession(row);
    final zone = _workspace.zones;
    final start = zone.wall(schedule.start.instant, zone.displayId);
    final end = zone.wall(schedule.end.instant, zone.displayId);
    final current = _workspace.now();
    final move = _workspace.canMove(row, view.logs);
    final elapsed = !schedule.end.instant.isAfter(current);
    final status = switch (row.status) {
      ActivityStatus.cancelled => 'Sesi dibatalkan',
      ActivityStatus.completed => 'Sesi terlaksana',
      ActivityStatus.postponed => 'Sesi ditunda',
      ActivityStatus.skipped => 'Sesi dilewatkan',
      ActivityStatus.planned =>
        schedule.start.instant.isAfter(current)
            ? 'Sesi mendatang'
            : elapsed
            ? 'Waktu sesi berakhir'
            : 'Sesi berlangsung',
    };
    return NeoCard(
      tone: selected ? NeoCardTone.selected : NeoCardTone.plain,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status, style: NeoType.item),
          Text(
            '${taskTime(start)} – ${dateOnly(start) == dateOnly(end) ? clockLabel(minutesAt(end)) : taskTime(end)}',
          ),
          Text('Durasi terjadwal · ${_minutes(schedule.duration)}'),
          for (final log in view.logs.where((log) => log.target.id == row.id))
            Text('Catatan aktual · ${_minutes(log.actualDuration)}'),
          if (move || (row.status == ActivityStatus.planned && elapsed))
            TextButton(
              onPressed: _busy ? null : () => _sessionMenu(view, row),
              child: const Text('Tindakan sesi'),
            ),
        ],
      ),
    );
  }
}

String _minutes(Duration? value, {String empty = 'Belum dikonfirmasi'}) =>
    value == null ? empty : '${value.inMinutes} menit';
