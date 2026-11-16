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
import 'package:routina/presentation/demo/tasks.dart' show demoManualSlot;

enum SmartEntry { wizard, conflict, mismatch }

enum _Step { wizard, proposals, blocked, conflict, mismatch }

class DemoSmart extends StatefulWidget {
  const DemoSmart(
    this.demo,
    this.task, {
    this.entry = SmartEntry.wizard,
    super.key,
  });
  final DemoSession demo;
  final DemoTask task;
  final SmartEntry entry;
  @override
  State<DemoSmart> createState() => _DemoSmartState();
}

class _DemoSmartState extends State<DemoSmart> {
  final form = GlobalKey<FormState>();
  late final demo = widget.demo;
  late final task = widget.task;
  late _Step step = switch (widget.entry) {
    SmartEntry.wizard => _Step.wizard,
    SmartEntry.conflict => _Step.conflict,
    SmartEntry.mismatch => _Step.mismatch,
  };
  late int estimate = task.remaining ?? task.estimate ?? 60;
  int minimum = 25;
  int maximum = 120;
  String preference = 'Jam aktif';
  String? issue;
  String blocked = '';
  bool busy = false;
  bool stale = false;
  bool skipFixture = false;
  bool reduce = false;
  int selected = 0;
  int revision = 0;
  int? confirmedEstimate;
  late bool wholeEstimate = widget.entry == SmartEntry.wizard;
  List<DemoSlot> replace = [];
  List<List<DemoSlot>> proposals = [];

  DateTime? _previewStart(int length, {DateTime? after}) {
    final until = task.deadline;
    if (until == null) return null;
    final first = after?.add(Duration(minutes: 2 * demo.buffer)) ?? demo.today;
    for (var offset = 0; offset < 7; offset++) {
      final day = shiftDay(dateOnly(first), offset);
      if (day.isAfter(until)) break;
      final active =
          demo.planner.profile?.activeHours[day.weekday] ??
          const ActiveInterval(8 * 60, 21 * 60);
      final bounds = switch (preference) {
        'Pagi' => (360, 720),
        'Siang' => (720, 900),
        'Sore' => (900, 1140),
        'Malam' => (1140, 1440),
        _ => (0, 1440),
      };
      final begin = active.start > bounds.$1 ? active.start : bounds.$1;
      final end = active.end < bounds.$2 ? active.end : bounds.$2;
      for (var minute = begin; minute + length <= end; minute += 15) {
        final start = day.add(Duration(minutes: minute));
        final slot = DemoSlot(start, length);
        if (!start.isBefore(first) &&
            !slot.end.isAfter(until) &&
            !_conflicts(slot)) {
          return start;
        }
      }
    }
    return null;
  }

  bool _conflicts(DemoSlot slot) {
    final start = slot.start.subtract(Duration(minutes: demo.buffer));
    final end = slot.end.add(Duration(minutes: demo.buffer));
    bool overlaps(DateTime otherStart, DateTime otherEnd) =>
        start.isBefore(otherEnd) && end.isAfter(otherStart);
    final replacedIds = replace.map((item) => item.eventId).nonNulls.toSet();
    return demo.planner.events.any(
          (entry) =>
              !replacedIds.contains(entry.id) &&
              entry.state != PreviewEventState.trashed &&
              entry.kind != PreviewKind.deadline &&
              entry.options.availability != DayAvailability.free &&
              overlaps(
                entry.start.subtract(Duration(minutes: entry.options.before)),
                entry.end.add(Duration(minutes: entry.options.after)),
              ),
        ) ||
        task.upcoming.any(
          (entry) =>
              entry.eventId == null &&
              !replace.contains(entry) &&
              overlaps(entry.start, entry.end),
        );
  }

  Future<void> _find() async {
    if (busy || !(form.currentState?.validate() ?? false)) return;
    if (minimum > maximum) {
      setState(
        () => issue =
            'Durasi minimum harus lebih kecil atau sama dengan maksimum.',
      );
      return;
    }
    final accepted = await showNeoDialog(
      context,
      title: 'Konfirmasi estimasi sisa',
      message:
          'Cari usulan untuk $estimate menit dengan batas $minimum–$maximum menit per sesi.',
      confirmLabel: 'Konfirmasi estimasi',
    );
    if (!mounted || accepted != true) return;
    setState(() {
      confirmedEstimate = estimate;
      busy = true;
      issue = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    _calculate();
  }

  void _calculate() {
    final found = <List<DemoSlot>>[];
    var reason = '';
    if (task.deadline == null) {
      reason = 'Tentukan deadline tugas sebelum mencari sesi.';
    } else if (!skipFixture && demo.scenario == 'smart-no-slot') {
      reason = 'Jam aktif yang tersisa terisi jadwal contoh dan buffer.';
    } else if (estimate < minimum) {
      reason = 'Estimasi lebih kecil dari batas minimum sesi.';
    } else {
      final single = estimate <= maximum ? _previewStart(estimate) : null;
      if (single != null) {
        found.add([DemoSlot(single, estimate)]);
      }
      final count = estimate <= maximum ? 2 : (estimate / maximum).ceil();
      final segment = estimate ~/ count;
      if (count <= 8 && segment >= minimum) {
        final split = <DemoSlot>[];
        for (var i = 0; i < count; i++) {
          final length = segment + (i < estimate % count ? 1 : 0);
          final start = _previewStart(length, after: split.lastOrNull?.end);
          if (start == null) break;
          split.add(DemoSlot(start, length));
        }
        if (split.length == count) found.add(split);
      } else if (estimate > maximum) {
        reason =
            'Kombinasi batas minimum, maksimum, dan jumlah sesi contoh tidak menampung estimasi.';
      }
    }
    setState(() {
      busy = false;
      blocked = reason.isNotEmpty
          ? reason
          : 'Tidak ada rentang yang memenuhi jam aktif, buffer, deadline, dan durasi sesi.';
      revision = demo.revision;
      proposals = found;
      selected = 0;
      stale = false;
      step = found.isEmpty ? _Step.blocked : _Step.proposals;
    });
  }

  Future<void> _approve() async {
    final candidate = proposals[selected];
    final approved = await demoSheet<bool>(
      context,
      'Tinjau usulan jadwal',
      (sheet) => [
        for (final slot in replace)
          DemoFacts([
            ('Sesi lama', demoSlotLabel(slot)),
            ('Durasi', '${slot.minutes} menit'),
          ]),
        for (final slot in candidate)
          DemoFacts([
            ('Sesi pengerjaan', demoSlotLabel(slot)),
            ('Durasi', '${slot.minutes} menit'),
          ]),
        if (replace.isNotEmpty)
          Text(
            '${replace.length} sesi mendatang akan diganti. Riwayat tetap tersimpan.',
          ),
        NeoButton(
          label: 'Setujui dan simpan jadwal',
          onPressed: () => Navigator.pop(sheet, true),
        ),
        NeoButton(
          label: 'Batal',
          variant: NeoButtonVariant.secondary,
          onPressed: () => Navigator.pop(sheet),
        ),
      ],
      description: 'Konfirmasi untuk memasukkan usulan ke kalender pratinjau.',
    );
    if (!mounted || approved != true) return;
    if (demo.revision != revision ||
        candidate.any((slot) {
          final active = demo.planner.profile?.activeHours[slot.start.weekday];
          return _conflicts(slot) ||
              task.deadline == null ||
              slot.end.isAfter(task.deadline!) ||
              (active != null &&
                  (minutesAt(slot.start) < active.start ||
                      minutesAt(slot.end) > active.end));
        }) ||
        (!skipFixture && demo.scenario == 'smart-stale')) {
      setState(() => stale = true);
      return;
    }
    demo.applySlots(task, candidate, replace: replace);
    if (wholeEstimate) {
      demo.change(() => task.remaining = confirmedEstimate);
    }
    Navigator.pop(context);
    demoFeedback(context, 'Usulan diterapkan ke jadwal pratinjau.');
  }

  void _wizard({
    List<DemoSlot> replacement = const [],
    int? base,
    bool? totalEstimate,
  }) => setState(() {
    replace = replacement;
    if (base != null) estimate = base;
    if (totalEstimate != null) wholeEstimate = totalEstimate;
    issue = null;
    step = _Step.wizard;
  });

  @override
  Widget build(BuildContext context) {
    final (title, body, footer) = switch (step) {
      _Step.wizard => (
        'Smart Scheduling',
        _wizardBody(),
        NeoButton(
          label: 'Konfirmasi estimasi',
          loading: busy,
          onPressed: busy ? null : _find,
        ),
      ),
      _Step.proposals => (
        'Usulan jadwal',
        _proposalsBody(),
        NeoButton(
          label: 'Tinjau dan setujui',
          onPressed: stale ? null : _approve,
        ),
      ),
      _Step.blocked => (
        'Tidak ada slot',
        _blockedBody(),
        NeoButton(
          label: 'Ubah batas sesi',
          onPressed: () {
            skipFixture = true;
            _wizard(replacement: replace);
          },
        ),
      ),
      _Step.conflict => ('Konflik jadwal', _conflictBody(), null),
      _Step.mismatch => ('Selisih durasi', _mismatchBody(), null),
    };
    return PreviewPage(title: title, body: body, footer: footer);
  }

  Widget _wizardBody() => Form(
    key: form,
    child: DemoList([
      DemoHeading('Cari waktu untuk fokus', subtitle: task.title),
      const Text(
        'Durasi aktual berasal dari riwayat sesi. Progres subtugas dihitung dari checklist.',
        style: NeoType.caption,
      ),
      DemoFacts([
        (
          'Deadline tugas',
          task.deadline == null
              ? 'Belum ditentukan'
              : '${dateLabel(task.deadline!)} · ${clockLabel(task.time!)} ${task.zone}',
        ),
      ], tone: NeoCardTone.highlighted),
      NeoFormField(
        label: wholeEstimate
            ? 'Estimasi sisa (menit)'
            : 'Durasi yang akan dijadwalkan (menit)',
        key: ValueKey('estimate-${replace.length}'),
        labelAbove: true,
        initialValue: '$estimate',
        keyboardType: TextInputType.number,
        onChanged: (value) => estimate = int.tryParse(value) ?? 0,
        validator: (_) =>
            estimate < 1 || estimate > 1440 ? 'Masukkan 1–1440 menit.' : null,
      ),
      NeoFormField(
        label: 'Minimum sesi (menit)',
        labelAbove: true,
        initialValue: '$minimum',
        keyboardType: TextInputType.number,
        onChanged: (value) => minimum = int.tryParse(value) ?? 0,
        validator: (_) =>
            minimum < 5 || minimum > 720 ? 'Masukkan 5–720 menit.' : null,
      ),
      NeoFormField(
        label: 'Maksimum sesi (menit)',
        labelAbove: true,
        initialValue: '$maximum',
        keyboardType: TextInputType.number,
        onChanged: (value) => maximum = int.tryParse(value) ?? 0,
        validator: (_) =>
            maximum < 5 || maximum > 720 ? 'Masukkan 5–720 menit.' : null,
      ),
      PreviewField(
        label: 'Preferensi waktu',
        value: preference,
        onTap: () => demoPick(context, 'Preferensi waktu', [
          'Jam aktif',
          'Pagi',
          'Siang',
          'Sore',
          'Malam',
        ], (value) => setState(() => preference = value)),
      ),
      if (issue case final message?)
        Text(message, style: const TextStyle(color: NeoColors.errorText)),
      const Text(
        'Pratinjau menggunakan jadwal dan batas contoh.',
        style: NeoType.caption,
      ),
    ]),
  );

  Widget _proposalsBody() => DemoList([
    const DemoHeading(
      'Pilih usulan jadwal',
      subtitle: 'Tinjau jumlah sesi dan durasi sebelum menyetujui.',
    ),
    NeoCard(
      tone: NeoCardTone.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Usulan · belum tersimpan', style: NeoType.item),
          const SizedBox(height: NeoSpace.xs),
          Text(
            '${proposals[selected].fold(0, (total, slot) => total + slot.minutes)} menit',
            style: NeoType.metric,
          ),
          Text(
            '${proposals[selected].length} sesi · Deadline ${dateLabel(task.deadline!)}',
            style: NeoType.caption,
          ),
        ],
      ),
    ),
    if (stale)
      PreviewNotice(
        title: 'Usulan sudah kedaluwarsa',
        message:
            'Jadwal berubah saat usulan diperiksa. Hitung ulang sebelum menyimpan.',
        warning: true,
        button: NeoButton(
          label: 'Hitung ulang',
          onPressed: () {
            skipFixture = true;
            _calculate();
          },
        ),
      ),
    for (var index = 0; index < proposals.length; index++)
      NeoCard(
        tone: selected == index ? NeoCardTone.selected : NeoCardTone.plain,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CategoryChip(
              label: proposals[index].length == 1
                  ? 'Satu sesi'
                  : 'Beberapa sesi',
              selected: selected == index,
              onSelected: (_) => setState(() => selected = index),
            ),
            for (final slot in proposals[index])
              Padding(
                padding: const EdgeInsets.only(top: NeoSpace.xs),
                child: Text(
                  '${demoSlotLabel(slot)} · ${slot.minutes} menit',
                  style: NeoType.caption,
                ),
              ),
          ],
        ),
      ),
    NeoButton(
      label: 'Ubah pengaturan',
      variant: NeoButtonVariant.secondary,
      onPressed: () => _wizard(replacement: replace),
    ),
  ]);

  Widget _blockedBody() => DemoList([
    const DemoHeading('Belum menemukan slot'),
    PreviewNotice(
      title: 'Sesi belum dapat dibuat',
      message: blocked,
      warning: true,
    ),
    const Text('Alternatif', style: NeoType.section),
    DemoRow(
      'Periksa jam aktif',
      icon: Icons.schedule,
      onTap: () => demoSheet<void>(
        context,
        'Jam aktif',
        (_) => [
          for (final item in demo.planner.profile!.activeHours.entries)
            Text(
              '${dayNames[item.key - 1]} · ${clockLabel(item.value.start)}–${clockLabel(item.value.end)}',
            ),
        ],
      ),
    ),
    DemoRow(
      'Tambah sesi manual',
      icon: Icons.edit_calendar,
      onTap: () => demoManualSlot(context, demo, task),
    ),
    DemoRow(
      'Coba semua jam aktif',
      icon: Icons.autorenew,
      onTap: () {
        preference = 'Jam aktif';
        skipFixture = true;
        _calculate();
      },
    ),
  ]);

  Widget _conflictBody() => DemoList([
    DemoHeading('Tinjau sesi yang bentrok', subtitle: task.title),
    const PreviewNotice(
      title: 'Jadwal perlu ditinjau',
      message:
          'Pilih cakupan untuk mencari usulan baru, atau pertahankan jadwal.',
      warning: true,
    ),
    for (final slot in task.slots)
      DemoFacts(
        [
          (
            slot.history
                ? 'Riwayat · hanya baca'
                : demo.slotConflicts(slot)
                ? 'Sesi terdampak'
                : 'Sesi lain',
            demoSlotLabel(slot),
          ),
          ('Durasi', '${slot.minutes} menit'),
        ],
        tone: demo.slotConflicts(slot)
            ? NeoCardTone.warning
            : NeoCardTone.plain,
      ),
    NeoButton(
      label: 'Atur ulang sesi terdampak',
      onPressed: () {
        final affected = task.upcoming.where(demo.slotConflicts).toList();
        final minutes = affected.fold(0, (sum, slot) => sum + slot.minutes);
        _wizard(replacement: affected, base: minutes);
      },
    ),
    NeoButton(
      label: 'Atur ulang semua sesi mendatang',
      variant: NeoButtonVariant.secondary,
      onPressed: () => _wizard(
        replacement: task.upcoming,
        base: task.upcoming.fold<int>(0, (total, slot) => total + slot.minutes),
      ),
    ),
    NeoButton(
      label: 'Pertahankan jadwal',
      variant: NeoButtonVariant.secondary,
      onPressed: () => Navigator.pop(context),
    ),
  ]);

  Widget _mismatchBody() {
    final planned = task.upcoming.fold(0, (sum, slot) => sum + slot.minutes);
    final remaining = task.remaining ?? 0;
    final difference = remaining - planned;
    return DemoList([
      DemoHeading('Bandingkan alokasi', subtitle: task.title),
      DemoPair(
        DemoFacts([
          ('Estimasi sisa disetujui', '$remaining menit'),
        ], tone: NeoCardTone.selected),
        DemoFacts([('Sesi mendatang terjadwal', '$planned menit')]),
      ),
      PreviewNotice(
        title: difference == 0
            ? 'Durasi sudah seimbang'
            : 'Selisih ${difference.abs() ~/ 60 > 0 ? '${difference.abs() ~/ 60} jam ' : ''}${difference.abs() % 60} menit',
        message: difference > 0
            ? 'Tambahkan waktu atau optimalkan kembali sesi mendatang.'
            : difference < 0
            ? 'Kurangi sebagian sesi atau pertahankan jadwal.'
            : 'Jadwal yang ada memenuhi estimasi sisa.',
      ),
      DemoFacts([
        ('Estimasi awal', '${task.estimate ?? '—'} menit'),
        ('Durasi aktual tercatat', '${task.actual} menit'),
      ]),
      if (difference > 0)
        NeoButton(
          label: 'Tambah sesi untuk selisih',
          onPressed: () async {
            final approved = await showNeoDialog(
              context,
              title: 'Sesuaikan selisih durasi?',
              message:
                  'Estimasi sisa $remaining menit dan jadwal mendatang $planned menit. Cari $difference menit tambahan sambil mempertahankan sesi yang ada.',
              confirmLabel: 'Cari waktu tambahan',
            );
            if (mounted && approved == true) _wizard(base: difference);
          },
        ),
      if (difference < 0)
        NeoButton(
          label: 'Kurangi sesi mendatang',
          onPressed: reduce ? null : () => _reduce(difference.abs()),
        ),
      if (remaining > 0)
        NeoButton(
          label: 'Optimalkan semua sesi',
          variant: NeoButtonVariant.secondary,
          onPressed: () => _wizard(replacement: task.upcoming, base: remaining),
        ),
      NeoButton(
        label: 'Pertahankan jadwal',
        variant: NeoButtonVariant.secondary,
        onPressed: () => Navigator.pop(context),
      ),
    ]);
  }

  Future<void> _reduce(int minutes) async {
    var excess = minutes;
    final targets = <DemoSlot>[];
    final shortened = <DemoSlot>[];
    for (final slot in task.upcoming.reversed) {
      if (excess == 0) break;
      targets.add(slot);
      if (slot.minutes > excess) {
        shortened.add(DemoSlot(slot.start, slot.minutes - excess));
        break;
      }
      excess -= slot.minutes;
    }
    setState(() => reduce = true);
    final accepted = await showNeoDialog(
      context,
      title: 'Kurangi durasi sesi?',
      message:
          'Kurangi $minutes menit dari sesi paling akhir. Riwayat sesi tetap tersimpan.',
      confirmLabel: 'Setujui pengurangan',
    );
    if (!mounted) return;
    setState(() => reduce = false);
    if (accepted == true) {
      demo.applySlots(task, shortened, replace: targets);
      Navigator.pop(context);
    }
  }
}
