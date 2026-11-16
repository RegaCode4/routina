import 'package:flutter/material.dart';
import 'package:routina/application/task_workspace.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/demo/demo_widgets.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/planner/preview_ui.dart';
import 'package:routina/presentation/tasks/task_editor.dart';

class SessionEditor extends StatefulWidget {
  const SessionEditor({
    required this.workspace,
    required this.task,
    this.previous,
    this.proposal,
    super.key,
  });
  final TaskWorkspace workspace;
  final TaskView task;
  final WorkSession? previous;
  final WorkSlot? proposal;
  @override
  State<SessionEditor> createState() => _SessionEditorState();
}

class _SessionEditorState extends State<SessionEditor> {
  TaskWorkspace get _workspace => widget.workspace;
  late final WorkSlot? _initial = widget.proposal ?? _readInitial();
  late DateTime? _day = _initial == null ? null : dateOnly(_initial.start);
  late DateTime? _endDay =
      _initial == null || dateOnly(_initial.start) == dateOnly(_initial.end)
      ? null
      : dateOnly(_initial.end);
  late int? _start = _initial == null ? null : minutesAt(_initial.start);
  late int? _end = _initial == null ? null : minutesAt(_initial.end);
  bool _busy = false;
  String? _error;

  WorkSlot? _readInitial() {
    final session = widget.previous;
    if (session == null) return null;
    final schedule = _workspace.effectiveSession(session);
    final zones = _workspace.zones;
    return (
      start: zones.wall(schedule.start.instant, zones.displayId),
      end: zones.wall(schedule.end.instant, zones.displayId),
    );
  }

  Future<void> _pickDate({bool end = false}) async {
    final value = await pickPreviewDate(
      context,
      _workspace.today,
      selected: end ? _endDay ?? _day : _day,
    );
    if (!mounted || value == null) return;
    setState(() {
      if (end) {
        _endDay = _day != null && dateOnly(value) == dateOnly(_day!)
            ? null
            : value;
      } else {
        _day = value;
      }
    });
  }

  Future<void> _pickTime({bool end = false}) async {
    final value = await pickPreviewTime(context, initial: end ? _end : _start);
    if (!mounted || value == null) return;
    setState(() {
      if (end) {
        _end = value;
      } else {
        _start = value;
      }
    });
  }

  Future<void> _save() async {
    if (_busy || _day == null || _start == null || _end == null) return;
    final start = civilDate(_day!).add(Duration(minutes: _start!));
    final end = civilDate(_endDay ?? _day!).add(Duration(minutes: _end!));
    final proposal = widget.proposal;
    final isProposal =
        proposal != null &&
        start == civilTime(proposal.start) &&
        end == civilTime(proposal.end);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var approved = const SessionWarnings({});
      while (true) {
        try {
          final saved = await _workspace.saveSession(
            widget.task.task.id,
            start,
            end,
            previous: widget.previous,
            approved: approved,
          );
          if (mounted) Navigator.pop(context, saved);
          return;
        } on SessionWarnings catch (warnings) {
          if (!mounted) return;
          if (isProposal) {
            setState(
              () => _error =
                  'Slot berubah. Pilih waktu lain atau cari ulang slot.',
            );
            return;
          }
          final consent = await showNeoDialog(
            context,
            title: 'Simpan sesi dengan peringatan?',
            message: [
              ...warnings.schedule.map(warningBody),
              if (warnings.afterDeadline)
                'Sesi berakhir setelah tenggat tugas.',
            ].join('\n'),
            confirmLabel: 'Simpan dengan peringatan',
          );
          if (!mounted || consent != true) return;
          approved = warnings;
        }
      }
    } on TaskIssue catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on StaleRecord {
      if (mounted) {
        setState(
          () => _error =
              'Data sesi atau tugas telah berubah. Buka kembali formulir.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Sesi belum dapat disimpan. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PreviewPage(
    title: widget.proposal != null
        ? 'Tinjau slot'
        : widget.previous == null
        ? 'Tambah sesi manual'
        : 'Pindah sesi',
    footer: NeoButton(
      label: 'Simpan sesi',
      loading: _busy,
      onPressed: !_busy && _day != null && _start != null && _end != null
          ? _save
          : null,
    ),
    body: AbsorbPointer(
      absorbing: _busy,
      child: DemoList([
        DemoHeading(
          'Sesi pengerjaan',
          subtitle: switch (widget.task.displayDeadline) {
            null => 'Tugas ini belum memiliki tenggat.',
            final deadline => 'Tenggat tugas tetap ${taskTime(deadline)}.',
          },
        ),
        PreviewField(
          label: 'Tanggal',
          value: _day == null ? 'Pilih tanggal' : dateLabel(_day!, year: true),
          icon: Icons.event_outlined,
          onTap: _pickDate,
        ),
        PreviewField(
          label: 'Jam mulai',
          value: _start == null ? 'Pilih jam' : clockLabel(_start!),
          icon: Icons.schedule,
          onTap: _pickTime,
          numeric: true,
        ),
        PreviewField(
          label: 'Jam selesai',
          value: _end == null ? 'Pilih jam' : clockLabel(_end!),
          icon: Icons.schedule,
          onTap: () => _pickTime(end: true),
          numeric: true,
        ),
        PreviewField(
          label: 'Tanggal selesai (opsional)',
          value: _endDay == null
              ? 'Hari yang sama'
              : dateLabel(_endDay!, year: true),
          icon: Icons.event_outlined,
          onTap: () => _pickDate(end: true),
        ),
        if (_error case final error?)
          PreviewNotice(
            title: 'Periksa jadwal sesi',
            message: error,
            warning: true,
          ),
      ]),
    ),
  );
}
