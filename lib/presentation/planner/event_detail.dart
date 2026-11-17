import 'package:flutter/material.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/application/calendar_zones.dart';
import 'package:routina/domain/planner_store.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/design_system/neo_badges.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/event_editor.dart';
import 'package:routina/presentation/planner/preview_ui.dart';
import 'package:routina/presentation/planner/trash_screen.dart';

class EventDetail extends StatefulWidget {
  const EventDetail({
    required this.repository,
    required this.id,
    this.initial,
    this.categories,
    super.key,
  });
  final PlannerPreviewRepository repository;
  final String id;
  final PreviewEvent? initial;
  final Map<String, String>? categories;
  @override
  State<EventDetail> createState() => _EventDetailState();
}

class _EventDetailState extends State<EventDetail> {
  late PreviewEvent _event =
      widget.initial ??
      widget.repository.events.firstWhere((event) => event.id == widget.id);
  bool _busy = false;

  Future<void> _edit({bool replacement = false}) async {
    final event = _event;
    final scope = !replacement && event.series != null
        ? await _scope('Edit kegiatan berulang')
        : null;
    if (!mounted || (!replacement && event.series != null && scope == null)) {
      return;
    }
    final saved = await Navigator.of(context).push<PreviewEvent>(
      MaterialPageRoute(
        builder: (_) => EventEditor(
          repository: widget.repository,
          full: true,
          scope: scope,
          categories: widget.categories,
          draft: replacement
              ? _replacementDraft(event)
              : EventDraft.fromEvent(event),
        ),
      ),
    );
    if (!mounted || saved == null) return;
    if (replacement) {
      _feedback('Jadwal pengganti tersimpan.');
    } else {
      setState(() => _event = saved);
    }
  }

  EventDraft _replacementDraft(PreviewEvent event) =>
      EventDraft.fromEvent(event)
        ..id = ''
        ..series = null
        ..recurrenceKey = null
        ..supersedesId = event.id
        ..state = PreviewEventState.upcoming
        ..recurrence = 'Sekali'
        ..rule = null
        ..date = null
        ..endDate = null
        ..start = null
        ..end = null;

  Future<void> _replace() async {
    final event = _event;
    final choice = await previewChoices(context, 'Jadwal pengganti', [
      'Pilih tanggal manual',
      if (widget.repository.usesStoredCalendar && !event.allDay)
        'Cari slot pengganti',
      'Jadwalkan nanti',
    ], (item) => item);
    if (!mounted || choice == null || choice == 'Jadwalkan nanti') return;
    if (choice == 'Pilih tanggal manual') {
      await _edit(replacement: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final proposal = await widget.repository.suggestReplacement(event);
      if (!mounted) return;
      if (proposal == null) {
        _feedback(
          'Belum ada slot pengganti dalam tujuh hari. Pilih tanggal manual.',
        );
        return;
      }
      final zones = CalendarZones(
        deviceZoneId: proposal.deviceZone,
        displayZoneId: proposal.displayZone,
      );
      final start = zones.wall(proposal.slot.start, proposal.displayZone);
      final end = zones.wall(proposal.slot.end, proposal.displayZone);
      final accepted = await showNeoDialog(
        context,
        title: 'Tinjau slot pengganti',
        message:
            '${dateLabel(start)} · ${clockLabel(minutesAt(start))}–${clockLabel(minutesAt(end))}',
        confirmLabel: 'Setujui & Simpan',
      );
      if (!mounted || accepted != true) return;
      await widget.repository.approveReplacement(proposal);
      if (mounted) _feedback('Jadwal pengganti tersimpan.');
    } on StaleRecord {
      if (mounted) _feedback('Kalender berubah. Cari slot pengganti lagi.');
    } catch (_) {
      if (mounted) _feedback('Slot pengganti belum dapat dibaca.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _feedback(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _change(PreviewEventState state, {SeriesScope? scope}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.repository.changeActivity(
        _event,
        state,
        scope: scope,
      );
      if (mounted) setState(() => _event = updated);
    } catch (error) {
      if (mounted) {
        _feedback(switch (error) {
          TrashProblem.alreadyArchived =>
            'Seri ini masih memiliki cakupan di Tempat Sampah.',
          StateError() => error.message,
          _ => 'Perubahan belum dapat disimpan. Coba lagi.',
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<SeriesScope?> _scope(String title) => previewChoices(
    context,
    title,
    SeriesScope.values,
    (value) => value.label,
  );

  Future<void> _delete() async {
    final event = _event;
    final scope = event.series == null
        ? null
        : await _scope('Hapus kegiatan berulang');
    if (!mounted || (event.series != null && scope == null)) return;
    final yes = await showNeoDialog(
      context,
      title: 'Pindahkan ke Tempat Sampah?',
      message:
          '${event.title}${scope == null ? '' : ' · ${scope.label}'}${widget.repository.usesStoredCalendar && scope != null && scope != SeriesScope.occurrence ? '\nPerubahan cakupan berlaku pada kejadian mendatang. Riwayat tetap tersedia.' : ''}',
      confirmLabel: 'Hapus kegiatan',
      danger: true,
    );
    if (mounted && yes == true) {
      await _change(PreviewEventState.trashed, scope: scope);
    }
  }

  Future<void> _outcome() async {
    final choice = await previewChoices(context, 'Bagaimana hasilnya?', [
      PreviewEventState.done,
      PreviewEventState.postponed,
      PreviewEventState.skipped,
    ], (value) => badgeFor(value)!.label);
    if (!mounted || choice == null) return;
    await _change(choice);
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final state = event.state;
    final badge = badgeFor(state);
    final outcome =
        state == PreviewEventState.postponed ||
        state == PreviewEventState.skipped;
    final trash = state == PreviewEventState.trashed;
    return PreviewPage(
      title: 'Detail kegiatan',
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (trash)
            NeoButton(
              label: 'Lihat Tempat Sampah',
              onPressed: () => _showTrash(context),
            )
          else if (outcome)
            NeoButton(
              label: 'Jadwalkan pengganti',
              onPressed: _busy ? null : _replace,
            )
          else if (state == PreviewEventState.pending)
            NeoButton(
              label: 'Konfirmasi hasil',
              onPressed: _busy ? null : _outcome,
            )
          else if (state == PreviewEventState.done &&
              widget.repository.usesStoredCalendar)
            NeoButton(label: 'Kembali', onPressed: () => Navigator.pop(context))
          else
            NeoButton(label: 'Edit kegiatan', onPressed: _edit),
          const SizedBox(height: NeoSpace.sm),
          NeoButton(
            variant: NeoButtonVariant.secondary,
            label: trash || outcome
                ? 'Kembali'
                : state == PreviewEventState.pending
                ? 'Edit kegiatan'
                : 'Hapus kegiatan',
            onPressed: _busy
                ? null
                : trash || outcome
                ? () => Navigator.pop(context)
                : state == PreviewEventState.pending
                ? _edit
                : _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(NeoSpace.page),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: badge != null
                ? StatusBadge(status: badge)
                : DecoratedBox(
                    decoration: const BoxDecoration(
                      color: NeoColors.blueTint,
                      borderRadius: NeoRadius.small,
                      border: Border.fromBorderSide(NeoLine.thin),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: NeoSpace.xs,
                        vertical: NeoSpace.xxs,
                      ),
                      child: Text(switch (state) {
                        PreviewEventState.trashed => 'Di Tempat Sampah',
                        PreviewEventState.exception => 'Pengecualian seri',
                        _ => 'Belum dimulai',
                      }, style: NeoType.badge),
                    ),
                  ),
          ),
          const SizedBox(height: NeoSpace.sm),
          if (event.isException)
            const Text('Pengecualian seri', style: NeoType.badge),
          Text(event.title, style: NeoType.display),
          const SizedBox(height: NeoSpace.md),
          NeoCard(
            tone: NeoCardTone.selected,
            emphasis: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: NeoSize.navIcon,
                    ),
                    const SizedBox(width: NeoSpace.xs),
                    Expanded(
                      child: Text(
                        dateLabel(event.start, long: true, year: true),
                        style: NeoType.item,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: NeoSpace.md),
                Text(
                  eventTime(event),
                  style: NeoType.metric.copyWith(
                    fontSize: event.allDay ? 20 : 29,
                  ),
                ),
                const SizedBox(height: NeoSpace.sm),
                Text(event.options.zone, style: NeoType.caption),
              ],
            ),
          ),
          const SizedBox(height: NeoSpace.md),
          _fact('Kategori', event.options.category),
          _fact(
            'Pengulangan',
            state == PreviewEventState.exception || event.isException
                ? 'Hanya kejadian ini'
                : event.options.recurrence,
          ),
          _fact('Lokasi', event.options.location),
          if (event.options.description.isNotEmpty) ...[
            const SizedBox(height: NeoSpace.sm),
            Text(event.options.description, style: NeoType.caption),
          ],
          if (event.options.note.isNotEmpty)
            _fact('Catatan', event.options.note),
          if (event.options.link.isNotEmpty)
            _fact('Tautan', event.options.link),
          if (outcome) ...[
            const SizedBox(height: NeoSpace.md),
            const PreviewNotice(
              title: 'Kejadian asal tetap tercatat',
              message: 'Tinjau jadwal pengganti bila diperlukan.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _fact(String label, String value) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: NeoSpace.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: NeoType.caption.copyWith(color: NeoColors.muted),
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '—' : value,
                style: NeoType.caption.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
      const Divider(height: 1, color: NeoColors.line),
    ],
  );

  Future<void> _showTrash(BuildContext context) async {
    if (widget.repository.trashWorkspace case final workspace?) {
      var changed = false;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TrashScreen(
            workspace: workspace,
            onChanged: () => changed = true,
          ),
        ),
      );
      if (context.mounted && changed) Navigator.of(context).pop();
      return;
    }
    List<PreviewEvent> entries;
    try {
      entries = await widget.repository.readTrashedActivities();
    } catch (_) {
      if (context.mounted) _feedback('Tempat Sampah belum dapat dibaca.');
      return;
    }
    if (!context.mounted) return;
    await showNeoBottomSheet<void>(
      context,
      builder: (_) => NeoBottomSheet(
        title: widget.repository.usesStoredCalendar
            ? 'Tempat Sampah'
            : 'Tempat Sampah · pratinjau',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final event in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: NeoSpace.sm),
                child: Text(event.title),
              ),
          ],
        ),
      ),
    );
  }
}
