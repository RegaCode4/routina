import 'package:flutter/material.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/design_system/neo_badges.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_form_field.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/design_system/planner_cards.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

import 'package:routina/presentation/demo/demo_session.dart';
import 'package:routina/presentation/demo/demo_widgets.dart';
import 'package:routina/presentation/demo/smart.dart';

class DemoTasks extends StatefulWidget {
  const DemoTasks(this.demo, {super.key});
  final DemoSession demo;
  @override
  State<DemoTasks> createState() => _DemoTasksState();
}

class _DemoTasksState extends State<DemoTasks> {
  String query = '';
  String filter = 'Semua';
  String category = 'Semua kategori';
  String sort = 'Deadline terdekat';
  String priority = 'Semua prioritas';
  DateTime? day;

  @override
  Widget build(BuildContext context) {
    final demo = widget.demo;
    return ListenableBuilder(
      listenable: demo,
      builder: (context, _) {
        bool overdue(DemoTask task) =>
            !task.completed && (task.deadline?.isBefore(demo.today) ?? false);
        final matches = demo.tasks
            .where(
              (task) =>
                  task.title.toLowerCase().contains(
                    query.trim().toLowerCase(),
                  ) &&
                  (category == 'Semua kategori' || task.category == category) &&
                  (priority == 'Semua prioritas' ||
                      task.priority == priority) &&
                  (day == null ||
                      (task.date != null && dateOnly(task.date!) == day)) &&
                  (filter != 'Overdue' || overdue(task)) &&
                  (filter != 'Selesai' || task.completed) &&
                  (filter != 'Aktif' || !task.completed),
            )
            .toList();
        if (sort == 'Deadline terdekat') {
          matches.sort(
            (a, b) => (a.deadline ?? DateTime(9999)).compareTo(
              b.deadline ?? DateTime(9999),
            ),
          );
        } else if (sort == 'Prioritas tertinggi') {
          const priority = {'Tinggi': 0, 'Sedang': 1, 'Rendah': 2};
          matches.sort(
            (a, b) => (priority[a.priority] ?? 3).compareTo(
              priority[b.priority] ?? 3,
            ),
          );
        } else {
          matches.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
        }
        Widget card(DemoTask task) => TaskCard(
          title: task.title,
          due: task.deadline == null
              ? 'Tanpa deadline'
              : 'Deadline · ${dateLabel(task.deadline!)} · ${clockLabel(task.time!)}',
          priority: task.priority,
          subtasks: task.checklist.isEmpty
              ? null
              : '${task.checked}/${task.checklist.length} subtugas',
          subtaskProgress: task.checklist.isEmpty
              ? null
              : task.checked / task.checklist.length,
          sessions: task.slots.isEmpty ? null : '${task.slots.length} sesi',
          status: task.completed
              ? NeoStatus.completed
              : overdue(task)
              ? NeoStatus.overdue
              : NeoStatus.active,
          onTap: () => openDemo<void>(context, DemoTaskDetail(demo, task.id)),
        );
        final state = demoFeed(demo, 'tasks', 'Daftar tugas');
        return DemoTab(
          'To-Do List',
          DemoList(tab: true, [
            const DemoHeading(
              'Rencanakan fokus',
              subtitle: 'Lacak deadline, subtugas, dan waktu pengerjaan.',
            ),
            NeoFormField(
              label: 'Cari tugas',
              hint: 'Cari judul tugas',
              icon: Icons.search,
              onChanged: (value) => setState(() => query = value),
            ),
            Wrap(
              spacing: NeoSpace.xs,
              runSpacing: NeoSpace.xxs,
              children: [
                CategoryChip(
                  label: 'Semua',
                  selected: filter == 'Semua',
                  onSelected: (_) => setState(() {
                    filter = 'Semua';
                    category = 'Semua kategori';
                    day = null;
                    priority = 'Semua prioritas';
                  }),
                ),
                CategoryChip(
                  label: 'Overdue',
                  selected: filter == 'Overdue',
                  onSelected: (_) => setState(() => filter = 'Overdue'),
                ),
                CategoryChip(
                  label: category == 'Semua kategori' ? 'Kategori' : category,
                  icon: Icons.filter_list,
                  selected: category != 'Semua kategori',
                  onSelected: (_) => demoPick(context, 'Kategori', [
                    'Semua kategori',
                    ...demo.categoryNames,
                    'Tanpa kategori',
                  ], (value) => setState(() => category = value)),
                ),
                CategoryChip(
                  label: 'Urutkan',
                  icon: Icons.sort,
                  onSelected: (_) => demoPick(context, 'Urutkan tugas', [
                    'Deadline terdekat',
                    'Prioritas tertinggi',
                    'Judul A–Z',
                  ], (value) => setState(() => sort = value)),
                ),
                CategoryChip(
                  label: 'Filter',
                  icon: Icons.tune,
                  selected:
                      day != null ||
                      priority != 'Semua prioritas' ||
                      ['Selesai', 'Aktif'].contains(filter),
                  onSelected: (_) async {
                    final field = await previewChoices(
                      context,
                      'Filter tugas',
                      ['Tanggal', 'Status', 'Prioritas'],
                      (value) => value,
                    );
                    if (!context.mounted) return;
                    switch (field) {
                      case 'Tanggal':
                        final value = await pickPreviewDate(
                          context,
                          demo.today,
                          selected: day,
                        );
                        if (mounted && value != null) {
                          setState(() => day = dateOnly(value));
                        }
                      case 'Status':
                        await demoPick(context, 'Status', [
                          'Semua',
                          'Aktif',
                          'Selesai',
                          'Overdue',
                        ], (value) => setState(() => filter = value));
                      case 'Prioritas':
                        await demoPick(
                          context,
                          'Prioritas',
                          ['Semua prioritas', 'Tinggi', 'Sedang', 'Rendah'],
                          (value) => setState(() => priority = value),
                        );
                    }
                  },
                ),
              ],
            ),
            if (state != null)
              state
            else if (matches.isEmpty)
              PreviewNotice(
                title: demo.tasks.isEmpty
                    ? 'Belum ada tugas'
                    : 'Tugas tidak ditemukan',
                message: 'Tambahkan tugas atau sesuaikan pencarian dan filter.',
                icon: Icons.fact_check_outlined,
                button: NeoButton(
                  label: 'Tambah tugas',
                  onPressed: () =>
                      openDemo<void>(context, DemoTaskEditor(demo, DemoTask())),
                ),
              )
            else ...[
              if (matches.every((task) => task.completed))
                const PreviewNotice(
                  title: 'Semua tugas selesai',
                  message: 'Tugas yang sesuai dengan filter ini sudah selesai.',
                ),
              if (matches.any((task) => !task.completed))
                const Text('Tugas aktif', style: NeoType.section),
              ...matches.where((task) => !task.completed).map(card),
              if (matches.any((task) => task.completed))
                const Text('Tugas selesai', style: NeoType.section),
              ...matches.where((task) => task.completed).map(card),
            ],
          ]),
        );
      },
    );
  }
}

class DemoTaskDetail extends StatelessWidget {
  const DemoTaskDetail(this.demo, this.id, {super.key});
  final DemoSession demo;
  final String id;

  Future<void> _complete(BuildContext context, DemoTask task) async {
    final hasFuture = task.upcoming.isNotEmpty;
    final choice = await demoSheet<bool>(
      context,
      'Tandai tugas selesai?',
      (sheet) => [
        NeoButton(
          label: hasFuture ? 'Selesai, pertahankan sesi' : 'Tandai selesai',
          onPressed: () => Navigator.pop(sheet, false),
        ),
        if (hasFuture)
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
      description: hasFuture
          ? 'Tentukan nasib sesi pengerjaan mendatang. Riwayat sesi tetap tersimpan.'
          : 'Status tugas akan diperbarui pada pratinjau ini.',
    );
    if (context.mounted && choice != null) {
      demo.completeTask(task, cancelFuture: choice);
    }
  }

  Future<void> _more(BuildContext context, DemoTask task) async {
    final action = await previewChoices(context, 'Tindakan tugas', [
      'Edit tugas',
      'Pindah ke Tempat Sampah',
    ], (value) => value);
    if (!context.mounted) return;
    if (action == 'Edit tugas') {
      await openDemo<void>(
        context,
        DemoTaskEditor(demo, task.copy(), full: true),
      );
      return;
    }
    if (action == 'Pindah ke Tempat Sampah') {
      final confirm = await showNeoDialog(
        context,
        title: 'Pindahkan tugas?',
        message: 'Tugas dan sesi mendatangnya dipindahkan ke Tempat Sampah.',
        confirmLabel: 'Pindahkan',
        danger: true,
      );
      if (context.mounted && confirm == true) {
        Navigator.pop(context);
        demo.discardTask(task);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: demo,
    builder: (context, _) {
      final task = demo.tasks.where((item) => item.id == id).firstOrNull;
      if (task == null) {
        return const PreviewPage(
          title: 'Detail tugas',
          body: DemoList([
            PreviewNotice(
              title: 'Tugas tidak tersedia',
              message: 'Kembali ke daftar tugas.',
            ),
          ]),
        );
      }
      return PreviewPage(
        title: 'Detail tugas',
        action: NeoIconButton(
          icon: Icons.more_horiz,
          label: 'Tindakan tugas',
          onPressed: () => _more(context, task),
        ),
        footer: task.completed
            ? null
            : DemoActions([
                NeoButton(
                  label: 'Cari slot',
                  icon: Icons.auto_awesome,
                  onPressed: () =>
                      openDemo<void>(context, DemoSmart(demo, task)),
                ),
                NeoButton(
                  label: 'Tandai Tugas Selesai',
                  variant: NeoButtonVariant.secondary,
                  onPressed: () => _complete(context, task),
                ),
              ]),
        body: DemoList([
          DemoHeading(
            task.title,
            subtitle: task.description.isEmpty ? null : task.description,
          ),
          Wrap(
            spacing: NeoSpace.xs,
            runSpacing: NeoSpace.xxs,
            children: [
              StatusBadge(
                status: task.completed
                    ? NeoStatus.completed
                    : task.deadline?.isBefore(demo.today) == true
                    ? NeoStatus.overdue
                    : NeoStatus.active,
              ),
              CategoryChip(label: task.category),
              CategoryChip(label: 'Prioritas ${task.priority}'),
            ],
          ),
          DemoFacts([
            (
              'Deadline tugas',
              task.deadline == null
                  ? 'Belum ditentukan'
                  : '${dateLabel(task.deadline!, year: true)} · ${clockLabel(task.time!)} ${task.zone}',
            ),
          ], tone: NeoCardTone.highlighted),
          Text(
            'Subtugas · ${task.checked}/${task.checklist.length}',
            style: NeoType.section,
          ),
          if (task.checklist.isEmpty)
            const Text('Belum ada subtugas.')
          else
            NeoCard(
              child: Column(
                children: [
                  NeoProgressBar(
                    value: task.checked / task.checklist.length,
                    label: 'Progres subtugas',
                  ),
                  for (final item in task.checklist.entries)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.key),
                      value: item.value,
                      onChanged: task.completed
                          ? null
                          : (value) => demo.change(
                              () => task.checklist[item.key] = value!,
                            ),
                    ),
                ],
              ),
            ),
          if (!task.completed &&
              task.checklist.isNotEmpty &&
              task.checked == task.checklist.length)
            const PreviewNotice(
              title: 'Checklist 100%',
              message:
                  'Tandai tugas selesai saat semua pekerjaan sudah selesai.',
              icon: Icons.checklist,
            ),
          const Text('Sesi pengerjaan', style: NeoType.section),
          if (task.slots.isEmpty) const Text('Belum ada sesi pengerjaan.'),
          for (final slot in task.slots)
            DemoFacts(
              [
                (
                  slot.history
                      ? 'Riwayat sesi'
                      : demo.slotConflicts(slot)
                      ? 'Sesi mendatang · Bentrok'
                      : 'Sesi mendatang',
                  demoSlotLabel(slot),
                ),
                ('Durasi terjadwal', '${slot.minutes} menit'),
                if (slot.history)
                  (
                    'Durasi aktual',
                    slot.actual == null
                        ? 'Belum tercatat'
                        : '${slot.actual} menit',
                  ),
              ],
              tone: demo.slotConflicts(slot)
                  ? NeoCardTone.warning
                  : NeoCardTone.plain,
            ),
          DemoFacts([
            (
              'Estimasi pekerjaan',
              task.estimate == null ? 'Belum diisi' : '${task.estimate} menit',
            ),
            (
              'Estimasi sisa disetujui',
              task.remaining == null
                  ? 'Belum dikonfirmasi'
                  : '${task.remaining} menit',
            ),
            ('Durasi aktual tercatat', '${task.actual} menit'),
          ]),
          if (!task.completed) ...[
            if (task.upcoming.any(demo.slotConflicts))
              NeoButton(
                label: 'Tinjau konflik sesi',
                variant: NeoButtonVariant.secondary,
                onPressed: () => openDemo<void>(
                  context,
                  DemoSmart(demo, task, entry: SmartEntry.conflict),
                ),
              ),
            if (task.remaining != null && task.upcoming.isNotEmpty)
              NeoButton(
                label: 'Tinjau selisih durasi',
                variant: NeoButtonVariant.secondary,
                onPressed: () => openDemo<void>(
                  context,
                  DemoSmart(demo, task, entry: SmartEntry.mismatch),
                ),
              ),
            NeoButton(
              label: 'Tambah sesi manual',
              variant: NeoButtonVariant.secondary,
              onPressed: () => demoManualSlot(context, demo, task),
            ),
          ],
        ]),
      );
    },
  );
}

class DemoTaskEditor extends StatefulWidget {
  const DemoTaskEditor(this.demo, this.draft, {this.full = false, super.key});
  final DemoSession demo;
  final DemoTask draft;
  final bool full;
  @override
  State<DemoTaskEditor> createState() => _DemoTaskEditorState();
}

class _DemoTaskEditorState extends State<DemoTaskEditor> {
  final form = GlobalKey<FormState>();
  late final draft = widget.draft;
  late bool full = widget.full;
  String? error;
  final zones = TimeMode.values.map(timeModeLabel).toList();

  @override
  void initState() {
    super.initState();
    if (draft.id.isEmpty) {
      draft.zone = timeModeLabel(widget.demo.preferences.deadlineTimeMode);
    }
  }

  Future<void> _changeDate() async {
    final value = await pickPreviewDate(
      context,
      widget.demo.today,
      selected: draft.date,
    );
    if (mounted && value != null) {
      setState(() {
        draft.date = value;
        error = null;
      });
    }
  }

  Future<void> _changeTime() async {
    final value = await pickPreviewTime(context, initial: draft.time);
    if (mounted && value != null) {
      setState(() {
        draft.time = value;
        error = null;
      });
    }
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    if (draft.deadline == null) {
      setState(() => error = 'Lengkapi tanggal dan jam deadline.');
      return;
    }
    if (draft.deadline?.isBefore(widget.demo.today) == true &&
        await showNeoDialog(
              context,
              title: 'Deadline sudah lewat',
              message: 'Tugas akan tampil sebagai overdue pada pratinjau.',
              confirmLabel: 'Simpan tugas',
            ) !=
            true) {
      return;
    }
    if (!mounted) return;
    draft.title = draft.title.trim();
    widget.demo.saveTask(draft);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PreviewPage(
    title: full
        ? (draft.id.isEmpty ? 'Form lengkap tugas' : 'Edit tugas')
        : 'Tambah tugas',
    footer: DemoActions([
      NeoButton(label: 'Simpan tugas', onPressed: _save),
      if (!full)
        NeoButton(
          label: 'Form lengkap',
          variant: NeoButtonVariant.secondary,
          onPressed: () => setState(() => full = true),
        ),
    ]),
    body: Form(
      key: form,
      child: DemoList([
        DemoHeading(
          full ? 'Rencanakan tugasmu' : 'Quick Add',
          subtitle:
              'Deadline menandai batas akhir. Sesi pengerjaan diatur terpisah.',
        ),
        NeoFormField(
          label: 'Judul tugas',
          hint: 'Contoh: Mengerjakan laporan',
          initialValue: draft.title,
          labelAbove: true,
          onChanged: (value) => draft.title = value,
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Isi judul tugas.' : null,
        ),
        if (full)
          NeoFormField(
            label: 'Deskripsi',
            initialValue: draft.description,
            maxLines: 3,
            labelAbove: true,
            onChanged: (value) => draft.description = value,
          ),
        PreviewField(
          label: 'Tanggal deadline',
          value: draft.date == null
              ? 'Pilih tanggal'
              : dateLabel(draft.date!, year: true),
          icon: Icons.event_outlined,
          onTap: _changeDate,
        ),
        PreviewField(
          label: 'Jam deadline',
          value: draft.time == null ? 'Pilih jam' : clockLabel(draft.time!),
          icon: Icons.schedule,
          numeric: true,
          onTap: _changeTime,
        ),
        if (draft.date != null || draft.time != null)
          TextButton(
            onPressed: () => setState(() {
              draft.date = null;
              draft.time = null;
              error = null;
            }),
            child: const Text('Hapus deadline'),
          ),
        if (error case final message?)
          Text(message, style: const TextStyle(color: NeoColors.errorText)),
        if (full) ...[
          _select(
            'Zona waktu',
            draft.zone,
            zones,
            (value) => draft.zone = value,
          ),
          _select('Kategori', draft.category, [
            ...widget.demo.categoryNames,
            'Tanpa kategori',
          ], (value) => draft.category = value),
          _select('Prioritas', draft.priority, [
            'Rendah',
            'Sedang',
            'Tinggi',
          ], (value) => draft.priority = value),
          const Text('Checklist subtugas', style: NeoType.section),
          for (final item in draft.checklist.entries)
            DemoRow(
              item.key,
              icon: Icons.checklist,
              onTap: () async {
                final action = await previewChoices(context, item.key, [
                  'Ubah nama subtugas',
                  'Hapus subtugas',
                ], (value) => value);
                if (!context.mounted || action == null) return;
                if (action == 'Ubah nama subtugas') {
                  final name = await demoText(
                    context,
                    'Ubah nama subtugas',
                    'Nama subtugas',
                    initial: item.key,
                  );
                  if (!context.mounted || name == null || name == item.key) {
                    return;
                  }
                  if (draft.checklist.containsKey(name)) {
                    demoFeedback(context, 'Nama subtugas sudah dipakai.');
                    return;
                  }
                  setState(() {
                    draft.checklist.remove(item.key);
                    draft.checklist[name] = item.value;
                  });
                  return;
                }
                final confirm = await showNeoDialog(
                  context,
                  title: 'Hapus subtugas?',
                  message: item.key,
                  confirmLabel: 'Hapus',
                  danger: true,
                );
                if (mounted && confirm == true) {
                  setState(() => draft.checklist.remove(item.key));
                }
              },
            ),
          NeoButton(
            label: 'Tambah subtugas',
            variant: NeoButtonVariant.secondary,
            onPressed: () async {
              final value = await demoText(
                context,
                'Tambah subtugas',
                'Nama subtugas',
              );
              if (mounted && value != null) {
                setState(() => draft.checklist.putIfAbsent(value, () => false));
              }
            },
          ),
          _select(
            'Pengingat deadline',
            draft.reminder,
            demoReminders,
            (value) => draft.reminder = value,
          ),
          if (widget.demo.permission == 'Ditolak' &&
              draft.reminder != demoReminders.first)
            const PreviewNotice(
              title: 'Notifikasi perangkat belum aktif',
              message: 'Pengingat dapat dilihat di Home pada pratinjau.',
              warning: true,
            ),
          PreviewField(
            label: 'Estimasi pekerjaan',
            value: draft.estimate == null
                ? 'Atur estimasi menit'
                : '${draft.estimate} menit',
            onTap: () async {
              final value = await demoNumber(
                context,
                'Estimasi pekerjaan (menit)',
                value: draft.estimate,
              );
              if (mounted && value != null) {
                setState(() => draft.estimate = value);
              }
            },
          ),
          if (draft.slots.isEmpty)
            const PreviewNotice(
              title: 'Sesi pengerjaan',
              message: 'Simpan tugas untuk menambah sesi atau mencari slot.',
            )
          else
            DemoFacts([
              for (final slot in draft.slots)
                (
                  slot.history ? 'Riwayat' : 'Sesi mendatang',
                  demoSlotLabel(slot),
                ),
            ]),
        ] else
          Text('Zona asal deadline · ${draft.zone}', style: NeoType.caption),
      ]),
    ),
  );

  Widget _select(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> update,
  ) => PreviewField(
    label: label,
    value: value,
    onTap: () => demoPick(
      context,
      label,
      options,
      (value) => setState(() => update(value)),
    ),
  );
}

Future<void> demoManualSlot(
  BuildContext context,
  DemoSession demo,
  DemoTask task,
) async {
  final day = await pickPreviewDate(context, demo.today);
  if (!context.mounted || day == null) return;
  final time = await pickPreviewTime(context);
  if (!context.mounted || time == null) return;
  final minutes = await demoNumber(
    context,
    'Durasi sesi (menit)',
    min: 5,
    max: 720,
  );
  if (!context.mounted || minutes == null) return;
  final slot = DemoSlot(dateOnly(day).add(Duration(minutes: time)), minutes);
  final warnings = previewWarnings(
    demo.planner,
    PreviewEvent(
      id: '',
      title: task.title,
      start: slot.start,
      end: slot.end,
      kind: PreviewKind.session,
    ),
  );
  final issues = [
    ...warnings.map(warningTitle),
    if (slot.start.isBefore(demo.today)) 'Sesi berada pada tanggal lampau.',
    if (task.deadline?.isBefore(slot.end) == true)
      'Sesi berakhir setelah deadline tugas.',
  ];
  final confirmed = await showNeoDialog(
    context,
    title: 'Simpan sesi manual?',
    message: [demoSlotLabel(slot), ...issues].join('\n'),
    confirmLabel: 'Simpan sesi',
    danger: issues.isNotEmpty,
  );
  if (context.mounted && confirmed == true) demo.applySlots(task, [slot]);
}
