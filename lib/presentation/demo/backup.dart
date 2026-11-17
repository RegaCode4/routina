import 'package:flutter/material.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/design_system/neo_badges.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_form_field.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

import 'package:routina/presentation/demo/demo_session.dart';
import 'package:routina/presentation/demo/demo_widgets.dart';

class DemoBackup extends StatelessWidget {
  const DemoBackup(this.demo, {super.key});
  final DemoSession demo;

  Future<void> _reminder(BuildContext context) async {
    final action = await previewChoices(context, 'Pengingat backup', [
      'Nonaktif',
      '7 hari',
      '14 hari',
      '30 hari',
      'Atur sendiri',
    ], (value) => value);
    if (!context.mounted || action == null) return;
    final days = switch (action) {
      'Nonaktif' => null,
      '7 hari' => 7,
      '14 hari' => 14,
      '30 hari' => 30,
      _ => await demoNumber(
        context,
        'Interval pengingat (hari)',
        min: 1,
        max: 365,
      ),
    };
    if (!context.mounted || (action == 'Atur sendiri' && days == null)) return;
    final saved = await saveDemoProfile(
      context,
      demo,
      (profile) => profile.copyWith(
        preferences: profile.preferences.copyWith(
          backupReminderDays: days,
          disableBackupReminder: days == null,
        ),
      ),
    );
    if (!context.mounted || !saved) return;
    demoFeedback(
      context,
      days == null
          ? 'Pengingat backup dinonaktifkan.'
          : 'Preferensi pengingat backup diatur setiap $days hari.',
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: demo,
    builder: (context, _) => PreviewPage(
      title: 'Backup & Restore',
      body: DemoList([
        const DemoHeading(
          'Kelola salinan datamu',
          subtitle: 'Coba alur ekspor dan pemulihan memakai data contoh.',
        ),
        DemoFacts([
          (
            'Ringkasan data',
            '${demo.planner.events.where((entry) => entry.kind == PreviewKind.activity && entry.state != PreviewEventState.trashed).length} kegiatan · ${demo.tasks.length} tugas · ${demo.routines.length} rutinitas',
          ),
          (
            'Backup terakhir',
            demo.lastBackup ?? 'Belum pernah membuat backup contoh',
          ),
        ], tone: NeoCardTone.selected),
        DemoRow(
          'Ekspor backup',
          icon: Icons.upload_file,
          subtitle: 'Siapkan file yang dilindungi password',
          onTap: () => openDemo<void>(context, _Export(demo)),
        ),
        DemoRow(
          'Pulihkan dari backup',
          icon: Icons.restore,
          subtitle: 'Periksa data sebelum memilih mode restore',
          onTap: () => openDemo<void>(context, _Restore(demo)),
        ),
        PreviewField(
          label: 'Pengingat backup',
          value: demo.backupReminder == null
              ? 'Nonaktif'
              : 'Setiap ${demo.backupReminder} hari',
          onTap: () => _reminder(context),
        ),
        Text(
          demo.planner.localReminders == null
              ? 'Simulasi. File, enkripsi, dan pengingat perangkat tidak dijalankan.'
              : 'Ekspor dan pemulihan memakai data contoh. Pengingat backup mengikuti izin perangkat dan Jam Tenang.',
          style: NeoType.caption,
        ),
      ]),
    ),
  );
}

class _Export extends StatefulWidget {
  const _Export(this.demo);
  final DemoSession demo;
  @override
  State<_Export> createState() => _ExportState();
}

class _ExportState extends State<_Export> {
  final form = GlobalKey<FormState>();
  String password = '';
  String repeated = '';
  bool busy = false;
  bool ready = false;
  String? result;
  bool success = false;

  Future<void> _prepare() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      result = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        busy = false;
        ready = true;
        password = '';
        repeated = '';
      });
    }
  }

  Future<void> _destination() async {
    final destination = await previewChoices(context, 'Tujuan file backup', [
      'Simpan ke perangkat',
      'Bagikan lewat Share Sheet',
      'Aplikasi cloud (simulasi)',
      'Batalkan berbagi',
    ], (value) => value);
    if (!mounted || destination == null) return;
    final scenario = widget.demo.scenario;
    final message = switch (destination) {
      'Batalkan berbagi' => 'Berbagi dibatalkan.',
      'Aplikasi cloud (simulasi)' =>
        'Pemilih aplikasi tidak tersedia pada simulasi ini.',
      _ when scenario == 'backup-write-error' =>
        'File contoh gagal ditulis. Coba pilih tujuan lagi.',
      _ when scenario == 'backup-picker-unavailable' =>
        'Pemilih file perangkat tidak tersedia.',
      _ when scenario == 'backup-share-cancel' => 'Berbagi dibatalkan.',
      _ => 'Ekspor simulasi selesai.',
    };
    setState(() {
      result = message;
      success = message == 'Ekspor simulasi selesai.';
    });
    if (success) {
      widget.demo.change(
        () => widget.demo.lastBackup = dateLabel(widget.demo.today, year: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PreviewPage(
    title: 'Ekspor Backup',
    footer: NeoButton(
      label: ready ? 'Pilih tujuan ekspor' : 'Siapkan backup contoh',
      loading: busy,
      onPressed: busy
          ? null
          : ready
          ? _destination
          : _prepare,
    ),
    body: Form(
      key: form,
      child: DemoList([
        const DemoHeading(
          'Lindungi file backup',
          subtitle:
              'Dalam fitur nyata, password diperlukan untuk membuka backup. Jangan masukkan password asli di simulasi.',
        ),
        if (ready)
          const PreviewNotice(
            title: 'File contoh siap diekspor',
            message: 'routina-contoh.backup · Simulasi persiapan file.',
            icon: Icons.lock_outline,
          )
        else ...[
          NeoFormField(
            label: 'Password contoh',
            labelAbove: true,
            obscureText: true,
            enabled: !busy,
            onChanged: (value) => password = value,
            validator: (_) => password.isEmpty ? 'Isi password contoh.' : null,
          ),
          NeoFormField(
            label: 'Konfirmasi password',
            labelAbove: true,
            obscureText: true,
            enabled: !busy,
            onChanged: (value) => repeated = value,
            validator: (_) =>
                repeated != password ? 'Password tidak sama.' : null,
          ),
          const PreviewNotice(
            title: 'Simpan password di tempat aman',
            message: 'Password backup asli mungkin tidak bisa dipulihkan.',
            warning: true,
          ),
        ],
        if (busy)
          const PreviewNotice(
            title: 'Menyiapkan ekspor',
            message: 'Mensimulasikan proses enkripsi.',
            loading: true,
          ),
        if (result case final message?)
          PreviewNotice(
            title: message,
            message: success
                ? 'Ringkasan backup contoh telah diperbarui.'
                : 'Pilih tujuan ekspor lagi jika perlu.',
            warning: !success,
          ),
      ]),
    ),
  );
}

enum _BackupFile {
  none('Backup tanpa konflik'),
  one('Backup dengan satu konflik'),
  many('Backup dengan beberapa konflik'),
  invalid('File bukan backup'),
  schema('Backup versi baru'),
  corrupt('Backup rusak'),
  rollback('Backup untuk uji rollback');

  const _BackupFile(this.label);
  final String label;
}

enum _RestoreStep { file, password, mode, merge, report }

const _conflicts = [
  (
    id: 'tugas-17',
    kind: 'Tugas',
    local: 'Laporan E-Commerce · 17.00',
    backup: 'Laporan bulanan · 18.00',
    localTime: '15 Nov 2026 · 09.00',
    backupTime: '14 Nov 2026 · 21.00',
  ),
  (
    id: 'rutinitas-06',
    kind: 'Rutinitas',
    local: 'Belajar Flutter · 20 menit',
    backup: 'Belajar Flutter · 30 menit',
    localTime: '15 Nov 2026 · 10.30',
    backupTime: '13 Nov 2026 · 17.45',
  ),
];

class _Restore extends StatefulWidget {
  const _Restore(this.demo);
  final DemoSession demo;
  @override
  State<_Restore> createState() => _RestoreState();
}

class _RestoreState extends State<_Restore> {
  _RestoreStep step = _RestoreStep.file;
  _BackupFile? file;
  String password = '';
  String? issue;
  bool busy = false;
  bool replaced = false;
  final choices = <String, String>{};

  int get conflictCount => switch (file) {
    _BackupFile.one => 1,
    _BackupFile.many => 2,
    _ => 0,
  };

  Future<void> _validate() async {
    setState(() {
      busy = true;
      issue = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final error = switch (file) {
      _BackupFile.invalid =>
        'Format file tidak dikenali sebagai backup Routina.',
      _BackupFile.schema => 'Versi skema belum didukung pada pratinjau ini.',
      _BackupFile.corrupt =>
        'Pemeriksaan integritas gagal. Pilih salinan lain.',
      _ when password != 'routina' =>
        'Password salah. Gunakan password contoh routina.',
      _ => null,
    };
    setState(() {
      busy = false;
      issue = error;
      if (error == null) {
        step = _RestoreStep.mode;
        password = '';
      }
    });
  }

  Future<void> _finish({required bool replace}) async {
    final approved = await showNeoDialog(
      context,
      title: replace ? 'Ganti semua data lokal?' : 'Gabungkan isi backup?',
      message: replace
          ? 'Pada fitur nyata, seluruh data lokal akan digantikan isi file backup. Langkah ini mensimulasikan hasilnya.'
          : 'Gunakan keputusan pada ${choices.length} konflik dan gabungkan item contoh yang baru.',
      confirmLabel: replace ? 'Ganti Semua' : 'Pulihkan gabungan',
      danger: replace,
    );
    if (!mounted || approved != true) return;
    setState(() {
      busy = true;
      replaced = replace;
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      busy = false;
      step = _RestoreStep.report;
    });
  }

  void _reset() => setState(() {
    file = null;
    password = '';
    issue = null;
    choices.clear();
    step = _RestoreStep.file;
  });

  @override
  Widget build(BuildContext context) => PreviewPage(
    title: 'Pulihkan Backup',
    body: DemoList([
      if (busy)
        const PreviewNotice(
          title: 'Memeriksa backup',
          message: 'Menyiapkan hasil simulasi.',
          loading: true,
        )
      else
        switch (step) {
          _RestoreStep.file => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DemoHeading(
                'Pilih file backup',
                subtitle: 'Pratinjau memakai berkas contoh.',
              ),
              const SizedBox(height: NeoSpace.md),
              PreviewField(
                label: 'File backup',
                value: file?.label ?? 'Belum ada file dipilih',
                icon: Icons.folder_outlined,
                onTap: () async {
                  final value = await previewChoices(
                    context,
                    'File backup contoh',
                    _BackupFile.values,
                    (value) => value.label,
                  );
                  if (mounted && value != null) {
                    setState(() {
                      file = value;
                      step = _RestoreStep.password;
                    });
                  }
                },
              ),
            ],
          ),
          _RestoreStep.password => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DemoHeading('Buka file contoh', subtitle: file!.label),
              const SizedBox(height: NeoSpace.md),
              NeoFormField(
                label: 'Password backup',
                labelAbove: true,
                obscureText: true,
                helper: 'Password contoh · routina',
                initialValue: password,
                onChanged: (value) => password = value,
              ),
              if (issue case final message?) ...[
                const SizedBox(height: NeoSpace.sm),
                PreviewNotice(
                  title: 'Backup tidak dapat dibuka',
                  message: message,
                  warning: true,
                ),
              ],
              const SizedBox(height: NeoSpace.md),
              NeoButton(label: 'Validasi backup', onPressed: _validate),
              const SizedBox(height: NeoSpace.sm),
              NeoButton(
                label: 'Pilih file lain',
                variant: NeoButtonVariant.secondary,
                onPressed: _reset,
              ),
            ],
          ),
          _RestoreStep.mode => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DemoHeading(
                'Periksa dan pilih mode',
                subtitle: 'Backup contoh lolos validasi.',
              ),
              const SizedBox(height: NeoSpace.md),
              DemoFacts([
                ('Ringkasan file', '8 kegiatan · 3 tugas · 2 rutinitas'),
                ('Konflik versi', '$conflictCount'),
              ], tone: NeoCardTone.selected),
              const SizedBox(height: NeoSpace.md),
              DemoRow(
                'Ganti Semua',
                icon: Icons.warning_amber,
                color: NeoColors.coralTint,
                subtitle: 'Ganti isi data lokal dengan isi backup.',
                onTap: () => _finish(replace: true),
              ),
              const SizedBox(height: NeoSpace.sm),
              DemoRow(
                'Gabungkan',
                icon: Icons.merge_type,
                subtitle: conflictCount == 0
                    ? 'Tambahkan item contoh baru. Tidak ada konflik.'
                    : 'Tinjau $conflictCount konflik sebelum melanjutkan.',
                onTap: () => setState(() => step = _RestoreStep.merge),
              ),
            ],
          ),
          _RestoreStep.merge => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DemoHeading(
                conflictCount == 0
                    ? 'Tidak ada konflik'
                    : 'Selesaikan konflik data',
                subtitle: conflictCount == 0
                    ? 'Item baru dapat digabungkan.'
                    : 'Pilih satu versi untuk setiap ID yang sama.',
              ),
              for (final item in _conflicts.take(conflictCount)) ...[
                const SizedBox(height: NeoSpace.md),
                Text('${item.kind} · ${item.id}', style: NeoType.section),
                const SizedBox(height: NeoSpace.xs),
                DemoPair(
                  _version(item.id, 'Lokal', item.local, item.localTime),
                  _version(item.id, 'Backup', item.backup, item.backupTime),
                ),
              ],
              if (choices.length < conflictCount) ...[
                const SizedBox(height: NeoSpace.sm),
                const PreviewNotice(
                  title: 'Pilih versi yang dipertahankan',
                  message: 'Tentukan semua pilihan untuk melanjutkan.',
                ),
              ],
              const SizedBox(height: NeoSpace.md),
              NeoButton(
                label: 'Tinjau gabungan',
                onPressed: choices.length == conflictCount
                    ? () => _finish(replace: false)
                    : null,
              ),
              const SizedBox(height: NeoSpace.sm),
              NeoButton(
                label: 'Kembali ke mode restore',
                variant: NeoButtonVariant.secondary,
                onPressed: () => setState(() => step = _RestoreStep.mode),
              ),
            ],
          ),
          _RestoreStep.report => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PreviewNotice(
                title: file == _BackupFile.rollback
                    ? 'Pemulihan gagal'
                    : 'Simulasi pemulihan selesai',
                message: file == _BackupFile.rollback
                    ? 'Perubahan contoh dibatalkan. Data pratinjau tetap utuh.'
                    : replaced
                    ? 'Mode Ganti Semua selesai diperagakan.'
                    : 'Mode Gabungkan selesai diperagakan dengan ${choices.length} keputusan konflik.',
                warning: file == _BackupFile.rollback,
              ),
              const SizedBox(height: NeoSpace.md),
              NeoButton(
                label: file == _BackupFile.rollback
                    ? 'Pilih file lain'
                    : 'Selesai',
                onPressed: file == _BackupFile.rollback
                    ? _reset
                    : () => Navigator.pop(context),
              ),
            ],
          ),
        },
    ]),
  );

  Widget _version(String id, String label, String content, String timestamp) =>
      NeoCard(
        dense: true,
        tone: choices[id] == label ? NeoCardTone.selected : NeoCardTone.plain,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label == 'Lokal' ? 'Data di perangkat' : 'Data dalam backup',
              style: NeoType.badge,
            ),
            const SizedBox(height: NeoSpace.xs),
            Text(content, style: NeoType.item),
            Text(timestamp, style: NeoType.numericCaption),
            const SizedBox(height: NeoSpace.xs),
            CategoryChip(
              label: 'Pilih versi $label',
              selected: choices[id] == label,
              onSelected: (_) => setState(() => choices[id] = label),
            ),
          ],
        ),
      );
}
