import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:routina/application/backup_workspace.dart';
import 'package:routina/data/backup_cipher.dart';
import 'package:routina/data/backup_files.dart';
import 'package:routina/domain/backup.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart' show minutesAt;
import 'package:routina/presentation/demo/demo_widgets.dart' show demoNumber;
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_form_field.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

part 'backup_restore_page.dart';

typedef _BackupSummary = ({
  Map<String, int> counts,
  PlannerPreferences preferences,
});

class BackupScreen extends StatefulWidget {
  const BackupScreen({
    required this.workspace,
    required this.onChanged,
    this.files = const SystemBackupFiles(),
    super.key,
  });

  final BackupWorkspace workspace;
  final Future<void> Function() onChanged;
  final BackupFiles files;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late Future<_BackupSummary> _summary = widget.workspace.summary();

  void _reload() {
    final summary = widget.workspace.summary();
    setState(() {
      _summary = summary;
    });
  }

  Future<void> _reminder(PlannerPreferences prefs) async {
    final choice = await previewChoices(
      context,
      'Pengingat backup',
      [0, 7, 14, 30, -1],
      (days) => switch (days) {
        0 => 'Nonaktif',
        -1 => 'Atur sendiri',
        _ => '$days hari',
      },
    );
    if (!mounted || choice == null) return;
    final days = choice == -1
        ? await demoNumber(
            context,
            'Interval pengingat (hari)',
            min: 1,
            max: 365,
            value: prefs.backupReminderDays,
          )
        : choice;
    if (!mounted || days == null) return;
    try {
      await widget.workspace.setReminder(days == 0 ? null : days);
      await widget.onChanged();
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        _feedback(context, 'Pengaturan pengingat belum dapat dimuat kembali.');
      }
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => PreviewPage(
    title: 'Backup & Restore',
    body: FutureBuilder<_BackupSummary>(
      future: _summary,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final ready = snapshot.connectionState == ConnectionState.done;
        return _backupList([
          const Text('Cadangkan datamu', style: NeoType.display),
          const Text('Simpan atau pulihkan data dari file terenkripsi.'),
          if (!ready)
            const PreviewNotice(
              title: 'Memuat ringkasan',
              message: 'Sedang membaca data lokal.',
              loading: true,
            )
          else if (data == null || snapshot.hasError)
            PreviewNotice(
              title: 'Ringkasan belum tersedia',
              message: 'Coba baca kembali data lokal.',
              warning: true,
              button: NeoButton(label: 'Muat ulang', onPressed: _reload),
            )
          else ...[
            NeoCard(
              tone: NeoCardTone.accent,
              emphasis: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Backup terakhir', style: NeoType.item),
                  const SizedBox(height: NeoSpace.xs),
                  Text(
                    data.preferences.lastBackupAt == null
                        ? 'Belum ada backup'
                        : dateLabel(
                            data.preferences.lastBackupAt!.toLocal(),
                            year: true,
                          ),
                    style: NeoType.title,
                  ),
                  const SizedBox(height: NeoSpace.xs),
                  Text(_countLabel(data.counts)),
                ],
              ),
            ),
            const Text('Kelola file backup', style: NeoType.section),
            _backupAction(
              'Ekspor backup',
              'Buat file terenkripsi dengan password.',
              Icons.lock_outline,
              () => _open(
                _BackupExportPage(
                  workspace: widget.workspace,
                  files: widget.files,
                  counts: data.counts,
                  onChanged: widget.onChanged,
                ),
              ),
            ),
            _backupAction(
              'Impor dan pulihkan',
              'Pilih file backup untuk ditinjau.',
              Icons.restore,
              () => _open(
                _BackupRestorePage(
                  workspace: widget.workspace,
                  files: widget.files,
                  onChanged: widget.onChanged,
                ),
              ),
            ),
            _backupAction(
              'Pengingat backup',
              data.preferences.backupReminderDays == null
                  ? 'Nonaktif'
                  : 'Setiap ${data.preferences.backupReminderDays} hari',
              Icons.notifications_none,
              () => _reminder(data.preferences),
            ),
          ],
        ]);
      },
    ),
  );
}

class _BackupExportPage extends StatefulWidget {
  const _BackupExportPage({
    required this.workspace,
    required this.files,
    required this.onChanged,
    required this.counts,
  });
  final BackupWorkspace workspace;
  final BackupFiles files;
  final Future<void> Function() onChanged;
  final Map<String, int> counts;

  @override
  State<_BackupExportPage> createState() => _BackupExportState();
}

class _BackupExportState extends State<_BackupExportPage> {
  final _password = TextEditingController();
  final _again = TextEditingController();
  Uint8List? _encrypted;
  bool _busy = false, _wroteFile = false;
  String? _error, _status;

  @override
  void dispose() {
    _password.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _encrypt() async {
    if (_password.text.isEmpty || _password.text != _again.text || _busy) {
      return;
    }
    final password = _password.text;
    FocusScope.of(context).unfocus();
    _password.clear();
    _again.clear();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await widget.workspace.export(password);
      if (mounted) setState(() => _encrypted = file);
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _error = _backupProblem(error, 'Backup belum dapat dienkripsi.'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deliver({required bool sharing}) async {
    final bytes = _encrypted;
    if (bytes == null || _busy) return;
    final timestamp = widget.workspace
        .now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-');
    final name = 'routina-$timestamp.${BackupCipher.extension}';
    final box = context.findRenderObject()! as RenderBox;
    final placement =
        box.localToGlobal(box.size.center(Offset.zero)) & const Size(1, 1);
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final done = sharing
          ? await widget.files.share(name, bytes, placement)
          : await widget.files.save(name, bytes);
      if (!mounted) return;
      if (!done) {
        setState(
          () => _status = sharing
              ? 'Berbagi dibatalkan.'
              : 'Penyimpanan dibatalkan.',
        );
        return;
      }
      if (sharing) {
        setState(() => _status = 'File diserahkan ke menu berbagi.');
        setState(() => _busy = false);
        final saved = await showNeoDialog(
          context,
          title: 'Salinan sudah tersimpan?',
          message:
              'Periksa hasil di aplikasi tujuan sebelum memperbarui tanggal backup terakhir.',
          confirmLabel: 'Sudah tersimpan',
        );
        if (!mounted || saved != true) return;
        setState(() => _busy = true);
      }
      setState(() {
        _wroteFile = true;
        _status = 'File backup tersimpan.';
      });
      try {
        await widget.workspace.recordExport();
        await widget.onChanged();
      } catch (_) {
        if (mounted) {
          setState(
            () => _error = 'Tanggal backup terakhir belum dapat diperbarui.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = sharing
              ? 'Menu berbagi belum dapat dibuka. Coba Simpan ke perangkat.'
              : 'File belum dapat disimpan. Periksa lokasi tujuan atau coba menu berbagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _encrypted != null;
    final mismatch = _again.text.isNotEmpty && _password.text != _again.text;
    return PopScope(
      canPop: !_busy,
      child: PreviewPage(
        title: 'Ekspor backup',
        body: _backupList([
          Text(
            ready ? 'Pilih tujuan backup' : 'Lindungi file backup',
            style: NeoType.display,
          ),
          if (!ready) ...[
            const PreviewNotice(
              title: 'Simpan password dengan aman',
              message: 'Backup tidak dapat dibuka bila password hilang.',
              icon: Icons.lock_outline,
              tone: NeoCardTone.highlighted,
              inline: true,
            ),
            _passwordField('Password backup', _password),
            _passwordField(
              'Ulangi password',
              _again,
              error: mismatch ? 'Password berbeda.' : null,
            ),
            Text(_countLabel(widget.counts)),
            const Text(
              'Kategori, riwayat, Tempat Sampah, dan pengaturan ikut dicadangkan.',
            ),
          ] else ...[
            const Text(
              'Pilih folder perangkat atau penyedia cloud yang tersedia di pemilih file.',
            ),
            NeoButton(
              label: 'Simpan ke perangkat',
              onPressed: _busy ? null : () => _deliver(sharing: false),
            ),
            NeoButton(
              label: 'Bagikan file backup',
              variant: NeoButtonVariant.secondary,
              onPressed: _busy ? null : () => _deliver(sharing: true),
            ),
          ],
          if (_busy)
            PreviewNotice(
              title: ready ? 'Menunggu tujuan file' : 'Mengenkripsi backup',
              message: ready
                  ? 'Selesaikan proses di pemilih file atau menu berbagi.'
                  : 'Sedang melindungi salinan data.',
              loading: true,
            ),
          if (_status case final status?)
            Semantics(liveRegion: true, child: Text(status)),
          if (_error case final error?) _backupError(error),
        ]),
        footer: ready
            ? NeoButton(
                label: _wroteFile ? 'Selesai' : 'Kembali',
                variant: NeoButtonVariant.secondary,
                onPressed: _busy ? null : () => Navigator.pop(context),
              )
            : NeoButton(
                label: 'Enkripsi dan lanjut',
                onPressed:
                    _busy ||
                        mismatch ||
                        _password.text.isEmpty ||
                        _again.text.isEmpty
                    ? null
                    : _encrypt,
              ),
      ),
    );
  }

  Widget _passwordField(
    String label,
    TextEditingController controller, {
    String? error,
  }) => NeoFormField(
    label: label,
    labelAbove: true,
    controller: controller,
    obscureText: true,
    icon: Icons.lock_outline,
    errorText: error,
    enabled: !_busy,
    onChanged: (_) => setState(() {}),
  );
}

ListView _backupList(List<Widget> children) => ListView(
  padding: const EdgeInsets.all(NeoSpace.page),
  children: [
    for (final child in children)
      Padding(
        padding: const EdgeInsets.only(bottom: NeoSpace.md),
        child: child,
      ),
  ],
);

Widget _backupAction(
  String title,
  String subtitle,
  IconData icon,
  VoidCallback action,
) => NeoCard(
  dense: true,
  onTap: action,
  child: Row(
    children: [
      Icon(icon),
      const SizedBox(width: NeoSpace.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: NeoType.item),
            Text(subtitle, style: NeoType.caption),
          ],
        ),
      ),
      const Icon(Icons.chevron_right),
    ],
  ),
);

Widget _backupError(String message) => PreviewNotice(
  title: 'Periksa kembali',
  message: message,
  warning: true,
  icon: Icons.error_outline,
);

String _countLabel(Map<String, int> counts) =>
    '${counts['eventOccurrence'] ?? 0} kegiatan tersimpan · ${counts['eventSeries'] ?? 0} seri · ${counts['task'] ?? 0} tugas · ${counts['routine'] ?? 0} rutinitas';

void _feedback(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

String _backupProblem(Object issue, String fallback) => switch (issue) {
  BackupIssue.passwordRequired => 'Masukkan password backup.',
  BackupIssue.readFailed =>
    'File backup tidak dapat dibaca dari lokasi yang dipilih.',
  BackupIssue.invalidFile =>
    'File bukan backup Routina yang valid atau file terpotong.',
  BackupIssue.unsupportedFormat => 'Versi format backup ini belum didukung.',
  BackupIssue.unsupportedSchema =>
    'Versi skema database di file tidak kompatibel dengan aplikasi ini.',
  BackupIssue.authentication =>
    'File tidak bisa diautentikasi. Periksa password atau pilih salinan file lain.',
  BackupIssue.tooLarge =>
    'Backup melebihi batas 32 MiB atau kapasitas entitas.',
  BackupIssue.invalidData => 'Isi backup tidak lolos pemeriksaan integritas.',
  BackupIssue.incompleteChoices => 'Pilih versi untuk setiap konflik.',
  BackupIssue.incompatibleMerge =>
    'Pilihan menghasilkan relasi atau identitas yang bertentangan. Tinjau pilihan penggabungan.',
  BackupIssue.trashConflict =>
    'Status Tempat Sampah berbeda untuk item yang sama. Untuk memakai seluruh isi backup, tinjau Ganti Semua.',
  BackupIssue.staleReview =>
    'Data lokal berubah. Tinjau kembali sebelum menyimpan.',
  BackupIssue.applyFailed =>
    'Pemulihan dibatalkan. Perubahan database telah di-rollback.',
  _ => fallback,
};
