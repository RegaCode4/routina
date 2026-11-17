part of 'backup_screen.dart';

class _BackupRestorePage extends StatefulWidget {
  const _BackupRestorePage({
    required this.workspace,
    required this.files,
    required this.onChanged,
  });
  final BackupWorkspace workspace;
  final BackupFiles files;
  final Future<void> Function() onChanged;

  @override
  State<_BackupRestorePage> createState() => _BackupRestoreState();
}

class _BackupRestoreState extends State<_BackupRestorePage> {
  final _password = TextEditingController();
  PickedBackup? _file;
  VerifiedBackup? _verified;
  RestoreMode _mode = RestoreMode.merge;
  BackupReview? _review;
  final _choices = <String, BackupChoice>{};
  int _index = 0;
  String? _progress, _error;
  bool _finished = false;
  bool get _busy => _progress != null;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    await _run(
      'Menunggu pemilih file',
      () async {
        final file = await widget.files.pick();
        if (!mounted || file == null) return;
        _password.clear();
        setState(() => _file = file);
      },
      fallback: 'File belum dapat dibaca. Periksa penyedia file dan coba lagi.',
    );
  }

  Future<void> _authenticate() async {
    final file = _file!;
    final password = _password.text;
    FocusScope.of(context).unfocus();
    _password.clear();
    await _run('Memvalidasi backup', () async {
      final verified = await widget.workspace.openEncrypted(
        file.bytes,
        password,
      );
      if (!mounted) return;
      setState(() {
        _verified = verified;
        _file = null;
      });
    });
  }

  Future<void> _prepare() async {
    await _run('Meninjau isi backup', () async {
      final review = await widget.workspace.review(_verified!, _mode);
      if (!mounted) return;
      setState(() {
        _choices.clear();
        _index = 0;
        _review = review;
      });
    });
  }

  Future<void> _safetyCopy() async {
    final summary = await widget.workspace.summary().catchError((Object _) {
      if (mounted) {
        setState(
          () => _error = 'Cadangan data saat ini belum dapat disiapkan.',
        );
      }
      return (counts: <String, int>{}, preferences: const PlannerPreferences());
    });
    if (!mounted || summary.counts.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _BackupExportPage(
          workspace: widget.workspace,
          files: widget.files,
          counts: summary.counts,
          onChanged: widget.onChanged,
        ),
      ),
    );
  }

  Future<void> _apply() async {
    final review = _review!;
    final replace = review.mode == RestoreMode.replace;
    final answer = await showNeoDialog(
      context,
      title: replace ? 'Ganti semua data lokal?' : 'Simpan hasil penggabungan?',
      message: replace
          ? 'Seluruh aktivitas, riwayat, kategori, Tempat Sampah, dan pengaturan lokal akan diganti oleh file backup.'
          : 'Data dari backup akan digabungkan sesuai pilihanmu. ${review.conflicts.length} konflik telah ditinjau.',
      confirmLabel: replace ? 'Ganti Semua' : 'Gabungkan',
      danger: replace,
    );
    if (!mounted || answer != true) return;
    await _run('Menerapkan pemulihan', () async {
      await widget.workspace.apply(review, Map.of(_choices));
      if (mounted) setState(() => _finished = true);
      try {
        await widget.onChanged();
      } catch (_) {
        if (mounted) {
          setState(
            () => _error =
                'Data tersimpan. Buka kembali aplikasi untuk memuat tampilan terbaru.',
          );
        }
      }
    });
  }

  Future<void> _run(
    String status,
    Future<void> Function() work, {
    String fallback = 'Operasi backup belum dapat dilanjutkan. Coba lagi.',
  }) async {
    if (_busy) return;
    setState(() {
      _progress = status;
      _error = null;
    });
    try {
      await work();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _backupProblem(error, fallback);
          if (error == BackupIssue.staleReview) {
            _review = null;
            _choices.clear();
          }
        });
      }
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, contents, footer) = _screen();
    return PopScope(
      canPop: !_busy,
      child: PreviewPage(
        title: title,
        body: _backupList([
          ...contents,
          if (_progress case final progress?)
            PreviewNotice(
              title: progress,
              message: 'Mohon tunggu hingga langkah ini selesai.',
              loading: true,
            ),
          if (_error case final error?) _backupError(error),
        ]),
        footer: footer,
      ),
    );
  }

  (String, List<Widget>, Widget?) _screen() {
    if (_finished) {
      return (
        'Pemulihan selesai',
        [
          PreviewNotice(
            title: 'Data dipulihkan',
            message: _mode == RestoreMode.replace
                ? 'Data dari file backup sudah menggantikan data lokal.'
                : 'Data lokal dan backup sudah digabungkan.',
            icon: Icons.check_circle_outline,
          ),
        ],
        NeoButton(
          label: 'Selesai',
          onPressed: _busy ? null : () => Navigator.pop(context),
        ),
      );
    }
    if (_review case final review?) return _reviewPage(review);
    if (_verified case final verified?) return _modePage(verified);
    return _passwordPage();
  }

  (String, List<Widget>, Widget?) _passwordPage() {
    final file = _file;
    return (
      'Impor dan pulihkan',
      [
        const Text('Pilih file backup', style: NeoType.display),
        PreviewField(
          label: 'File backup',
          value: file?.name ?? 'Belum dipilih',
          icon: Icons.folder_open,
          onTap: _pick,
        ),
        if (file != null)
          NeoFormField(
            label: 'Password backup',
            controller: _password,
            obscureText: true,
            icon: Icons.lock_outline,
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
          ),
      ],
      NeoButton(
        label: file == null ? 'Pilih file' : 'Validasi backup',
        onPressed: _busy
            ? null
            : file == null
            ? _pick
            : (_password.text.isEmpty ? null : _authenticate),
      ),
    );
  }

  (String, List<Widget>, Widget?) _modePage(VerifiedBackup verified) => (
    'Mode pemulihan',
    [
      const Text('Tinjau isi backup', style: NeoType.display),
      Text(
        '${dateLabel(verified.archive.createdAt.toLocal(), year: true)} · File tervalidasi',
      ),
      NeoCard(
        tone: NeoCardTone.selected,
        child: Text(_countLabel(verified.archive.snapshot.counts)),
      ),
      _modeChoice(
        RestoreMode.merge,
        'Gabungkan',
        'Pertahankan data lokal dan tinjau perbedaan versi.',
      ),
      _modeChoice(
        RestoreMode.replace,
        'Ganti Semua',
        'Ganti seluruh data lokal dengan isi file ini.',
      ),
      if (_mode == RestoreMode.replace)
        NeoButton(
          label: 'Ekspor cadangan data saat ini',
          variant: NeoButtonVariant.secondary,
          onPressed: _busy ? null : _safetyCopy,
        ),
    ],
    NeoButton(
      label: _mode == RestoreMode.merge
          ? 'Tinjau penggabungan'
          : 'Tinjau penggantian',
      onPressed: _busy ? null : _prepare,
    ),
  );

  Widget _modeChoice(RestoreMode value, String label, String caption) =>
      NeoCard(
        tone: _mode == value ? NeoCardTone.selected : NeoCardTone.plain,
        onTap: _busy ? null : () => setState(() => _mode = value),
        child: Row(
          children: [
            Icon(
              _mode == value
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            const SizedBox(width: NeoSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: NeoType.item),
                  Text(caption, style: NeoType.caption),
                ],
              ),
            ),
          ],
        ),
      );

  (String, List<Widget>, Widget?) _reviewPage(BackupReview review) {
    final conflicts = review.conflicts;
    final replace = review.mode == RestoreMode.replace;
    final conflict = conflicts.isEmpty ? null : conflicts[_index];
    final allChosen = _choices.length == conflicts.length;
    final hasMore = conflict != null && _index < conflicts.length - 1;
    return (
      conflict == null ? 'Tinjau pemulihan' : 'Konflik penggabungan',
      [
        if (conflict == null) ...[
          Text(
            replace ? 'Ganti data di perangkat' : 'Siap digabungkan',
            style: NeoType.display,
          ),
          NeoCard(
            tone: NeoCardTone.highlighted,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Data di perangkat', style: NeoType.item),
                Text(_countLabel(review.local.counts)),
                const SizedBox(height: NeoSpace.xs),
                const Text('Data dalam backup', style: NeoType.item),
                Text(_countLabel(review.backup.archive.snapshot.counts)),
              ],
            ),
          ),
          Text(
            replace
                ? 'Seluruh data lokal akan diganti setelah konfirmasi.'
                : 'Tidak ada konflik versi. Item dengan ID berbeda tetap terpisah.',
          ),
        ] else ...[
          Text(
            'Konflik ${_index + 1} dari ${conflicts.length}',
            style: NeoType.badge,
          ),
          Text(_entityDisplay(conflict.local), style: NeoType.title),
          Text(
            conflict.local.id == conflict.backup.id
                ? 'Pilih versi yang akan disimpan untuk item ini.'
                : 'Perangkat dan backup memiliki profil yang berbeda. Pilih satu profil.',
          ),
          LayoutBuilder(
            builder: (context, box) {
              final local = _version(conflict, BackupChoice.local);
              final backup = _version(conflict, BackupChoice.backup);
              if (box.maxWidth < MediaQuery.textScalerOf(context).scale(310)) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    local,
                    const SizedBox(height: NeoSpace.sm),
                    backup,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: local),
                  const SizedBox(width: NeoSpace.xs),
                  Expanded(child: backup),
                ],
              );
            },
          ),
          Text('${_choices.length} dari ${conflicts.length} konflik dipilih'),
          if (_index > 0)
            NeoButton(
              label: 'Konflik sebelumnya',
              variant: NeoButtonVariant.secondary,
              onPressed: _busy ? null : () => setState(() => _index--),
            ),
        ],
        NeoButton(
          label: 'Kembali ke mode pemulihan',
          variant: NeoButtonVariant.secondary,
          onPressed: _busy
              ? null
              : () => setState(() {
                  _review = null;
                  _error = null;
                }),
        ),
      ],
      NeoButton(
        label: hasMore
            ? 'Lanjut ke konflik berikutnya'
            : replace
            ? 'Konfirmasi Ganti Semua'
            : 'Konfirmasi Gabungkan',
        onPressed: _busy
            ? null
            : hasMore
            ? (_choices.containsKey(conflict.key)
                  ? () => setState(() => _index++)
                  : null)
            : (allChosen ? _apply : null),
      ),
    );
  }

  Widget _version(BackupConflict conflict, BackupChoice choice) {
    final local = choice == BackupChoice.local;
    final row = local ? conflict.local : conflict.backup;
    final other = local ? conflict.backup : conflict.local;
    final fields = _entityFields(row);
    final otherFields = _entityFields(other);
    final changes = {
      ...fields.keys,
      ...otherFields.keys,
    }.where((key) => fields[key] != otherFields[key]).toList();
    final atAGlance = changes.where(_primaryFields.contains).take(4).toSet();
    final details = changes.where((key) => !atAGlance.contains(key)).toList();
    final selected = _choices[conflict.key] == choice;
    return NeoCard(
      tone: selected ? NeoCardTone.selected : NeoCardTone.plain,
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            local ? 'Data di perangkat' : 'Data dalam backup',
            style: NeoType.item,
          ),
          const SizedBox(height: NeoSpace.xs),
          Text(_entityDisplay(row), style: NeoType.item),
          Text(_localTime(row.updatedAt), style: NeoType.caption),
          Text('Revisi ${row.record['revision']}', style: NeoType.caption),
          for (final key in atAGlance) _field(key, fields[key]),
          if (details.isNotEmpty)
            ExpansionTile(
              title: const Text('Rincian perubahan'),
              tilePadding: EdgeInsets.zero,
              children: [
                for (final key in details)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _field(key, fields[key]),
                  ),
              ],
            ),
          const SizedBox(height: NeoSpace.xs),
          NeoButton(
            label: local ? 'Pilih lokal' : 'Pilih backup',
            variant: selected
                ? NeoButtonVariant.primary
                : NeoButtonVariant.secondary,
            onPressed: _busy
                ? null
                : () => setState(() => _choices[conflict.key] = choice),
          ),
        ],
      ),
    );
  }

  Widget _field(String key, Object? value) => Padding(
    padding: const EdgeInsets.only(top: NeoSpace.xs),
    child: Text(
      '${_fieldLabel(key)}\n${_readableValue(key, value)}',
      style: NeoType.caption,
    ),
  );
}

String _entityDisplay(BackupEntity row) =>
    row.data['title'] as String? ??
    row.data['name'] as String? ??
    switch (row.kind) {
      RecordKind.profile => 'Profil lokal',
      RecordKind.eventSeries => 'Seri kegiatan',
      RecordKind.routineOccurrence => 'Kejadian rutinitas',
      RecordKind.workSession => 'Sesi pengerjaan',
      RecordKind.timeLog => 'Catatan waktu',
      RecordKind.reminderRule => 'Aturan pengingat',
      RecordKind.statusHistory => 'Riwayat status',
      RecordKind.trashEntry => 'Arsip Tempat Sampah',
      _ => row.id,
    };

Map<String, Object?> _entityFields(BackupEntity row) => {
  'ID': row.id,
  'Induk': row.record['parent_id'],
  for (final field in row.data.entries)
    if (field.key != 'id') field.key: field.value,
  if (row.data['details'] case final String details) ...{
    for (final name in ['location', 'note'])
      name: (jsonDecode(details) as Map<String, dynamic>)[name],
  },
  if (row.timer case final timer?) 'Timer': jsonEncode(timer),
  if (row.goalEvent case final goal?) 'Pencapaian target': jsonEncode(goal),
};

const _primaryFields = {
  'start_us',
  'end_us',
  'deadline_us',
  'local_day',
  'status',
  'location',
};

String _fieldLabel(String key) => switch (key) {
  'start_us' => 'Mulai',
  'end_us' => 'Selesai pada',
  'deadline_us' => 'Tenggat',
  'local_day' => 'Tanggal',
  'status' => 'Status',
  'location' => 'Lokasi',
  'note' => 'Catatan',
  'description' => 'Deskripsi',
  'title' || 'name' => 'Nama',
  'category_id' => 'ID kategori',
  'details' => 'Rincian kegiatan',
  'preferences' => 'Preferensi profil',
  _ => key.replaceAll('_', ' '),
};

String _readableValue(String key, Object? value) {
  if (value == null || value == '') return 'Kosong';
  if (value is int && {'start_us', 'end_us', 'deadline_us'}.contains(key)) {
    return _localTime(DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true));
  }
  if (key == 'status') {
    return switch (value) {
      'planned' => 'Belum selesai',
      'completed' => 'Selesai',
      'postponed' => 'Ditunda',
      'skipped' => 'Dilewatkan',
      'cancelled' => 'Dibatalkan',
      _ => value.toString(),
    };
  }
  return value.toString();
}

String _localTime(DateTime instant) {
  final local = instant.toLocal();
  return '${dateLabel(local, year: true)} ${clockLabel(minutesAt(local))}';
}
