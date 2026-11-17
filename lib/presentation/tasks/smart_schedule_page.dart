import 'package:flutter/material.dart';
import 'package:routina/application/smart_scheduling.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/domain/scheduling_engine.dart';
import 'package:routina/presentation/demo/demo_widgets.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

enum SchedulingPage { setup, conflict, comparison }

enum _Step { setup, conflict, comparison, proposal, failure, stale }

class SmartSchedulePage extends StatefulWidget {
  const SmartSchedulePage({
    required this.scheduling,
    required this.taskId,
    required this.onManual,
    this.entry = SchedulingPage.setup,
    super.key,
  });

  final SmartScheduling scheduling;
  final String taskId;
  final SchedulingPage entry;
  final Future<void> Function(WorkSession? existing) onManual;

  @override
  State<SmartSchedulePage> createState() => _SmartSchedulePageState();
}

class _SmartSchedulePageState extends State<SmartSchedulePage> {
  SchedulingReview? _review;
  SchedulingProposal? _proposal;
  SlotSearchResult? _result;
  ScheduleAction? _action;
  late _Step _step = switch (widget.entry) {
    SchedulingPage.setup => _Step.setup,
    SchedulingPage.conflict => _Step.conflict,
    SchedulingPage.comparison => _Step.comparison,
  };
  Duration? _remaining;
  int? _minimum;
  int? _maximum;
  bool _limitsEdited = false;
  bool _busy = false;
  bool _loadError = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => _run(() async {
    final fresh = await widget.scheduling.review(widget.taskId);
    if (!mounted) return;
    setState(() {
      _review = fresh;
      _remaining = fresh.confirmedRemaining ?? fresh.suggestedRemaining;
      if (!_limitsEdited) {
        _minimum = fresh.limits?.minimumMinutes;
        _maximum = fresh.limits?.maximumSessions;
      }
      _loadError = false;
      if (_step == _Step.stale) {
        _action = null;
        _step = fresh.conflicts.isEmpty ? _Step.setup : _Step.conflict;
      }
    });
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on StaleRecord {
      if (mounted) {
        setState(() {
          _proposal = null;
          _step = _Step.stale;
          _loadError = _review == null;
          _error = _review == null
              ? 'Data tugas sudah berubah atau dihapus.'
              : null;
        });
      }
    } on SchedulingInput catch (issue) {
      if (mounted) setState(() => _error = _problem(issue.problem));
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError = _review == null;
          _error = 'Data lokal belum dapat diproses. Coba lagi.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(SchedulingReview state) async {
    final remaining = _remaining;
    if (remaining == null) {
      setState(() => _error = 'Isi estimasi sisa pengerjaan terlebih dahulu.');
      return;
    }
    await _run(() async {
      await widget.scheduling.confirmRemaining(state, remaining);
      final fresh = await widget.scheduling.review(widget.taskId);
      if (!mounted) return;
      setState(() {
        _review = fresh;
        _step =
            _action == null &&
                (fresh.upcoming.isNotEmpty || remaining == Duration.zero)
            ? _Step.comparison
            : _Step.setup;
      });
    });
  }

  Future<void> _search(SchedulingReview state, ScheduleAction action) async {
    if (state.confirmedRemaining != _remaining ||
        state.confirmedRemaining == null) {
      setState(() {
        _action = action;
        _step = _Step.setup;
      });
      return;
    }
    final minimum = _minimum;
    final maximum = _maximum;
    if (minimum == null || maximum == null) {
      setState(() {
        _action = action;
        _step = _Step.setup;
        _error = _problem(SchedulingProblem.limits);
      });
      return;
    }
    await _run(() async {
      final outcome = await widget.scheduling.propose(
        state,
        action,
        _limitsEdited
            ? (minimumMinutes: minimum, maximumSessions: maximum)
            : null,
      );
      if (!mounted) return;
      setState(() {
        _action = action;
        _result = outcome.result;
        _proposal = outcome.proposal;
        _step = outcome.proposal == null ? _Step.failure : _Step.proposal;
      });
    });
  }

  Future<void> _approve(SchedulingProposal proposal) async {
    final accepted = await showNeoDialog(
      context,
      title: 'Simpan perubahan jadwal?',
      message:
          '${proposal.additions.length} sesi akan disimpan dan '
          '${proposal.removals.length} sesi akan dibatalkan. '
          'Kalender akan diperiksa lagi sebelum perubahan disimpan.',
      confirmLabel: 'Setujui & Simpan Sesi',
    );
    if (!mounted || accepted != true) return;
    await _run(() async {
      await widget.scheduling.approve(proposal);
      if (!mounted) return;
      demoFeedback(context, 'Perubahan sesi tersimpan.');
      Navigator.pop(context);
    });
  }

  Future<void> _editNumber(
    String label, {
    required int? value,
    required int min,
    required int max,
    required ValueChanged<int> update,
  }) async {
    final selected = await demoNumber(
      context,
      label,
      value: value,
      min: min,
      max: max,
    );
    if (mounted && selected != null) {
      setState(() {
        update(selected);
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _review;
    final title = switch (_step) {
      _Step.conflict => 'Konflik sesi',
      _Step.comparison => 'Sisa waktu tugas',
      _ => 'Smart Scheduling',
    };
    final pinReview =
        !_busy &&
        _step == _Step.proposal &&
        MediaQuery.sizeOf(context).height >= 620 &&
        MediaQuery.textScalerOf(context).scale(16) <= 22;
    return PreviewPage(
      title: title,
      footer: pinReview ? DemoActions(_proposalActions(_proposal!)) : null,
      body: _busy
          ? Center(
              child: CircularProgressIndicator(
                semanticsLabel: _step == _Step.proposal
                    ? 'Memeriksa ulang kalender'
                    : 'Memeriksa jadwal',
              ),
            )
          : _loadError || state == null
          ? DemoList([
              PreviewNotice(
                title: 'Jadwal gagal dimuat',
                message: _error ?? 'Coba baca lagi data lokal.',
                button: NeoButton(label: 'Coba lagi', onPressed: _load),
              ),
            ])
          : DemoList([
              ...switch (_step) {
                _Step.setup => _setup(state),
                _Step.conflict => _conflict(state),
                _Step.comparison => _comparison(state),
                _Step.proposal => [
                  ..._preview(_proposal!),
                  if (!pinReview) ..._proposalActions(_proposal!),
                ],
                _Step.failure => _failure(state),
                _Step.stale => [
                  const PreviewNotice(
                    title: 'Usulan perlu diperbarui',
                    message:
                        'Kalender, waktu, atau data tugas berubah. Muat jadwal terbaru untuk memeriksa kembali.',
                    warning: true,
                  ),
                  NeoButton(label: 'Periksa ulang jadwal', onPressed: _load),
                ],
              },
              if (_error case final message?)
                PreviewNotice(
                  title: 'Periksa pencarian',
                  message: message,
                  warning: true,
                ),
            ], key: ValueKey(_step)),
    );
  }

  List<Widget> _setup(SchedulingReview state) {
    final canSearch = state.deadline?.isAfter(state.current) ?? false;
    final confirmed =
        state.confirmedRemaining != null &&
        state.confirmedRemaining == _remaining;
    final action =
        _action ??
        (state.upcoming.isEmpty
            ? ScheduleAction.add
            : ScheduleAction.replanAll);
    return [
      DemoHeading(
        _action == null ? 'Cari waktu untuk fokus' : _actionLabel(action),
        subtitle: state.task.title,
      ),
      NeoCard(
        tone: NeoCardTone.highlighted,
        dense: true,
        child: Row(
          children: [
            const Icon(Icons.event_outlined),
            const SizedBox(width: NeoSpace.sm),
            Expanded(child: Text(_deadline(state), style: NeoType.item)),
          ],
        ),
      ),
      DemoFacts([
        ('Estimasi awal', scheduleDuration(state.task.initialEstimate)),
        ('Durasi aktual tercatat', scheduleDuration(state.actual)),
        (
          'Preferensi waktu',
          state.preference.isEmpty ? 'Fleksibel' : state.preference,
        ),
        ('Jam aktif', state.hours.isEmpty ? 'Belum diatur' : _hours(state)),
        ('Buffer sebelum dan sesudah', scheduleDuration(state.buffer)),
      ]),
      if (!canSearch)
        const PreviewNotice(
          title: 'Tenggat perlu ditinjau',
          message:
              'Ubah tenggat dari detail tugas untuk mencari slot mendatang.',
          warning: true,
        ),
      PreviewField(
        label: confirmed ? 'Estimasi sisa disetujui' : 'Estimasi sisa usulan',
        value: scheduleDuration(_remaining, empty: 'Isi estimasi sisa'),
        icon: Icons.edit_outlined,
        onTap: () => _editNumber(
          'Estimasi sisa (menit)',
          value: _remaining?.inMinutes,
          min: 0,
          max: 5256000,
          update: (value) => _remaining = Duration(minutes: value),
        ),
      ),
      const Text('Durasi aktual dan progres checklist dicatat terpisah.'),
      DemoPair(
        PreviewField(
          label: 'Durasi minimum per sesi',
          value: _minimum == null ? 'Pilih durasi' : '$_minimum menit',
          icon: Icons.edit_outlined,
          onTap: () => _editNumber(
            'Durasi minimum (menit)',
            value: _minimum,
            min: 1,
            max: 1440,
            update: (value) {
              _minimum = value;
              _limitsEdited = true;
            },
          ),
        ),
        PreviewField(
          label: 'Jumlah maksimum sesi',
          value: _maximum == null ? 'Pilih jumlah' : '$_maximum sesi',
          icon: Icons.edit_outlined,
          onTap: () => _editNumber(
            'Jumlah maksimum sesi',
            value: _maximum,
            min: 1,
            max: 5256000,
            update: (value) {
              _maximum = value;
              _limitsEdited = true;
            },
          ),
        ),
      ),
      if (!confirmed)
        NeoButton(
          label: 'Konfirmasi estimasi',
          onPressed: () => _confirm(state),
        )
      else if (canSearch &&
          (_action != null ||
              (state.upcoming.isEmpty &&
                  state.confirmedRemaining! > Duration.zero)))
        NeoButton(label: 'Cari slot', onPressed: () => _search(state, action)),
      if (confirmed &&
          (state.upcoming.isNotEmpty ||
              state.confirmedRemaining == Duration.zero))
        NeoButton(
          label: 'Bandingkan alokasi',
          variant: NeoButtonVariant.secondary,
          onPressed: () => setState(() => _step = _Step.comparison),
        ),
      if (!canSearch)
        NeoButton(
          label: 'Jadwalkan secara manual',
          variant: NeoButtonVariant.secondary,
          onPressed: () => widget.onManual(null),
        ),
    ];
  }

  List<Widget> _comparison(SchedulingReview state) {
    final confirmed = state.confirmedRemaining;
    if (confirmed == null) return _setup(state);
    final difference = confirmed - state.scheduled;
    return [
      DemoHeading('Bandingkan alokasi', subtitle: state.task.title),
      DemoPair(
        _amountCard('Estimasi sisa disetujui', confirmed, NeoCardTone.selected),
        _amountCard('Total sesi mendatang', state.scheduled, NeoCardTone.plain),
      ),
      NeoCard(
        tone: difference == Duration.zero
            ? NeoCardTone.plain
            : NeoCardTone.highlighted,
        child: Text(scheduleMismatch(difference), style: NeoType.section),
      ),
      DemoFacts([
        ('Estimasi awal', scheduleDuration(state.task.initialEstimate)),
        ('Durasi aktual tercatat', scheduleDuration(state.actual)),
        ('Tenggat', _deadline(state)),
      ]),
      if (difference > Duration.zero)
        NeoButton(
          label: 'Tambahkan sesi',
          onPressed: () => _search(state, ScheduleAction.add),
        ),
      if (difference.isNegative)
        NeoButton(
          label: 'Kurangi sesi',
          onPressed: () => _search(state, ScheduleAction.reduce),
        ),
      if (state.upcoming.isNotEmpty)
        NeoButton(
          label: 'Optimasi ulang',
          variant: NeoButtonVariant.secondary,
          onPressed: () => _search(state, ScheduleAction.replanAll),
        ),
      NeoButton(
        label: 'Koreksi estimasi',
        variant: NeoButtonVariant.secondary,
        onPressed: () => setState(() => _step = _Step.setup),
      ),
      NeoButton(
        label: 'Pertahankan rencana',
        variant: NeoButtonVariant.secondary,
        onPressed: () => Navigator.pop(context),
      ),
    ];
  }

  List<Widget> _conflict(SchedulingReview state) => [
    DemoHeading('Sesi perlu ditinjau', subtitle: state.task.title),
    if (state.conflicts.isEmpty)
      const PreviewNotice(
        title: 'Tidak ada sesi bentrok',
        message:
            'Kalender saat ini bebas bentrok untuk sesi mendatang tugas ini.',
      ),
    for (final row in state.upcoming)
      _slot(
        state,
        row.slot,
        state.conflicts.containsKey(row.record.id)
            ? 'Bentrok · ${state.conflicts[row.record.id]!.map((item) => item.title).toSet().join(', ')}'
            : 'Terjadwal · bebas bentrok',
        warning: state.conflicts.containsKey(row.record.id),
        action: row.movable && state.conflicts.containsKey(row.record.id)
            ? TextButton(
                onPressed: () async {
                  await widget.onManual(row.record);
                  if (mounted) await _load();
                },
                child: const Text('Edit sesi manual'),
              )
            : null,
      ),
    if (state.history.isNotEmpty) ...[
      const Text('Riwayat sesi', style: NeoType.section),
      for (final row in state.history)
        _slot(state, row.slot, 'Riwayat · hanya baca'),
    ],
    if (state.conflicts.isNotEmpty)
      NeoButton(
        label: 'Tinjau opsi penjadwalan ulang',
        onPressed: () async {
          final picked = await previewChoices(
            context,
            'Cakupan penjadwalan ulang',
            [ScheduleAction.replanConflicts, ScheduleAction.replanAll],
            _actionLabel,
          );
          if (mounted && picked != null) await _search(state, picked);
        },
      ),
    NeoButton(
      label: 'Pertahankan jadwal',
      variant: NeoButtonVariant.secondary,
      onPressed: () => Navigator.pop(context),
    ),
  ];

  List<Widget> _preview(SchedulingProposal proposal) {
    final state = proposal.review;
    final removed = proposal.removals.map((row) => row.record.id).toSet();
    final timeline = [
      for (final row in state.upcoming)
        if (!removed.contains(row.record.id))
          (slot: row.slot, label: 'Sesi dipertahankan', proposed: false),
      for (final slot in proposal.additions)
        (slot: slot, label: 'Sesi usulan', proposed: true),
    ]..sort((a, b) => a.slot.start.compareTo(b.slot.start));
    return [
      DemoHeading('Tinjau rekomendasi', subtitle: state.task.title),
      NeoCard(
        tone: NeoCardTone.accent,
        emphasis: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Usulan · belum tersimpan', style: NeoType.item),
            const SizedBox(height: NeoSpace.xs),
            Text(scheduleDuration(proposal.total), style: NeoType.metric),
            Text('${timeline.length} sesi mendatang'),
            Text('Tenggat · ${_deadline(state)}'),
          ],
        ),
      ),
      if (proposal.removals.isNotEmpty) ...[
        const Text('Sesi yang akan dibatalkan', style: NeoType.section),
        for (final row in proposal.removals)
          _slot(state, row.slot, 'Jadwal saat ini', warning: true),
      ],
      const Text('Linimasa sesi mendatang', style: NeoType.section),
      if (timeline.isEmpty)
        const Text('Tidak ada sesi mendatang setelah perubahan.'),
      for (final row in timeline)
        _slot(state, row.slot, row.label, proposed: row.proposed),
    ];
  }

  List<Widget> _proposalActions(SchedulingProposal proposal) => [
    NeoButton(label: 'Pilih rencana ini', onPressed: () => _approve(proposal)),
    NeoButton(
      label: 'Ubah batas sesi',
      variant: NeoButtonVariant.secondary,
      onPressed: () => setState(() => _step = _Step.setup),
    ),
  ];

  Widget _amountCard(String label, Duration duration, NeoCardTone tone) =>
      NeoCard(
        tone: tone,
        dense: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(scheduleDuration(duration), style: NeoType.section),
            Text(label, style: NeoType.caption),
          ],
        ),
      );

  List<Widget> _failure(SchedulingReview state) {
    final result = _result!;
    return [
      DemoHeading('Tak ada slot yang cocok', subtitle: state.task.title),
      PreviewNotice(
        title: 'Kendala pencarian',
        message: _failureReason(result),
        warning: true,
      ),
      DemoFacts([
        ('Estimasi sisa disetujui', scheduleDuration(state.confirmedRemaining)),
        ('Tenggat', _deadline(state)),
        ('Durasi minimum per sesi', '$_minimum menit'),
        ('Jumlah maksimum sesi', '$_maximum sesi'),
      ]),
      NeoButton(
        label: 'Sesuaikan batas sesi',
        onPressed: () => setState(() => _step = _Step.setup),
      ),
      const Text(
        'Kamu bisa mengurangi durasi minimum atau menambah jumlah maksimum sesi.',
      ),
      if (_action == ScheduleAction.replanConflicts ||
          _action == ScheduleAction.reduce)
        NeoButton(
          label: 'Optimasi ulang semua sesi mendatang',
          variant: NeoButtonVariant.secondary,
          onPressed: () => _search(state, ScheduleAction.replanAll),
        ),
      NeoButton(
        label: 'Jadwalkan secara manual',
        variant: NeoButtonVariant.secondary,
        onPressed: () async {
          await widget.onManual(null);
          if (mounted) {
            setState(() => _step = _Step.setup);
            await _load();
          }
        },
      ),
      NeoButton(
        label: 'Kembali ke tugas',
        variant: NeoButtonVariant.secondary,
        onPressed: () => Navigator.pop(context),
      ),
    ];
  }

  Widget _slot(
    SchedulingReview state,
    SchedulingSlot slot,
    String label, {
    bool warning = false,
    bool proposed = false,
    Widget? action,
  }) {
    final zone = state.zones.displayId;
    final start = state.zones.wall(slot.start, zone);
    final end = state.zones.wall(slot.end, zone);
    final startZone = state.zones.abbreviation(slot.start, zone);
    final endZone = state.zones.abbreviation(slot.end, zone);
    final shownZone = startZone == zone && endZone == zone
        ? zone
        : '$zone ($startZone${endZone == startZone ? '' : '–$endZone'})';
    return NeoCard(
      tone: warning
          ? NeoCardTone.warning
          : proposed
          ? NeoCardTone.selected
          : NeoCardTone.plain,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateLabel(start, long: true), style: NeoType.item),
          Text(
            '${clockLabel(minutesAt(start))}–${dateOnly(start) == dateOnly(end) ? clockLabel(minutesAt(end)) : '${dateLabel(end)} ${clockLabel(minutesAt(end))}'} · $shownZone',
          ),
          Text('$label · ${scheduleDuration(slotDuration(slot))}'),
          ?action,
        ],
      ),
    );
  }
}

String scheduleDuration(Duration? duration, {String empty = 'Belum diisi'}) {
  if (duration == null) return empty;
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  return [
    if (hours > 0) '$hours jam',
    if (minutes > 0 || duration == Duration.zero) '$minutes menit',
    if (seconds > 0) '$seconds detik',
    if (duration > Duration.zero && duration.inSeconds == 0) '< 1 detik',
  ].join(' ');
}

String scheduleMismatch(Duration difference) => difference == Duration.zero
    ? 'Sesuai'
    : '${difference.isNegative ? 'Lebih' : 'Kurang'} ${scheduleDuration(difference.abs())}';

String _deadline(SchedulingReview state) {
  final deadline = state.deadline;
  if (deadline == null) return 'Belum diisi';
  final zone = state.task.deadline!.mode == TimeMode.originalZone
      ? state.task.deadline!.zoneId
      : state.zones.deviceId;
  final wall = state.zones.wall(deadline, zone);
  return '${dateLabel(wall, year: true)} · ${clockLabel(minutesAt(wall))} · $zone';
}

String _hours(SchedulingReview state) {
  const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  final groups = <DailyHours, List<String>>{};
  for (final day in List.generate(7, (index) => index + 1)) {
    if (state.hours[day] case final hours?) {
      groups.putIfAbsent(hours, () => []).add(days[day - 1]);
    }
  }
  return [
    for (final entry in groups.entries)
      '${entry.value.join(', ')} ${clockLabel(entry.key.startMinute)}–'
          '${entry.key.endMinute == 1440 ? '24.00' : clockLabel(entry.key.endMinute)}',
    state.zones.deviceId,
  ].join('\n');
}

String _actionLabel(ScheduleAction action) => switch (action) {
  ScheduleAction.add => 'Tambahkan sesi',
  ScheduleAction.reduce => 'Kurangi sesi',
  ScheduleAction.replanConflicts => 'Hanya sesi bentrok',
  ScheduleAction.replanAll => 'Seluruh sesi mendatang',
};

String _problem(SchedulingProblem problem) => switch (problem) {
  SchedulingProblem.estimate => 'Konfirmasi estimasi sisa terlebih dahulu.',
  SchedulingProblem.deadline => 'Tenggat harus masih akan datang.',
  SchedulingProblem.limits =>
    'Isi durasi minimum dan jumlah maksimum sesi untuk pencarian.',
  SchedulingProblem.scope =>
    'Sesi bentrok yang dapat dipindah sudah berubah. Tinjau kembali jadwal.',
  SchedulingProblem.adjustment =>
    'Pilihan ini belum menghasilkan perubahan yang sesuai. Tinjau estimasi, cakupan, atau jadwal manual.',
};

String _failureReason(SlotSearchResult result) => switch (result.failure) {
  SlotFailure.activeHours =>
    'Tidak ada jendela jam aktif yang bisa dipakai sebelum tenggat.',
  SlotFailure.busy => 'Seluruh jam aktif sebelum tenggat terisi jadwal sibuk.',
  SlotFailure.buffer =>
    'Jeda sebelum atau sesudah kegiatan mengurangi ruang yang bisa dipakai.',
  SlotFailure.insufficient =>
    'Total waktu yang bisa dipakai hanya ${scheduleDuration(result.available)}.',
  SlotFailure.minimum =>
    'Durasi minimum membuat potongan waktu kosong tidak dapat digabungkan untuk mencapai estimasi.',
  SlotFailure.maximum =>
    'Batas jumlah sesi tidak cukup untuk menampung estimasi dalam slot yang tersedia.',
  null => '',
};
