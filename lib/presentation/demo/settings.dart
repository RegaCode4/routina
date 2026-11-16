import 'package:flutter/material.dart';
import 'package:routina/domain/preview_event.dart';
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

Future<bool> _saveProfile(
  BuildContext context,
  DemoSession demo,
  PreviewProfile profile,
) async {
  try {
    await demo.planner.saveProfile(profile);
  } catch (_) {
    if (context.mounted) demoFeedback(context, 'Profil belum dapat disimpan.');
    return false;
  }
  if (context.mounted) demo.change(() {});
  return true;
}

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
              );
              if (!context.mounted || name == null) return;
              final saved = await _saveProfile(
                context,
                demo,
                PreviewProfile(
                  name: name,
                  activeHours: profile.activeHours,
                  study: profile.study,
                  workout: profile.workout,
                  sundayFirst: profile.sundayFirst,
                  notifications: profile.notifications,
                ),
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
            subtitle: 'Atur cara minggu dan slot tampil di pratinjau.',
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
              final saved = await _saveProfile(
                context,
                demo,
                PreviewProfile(
                  name: profile.name,
                  activeHours: profile.activeHours,
                  study: profile.study,
                  workout: profile.workout,
                  sundayFirst: next == 'Minggu',
                  notifications: profile.notifications,
                ),
              );
              if (context.mounted && saved) {
                demoFeedback(context, 'Awal minggu diubah.');
              }
            },
          ),
          PreviewField(
            label: 'Zona waktu',
            value: demo.zone,
            onTap: () async {
              final next = await previewChoices(
                context,
                'Zona waktu kalender',
                [
                  'Pertahankan zona asal (WIB)',
                  'Ikuti zona perangkat',
                  'WITA',
                  'WIT',
                ],
                (value) => value,
              );
              if (!context.mounted || next == null || next == demo.zone) return;
              final approved = await showNeoDialog(
                context,
                title: 'Ubah preferensi zona?',
                message:
                    'Pilihan ini berlaku pada tampilan pengaturan pratinjau.',
                confirmLabel: 'Ubah preferensi',
              );
              if (context.mounted && approved == true) {
                demo.change(() {
                  demo.zone = next;
                  demo.revision++;
                });
                demoFeedback(context, 'Preferensi zona waktu diubah.');
              }
            },
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
              if (context.mounted && minutes != null) {
                demo.change(() {
                  demo.buffer = minutes;
                  demo.revision++;
                });
                demoFeedback(context, 'Buffer contoh diubah.');
              }
            },
          ),
        ]),
      );
    },
  );
}

class DemoNotifications extends StatelessWidget {
  const DemoNotifications(this.demo, {super.key});
  final DemoSession demo;

  Future<bool> _global(BuildContext context, bool enabled) {
    final profile = demo.planner.profile!;
    return _saveProfile(
      context,
      demo,
      PreviewProfile(
        name: profile.name,
        activeHours: profile.activeHours,
        study: profile.study,
        workout: profile.workout,
        sundayFirst: profile.sundayFirst,
        notifications: enabled,
      ),
    );
  }

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
    demo.change(() {
      if (start) {
        demo.quietStart = value;
      } else {
        demo.quietEnd = value;
      }
    });
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
          value:
              demo.permission == 'Diizinkan' &&
              demo.planner.profile!.notifications,
          onChanged: demo.permission == 'Diizinkan'
              ? (value) => _global(context, value)
              : null,
        ),
        const Text('Jenis pengingat', style: NeoType.section),
        NeoCard(
          child: Column(
            children: [
              for (final entry in demo.notificationTypes.entries)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.key),
                  value: entry.value,
                  onChanged: (value) => demo.change(
                    () => demo.notificationTypes[entry.key] = value,
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
            onChanged: (value) => demo.change(() => demo.quiet = value),
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
            value: demo.quietExceptions,
            onChanged: (value) =>
                demo.change(() => demo.quietExceptions = value),
          ),
          if (demo.quietExceptions)
            for (final type in demo.notificationTypes.keys)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(type),
                value: demo.quietAllowed.contains(type),
                onChanged: (value) => demo.change(() {
                  if (value == true) {
                    demo.quietAllowed.add(type);
                  } else {
                    demo.quietAllowed.remove(type);
                  }
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

  Future<void> _edit(BuildContext context, [DemoCategory? item]) async {
    final saved = await openDemo<bool>(context, _CategoryEditor(demo, item));
    if (context.mounted && saved == true) {
      demoFeedback(context, 'Kategori disimpan.');
    }
  }

  Future<void> _delete(BuildContext context, DemoCategory item) async {
    final choices = [
      'Tanpa kategori',
      ...demo.categoryNames.where((name) => name != item.name),
    ];
    final picked = await demoSheet<String>(
      context,
      'Hapus kategori ${item.name}?',
      (sheet) => [
        for (final choice in choices)
          NeoButton(
            label: choice == 'Tanpa kategori'
                ? 'Jadikan Tanpa Kategori'
                : 'Pindahkan ke $choice',
            variant: NeoButtonVariant.secondary,
            onPressed: () => Navigator.pop(sheet, choice),
          ),
        NeoButton(
          label: 'Batal',
          variant: NeoButtonVariant.secondary,
          onPressed: () => Navigator.pop(sheet),
        ),
      ],
      description:
          'Pilih tujuan kategori untuk semua aktivitas, tugas, dan rutinitas yang menggunakannya.',
    );
    if (!context.mounted || picked == null) return;
    demo.deleteCategory(item, picked);
    demoFeedback(context, 'Kategori dihapus. Item dipindahkan ke $picked.');
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
                icon: demoCategoryIcons[item.icon],
                color: demoCategoryColors[item.color],
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

const demoCategoryIcons = [
  Icons.label_outline,
  Icons.work_outline,
  Icons.school_outlined,
  Icons.favorite_border,
];
const _colorLabels = ['Biru', 'Kuning', 'Koral', 'Hijau'];
const _iconLabels = ['Label', 'Pekerjaan', 'Belajar', 'Favorit'];

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor(this.demo, this.category);
  final DemoSession demo;
  final DemoCategory? category;
  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  final form = GlobalKey<FormState>();
  late String name = widget.category?.name ?? '';
  late int color = widget.category?.color ?? 0;
  late int icon = widget.category?.icon ?? 0;

  void _save() {
    if (!form.currentState!.validate()) return;
    final category = widget.category;
    if (category == null) {
      widget.demo.change(
        () => widget.demo.categories.add(
          DemoCategory(name.trim(), color)..icon = icon,
        ),
      );
    } else {
      category.icon = icon;
      widget.demo.renameCategory(category, name.trim(), color);
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => PreviewPage(
    title: widget.category == null ? 'Tambah kategori' : 'Edit kategori',
    footer: NeoButton(label: 'Simpan kategori', onPressed: _save),
    body: Form(
      key: form,
      child: DemoList([
        NeoFormField(
          label: 'Nama kategori',
          initialValue: name,
          onChanged: (value) => name = value,
          validator: (_) {
            if (name.trim().isEmpty) return 'Isi nama kategori.';
            if (name.trim().toLowerCase() == 'tanpa kategori' ||
                widget.demo.categories.any(
                  (item) =>
                      item != widget.category &&
                      item.name.toLowerCase() == name.trim().toLowerCase(),
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
            for (var i = 0; i < _colorLabels.length; i++)
              CategoryChip(
                label: _colorLabels[i],
                color: demoCategoryColors[i],
                selected: i == color,
                onSelected: (_) => setState(() => color = i),
              ),
          ],
        ),
        const Text('Ikon', style: NeoType.section),
        Wrap(
          spacing: NeoSpace.xs,
          runSpacing: NeoSpace.xxs,
          children: [
            for (var i = 0; i < _iconLabels.length; i++)
              CategoryChip(
                label: _iconLabels[i],
                icon: demoCategoryIcons[i],
                selected: i == icon,
                onSelected: (_) => setState(() => icon = i),
              ),
          ],
        ),
      ]),
    ),
  );
}
