import 'package:flutter/material.dart';
import 'package:routina/application/calendar_zones.dart';
import 'package:routina/application/trash_workspace.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

enum _TrashResult { restored, deleted }

enum _RecoveryChoice { approve, move }

class TrashScreen extends StatefulWidget {
  const TrashScreen({
    required this.workspace,
    required this.onChanged,
    super.key,
  });

  final TrashWorkspace workspace;
  final VoidCallback onChanged;

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  late Future<TrashList> _items = widget.workspace.list();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _reload);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _reload() {
    final items = widget.workspace.list();
    setState(() {
      _items = items;
    });
  }

  Future<void> _open(TrashItem item, TrashList list) async {
    final result = await Navigator.of(context).push<_TrashResult>(
      MaterialPageRoute(
        builder: (_) => _TrashDetail(
          workspace: widget.workspace,
          item: item,
          zone: list.zone,
        ),
      ),
    );
    if (!mounted) return;
    _reload();
    if (result == null) return;
    widget.onChanged();
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result == _TrashResult.restored
                ? 'Item dipulihkan.'
                : 'Item dihapus permanen.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => PreviewPage(
    title: 'Tempat Sampah',
    body: FutureBuilder<TrashList>(
      future: _items,
      builder: (context, snapshot) {
        final list = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.hasError ||
            list == null) {
          final failed = snapshot.connectionState == ConnectionState.done;
          return ListView(
            padding: const EdgeInsets.all(NeoSpace.page),
            children: [
              PreviewNotice(
                title: failed
                    ? 'Tempat Sampah belum dapat dibaca'
                    : 'Memuat Tempat Sampah',
                message: failed
                    ? 'Coba baca kembali data lokal.'
                    : 'Sedang membaca item yang dihapus.',
                warning: failed,
                loading: !failed,
                button: failed
                    ? NeoButton(label: 'Muat ulang', onPressed: _reload)
                    : null,
              ),
            ],
          );
        }
        return _list(list);
      },
    ),
  );

  Widget _list(TrashList list) {
    final zones = CalendarZones(deviceZoneId: list.zone);
    final expired = list.items.any(
      (item) => !item.entry.canRestoreAt(list.observedAt),
    );
    return ListView.builder(
      padding: const EdgeInsets.all(NeoSpace.page),
      itemCount: list.items.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Item yang dihapus', style: NeoType.display),
              const SizedBox(height: NeoSpace.xxs),
              const Text('Pulihkan item dalam masa retensi 30 hari.'),
              const SizedBox(height: NeoSpace.page),
              if (expired) ...[
                const PreviewNotice(
                  title: 'Masa retensi berakhir',
                  message:
                      'Item kedaluwarsa dapat dihapus permanen secara manual.',
                  warning: true,
                  icon: Icons.warning_amber_rounded,
                ),
                const SizedBox(height: NeoSpace.sm),
              ],
            ],
          );
        }
        if (index == list.items.length + 1) {
          return list.items.isEmpty
              ? const PreviewNotice(
                  title: 'Tempat Sampah kosong',
                  message:
                      'Kegiatan, tugas, dan rutinitas yang dihapus akan muncul di sini.',
                  icon: Icons.delete_outline,
                )
              : const Padding(
                  padding: EdgeInsets.only(top: NeoSpace.sm),
                  child: Text(
                    'Item di sini tersisih dari agenda, pengingat, dan KPI aktif.',
                    style: NeoType.caption,
                  ),
                );
        }
        final item = list.items[index - 1];
        final deleted = zones.wall(item.entry.deletedAt, list.zone);
        final days = _remainingDays(item.entry, list.observedAt);
        return Padding(
          padding: const EdgeInsets.only(bottom: NeoSpace.xs),
          child: NeoCard(
            dense: true,
            tone: days == 0
                ? NeoCardTone.warning
                : days <= 3
                ? NeoCardTone.highlighted
                : NeoCardTone.plain,
            onTap: () => _open(item, list),
            child: Row(
              children: [
                _KindIcon(item.kind),
                const SizedBox(width: NeoSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: NeoType.item),
                      const SizedBox(height: NeoSpace.xxs),
                      Text(
                        '${item.kind.label} · Dihapus ${dateLabel(deleted)} · ${days == 0 ? 'Kedaluwarsa' : 'Sisa $days hari'}',
                        style: NeoType.caption,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TrashDetail extends StatefulWidget {
  const _TrashDetail({
    required this.workspace,
    required this.item,
    required this.zone,
  });
  final TrashWorkspace workspace;
  final TrashItem item;
  final String zone;

  @override
  State<_TrashDetail> createState() => _TrashDetailState();
}

class _TrashDetailState extends State<_TrashDetail> {
  bool _busy = false;
  String? _error;

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      DateTime? targetDate;
      while (mounted) {
        final proposal = await widget.workspace.review(
          widget.item,
          moveTo: targetDate,
        );
        if (!mounted) return;
        final choice = await _review(proposal);
        if (!mounted || choice == null) return;
        if (choice == _RecoveryChoice.approve) {
          await widget.workspace.approve(proposal);
          if (mounted) Navigator.pop(context, _TrashResult.restored);
          return;
        }
        final zones = CalendarZones(
          deviceZoneId: proposal.check.deviceZone,
          displayZoneId: proposal.check.displayZone,
        );
        final today = dateOnly(
          zones.wall(widget.workspace.now(), zones.displayId),
        );
        final initial = targetDate ?? widget.item.scheduleDay;
        targetDate = await showDatePicker(
          context: context,
          helpText: 'Pilih tanggal kegiatan',
          firstDate: today,
          lastDate: DateTime(9999, 12, 31),
          initialDate: initial != null && !dateOnly(initial).isBefore(today)
              ? dateOnly(initial)
              : today,
          currentDate: today,
        );
        if (targetDate == null) return;
      }
    } catch (error) {
      if (mounted) setState(() => _error = _issue(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_RecoveryChoice?> _review(RecoveryProposal proposal) {
    final conflicts = proposal.check.conflicts.toList();
    final conflict = conflicts.isNotEmpty;
    final categories = proposal.check.removedCategories;
    return showNeoBottomSheet<_RecoveryChoice>(
      context,
      builder: (sheet) => NeoBottomSheet(
        title: conflict ? 'Pemulihan memicu bentrok' : 'Pulihkan item?',
        description: widget.item.title,
        leading: Icon(conflict ? Icons.warning_amber_rounded : Icons.restore),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (proposal.moveTo case final date?)
              Text('Tanggal kegiatan baru · ${dateLabel(date, year: true)}'),
            for (final match in conflicts.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: NeoSpace.xs),
                child: Text(
                  '${match.restoredTitle} · ${match.existingTitle}\n'
                  '${dateLabel(match.existingStart)} ${clockLabel(minutesAt(match.existingStart))}–${clockLabel(minutesAt(match.existingEnd))} · ${warningTitle(match.warning)}',
                ),
              ),
            if (conflicts.length > 6)
              Text('${conflicts.length - 6} bentrok lainnya.'),
            if (conflict) const Text('Jadwal lain tetap pada waktunya.'),
            if (categories.isNotEmpty)
              Text(
                'Kategori ${categories.join(', ')} sudah dihapus. Item terkait akan dipulihkan tanpa kategori.',
              ),
            if (proposal.check.checksRecurring)
              const Text(
                'Kejadian berulang diperiksa hingga 90 hari kalender dari kejadian pertama yang kembali.',
              ),
            const SizedBox(height: NeoSpace.md),
            NeoButton(
              label: conflict ? 'Pulihkan dengan bentrok' : 'Pulihkan',
              variant: conflict
                  ? NeoButtonVariant.danger
                  : NeoButtonVariant.primary,
              onPressed: () => Navigator.pop(sheet, _RecoveryChoice.approve),
            ),
            if (conflict && widget.item.canMove) ...[
              const SizedBox(height: NeoSpace.xs),
              NeoButton(
                label: 'Pilih tanggal lain',
                variant: NeoButtonVariant.secondary,
                onPressed: () => Navigator.pop(sheet, _RecoveryChoice.move),
              ),
            ],
            const SizedBox(height: NeoSpace.xs),
            NeoButton(
              label: 'Batal',
              variant: NeoButtonVariant.secondary,
              onPressed: () => Navigator.pop(sheet),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final item = widget.item;
    final approved = await showNeoDialog(
      context,
      title: 'Hapus item secara permanen?',
      message:
          '${item.title} beserta data miliknya akan dihapus dari perangkat. Tindakan ini tidak dapat dibatalkan.',
      confirmLabel: 'Hapus Permanen',
      danger: true,
    );
    if (!mounted || approved != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.workspace.permanentlyDelete(item);
      if (mounted) Navigator.pop(context, _TrashResult.deleted);
    } catch (error) {
      if (mounted) setState(() => _error = _issue(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final zone = widget.zone;
    final zones = CalendarZones(deviceZoneId: zone);
    final days = _remainingDays(item.entry, widget.workspace.now());
    final deleted = zones.wall(item.entry.deletedAt, zone);
    final expires = zones.wall(item.entry.expiresAt, zone);
    return PreviewPage(
      title: 'Item terhapus',
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NeoButton(
            label: 'Pulihkan ${item.kind.label.toLowerCase()}',
            loading: _busy,
            onPressed: days > 0 && !_busy ? _restore : null,
          ),
          const SizedBox(height: NeoSpace.sm),
          NeoButton(
            label: 'Hapus permanen',
            variant: NeoButtonVariant.secondary,
            onPressed: _busy ? null : _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(NeoSpace.page),
        children: [
          Text(item.title, style: NeoType.display),
          const SizedBox(height: NeoSpace.xxs),
          Text(
            '${item.kind.label} · Dihapus ${dateLabel(deleted, year: true)}',
          ),
          const SizedBox(height: NeoSpace.page),
          NeoCard(
            tone: days == 0 ? NeoCardTone.warning : NeoCardTone.highlighted,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  days == 0 ? Icons.warning_amber_rounded : Icons.access_time,
                ),
                const SizedBox(width: NeoSpace.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        days == 0
                            ? 'Masa retensi berakhir'
                            : 'Sisa retensi $days hari',
                        style: NeoType.item,
                      ),
                      const SizedBox(height: NeoSpace.xxs),
                      Text(
                        'Batas pemulihan ${dateLabel(expires, year: true)} ${clockLabel(minutesAt(expires))} · $zone',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (item.scheduleDay case final date?) ...[
            const SizedBox(height: NeoSpace.md),
            Text(switch (item.kind) {
              TrashKind.task => 'Tenggat · ${dateLabel(date, year: true)}',
              TrashKind.series =>
                'Cakupan mulai · ${dateLabel(date, year: true)}',
              _ => 'Jadwal asal · ${dateLabel(date, year: true)}',
            }),
          ],
          if (item.category case final category?) ...[
            const SizedBox(height: NeoSpace.xs),
            Text('Kategori · $category'),
          ],
          if (item.description case final description?
              when description.trim().isNotEmpty) ...[
            const SizedBox(height: NeoSpace.xs),
            Text(description),
          ],
          if (_error case final message?) ...[
            const SizedBox(height: NeoSpace.md),
            PreviewNotice(
              title: 'Perubahan belum disimpan',
              message: message,
              warning: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _KindIcon extends StatelessWidget {
  const _KindIcon(this.kind);
  final TrashKind kind;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (kind) {
      TrashKind.event => (Icons.event_outlined, NeoColors.blueTint),
      TrashKind.task => (Icons.task_alt, NeoColors.yellowTint),
      TrashKind.routine => (Icons.repeat, NeoColors.coralTint),
      TrashKind.series => (Icons.event_repeat_outlined, NeoColors.blueTint),
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: NeoRadius.input),
      child: SizedBox.square(
        dimension: NeoSize.cardIcon,
        child: Icon(icon, size: 20),
      ),
    );
  }
}

int _remainingDays(TrashEntry entry, DateTime now) {
  final time = entry.expiresAt.difference(now);
  return time <= Duration.zero
      ? 0
      : (time.inMicroseconds / Duration.microsecondsPerDay).ceil();
}

String _issue(Object error) => switch (error) {
  TrashProblem.expired => 'Masa retensi item sudah berakhir.',
  TrashProblem.unavailableParent =>
    'Pulihkan item induk atau item terkait terlebih dahulu.',
  TrashProblem.seriesChanged =>
    'Cakupan seri berubah sejak item dihapus. Data di Tempat Sampah tetap tersedia.',
  TrashProblem.referenced =>
    'Item masih dirujuk oleh aktivitas atau riwayat lain. Tinjau hubungan tersebut sebelum menghapus permanen.',
  TrashProblem.invalidSchedule =>
    'Pilih tanggal dengan waktu mulai yang masih mendatang.',
  StaleRecord() =>
    'Item atau kalender berubah. Tinjau ulang sebelum melanjutkan.',
  _ => 'Coba lakukan tindakan ini kembali.',
};
