import 'package:flutter/material.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/design_system/neo_badges.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/event_editor.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

class EventDetail extends StatefulWidget {
  const EventDetail({required this.repository, required this.id, super.key});
  final PlannerPreviewRepository repository;
  final String id;
  @override
  State<EventDetail> createState() => _EventDetailState();
}

class _EventDetailState extends State<EventDetail> {
  PreviewEvent get _event =>
      widget.repository.events.firstWhere((event) => event.id == widget.id);

  Future<void> _edit({bool replacement = false}) async {
    final event = _event;
    final scope = !replacement && event.series != null
        ? await _scope('Edit kegiatan berulang')
        : null;
    if (!mounted || (!replacement && event.series != null && scope == null)) {
      return;
    }
    await Navigator.of(context).push<PreviewEvent>(
      MaterialPageRoute(
        builder: (_) => EventEditor(
          repository: widget.repository,
          full: true,
          scope: scope,
          draft: replacement
              ? EventDraft(title: event.title)
              : EventDraft.fromEvent(event),
        ),
      ),
    );
    if (mounted) setState(() {});
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
      message: '${event.title}${scope == null ? '' : ' · ${scope.label}'}',
      confirmLabel: 'Hapus kegiatan',
      danger: true,
    );
    if (mounted && yes == true) {
      setState(
        () => widget.repository.setEventState(
          event.id,
          PreviewEventState.trashed,
          scope: scope,
        ),
      );
    }
  }

  Future<void> _outcome() async {
    final event = _event;
    final choice = await previewChoices(context, 'Bagaimana hasilnya?', [
      PreviewEventState.done,
      PreviewEventState.postponed,
      PreviewEventState.skipped,
    ], (value) => badgeFor(value)!.label);
    if (!mounted || choice == null) return;
    setState(() => widget.repository.setEventState(event.id, choice));
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
              onPressed: () => _edit(replacement: true),
            )
          else if (state == PreviewEventState.pending)
            NeoButton(label: 'Konfirmasi hasil', onPressed: _outcome)
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
            onPressed: trash || outcome
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
            state == PreviewEventState.exception
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

  Future<void> _showTrash(BuildContext context) => showNeoBottomSheet<void>(
    context,
    builder: (_) => NeoBottomSheet(
      title: 'Tempat Sampah · pratinjau',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final event in widget.repository.events.where(
            (event) => event.state == PreviewEventState.trashed,
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: NeoSpace.sm),
              child: Text(event.title),
            ),
        ],
      ),
    ),
  );
}
