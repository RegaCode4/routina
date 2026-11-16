import 'package:flutter/material.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/application/task_workspace.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/demo/demo_widgets.dart';
import 'package:routina/presentation/design_system/neo_badges.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_form_field.dart';
import 'package:routina/presentation/design_system/neo_navigation.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/design_system/planner_cards.dart';
import 'package:routina/presentation/planner/preview_ui.dart';
import 'package:routina/presentation/tasks/task_editor.dart';

class TaskList extends StatefulWidget {
  const TaskList({
    required this.repository,
    required this.workspace,
    required this.revision,
    required this.onOpen,
    required this.onAdd,
    super.key,
  });
  final PlannerPreviewRepository repository;
  final TaskWorkspace workspace;
  final int revision;
  final ValueChanged<String> onOpen;
  final VoidCallback onAdd;
  @override
  State<TaskList> createState() => _TaskListState();
}

enum _Status {
  all('Semua'),
  active('Aktif'),
  overdue('Overdue'),
  completed('Selesai');

  const _Status(this.label);
  final String label;

  bool matches(TaskView task) => switch (this) {
    all => true,
    active => !task.completed,
    overdue => task.overdue,
    completed => task.completed,
  };
}

enum _Order {
  deadline('Tenggat terdekat'),
  priority('Prioritas tertinggi'),
  title('Judul A–Z');

  const _Order(this.label);
  final String label;
}

class _TaskListState extends State<TaskList> {
  late Future<List<TaskView>> _load = widget.workspace.list();
  final _search = FocusNode();
  final _query = TextEditingController();
  _Status _status = _Status.all;
  _Order _order = _Order.deadline;
  String? _category;
  String? _priority;
  DateTime? _day;

  @override
  void didUpdateWidget(covariant TaskList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != oldWidget.revision ||
        widget.workspace != oldWidget.workspace) {
      _load = widget.workspace.list();
      if (_category?.isNotEmpty == true &&
          !widget.repository.categories.any((row) => row.id == _category)) {
        _category = null;
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _query.dispose();
    super.dispose();
  }

  bool get _filtered =>
      _status != _Status.all ||
      _category != null ||
      _priority != null ||
      _day != null;

  void _reset() => setState(() {
    _status = _Status.all;
    _category = null;
    _priority = null;
    _day = null;
    _query.clear();
  });

  Future<void> _pickCategory() async {
    final values = {
      '*': 'Semua kategori',
      '': 'Tanpa kategori',
      for (final category in widget.repository.categories)
        category.id: category.name,
    };
    final pick = await previewChoices(
      context,
      'Kategori',
      values.keys.toList(),
      (value) => values[value]!,
    );
    if (mounted && pick != null) {
      setState(() => _category = pick == '*' ? null : pick);
    }
  }

  Future<void> _filter() async {
    _search.unfocus();
    final field = await previewChoices(context, 'Filter tugas', [
      'Tanggal',
      'Status',
      'Prioritas',
    ], (value) => value);
    if (!mounted || field == null) return;
    switch (field) {
      case 'Tanggal':
        final option = await previewChoices(context, 'Tanggal tenggat', [
          'Pilih tanggal',
          'Semua tanggal',
        ], (value) => value);
        if (!mounted || option == null) return;
        if (option == 'Semua tanggal') {
          setState(() => _day = null);
          return;
        }
        final picked = await pickPreviewDate(
          context,
          widget.workspace.today,
          selected: _day,
        );
        if (mounted && picked != null) setState(() => _day = civilDate(picked));
      case 'Status':
        final status = await previewChoices(
          context,
          'Status tugas',
          _Status.values,
          (value) => value.label,
        );
        if (mounted && status != null) setState(() => _status = status);
      case 'Prioritas':
        final priority = await previewChoices(context, 'Prioritas', [
          'Semua prioritas',
          'Tanpa prioritas',
          ...taskPriorities,
        ], (value) => value);
        if (mounted && priority != null) {
          setState(
            () => _priority = priority == 'Semua prioritas'
                ? null
                : priority == 'Tanpa prioritas'
                ? ''
                : priority,
          );
        }
    }
  }

  List<TaskView> _matches(List<TaskView> tasks) {
    final query = _query.text.trim().toLowerCase();
    final rows = tasks.where((view) {
      final task = view.task;
      return task.title.toLowerCase().contains(query) &&
          _status.matches(view) &&
          (_category == null || (task.categoryId ?? '') == _category) &&
          (_priority == null || (task.priority ?? '') == _priority) &&
          (_day == null ||
              (view.displayDeadline != null &&
                  civilDate(view.displayDeadline!) == _day));
    }).toList();
    int byDeadline(TaskView a, TaskView b) => (a.deadline ?? DateTime.utc(9999))
        .compareTo(b.deadline ?? DateTime.utc(9999));
    int priority(TaskView view) {
      final index = taskPriorities.indexOf(view.task.priority ?? '');
      return index < 0 ? taskPriorities.length : index;
    }

    rows.sort((a, b) {
      final rank = switch (_order) {
        _Order.deadline => byDeadline(a, b),
        _Order.priority => priority(a).compareTo(priority(b)),
        _Order.title => 0,
      };
      if (rank != 0) return rank;
      if (_order == _Order.priority) {
        final deadlineRank = byDeadline(a, b);
        if (deadlineRank != 0) return deadlineRank;
      }
      final title = a.task.title.toLowerCase().compareTo(
        b.task.title.toLowerCase(),
      );
      return title == 0 ? a.task.id.compareTo(b.task.id) : title;
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppHeader(
        title: 'To-Do List',
        action: NeoIconButton(
          icon: Icons.search,
          label: 'Fokus pencarian tugas',
          onPressed: _search.requestFocus,
        ),
      ),
      Expanded(
        child: FutureBuilder<List<TaskView>>(
          future: _load,
          builder: (context, snapshot) {
            final tasks = snapshot.data ?? const [];
            final rows = _matches(tasks);
            final active = rows.where((row) => !row.completed).toList();
            final done = rows.where((row) => row.completed).toList();
            final category = widget.repository.categories
                .where((row) => row.id == _category)
                .firstOrNull;
            return DemoList(tab: true, [
              const DemoHeading(
                'Rencanakan fokus',
                subtitle: 'Tenggat membantu menentukan tugas berikutnya.',
              ),
              NeoFormField(
                label: 'Cari tugas',
                hint: 'Cari judul tugas',
                icon: Icons.search,
                focusNode: _search,
                controller: _query,
                onChanged: (_) => setState(() {}),
              ),
              Wrap(
                spacing: NeoSpace.xs,
                runSpacing: NeoSpace.xxs,
                children: [
                  CategoryChip(
                    label: 'Semua',
                    selected: !_filtered,
                    onSelected: (_) => _reset(),
                  ),
                  CategoryChip(
                    label: 'Overdue',
                    selected: _status == _Status.overdue,
                    onSelected: (value) => setState(
                      () => _status = value ? _Status.overdue : _Status.all,
                    ),
                  ),
                  CategoryChip(
                    label:
                        category?.name ??
                        (_category == '' ? 'Tanpa kategori' : 'Kategori'),
                    selected: _category != null,
                    onSelected: (_) => _pickCategory(),
                  ),
                  CategoryChip(
                    label: 'Urutkan',
                    selected: _order != _Order.deadline,
                    onSelected: (_) async {
                      final order = await previewChoices(
                        context,
                        'Urutkan tugas',
                        _Order.values,
                        (value) => value.label,
                      );
                      if (mounted && order != null) {
                        setState(() => _order = order);
                      }
                    },
                  ),
                  CategoryChip(
                    label: 'Filter',
                    selected:
                        _day != null ||
                        _priority != null ||
                        _status == _Status.active ||
                        _status == _Status.completed,
                    onSelected: (_) => _filter(),
                  ),
                ],
              ),
              if (snapshot.hasError)
                PreviewNotice(
                  title: 'Daftar tugas gagal dimuat',
                  message: 'Coba baca lagi data lokal.',
                  button: NeoButton(
                    label: 'Coba lagi',
                    onPressed: () => setState(() {
                      _load = widget.workspace.list();
                    }),
                  ),
                )
              else if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Memuat daftar tugas',
                  ),
                )
              else if (rows.isEmpty)
                PreviewNotice(
                  title: tasks.isEmpty
                      ? 'Belum ada tugas'
                      : 'Tugas tidak ditemukan',
                  message: tasks.isEmpty
                      ? 'Tambahkan tugas dengan tenggat.'
                      : 'Sesuaikan pencarian atau hapus filter.',
                  icon: Icons.fact_check_outlined,
                  button: NeoButton(
                    label: tasks.isEmpty ? 'Tambah tugas' : 'Hapus filter',
                    onPressed: tasks.isEmpty ? widget.onAdd : _reset,
                  ),
                )
              else ...[
                if (active.isNotEmpty)
                  const Text('Tugas aktif', style: NeoType.section),
                ...active.map(_card),
                if (active.isEmpty &&
                    done.isNotEmpty &&
                    !_filtered &&
                    _query.text.isEmpty)
                  const PreviewNotice(
                    title: 'Semua tugas selesai',
                    message: 'Tambahkan tugas ketika ada pekerjaan baru.',
                  ),
                if (done.isNotEmpty)
                  const Text('Tugas selesai', style: NeoType.section),
                ...done.map(_card),
              ],
            ]);
          },
        ),
      ),
    ],
  );

  Widget _card(TaskView view) {
    final deadline = view.displayDeadline;
    return TaskCard(
      title: view.task.title,
      due: deadline == null
          ? 'Tanpa tenggat'
          : '${dateLabel(deadline)} · ${clockLabel(minutesAt(deadline))} ${widget.workspace.zones.displayId}',
      priority: view.task.priority,
      status: view.completed
          ? NeoStatus.completed
          : view.overdue
          ? NeoStatus.overdue
          : null,
      subtasks: view.progress == null
          ? null
          : '${view.checked}/${view.subtasks.length} subtugas · ${(view.progress! * 100).round()}%',
      subtaskProgress: view.progress,
      sessions: view.upcoming.isEmpty ? null : '${view.upcoming.length} sesi',
      onTap: () => widget.onOpen(view.task.id),
    );
  }
}
