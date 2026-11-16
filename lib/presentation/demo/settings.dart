import 'package:flutter/material.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';
import 'package:routina/presentation/design_system/neo_badges.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_form_field.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/preview_ui.dart';
import 'package:routina/presentation/planner/setup_screens.dart';

import 'package:routina/presentation/demo/backup.dart';
import 'package:routina/presentation/demo/demo_session.dart';
import 'package:routina/presentation/demo/demo_widgets.dart';
import 'package:routina/presentation/demo/statistics.dart';
import 'package:routina/presentation/demo/trash.dart';

class DemoProfile extends StatelessWidget {
  const DemoProfile(this.demo, {super.key});
  final DemoSession demo;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: demo,
    builder: (context, _) {
      final profile = demo.planner.profile!;
      return DemoTab(
        'Profil',
        DemoList(tab: true, [
          NeoCard(
            tone: NeoCardTone.selected,
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: NeoColors.yellow,
                  foregroundColor: NeoColors.ink,
                  radius: 25,
                  child: Icon(Icons.person_outline),
                ),
                const SizedBox(width: NeoSpace.sm),
                Expanded(
                  child: DemoHeading(
                    profile.name.isEmpty ? 'Profil lokal' : profile.name,
                    subtitle: profile.name.isEmpty
                        ? 'Nama tampilan belum diisi.'
                        : 'Preferensi Routina',
                  ),
                ),
              ],
            ),
          ),
          if (demo.permission == 'Ditolak')
            PreviewNotice(
              title: 'Notifikasi perangkat belum aktif',
              message: 'Pengingat tetap dapat dilihat di Home.',
              warning: true,
              button: NeoButton(
                label: 'Buka pengaturan notifikasi',
                onPressed: () =>
                    openDemo<void>(context, DemoNotifications(demo)),
              ),
            ),
          if (demo.scenario == 'backup-due' && demo.lastBackup == null)
            const PreviewNotice(
              title: 'Waktunya membuat backup',
              message: 'Buka Backup & Restore untuk melihat ringkasan.',
            ),
          DemoRow(
            'Edit profil',
            icon: Icons.badge_outlined,
            subtitle: 'Nama tampilan',
            onTap: () async {
              final name = await demoText(
                context,
                'Edit profil',
                'Nama tampilan',
                initial: profile.name,
                requiredInput: false,
              );
              if (!context.mounted || name == null) return;
              final saved = await saveDemoProfile(
                context,
                demo,
                (profile) => profile.copyWith(name: name),
              );
              if (context.mounted && saved) {
                demoFeedback(context, 'Profil disimpan.');
              }
            },
          ),
          DemoRow(
            'Jam aktif & preferensi',
            icon: Icons.schedule,
            subtitle: 'Jam per hari, belajar, dan workout',
            onTap: () async {
              final saved = await openDemo<bool>(
                context,
                PlannerActiveHours(
                  repository: demo.planner,
                  name: profile.name,
                  settings: true,
                ),
              );
              if (context.mounted && saved == true) {
                demo.change(() => demo.revision++);
                demoFeedback(context, 'Jam aktif disimpan.');
              }
            },
          ),
          DemoRow(
            'Kalender & zona waktu',
            icon: Icons.calendar_today_outlined,
            subtitle: 'Awal minggu, zona waktu, dan buffer',
            onTap: () => openDemo<void>(context, _CalendarSettings(demo)),
          ),
          DemoRow(
            'Notifikasi & Quiet Hours',
            icon: Icons.notifications_outlined,
            subtitle: 'Izin, jenis, dan waktu senyap',
            onTap: () => openDemo<void>(context, DemoNotifications(demo)),
          ),
          DemoRow(
            'Kategori',
            icon: Icons.label_outline,
            subtitle: 'Kelola kategori bersama',
            onTap: () => openDemo<void>(context, _Categories(demo)),
          ),
          DemoRow(
            'Backup & Restore',
            icon: Icons.folder_outlined,
            subtitle: 'Ekspor, pulihkan, dan pengingat',
            onTap: () => openDemo<void>(context, DemoBackup(demo)),
          ),
          DemoRow(
            'Tempat Sampah',
            icon: Icons.delete_outline,
            subtitle: 'Pulihkan atau hapus item',
            onTap: () => openDemo<void>(context, DemoTrashScreen(demo)),
          ),
          DemoRow(
            'Statistik',
            icon: Icons.bar_chart,
            onTap: () => openDemo<void>(
              context,
              DemoStatistics(demo),
              route: '/statistik',
            ),
          ),
        ]),
      );
    },
  );
}

class _CalendarSettings extends StatelessWidget {
  const _CalendarSettings(this.demo);
  final DemoSession demo;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: demo,
    builder: (context, _) {
      final profile = demo.planner.profile!;
      return PreviewPage(
        title: 'Kalender & zona waktu',
        body: DemoList([
          const DemoHeading(
            'Sesuaikan kalender',
            subtitle:
                'Pilih awal minggu, zona tampilan, dan mode waktu aktivitas.',
          ),
          PreviewField(
            label: 'Awal minggu',
            value: profile.sundayFirst ? 'Minggu' : 'Senin',
            onTap: () async {
              final next = await previewChoices(context, 'Awal minggu', [
                'Senin',
                'Minggu',
              ], (value) => value);
              if (!context.mounted ||
                  next == null ||
                  (next == 'Minggu') == profile.sundayFirst) {
                return;
              }
              final approved = await showNeoDialog(
                context,
                title: 'Ubah awal minggu?',
                message:
                    'Kalender dan agregat statistik mingguan akan dihitung ulang.',
                confirmLabel: 'Ubah awal minggu',
              );
              if (!context.mounted || approved != true) return;
              final saved = await saveDemoProfile(
                context,
                demo,
                (profile) => profile.copyWith(sundayFirst: next == 'Minggu'),
              );
              if (context.mounted && saved) {
                demoFeedback(context, 'Awal minggu diubah.');
              }
            },
          ),
          PreviewField(
            label: 'Zona waktu tampilan',
            value: profile.preferences.calendarZoneId ?? 'Ikuti zona perangkat',
            onTap: () async {
              final next =
                  await previewChoices(context, 'Zona waktu tampilan', [
                    'Ikuti zona perangkat',
                    'Asia/Jakarta',
                    'Asia/Makassar',
                    'Asia/Jayapura',
                  ], (value) => value);
              if (!context.mounted || next == null) return;
              final zoneId = next == 'Ikuti zona perangkat' ? null : next;
              if (zoneId == profile.preferences.calendarZoneId) return;
              final approved = await showNeoDialog(
                context,
                title: 'Ubah preferensi zona?',
                message:
                    'Zona tampilan disimpan sebagai preferensi. Deadline dengan mode zona asal tetap memakai zona tersimpan.',
                confirmLabel: 'Ubah preferensi',
              );
              if (!context.mounted || approved != true) return;
              final saved = await saveDemoProfile(
                context,
                demo,
                (profile) => profile.copyWith(
                  preferences: profile.preferences.copyWith(
                    calendarZoneId: zoneId,
                    useDeviceZone: zoneId == null,
                  ),
                ),
              );
              if (context.mounted && saved) {
                demoFeedback(context, 'Preferensi zona waktu diubah.');
              }
            },
          ),
          _modeField(
            context,
            'Mode waktu kegiatan',
            profile.preferences.eventTimeMode,
            (prefs, value) => prefs.copyWith(eventTimeMode: value),
          ),
          _modeField(
            context,
            'Mode waktu rutinitas',
            profile.preferences.routineTimeMode,
            (prefs, value) => prefs.copyWith(routineTimeMode: value),
          ),
          _modeField(
            context,
            'Mode waktu deadline',
            profile.preferences.deadlineTimeMode,
            (prefs, value) => prefs.copyWith(deadlineTimeMode: value),
          ),
          PreviewField(
            label: 'Buffer default',
            value: '${demo.buffer} menit',
            onTap: () async {
              final minutes = await demoNumber(
                context,
                'Buffer default (menit)',
                value: demo.buffer,
                min: 0,
                max: 120,
              );
              if (!context.mounted || minutes == null) return;
              final saved = await saveDemoProfile(
                context,
                demo,
                (profile) =>
                    profile.copyWith(defaultBuffer: Duration(minutes: minutes)),
              );
              if (context.mounted && saved) {
                demoFeedback(context, 'Buffer diubah.');
              }
            },
          ),
        ]),
      );
    },
  );

  Widget _modeField(
    BuildContext context,
    String label,
    TimeMode active,
    PlannerPreferences Function(PlannerPreferences, TimeMode) update,
  ) => PreviewField(
    label: label,
    value: timeModeLabel(active),
    onTap: () async {
      final picked = await previewChoices(
        context,
        label,
        TimeMode.values,
        timeModeLabel,
      );
      if (!context.mounted || picked == null || active == picked) return;
      await saveDemoProfile(
        context,
        demo,
        (profile) =>
            profile.copyWith(preferences: update(profile.preferences, picked)),
      );
    },
  );
}

class DemoNotifications extends StatelessWidget {
  const DemoNotifications(this.demo, {super.key});
  final DemoSession demo;

  static const _reminderLabels = {
    ReminderKind.event: 'Kegiatan',
    ReminderKind.deadline: 'Tenggat tugas',
    ReminderKind.workSession: 'Sesi pengerjaan',
    ReminderKind.routine: 'Rutinitas',
  };

  Future<bool> _global(BuildContext context, bool enabled) => saveDemoProfile(
    context,
    demo,
    (profile) => profile.copyWith(notifications: enabled),
  );

  Future<bool> _preferences(
    BuildContext context,
    PlannerPreferences Function(PlannerPreferences) update,
  ) => saveDemoProfile(
    context,
    demo,
    (profile) => profile.copyWith(preferences: update(profile.preferences)),
  );

  Future<void> _permission(BuildContext context) async {
    final result = await demoSheet<String>(
      context,
      demo.permission == 'Ditolak'
          ? 'Izin notifikasi ditolak'
          : 'Izin notifikasi perangkat',
      (sheet) => [
        NeoButton(
          label: 'Izinkan pada simulasi',
          onPressed: () => Navigator.pop(sheet, 'Diizinkan'),
        ),
        NeoButton(
          label: 'Tolak pada simulasi',
          variant: NeoButtonVariant.secondary,
          onPressed: () => Navigator.pop(sheet, 'Ditolak'),
        ),
        NeoButton(
          label: 'Batal',
          variant: NeoButtonVariant.secondary,
          onPressed: () => Navigator.pop(sheet),
        ),
      ],
      description:
          'Pengingat bisa dilihat di Home. Kelola izin perangkat di pengaturan sistem saat fitur terhubung.',
    );
    if (!context.mounted || result == null) return;
    final saved = await _global(context, result == 'Diizinkan');
    if (context.mounted && saved) demo.change(() => demo.permission = result);
  }

  Future<void> _quietTime(BuildContext context, {required bool start}) async {
    final value = await pickPreviewTime(
      context,
      initial: start ? demo.quietStart : demo.quietEnd,
    );
    if (!context.mounted || value == null) return;
    if (value == (start ? demo.quietEnd : demo.quietStart)) {
      demoFeedback(context, 'Jam mulai dan berakhir harus berbeda.');
      return;
    }
    await saveDemoProfile(
      context,
      demo,
      (profile) => profile.copyWith(
        quietHours: (
          startMinute: start
              ? value
              : profile.quietHours?.startMinute ?? demo.quietStart,
          endMinute: start
              ? profile.quietHours?.endMinute ?? demo.quietEnd
              : value,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: demo,
    builder: (context, _) => PreviewPage(
      title: 'Notifikasi',
      body: DemoList([
        const DemoHeading(
          'Atur pengingat',
          subtitle: 'Izin perangkat dan waktu senyap.',
        ),
        PreviewNotice(
          title: 'Izin · ${demo.permission}',
          message: demo.permission == 'Diizinkan'
              ? 'Focus atau Jangan Ganggu dapat menahan pengingat.'
              : 'Pengingat tetap dapat dilihat di Home.',
          warning: demo.permission == 'Ditolak',
          button: demo.permission == 'Diizinkan'
              ? null
              : NeoButton(
                  label: demo.permission == 'Ditolak'
                      ? 'Buka Pengaturan Sistem'
                      : 'Minta izin',
                  onPressed: () => _permission(context),
                ),
        ),
        if (demo.scenario == 'notifications-error' &&
            !demo.dismissedFeeds.contains('notifications'))
          PreviewNotice(
            title: 'Pengingat gagal dijadwalkan',
            message: 'Coba lagi pada pratinjau.',
            warning: true,
            button: NeoButton(
              label: 'Coba lagi',
              onPressed: () => demo.retry('notifications'),
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pengingat global'),
          subtitle: const Text('Preferensi lokal pengingat.'),
          value: demo.planner.profile!.notifications,
          onChanged: (value) => _global(context, value),
        ),
        const Text('Jenis pengingat', style: NeoType.section),
        NeoCard(
          child: Column(
            children: [
              for (final entry in _reminderLabels.entries)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value),
                  value: demo.preferences.reminderTypes[entry.key] ?? true,
                  onChanged: (value) => _preferences(
                    context,
                    (prefs) => prefs.copyWith(
                      reminderTypes: {...prefs.reminderTypes, entry.key: value},
                    ),
                  ),
                ),
            ],
          ),
        ),
        const PreviewNotice(
          title: 'Pengingat per aktivitas',
          message:
              'Atur beberapa pengingat dari form kegiatan. Perubahan pengingat mengikuti konfirmasi di form.',
        ),
        NeoCard(
          tone: NeoCardTone.accent,
          emphasis: true,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Quiet Hours'),
            subtitle: const Text('Waktu senyap pengingat'),
            value: demo.quiet,
            onChanged: (value) => saveDemoProfile(
              context,
              demo,
              (profile) => profile.copyWith(
                preferences: profile.preferences.copyWith(quietEnabled: value),
                quietHours: value
                    ? profile.quietHours ??
                          (
                            startMinute: demo.quietStart,
                            endMinute: demo.quietEnd,
                          )
                    : profile.quietHours,
              ),
            ),
          ),
        ),
        if (demo.quiet) ...[
          PreviewField(
            label: 'Jam mulai',
            value: clockLabel(demo.quietStart),
            icon: Icons.schedule,
            onTap: () => _quietTime(context, start: true),
          ),
          PreviewField(
            label: 'Jam selesai',
            value: clockLabel(demo.quietEnd),
            icon: Icons.schedule,
            onTap: () => _quietTime(context, start: false),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pengecualian per jenis'),
            value: demo.preferences.quietExceptionsEnabled,
            onChanged: (value) => _preferences(
              context,
              (prefs) => prefs.copyWith(quietExceptionsEnabled: value),
            ),
          ),
          if (demo.preferences.quietExceptionsEnabled)
            for (final entry in _reminderLabels.entries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                value: demo.preferences.quietExceptions.contains(entry.key),
                onChanged: (value) => _preferences(context, (prefs) {
                  final exceptions = {...prefs.quietExceptions};
                  if (value == true) {
                    exceptions.add(entry.key);
                  } else {
                    exceptions.remove(entry.key);
                  }
                  return prefs.copyWith(quietExceptions: exceptions);
                }),
              ),
        ],
      ]),
    ),
  );
}

class _Categories extends StatelessWidget {
  const _Categories(this.demo);
  final DemoSession demo;

  Future<void> _edit(BuildContext context, [Category? item]) async {
    final saved = await openDemo<bool>(context, _CategoryEditor(demo, item));
    if (context.mounted && saved == true) {
      demoFeedback(context, 'Kategori disimpan.');
    }
  }

  Future<void> _delete(BuildContext context, Category item) async {
    final choices = [
      null,
      ...demo.categories.where((category) => category.id != item.id),
    ];
    final picked = await demoSheet<({Category? replacement})>(
      context,
      'Hapus kategori ${item.name}?',
      (sheet) => [
        for (final choice in choices)
          NeoButton(
            label: choice == null
                ? 'Jadikan Tanpa Kategori'
                : 'Pindahkan ke ${choice.name}',
            variant: NeoButtonVariant.secondary,
            onPressed: () => Navigator.pop(sheet, (replacement: choice)),
          ),
        NeoButton(
          label: 'Batal',
          variant: NeoButtonVariant.secondary,
          onPressed: () => Navigator.pop(sheet),
        ),
      ],
      description:
          'Kegiatan, tugas, dan rutinitas tetap ada. Pilih kategori tujuan untuk semua item terkait.',
    );
    if (!context.mounted || picked == null) return;
    final destination = picked.replacement?.name ?? 'Tanpa Kategori';
    final approved = await showNeoDialog(
      context,
      title: 'Hapus kategori dan pindahkan item?',
      message: 'Semua item terkait akan dipindahkan ke $destination.',
      confirmLabel: 'Pindahkan dan hapus kategori',
      danger: true,
    );
    if (!context.mounted || approved != true) return;
    try {
      await demo.deleteCategory(item, replacement: picked.replacement);
      if (context.mounted) {
        demoFeedback(
          context,
          'Kategori dihapus. Item dipindahkan ke $destination.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        demoFeedback(context, 'Pemindahan gagal. Coba lagi.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: demo,
    builder: (context, _) {
      final status = demoFeed(demo, 'categories', 'Kategori');
      return PreviewPage(
        title: 'Kategori',
        footer: NeoButton(
          label: 'Tambah kategori',
          icon: Icons.add,
          onPressed: () => _edit(context),
        ),
        body: DemoList([
          const DemoHeading(
            'Kategori bersama',
            subtitle: 'Kategori dipakai pada kegiatan, tugas, dan rutinitas.',
          ),
          if (status != null)
            status
          else if (demo.categories.isEmpty)
            const PreviewNotice(
              title: 'Belum ada kategori',
              message: 'Tambahkan kategori dengan warna dan ikon.',
            )
          else
            for (final item in demo.categories)
              DemoRow(
                item.name,
                icon: _categoryIcons[item.icon]?.$2 ?? Icons.label_outline,
                color: Color(item.color),
                onTap: () async {
                  final action = await previewChoices(context, item.name, [
                    'Edit kategori',
                    'Hapus kategori',
                  ], (value) => value);
                  if (!context.mounted) return;
                  if (action == 'Edit kategori') {
                    await _edit(context, item);
                  } else if (action == 'Hapus kategori') {
                    await _delete(context, item);
                  }
                },
              ),
        ]),
      );
    },
  );
}

const _categoryIcons = {
  'label': ('Label', Icons.label_outline),
  'work': ('Pekerjaan', Icons.work_outline),
  'study': ('Belajar', Icons.school_outlined),
  'favorite': ('Favorit', Icons.favorite_border),
};

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor(this.demo, this.category);
  final DemoSession demo;
  final Category? category;
  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  final form = GlobalKey<FormState>();
  late String name = widget.category?.name ?? '';
  late int color =
      widget.category?.color ?? previewCategoryPalette.values.first;
  late String icon = widget.category?.icon ?? 'label';
  bool saving = false;
  String? error;

  Future<void> _save() async {
    if (saving || !form.currentState!.validate()) return;
    final category = widget.category;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.demo.saveCategory(
        Category(
          category?.metadata ?? RecordMetadata.create(),
          name: name.trim(),
          color: color,
          icon: icon,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Kategori belum dapat disimpan. Coba lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PreviewPage(
    title: widget.category == null ? 'Tambah kategori' : 'Edit kategori',
    footer: NeoButton(
      label: 'Simpan kategori',
      onPressed: saving ? null : _save,
      loading: saving,
    ),
    body: Form(
      key: form,
      child: DemoList([
        NeoFormField(
          label: 'Nama kategori',
          initialValue: name,
          onChanged: (value) => name = value,
          validator: (_) {
            if (name.trim().isEmpty) return 'Isi nama kategori.';
            if (!isCategoryNameAvailable(
              name,
              widget.demo.categories,
              editingId: widget.category?.id,
            )) {
              return 'Nama ini sudah dipakai. Pilih nama lain.';
            }
            return null;
          },
        ),
        const Text('Warna', style: NeoType.section),
        Wrap(
          spacing: NeoSpace.xs,
          runSpacing: NeoSpace.xxs,
          children: [
            for (final choice in previewCategoryPalette.entries)
              CategoryChip(
                label: choice.key,
                color: Color(choice.value),
                selected: choice.value == color,
                onSelected: (_) => setState(() => color = choice.value),
              ),
          ],
        ),
        const Text('Ikon', style: NeoType.section),
        Wrap(
          spacing: NeoSpace.xs,
          runSpacing: NeoSpace.xxs,
          children: [
            for (final choice in _categoryIcons.entries)
              CategoryChip(
                label: choice.value.$1,
                icon: choice.value.$2,
                selected: choice.key == icon,
                onSelected: (_) => setState(() => icon = choice.key),
              ),
          ],
        ),
        if (error case final message?)
          PreviewNotice(
            title: 'Kategori belum disimpan',
            message: message,
            warning: true,
          ),
      ]),
    ),
  );
}
