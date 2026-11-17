import 'package:routina/presentation/planner/reminder_ui.dart';
import 'package:flutter/material.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/application/task_workspace.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/demo/demo_widgets.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_form_field.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

const taskPriorities = ['Tinggi', 'Sedang', 'Rendah'];

String taskTime(DateTime wall) =>
    '${dateLabel(wall, year: true)} · ${clockLabel(minutesAt(wall))}';

class TaskEditor extends StatefulWidget {
  const TaskEditor({
    required this.repository,
    required this.workspace,
    this.initial,
    this.deadlineOnly = false,
    super.key,
  });
  final PlannerPreviewRepository repository;
  final TaskWorkspace workspace;
  final TaskView? initial;
  final bool deadlineOnly;
  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  Task? get _original => widget.initial?.task;
  TaskWorkspace get _workspace => widget.workspace;
  late bool _full = _original != null;
  late String _title = _original?.title ?? '';
  late String _description = _original?.description ?? '';
  late String _estimate =
      _original?.initialEstimate?.inMinutes.toString() ?? '';
  late String? _category = _original?.categoryId;
  late String? _priority = _original?.priority;
  late TimeMode _mode =
      _original?.deadline?.mode ??
      widget.repository.profile?.preferences.deadlineTimeMode ??
      TimeMode.originalZone;
  late final String _originZone =
      _original?.deadline?.zoneId ?? _workspace.zones.displayId;
  late final DateTime? _initialWall = switch (_original?.deadline) {
    null => null,
    final time =>
      time.localWallTime == null
          ? _workspace.zones.wall(time.instant, time.zoneId)
          : DateTime.parse(time.localWallTime!),
  };
  late DateTime? _date = _initialWall;
  late int? _minute = _initialWall == null ? null : minutesAt(_initialWall);
  late final List<SubtaskEdit> _subtasks = [
    for (final item in widget.initial?.subtasks ?? <Subtask>[])
      (existing: item, title: item.title),
  ];
  late Set<Duration> _reminders = {
    for (final rule in widget.initial?.reminders ?? <ReminderRule>[])
      if (rule.enabled) rule.offset,
  };
  bool _remindersEdited = false;
  bool _busy = false;
  String? _error;

  ZonedTime? get _deadline {
    final date = _date;
    final minute = _minute;
    if (date == null || minute == null) return null;
    final previous = _original?.deadline;
    final wall = civilDate(date).add(Duration(minutes: minute));
    if (previous != null &&
        previous.mode == _mode &&
        wall == civilTime(_initialWall!)) {
      return previous;
    }
    final zone = _mode == TimeMode.localWallTime
        ? _workspace.zones.deviceId
        : _originZone;
    return _workspace.zones.atWall(wall, zone, _mode);
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final day = await pickPreviewDate(
      context,
      _workspace.today,
      selected: _date,
    );
    if (mounted && day != null) setState(() => _date = day);
  }

  Future<void> _pickTime() async {
    FocusScope.of(context).unfocus();
    final time = await pickPreviewTime(context, initial: _minute);
    if (mounted && time != null) setState(() => _minute = time);
  }

  Future<void> _save() async {
    if (_busy) return;
    final deadline = _deadline;
    final estimate = _estimate.trim().isEmpty
        ? null
        : int.tryParse(_estimate.trim());
    final duration = estimate == null ? null : Duration(minutes: estimate);
    if (deadline == null) {
      setState(() => _error = 'Lengkapi tanggal dan jam tenggat.');
      return;
    }
    if (!widget.deadlineOnly &&
        (_title.trim().isEmpty ||
            (_estimate.trim().isNotEmpty &&
                (estimate == null ||
                    estimate < 1 ||
                    duration?.inMinutes != estimate)))) {
      setState(
        () => _error = 'Isi judul dan masukkan estimasi menit yang valid.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var acceptPast = false;
      while (true) {
        try {
          final Task saved;
          if (widget.deadlineOnly) {
            saved = await _workspace.moveDeadline(
              _original!,
              deadline,
              acceptPast: acceptPast,
            );
          } else {
            saved = await _workspace.save(
              previous: _original,
              title: _title,
              deadline: deadline,
              categoryId: _category,
              description: _description,
              priority: _priority,
              estimate: duration,
              subtasks: List.of(_subtasks),
              reminders: _remindersEdited ? _reminders : null,
              acceptPast: acceptPast,
            );
          }
          if (mounted) Navigator.pop(context, saved);
          return;
        } on PastTaskDeadline {
          if (!mounted) return;
          final confirmed = await showNeoDialog(
            context,
            title: 'Tenggat sudah lewat',
            message: 'Tugas yang masih terbuka akan tampil sebagai Overdue.',
            confirmLabel: 'Simpan tenggat',
          );
          if (!mounted || confirmed != true) return;
          acceptPast = true;
        }
      }
    } on TaskIssue catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on StaleRecord {
      if (mounted) {
        setState(
          () => _error =
              'Data tugas telah berubah. Buka kembali formulir untuk memuat data terbaru.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Tugas belum dapat disimpan. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editSubtask([int? index]) async {
    if (index == null) {
      final name = await demoText(context, 'Tambah subtugas', 'Nama subtugas');
      if (mounted && name != null) {
        setState(() => _subtasks.add((existing: null, title: name)));
      }
      return;
    }
    final entry = _subtasks[index];
    final action = await previewChoices(context, entry.title, [
      'Ubah nama subtugas',
      'Hapus subtugas',
    ], (value) => value);
    if (!mounted || action == null) return;
    if (action == 'Hapus subtugas') {
      setState(() => _subtasks.removeAt(index));
    } else {
      final name = await demoText(
        context,
        action,
        'Nama subtugas',
        initial: entry.title,
      );
      if (mounted && name != null) {
        setState(
          () => _subtasks[index] = (existing: entry.existing, title: name),
        );
      }
    }
  }

  Future<void> _editReminders() async {
    final result = await pickReminderOffsets(
      context,
      title: 'Pengingat tenggat',
      label: _reminderLabel,
      selected: _reminders,
      presets: const [Duration(days: 1), Duration(hours: 1), Duration.zero],
    );
    if (mounted && result != null) {
      setState(() {
        _reminders = result;
        _remindersEdited = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.repository.categories;
    final title = widget.deadlineOnly
        ? 'Ubah tenggat'
        : !_full
        ? 'Tambah tugas'
        : _original == null
        ? 'Form lengkap tugas'
        : 'Edit tugas';
    final deadline = _deadline;
    final active =
        deadline != null && (widget.deadlineOnly || _title.trim().isNotEmpty);
    final overdue =
        deadline != null &&
        _workspace.zones.effectiveTime(deadline).isBefore(_workspace.now());
    return PreviewPage(
      title: title,
      footer: DemoActions([
        NeoButton(
          label: widget.deadlineOnly ? 'Simpan tenggat' : 'Simpan tugas',
          loading: _busy,
          onPressed: active && !_busy ? _save : null,
        ),
        if (!_full)
          NeoButton(
            label: 'Buka Form Lengkap',
            variant: NeoButtonVariant.secondary,
            onPressed: _busy ? null : () => setState(() => _full = true),
          ),
      ]),
      body: AbsorbPointer(
        absorbing: _busy,
        child: DemoList([
          if (!_full)
            const DemoHeading(
              'Quick Add',
              subtitle: 'Isi judul dan tenggat tugas.',
            ),
          if (widget.deadlineOnly)
            const Text('Perubahan tenggat hanya berlaku untuk tugas ini.'),
          if (!widget.deadlineOnly)
            NeoFormField(
              key: const ValueKey('task-title'),
              label: 'Judul',
              hint: 'Masukkan judul',
              initialValue: _title,
              onChanged: (value) => setState(() => _title = value),
              labelAbove: true,
            ),
          if (_full && !widget.deadlineOnly) ...[
            NeoFormField(
              label: 'Deskripsi',
              initialValue: _description,
              maxLines: 2,
              onChanged: (value) => _description = value,
              labelAbove: true,
            ),
            const Text('Tenggat dan kategori', style: NeoType.section),
          ],
          PreviewField(
            label: 'Tanggal tenggat',
            value: _date == null
                ? 'Pilih tanggal'
                : dateLabel(_date!, year: true),
            icon: Icons.event_outlined,
            onTap: _pickDate,
          ),
          PreviewField(
            label: 'Jam tenggat',
            value: _minute == null ? 'Pilih jam' : clockLabel(_minute!),
            icon: Icons.schedule,
            onTap: _pickTime,
          ),
          if (!_full)
            Text(
              'Zona tenggat · ${_mode == TimeMode.originalZone ? _originZone : _workspace.zones.deviceId}',
            ),
          if (overdue && _original?.status != ActivityStatus.completed)
            const PreviewNotice(
              title: 'Tenggat sudah lewat',
              message: 'Tugas terbuka akan ditandai Overdue.',
              warning: true,
            ),
          if (_full)
            PreviewField(
              label: 'Zona waktu tenggat',
              value: _mode == TimeMode.originalZone
                  ? 'Pertahankan zona asal · $_originZone'
                  : 'Ikuti jam lokal · ${_workspace.zones.deviceId}',
              onTap: () async {
                final mode = await previewChoices(
                  context,
                  'Zona waktu tenggat',
                  TimeMode.values,
                  (value) => value == TimeMode.originalZone
                      ? 'Pertahankan zona asal'
                      : 'Ikuti jam lokal',
                );
                if (mounted && mode != null) setState(() => _mode = mode);
              },
            ),
          if (_full && !widget.deadlineOnly) ...[
            PreviewField(
              label: 'Kategori',
              value:
                  categories
                      .where((item) => item.id == _category)
                      .firstOrNull
                      ?.name ??
                  'Tanpa kategori',
              onTap: () async {
                final options = {
                  '': 'Tanpa kategori',
                  for (final item in categories) item.id: item.name,
                };
                final category = await previewChoices(
                  context,
                  'Kategori',
                  options.keys.toList(),
                  (value) => options[value]!,
                );
                if (mounted && category != null) {
                  setState(
                    () => _category = category.isEmpty ? null : category,
                  );
                }
              },
            ),
            PreviewField(
              label: 'Prioritas',
              value: _priority ?? 'Tanpa prioritas',
              onTap: () async {
                final priority = await previewChoices(context, 'Prioritas', [
                  'Tanpa prioritas',
                  ...taskPriorities,
                ], (value) => value);
                if (mounted && priority != null) {
                  setState(
                    () => _priority = taskPriorities.contains(priority)
                        ? priority
                        : null,
                  );
                }
              },
            ),
            const Text('Checklist', style: NeoType.section),
            for (final (index, item) in _subtasks.indexed)
              PreviewField(
                label: 'Subtugas ${index + 1}',
                value: item.title,
                icon: Icons.edit_outlined,
                onTap: () => _editSubtask(index),
              ),
            NeoButton(
              label: 'Tambah subtugas',
              variant: NeoButtonVariant.secondary,
              onPressed: () => _editSubtask(),
            ),
            PreviewField(
              label: 'Pengingat',
              value: _reminders.isEmpty
                  ? 'Tanpa pengingat'
                  : _reminders.map(_reminderLabel).join(' · '),
              icon: Icons.notifications_outlined,
              onTap: _editReminders,
            ),
            if (widget.repository.profile?.notifications != true)
              const PreviewNotice(
                title: 'Notifikasi nonaktif',
                message: 'Tenggat tetap terlihat di Home dan Kalender.',
              ),
            NeoFormField(
              label: 'Estimasi pekerjaan (menit)',
              initialValue: _estimate,
              keyboardType: TextInputType.number,
              onChanged: (value) => _estimate = value,
              labelAbove: true,
            ),
            if (widget.initial?.sessions.isNotEmpty == true)
              Text(
                '${widget.initial!.sessions.length} sesi pengerjaan terkait',
              ),
          ],
          if (_error case final error?)
            PreviewNotice(
              title: 'Periksa isian tugas',
              message: error,
              warning: true,
            ),
        ]),
      ),
    );
  }
}

String _reminderLabel(Duration offset) => switch (offset.inMinutes) {
  0 => 'Saat tenggat',
  60 => '1 jam sebelum tenggat',
  1440 => '1 hari sebelum tenggat',
  final minutes => '$minutes menit sebelum tenggat',
};
