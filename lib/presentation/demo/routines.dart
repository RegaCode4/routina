import 'dart:async';

import 'package:flutter/material.dart';
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

class DemoRoutines extends StatelessWidget {
  const DemoRoutines(this.demo, {super.key});
  final DemoSession demo;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: demo,
    builder: (context, _) {
      final total = demo.routines.length;
      final start = shiftDay(
        demo.today,
        -(demo.planner.profile?.sundayFirst == true
            ? demo.today.weekday % 7
            : demo.today.weekday - 1),
      );
      final end = shiftDay(start, 6);
      final counts = demo.routines
          .where(
            (routine) =>
                routine.progress > 0 ||
                routine.log.any(
                  (item) => !item.day.isBefore(start) && !item.day.isAfter(end),
                ),
          )
          .length;
      final state = demoFeed(demo, 'routines', 'Rutinitas');
      return DemoTab(
        'Rutinitas',
        DemoList(tab: true, [
          DemoHeading(
            'Jaga ritmemu',
            subtitle: 'Minggu ini · ${dateLabel(start)} – ${dateLabel(end)}',
          ),
          if (state != null)
            state
          else if (total == 0)
            PreviewNotice(
              title: 'Belum ada rutinitas',
              message: 'Mulai dengan target durasi, jumlah, atau checklist.',
              button: NeoButton(
                label: 'Tambah rutinitas',
                onPressed: () => openDemo<void>(
                  context,
                  DemoRoutineEditor(demo, DemoRoutine()),
                ),
              ),
            )
          else ...[
            NeoCard(
              tone: NeoCardTone.yellow,
              emphasis: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Progres minggu ini', style: NeoType.item),
                  Text('$counts/$total', style: NeoType.display),
                  const Text(
                    'Rutinitas dengan catatan minggu ini',
                    style: NeoType.caption,
                  ),
                  const SizedBox(height: NeoSpace.sm),
                  NeoProgressBar(
                    value: counts / total,
                    label: 'Progres minggu ini',
                  ),
                ],
              ),
            ),
            const Text('Rutinitas aktif', style: NeoType.section),
            for (final routine in demo.routines)
              RoutineCard(
                title: routine.title,
                target:
                    '${routine.target} ${routine.type.unit} · ${routine.frequency}',
                actual: '${routine.progress} ${routine.type.unit}',
                progress: routine.target == 0
                    ? null
                    : (routine.progress / routine.target).clamp(0, 1),
                timer: routine.timer.isRunning
                    ? 'Timer berjalan'
                    : routine.timerOpened
                    ? 'Timer dijeda'
                    : null,
                status: routine.completed
                    ? NeoStatus.completed
                    : demo.scenario == 'routine-missed' &&
                          routine.id == 'sample-water' &&
                          routine.progress == 0
                    ? NeoStatus.missed
                    : NeoStatus.active,
                onTap: () => openDemo<void>(
                  context,
                  DemoRoutineDetail(demo, routine.id),
                ),
              ),
            NeoButton(
              label: 'Riwayat',
              variant: NeoButtonVariant.secondary,
              onPressed: () =>
                  openDemo<void>(context, _RoutineHistory(demo.routines)),
            ),
          ],
        ]),
      );
    },
  );
}

class DemoRoutineEditor extends StatefulWidget {
  const DemoRoutineEditor(
    this.demo,
    this.draft, {
    this.full = false,
    super.key,
  });
  final DemoSession demo;
  final DemoRoutine draft;
  final bool full;
  @override
  State<DemoRoutineEditor> createState() => _DemoRoutineEditorState();
}

class _DemoRoutineEditorState extends State<DemoRoutineEditor> {
  late final draft = widget.draft;
  late bool full = widget.full;
  late bool typeChosen = draft.id.isNotEmpty;
  late bool frequencyChosen = draft.id.isNotEmpty;
  final form = GlobalKey<FormState>();
  String? error;

  void _save() {
    if (!form.currentState!.validate()) return;
    if (!typeChosen || !frequencyChosen) {
      setState(() => error = 'Pilih jenis target dan frekuensi.');
      return;
    }
    if (draft.target < 1) {
      setState(() {
        full = true;
        error = 'Isi target atau tambahkan minimal satu item checklist.';
      });
      return;
    }
    draft.title = draft.title.trim();
    widget.demo.saveRoutine(draft);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PreviewPage(
    title: full
        ? (draft.id.isEmpty ? 'Form lengkap rutinitas' : 'Edit rutinitas')
        : 'Tambah rutinitas',
    footer: DemoActions([
      NeoButton(label: 'Simpan rutinitas', onPressed: _save),
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
          full ? 'Rancang ritmemu' : 'Quick Add',
          subtitle:
              'Tentukan target yang bisa kamu catat setiap kali menjalankannya.',
        ),
        NeoFormField(
          label: 'Nama rutinitas',
          hint: 'Contoh: Belajar Flutter',
          labelAbove: true,
          initialValue: draft.title,
          onChanged: (value) => draft.title = value,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Isi nama rutinitas.'
              : null,
        ),
        PreviewField(
          label: 'Jenis target',
          value: typeChosen ? draft.type.label : 'Pilih jenis target',
          onTap: () async {
            final type = await previewChoices(
              context,
              'Jenis target',
              DemoRoutineType.values,
              (type) => type.label,
            );
            if (mounted && type != null) {
              setState(() {
                if (draft.type != type) {
                  draft.actual = 0;
                  draft.completed = false;
                }
                draft.type = type;
                typeChosen = true;
                error = null;
                if (type == DemoRoutineType.checklist) full = true;
              });
            }
          },
        ),
        _choice(
          'Frekuensi',
          frequencyChosen ? draft.frequency : 'Pilih frekuensi',
          ['Setiap hari', 'Hari kerja', 'Akhir pekan', 'Mingguan'],
          (value) {
            draft.frequency = value;
            frequencyChosen = true;
            error = null;
          },
        ),
        if (full) ...[
          if (draft.type == DemoRoutineType.checklist) ...[
            for (final name in draft.checklist.keys)
              DemoRow(
                name,
                icon: Icons.checklist,
                onTap: () => setState(() => draft.checklist.remove(name)),
              ),
            NeoButton(
              label: 'Tambah item checklist',
              variant: NeoButtonVariant.secondary,
              onPressed: () async {
                final name = await demoText(
                  context,
                  'Tambah item',
                  'Nama item',
                );
                if (mounted && name != null) {
                  setState(() {
                    draft.checklist.putIfAbsent(name, () => false);
                    error = null;
                  });
                }
              },
            ),
          ] else
            PreviewField(
              label: 'Target ${draft.type.label.toLowerCase()}',
              value: '${draft.goal} ${draft.type.unit}',
              onTap: () async {
                final value = await demoNumber(
                  context,
                  'Target (${draft.type.unit})',
                  value: draft.goal,
                );
                if (mounted && value != null) {
                  setState(() {
                    draft.goal = value;
                    error = null;
                  });
                }
              },
            ),
          _choice('Preferensi waktu', draft.schedule, [
            'Pagi',
            'Siang',
            'Sore',
            'Malam',
            'Bebas',
          ], (value) => draft.schedule = value),
          _choice('Kategori', draft.category, [
            ...widget.demo.categoryNames,
            'Tanpa kategori',
          ], (value) => draft.category = value),
          _choice(
            'Pengingat',
            draft.reminder,
            demoReminders,
            (value) => draft.reminder = value,
          ),
        ] else
          const Text(
            'Nilai target dan preferensi waktu dapat diatur di Form Lengkap.',
          ),
        if (error case final message?)
          Text(message, style: const TextStyle(color: NeoColors.errorText)),
      ]),
    ),
  );

  Widget _choice(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> change,
  ) => PreviewField(
    label: label,
    value: value,
    onTap: () => demoPick(
      context,
      label,
      options,
      (value) => setState(() => change(value)),
    ),
  );
}

class DemoRoutineDetail extends StatefulWidget {
  const DemoRoutineDetail(this.demo, this.id, {super.key});
  final DemoSession demo;
  final String id;
  @override
  State<DemoRoutineDetail> createState() => _DemoRoutineDetailState();
}

class _DemoRoutineDetailState extends State<DemoRoutineDetail> {
  Timer? ticker;
  AppLifecycleListener? lifecycle;
  bool restored = false;
  late final demo = widget.demo;
  DemoRoutine? get routine =>
      demo.routines.where((item) => item.id == widget.id).firstOrNull;

  @override
  void initState() {
    super.initState();
    restored = routine?.timerOpened == true;
    lifecycle = AppLifecycleListener(
      onResume: () {
        if (routine?.timerOpened == true && mounted) {
          setState(() => restored = true);
        }
      },
    );
    _watch();
  }

  void _watch() {
    ticker?.cancel();
    if (routine?.timer.isRunning == true) {
      ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (routine?.timer.isRunning == true && mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    lifecycle?.dispose();
    ticker?.cancel();
    super.dispose();
  }

  Future<void> _manual(DemoRoutine item) async {
    final value = await demoNumber(
      context,
      'Catat aktual (${item.type.unit})',
      min: 0,
      value: item.actual,
    );
    if (mounted && value != null) demo.change(() => item.actual = value);
  }

  Future<void> _stop(DemoRoutine item) async {
    final accepted = await showNeoDialog(
      context,
      title: 'Akhiri timer?',
      message: 'Menit penuh dari timer ditambahkan ke durasi aktual.',
      confirmLabel: 'Simpan durasi',
    );
    if (!mounted || accepted != true) return;
    demo.change(() {
      item.timer.stop();
      item.actual += item.timer.elapsed.inMinutes;
      item.timer.reset();
      item.timerOpened = false;
    });
    _watch();
    setState(() => restored = false);
  }

  Future<void> _complete(DemoRoutine item) async {
    final accepted = await showNeoDialog(
      context,
      title: 'Tandai rutinitas selesai?',
      message:
          'Progres ${item.progress} ${item.type.unit} akan dicatat di riwayat hari ini.',
      confirmLabel: 'Tandai selesai',
    );
    if (!mounted || accepted != true) return;
    demo.completeRoutine(item);
  }

  Future<void> _more(DemoRoutine item) async {
    final action = await previewChoices(context, 'Tindakan rutinitas', [
      'Edit rutinitas',
      'Pindah ke Tempat Sampah',
    ], (value) => value);
    if (!mounted) return;
    if (action == 'Edit rutinitas') {
      await openDemo<void>(
        context,
        DemoRoutineEditor(demo, item.copy(), full: true),
      );
      return;
    }
    if (action == 'Pindah ke Tempat Sampah') {
      final answer = await showNeoDialog(
        context,
        title: 'Pindahkan rutinitas?',
        message: 'Riwayat contoh dapat dipulihkan dari Tempat Sampah.',
        confirmLabel: 'Pindahkan',
        danger: true,
      );
      if (mounted && answer == true) {
        Navigator.pop(context);
        demo.discardRoutine(item);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: demo,
    builder: (context, _) {
      final item = routine;
      if (item == null) {
        return const PreviewPage(
          title: 'Detail rutinitas',
          body: DemoList([Text('Rutinitas tidak tersedia.')]),
        );
      }
      final reached = item.target > 0 && item.progress >= item.target;
      final elapsed = item.timer.elapsed;
      final display = [
        elapsed.inHours,
        elapsed.inMinutes % 60,
        elapsed.inSeconds % 60,
      ].map((value) => value.toString().padLeft(2, '0')).join(':');
      return PreviewPage(
        title: 'Detail rutinitas',
        action: NeoIconButton(
          icon: Icons.more_horiz,
          label: 'Tindakan rutinitas',
          onPressed: () => _more(item),
        ),
        footer: item.completed
            ? null
            : NeoButton(
                label: 'Tandai Rutinitas Selesai',
                onPressed: item.timerOpened ? null : () => _complete(item),
              ),
        body: DemoList([
          DemoHeading(
            item.title,
            subtitle: '${item.frequency} · ${item.category}',
          ),
          Wrap(
            spacing: NeoSpace.xs,
            runSpacing: NeoSpace.xxs,
            children: [
              StatusBadge(
                status: item.completed ? NeoStatus.completed : NeoStatus.active,
              ),
              if (reached)
                const CategoryChip(
                  label: 'Target tercapai',
                  icon: Icons.flag_outlined,
                ),
            ],
          ),
          if (item.type == DemoRoutineType.duration) ...[
            NeoCard(
              tone: NeoCardTone.yellow,
              emphasis: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.timer.isRunning
                        ? 'Timer berjalan'
                        : item.timerOpened
                        ? 'Timer dijeda'
                        : 'Timer fokus',
                    style: NeoType.item,
                  ),
                  const SizedBox(height: NeoSpace.md),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      display,
                      style: NeoType.metric.copyWith(fontSize: 42),
                      semanticsLabel:
                          '${elapsed.inMinutes} menit ${elapsed.inSeconds % 60} detik',
                    ),
                  ),
                  const SizedBox(height: NeoSpace.sm),
                  if (restored)
                    const Text(
                      'Timer dipulihkan dalam sesi pratinjau ini.',
                      style: NeoType.caption,
                    ),
                  NeoProgressBar(
                    value: item.target == 0
                        ? 0
                        : (item.progress / item.target).clamp(0, 1),
                    label: 'Progres rutinitas',
                  ),
                  const SizedBox(height: NeoSpace.xs),
                  Text(
                    'Target ${item.target} menit · ${item.progress} menit aktual',
                    style: NeoType.caption,
                  ),
                ],
              ),
            ),
            if (item.log.isNotEmpty)
              DemoRow(
                'Riwayat aktivitas',
                icon: Icons.calendar_today_outlined,
                subtitle: '${item.log.first.value} menit tercatat',
                onTap: () => openDemo<void>(context, _RoutineHistory([item])),
              ),
            if (!item.completed)
              NeoButton(
                label: item.timer.isRunning
                    ? 'Jeda'
                    : item.timerOpened
                    ? 'Lanjutkan'
                    : 'Mulai timer',
                onPressed: () {
                  demo.change(() {
                    item.timerOpened = true;
                    if (item.timer.isRunning) {
                      item.timer.stop();
                    } else {
                      item.timer.start();
                    }
                  });
                  _watch();
                },
              ),
            if (item.timerOpened)
              NeoButton(
                label: 'Akhiri timer',
                variant: NeoButtonVariant.secondary,
                onPressed: () => _stop(item),
              ),
          ] else ...[
            DemoFacts([
              ('Target', '${item.target} ${item.type.unit}'),
              ('Progres aktual', '${item.progress} ${item.type.unit}'),
            ]),
            if (item.target > 0)
              NeoProgressBar(
                value: (item.progress / item.target).clamp(0, 1),
                label: 'Progres rutinitas',
              ),
          ],
          if (item.type == DemoRoutineType.checklist)
            NeoCard(
              child: Column(
                children: [
                  for (final line in item.checklist.entries)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(line.key),
                      value: line.value,
                      onChanged: item.completed
                          ? null
                          : (value) => demo.change(
                              () => item.checklist[line.key] = value!,
                            ),
                    ),
                ],
              ),
            )
          else if (!item.completed)
            NeoButton(
              label: 'Catat manual',
              variant: NeoButtonVariant.secondary,
              onPressed: () => _manual(item),
            ),
          const Text('Riwayat', style: NeoType.section),
          if (item.log.isEmpty) const Text('Belum ada catatan rutinitas.'),
          for (final entry in item.log.take(3))
            DemoFacts([
              (dateLabel(entry.day), '${entry.value} ${item.type.unit}'),
            ]),
          if (item.log.isNotEmpty)
            NeoButton(
              label: 'Lihat riwayat',
              variant: NeoButtonVariant.secondary,
              onPressed: () => openDemo<void>(context, _RoutineHistory([item])),
            ),
        ]),
      );
    },
  );
}

class _RoutineHistory extends StatelessWidget {
  const _RoutineHistory(this.routines);
  final List<DemoRoutine> routines;
  @override
  Widget build(BuildContext context) {
    final records = [
      for (final routine in routines)
        for (final item in routine.log)
          (routine: routine, day: item.day, value: item.value),
    ]..sort((first, second) => second.day.compareTo(first.day));
    return PreviewPage(
      title: 'Riwayat rutinitas',
      body: DemoList([
        if (records.isEmpty)
          const PreviewNotice(
            title: 'Belum ada riwayat',
            message: 'Catatan tampil setelah rutinitas ditandai selesai.',
          ),
        for (final item in records)
          DemoFacts([
            (dateLabel(item.day), item.routine.title),
            ('Aktual', '${item.value} ${item.routine.type.unit}'),
          ]),
      ]),
    );
  }
}
