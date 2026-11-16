import 'package:flutter/material.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/application/routine_workspace.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/presentation/demo/demo_widgets.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_form_field.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

const _cadence = {
  'FREQ=DAILY': 'Setiap hari',
  'FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR': 'Hari kerja',
  'FREQ=DAILY;BYDAY=SA,SU': 'Akhir pekan',
  'FREQ=WEEKLY': 'Mingguan',
};

String routineTypeLabel(RoutineTargetType type) => switch (type) {
  RoutineTargetType.duration => 'Durasi',
  RoutineTargetType.checklist => 'Checklist',
  RoutineTargetType.count => 'Jumlah',
  RoutineTargetType.frequency => 'Mingguan',
};

String routineCadenceLabel(String? rule) => rule == null
    ? 'Pilih frekuensi'
    : _cadence[rule] ?? 'Pengulangan tersimpan';

class RoutineEditor extends StatefulWidget {
  const RoutineEditor({
    required this.repository,
    required this.workspace,
    this.initial,
    this.reminders = const [],
    super.key,
  });

  final PlannerPreviewRepository repository;
  final RoutineWorkspace workspace;
  final Routine? initial;
  final List<ReminderRule> reminders;

  @override
  State<RoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends State<RoutineEditor> {
  Routine? get _original => widget.initial;
  late bool _full = _original != null;
  late String _title = _original?.title ?? '';
  late RoutineTargetType? _type = _original?.targetType;
  late String? _rule = _original?.frequencyRule;
  late String? _category = _original?.categoryId;
  late String? _preferredTime = _original?.preferredTime;
  late TimeMode _mode =
      _original?.timeMode ??
      widget.repository.profile?.preferences.routineTimeMode ??
      TimeMode.localWallTime;
  late final List<String> _checklist = [...?_original?.checklist];
  late int? _minutes = _original?.targetDuration?.inMinutes;
  late int? _quantity = _original?.targetAmount;
  final _form = GlobalKey<FormState>();
  late Set<Duration> _reminders = {
    for (final row in widget.reminders)
      if (row.enabled) row.offset,
  };
  bool _remindersEdited = false;
  bool _busy = false;
  String? _error;

  Future<void> _choose<T>(
    String label,
    List<T> list,
    String Function(T) text,
    ValueChanged<T> apply,
  ) async {
    final value = await previewChoices(context, label, list, text);
    if (mounted && value != null) {
      setState(() {
        apply(value);
        _error = null;
      });
    }
  }

  Future<void> _editItem([int? index]) async {
    final old = index == null ? null : _checklist[index];
    if (old != null) {
      final action = await previewChoices(context, old, [
        'Ubah nama item',
        'Hapus item',
      ], (value) => value);
      if (!mounted || action == null) return;
      if (action == 'Hapus item') {
        setState(() => _checklist.removeAt(index!));
        return;
      }
    }
    final item = await demoText(
      context,
      old == null ? 'Tambah item checklist' : 'Ubah nama item',
      'Nama item',
      initial: old ?? '',
    );
    if (!mounted || item == null) return;
    if (_checklist.asMap().entries.any(
      (row) =>
          row.key != index && row.value.toLowerCase() == item.toLowerCase(),
    )) {
      setState(() => _error = 'Nama item sudah digunakan.');
      return;
    }
    setState(() {
      if (index == null) {
        _checklist.add(item);
      } else {
        _checklist[index] = item;
      }
      _error = null;
    });
  }

  Future<void> _saving() async {
    if (_busy || !_form.currentState!.validate()) return;
    final type = _type;
    if (type == null || (_rule == null && _original == null)) {
      setState(() => _error = 'Pilih jenis target dan frekuensi.');
      return;
    }
    if (_invalid(type)) {
      setState(() {
        _full = true;
        _error = 'Isi nilai target atau tambahkan item checklist.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.workspace.save(
        Routine(
          _original?.metadata ?? RecordMetadata.create(),
          title: _title,
          targetType: type,
          targetAmount: _quantity,
          targetDuration: _minutes == null
              ? null
              : Duration(minutes: _minutes!),
          checklist: _checklist,
          categoryId: _category,
          frequencyRule: _rule,
          preferredTime: _preferredTime,
          timeMode: _mode,
        ),
        reminders: _remindersEdited ? _reminders : null,
      );
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context, saved);
      }
    } on RoutineIssue catch (issue) {
      if (mounted) setState(() => _error = issue.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Rutinitas belum dapat disimpan. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _invalid(RoutineTargetType type) => switch (type) {
    RoutineTargetType.duration =>
      (_minutes ?? 0) <= 0 ||
          Duration(minutes: _minutes!).inMinutes != _minutes,
    RoutineTargetType.checklist => _checklist.isEmpty,
    RoutineTargetType.count ||
    RoutineTargetType.frequency => (_quantity ?? 0) <= 0,
  };

  @override
  Widget build(BuildContext context) {
    final categories = {
      '': 'Tanpa kategori',
      for (final row in widget.repository.categories) row.id: row.name,
    };
    return PreviewPage(
      title: !_full
          ? 'Tambah rutinitas'
          : _original == null
          ? 'Form lengkap rutinitas'
          : 'Edit rutinitas',
      footer: DemoActions([
        NeoButton(
          label: 'Simpan rutinitas',
          loading: _busy,
          onPressed: _busy ? null : _saving,
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
        child: Form(
          key: _form,
          child: DemoList([
            if (!_full)
              const DemoHeading(
                'Quick Add',
                subtitle: 'Tentukan nama, target, dan frekuensi rutinitas.',
              ),
            NeoFormField(
              label: 'Nama rutinitas',
              hint: 'Masukkan nama',
              initialValue: _title,
              labelAbove: true,
              onChanged: (value) => _title = value,
              validator: (value) => value?.trim().isNotEmpty == true
                  ? null
                  : 'Isi nama rutinitas.',
            ),
            PreviewField(
              label: 'Jenis target',
              value: _type == null
                  ? 'Pilih jenis target'
                  : routineTypeLabel(_type!),
              onTap: () => _choose(
                'Jenis target',
                RoutineTargetType.values,
                routineTypeLabel,
                (value) => _type = value,
              ),
            ),
            if (_type == RoutineTargetType.checklist) ...[
              for (final (index, item) in _checklist.indexed)
                PreviewField(
                  label: 'Item ${index + 1}',
                  value: item,
                  icon: Icons.checklist,
                  onTap: () => _editItem(index),
                ),
              NeoButton(
                label: 'Tambah item checklist',
                variant: NeoButtonVariant.secondary,
                onPressed: () => _editItem(),
              ),
            ] else if (_type case final type?)
              NeoFormField(
                key: ValueKey(type),
                label: switch (type) {
                  RoutineTargetType.duration => 'Target durasi (menit)',
                  RoutineTargetType.frequency => 'Target (kali per minggu)',
                  _ => 'Target jumlah',
                },
                initialValue:
                    (type == RoutineTargetType.duration ? _minutes : _quantity)
                        ?.toString(),
                labelAbove: true,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final number = int.tryParse(value.trim());
                  if (type == RoutineTargetType.duration) {
                    _minutes = number;
                  } else {
                    _quantity = number;
                  }
                },
              ),
            PreviewField(
              label: 'Frekuensi',
              value: routineCadenceLabel(_rule),
              icon: Icons.repeat,
              onTap: () => _choose(
                'Frekuensi',
                _cadence.keys.toList(),
                routineCadenceLabel,
                (value) => _rule = value,
              ),
            ),
            if (_full) ...[
              PreviewField(
                label: 'Kategori',
                value: categories[_category] ?? 'Tanpa kategori',
                onTap: () => _choose(
                  'Kategori',
                  categories.keys.toList(),
                  (key) => categories[key]!,
                  (value) => _category = value.isEmpty ? null : value,
                ),
              ),
              const Text('Waktu dan pengingat', style: NeoType.section),
              PreviewField(
                label: 'Preferensi waktu',
                value: _preferredTime ?? 'Bebas',
                icon: Icons.schedule,
                onTap: () => _choose(
                  'Preferensi waktu',
                  ['Bebas', 'Pagi', 'Siang', 'Sore', 'Malam'],
                  (value) => value,
                  (value) => _preferredTime = value == 'Bebas' ? null : value,
                ),
              ),
              PreviewField(
                label: 'Mode waktu',
                value: timeModeLabel(_mode),
                onTap: () => _choose(
                  'Mode waktu',
                  TimeMode.values,
                  timeModeLabel,
                  (value) => _mode = value,
                ),
              ),
              PreviewField(
                label: 'Pengingat lokal',
                value: _reminders.isEmpty
                    ? 'Tanpa pengingat'
                    : _reminders.map((t) => _offset(t.inMinutes)).join(' · '),
                icon: Icons.notifications_outlined,
                onTap: () => _choose(
                  'Pengingat lokal',
                  [-1, 0, 10, 30, 60],
                  _offset,
                  (value) {
                    _reminders = value < 0 ? {} : {Duration(minutes: value)};
                    _remindersEdited = true;
                  },
                ),
              ),
            ],
            if (_error case final error?)
              PreviewNotice(
                title: 'Periksa isian rutinitas',
                message: error,
                warning: true,
              ),
          ]),
        ),
      ),
    );
  }
}

String _offset(int minutes) => switch (minutes) {
  -1 => 'Tanpa pengingat',
  0 => 'Saat mulai',
  _ => '$minutes menit sebelum mulai',
};
