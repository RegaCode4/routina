import 'package:flutter/material.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

import 'package:routina/presentation/demo/demo_session.dart';
import 'package:routina/presentation/demo/demo_widgets.dart';

class DemoTrashScreen extends StatelessWidget {
  const DemoTrashScreen(this.demo, {super.key});
  final DemoSession demo;

  Future<List<(String, String, DateTime?)>> _storedItems() async {
    final taskItems = await demo.planner.taskWorkspace!.trash();
    final eventItems = await demo.planner.readTrashedActivities();
    return [
      for (final item in taskItems) (item.title, 'Tugas', item.deletedAt),
      for (final item in eventItems) (item.title, 'Kegiatan', null),
    ];
  }

  Future<void> _restore(BuildContext context, DemoTrash item) async {
    final event = item.event;
    final conflict =
        demo.scenario == 'trash-conflict' ||
        event != null &&
            previewWarnings(
              demo.planner,
              event,
            ).contains(ScheduleWarning.overlap) ||
        (item.task?.upcoming.any(
              (slot) => demo.planner.events.any(
                (event) =>
                    event.kind != PreviewKind.deadline &&
                    event.state != PreviewEventState.trashed &&
                    event.start.isBefore(slot.end) &&
                    slot.start.isBefore(event.end),
              ),
            ) ??
            false);
    final choices = await demoSheet<String>(
      context,
      conflict ? 'Pemulihan bentrok dengan jadwal' : 'Pulihkan item?',
      (sheet) => [
        NeoButton(
          label: conflict ? 'Pulihkan dengan bentrok' : 'Pulihkan',
          onPressed: () => Navigator.pop(sheet, 'restore'),
        ),
        if (conflict && event != null)
          NeoButton(
            label: 'Pilih tanggal lain',
            variant: NeoButtonVariant.secondary,
            onPressed: () => Navigator.pop(sheet, 'move'),
          ),
        NeoButton(
          label: 'Batal',
          variant: NeoButtonVariant.secondary,
          onPressed: () => Navigator.pop(sheet),
        ),
      ],
      description: conflict
          ? '${item.title}. Jadwal lain tetap ada setelah pemulihan.'
          : '${item.title} akan muncul kembali di daftar pratinjau.',
    );
    if (!context.mounted || choices == null) return;
    DateTime? date;
    if (choices == 'move') {
      date = await pickPreviewDate(context, demo.today, selected: event?.start);
      if (!context.mounted || date == null || event == null) return;
      final start = date.add(Duration(minutes: minutesAt(event.start)));
      final moved = PreviewEvent(
        id: event.id,
        title: event.title,
        start: start,
        end: start.add(event.end.difference(event.start)),
        options: event.options,
      );
      if (previewWarnings(
        demo.planner,
        moved,
      ).contains(ScheduleWarning.overlap)) {
        demoFeedback(
          context,
          'Tanggal baru masih bentrok. Pilih tanggal lain.',
        );
        return;
      }
    }
    demo.restore(item, moveTo: date);
    demoFeedback(context, 'Item dipulihkan ke pratinjau.');
  }

  @override
  Widget build(BuildContext context) {
    if (demo.planner.taskWorkspace != null) {
      return _LocalTrash(read: _storedItems);
    }
    return ListenableBuilder(
      listenable: demo,
      builder: (context, _) {
        final items = demo.bin;
        final status = demoFeed(demo, 'trash', 'Tempat Sampah');
        return PreviewPage(
          title: 'Tempat Sampah',
          body: DemoList([
            const DemoHeading(
              'Pulihkan item terhapus',
              subtitle: 'Retensi contoh · 30 hari sejak tanggal penghapusan.',
            ),
            if (status != null)
              status
            else if (items.isEmpty)
              const PreviewNotice(
                title: 'Tempat Sampah kosong',
                message:
                    'Item yang dihapus dari pratinjau akan muncul di sini.',
                icon: Icons.delete_outline,
              )
            else
              for (final item in items) _item(context, item),
          ]),
        );
      },
    );
  }

  Widget _item(BuildContext context, DemoTrash item) {
    final days =
        demo.scenario == 'trash-expired' && item == demo.trash.lastOrNull
        ? 0
        : shiftDay(item.deleted, 30).difference(demo.today).inDays;
    final expired = days <= 0;
    return NeoCard(
      tone: days <= 3 ? NeoCardTone.warning : NeoCardTone.plain,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(item.title, style: NeoType.item),
          Text(
            '${item.kind} · Dihapus ${dateLabel(item.deleted)}',
            style: NeoType.caption,
          ),
          Text(
            expired ? 'Retensi kedaluwarsa' : 'Sisa $days hari',
            style: NeoType.numericCaption,
          ),
          const SizedBox(height: NeoSpace.sm),
          Wrap(
            spacing: NeoSpace.xs,
            runSpacing: NeoSpace.xs,
            children: [
              NeoButton(
                label: 'Pulihkan',
                variant: NeoButtonVariant.secondary,
                onPressed: expired ? null : () => _restore(context, item),
              ),
              NeoButton(
                label: 'Hapus Permanen',
                variant: NeoButtonVariant.danger,
                onPressed: () async {
                  final approved = await showNeoDialog(
                    context,
                    title: 'Hapus item secara permanen?',
                    message:
                        '${item.title} tidak dapat dipulihkan dari pratinjau setelah dihapus.',
                    confirmLabel: 'Hapus Permanen',
                    danger: true,
                  );
                  if (context.mounted && approved == true) {
                    demo.removePermanently(item);
                    demoFeedback(
                      context,
                      'Item dihapus permanen dari pratinjau.',
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocalTrash extends StatefulWidget {
  const _LocalTrash({required this.read});
  final Future<List<(String, String, DateTime?)>> Function() read;

  @override
  State<_LocalTrash> createState() => _LocalTrashState();
}

class _LocalTrashState extends State<_LocalTrash> {
  late var _items = widget.read();

  @override
  Widget build(BuildContext context) => PreviewPage(
    title: 'Tempat Sampah',
    body: FutureBuilder<List<(String, String, DateTime?)>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Memuat Tempat Sampah',
            ),
          );
        }
        final items = snapshot.data ?? const [];
        return DemoList([
          if (snapshot.hasError)
            PreviewNotice(
              title: 'Tempat Sampah gagal dimuat',
              message: 'Coba baca lagi data lokal.',
              button: NeoButton(
                label: 'Coba lagi',
                onPressed: () => setState(() {
                  _items = widget.read();
                }),
              ),
            )
          else if (items.isEmpty)
            const PreviewNotice(
              title: 'Tempat Sampah kosong',
              message: 'Tugas dan kegiatan yang dihapus akan muncul di sini.',
            )
          else
            for (final (title, kind, removed) in items)
              NeoCard(
                dense: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: NeoType.item),
                    Text(
                      removed == null
                          ? kind
                          : '$kind · Dihapus ${dateLabel(removed.toLocal())}',
                      style: NeoType.caption,
                    ),
                  ],
                ),
              ),
        ]);
      },
    ),
  );
}
