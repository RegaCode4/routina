import 'package:flutter/material.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/design_system/neo_badges.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/design_system/planner_cards.dart';
import 'package:routina/presentation/planner/preview_ui.dart';
import 'package:routina/presentation/planner/reminder_ui.dart';

class PlannerHome extends StatefulWidget {
  const PlannerHome({
    required this.repository,
    required this.onOpen,
    required this.onConfirm,
    required this.onCalendar,
    required this.onStats,
    required this.onAdd,
    this.onOpenRoutine,
    this.revision = 0,
    super.key,
  });
  final PlannerPreviewRepository repository;
  final ValueChanged<PreviewEvent> onOpen;
  final ValueChanged<PreviewEvent> onConfirm;
  final VoidCallback onCalendar;
  final VoidCallback onStats;
  final VoidCallback onAdd;
  final void Function(String id, DateTime day)? onOpenRoutine;
  final int revision;

  @override
  State<PlannerHome> createState() => _PlannerHomeState();
}

class _PlannerHomeState extends State<PlannerHome> {
  late Future<void> _load = widget.repository.load(PreviewSurface.home);

  @override
  void didUpdateWidget(covariant PlannerHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.repository.usesStoredCalendar &&
        oldWidget.revision != widget.revision) {
      _load = widget.repository.load(PreviewSurface.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.repository.profile!;
    final name = profile.name.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NeoSpace.page,
        NeoSpace.page,
        NeoSpace.page,
        NeoSize.fab + NeoSpace.section,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<void>(
                    future: _load,
                    builder: (context, _) => Text(
                      dateLabel(
                        widget.repository.today,
                        long: true,
                        year: true,
                      ).toUpperCase(),
                      style: NeoType.badge.copyWith(color: NeoColors.muted),
                    ),
                  ),
                  const SizedBox(height: NeoSpace.xxs),
                  Text(
                    name.isEmpty ? 'Halo!' : 'Halo, $name.',
                    style: NeoType.display.copyWith(fontSize: 36),
                  ),
                ],
              ),
            ),
            const SizedBox(width: NeoSpace.sm),
            if (widget.repository.localReminders case final service?)
              ListenableBuilder(
                listenable: service,
                builder: (context, _) => NeoIconButton(
                  icon: service.dashboard.sendsToSystem
                      ? Icons.notifications_none
                      : Icons.notifications_off_outlined,
                  label: 'Pengingat',
                  indicator:
                      service.dashboard.reminders.isNotEmpty ||
                      widget.repository.homeEntries.any(
                        (entry) => entry.state == PreviewEventState.pending,
                      ),
                  onPressed: () => _reminders(context),
                ),
              )
            else
              NeoIconButton(
                icon: profile.notifications
                    ? Icons.notifications_none
                    : Icons.notifications_off_outlined,
                label: 'Pengingat',
                indicator: widget.repository.homeEntries.any(
                  (entry) => entry.state == PreviewEventState.pending,
                ),
                onPressed: () => _reminders(context),
              ),
          ],
        ),
        const SizedBox(height: NeoSpace.sm),
        FutureBuilder<void>(
          future: _load,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            if (loading || snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HomeKpis(onStats: widget.onStats),
                  const SizedBox(height: NeoSpace.page),
                  PreviewNotice(
                    title: loading ? 'Memuat agenda' : 'Agenda belum tersedia',
                    message: loading
                        ? 'Sedang membaca aktivitas hari ini.'
                        : 'Coba lagi untuk membaca aktivitas.',
                    loading: loading,
                    warning: snapshot.hasError,
                    icon: Icons.error_outline,
                    button: snapshot.hasError
                        ? NeoButton(
                            label: 'Muat ulang',
                            onPressed: () {
                              final retry = widget.repository.load(
                                PreviewSurface.home,
                              );
                              setState(() {
                                _load = retry;
                              });
                            },
                          )
                        : null,
                  ),
                ],
              );
            }
            final statistics = widget.repository.homeProductivity;
            final today = statistics?.dates.start ?? widget.repository.today;
            return _agenda(
              profile,
              DailyPreview(
                widget.repository.homeEntries,
                dateOnly(today),
                tally: statistics?.tally,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _agenda(PreviewProfile profile, DailyPreview daily) {
    final pending =
        (widget.repository.usesStoredCalendar
                ? widget.repository.homeEntries.reversed
                : daily.agenda)
            .where(
              (entry) =>
                  entry.kind == PreviewKind.activity &&
                  entry.state == PreviewEventState.pending,
            )
            .toList();
    final conflicted = daily.agenda
        .where(
          (entry) =>
              entry.warning == ScheduleWarning.overlap ||
              (entry.kind == PreviewKind.session &&
                  entry.warning == ScheduleWarning.buffer),
        )
        .firstOrNull;
    final overdue = widget.repository.homeEntries
        .where(
          (entry) =>
              entry.kind == PreviewKind.deadline &&
              entry.state == PreviewEventState.pending &&
              (widget.repository.usesStoredCalendar ||
                  entry.start.isBefore(widget.repository.today)),
        )
        .toList();
    final next = widget.repository.usesStoredCalendar
        ? widget.repository.homeNextEvent
        : daily.next;
    final routineTargets =
        widget.repository.homeProductivity?.history
            .where((item) => item.isUnscheduledTarget)
            .toList() ??
        const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeKpis(daily: daily, onStats: widget.onStats),
        const SizedBox(height: NeoSpace.page),
        const Text('KEGIATAN TERDEKAT', style: NeoType.badge),
        const SizedBox(height: NeoSpace.xs),
        if (next != null)
          ActivityCard(
            title: next.title,
            time: dateOnly(next.start) == widget.repository.today
                ? 'Hari ini · ${eventTime(next)}'
                : '${dateLabel(next.start)} · ${eventTime(next)}',
            highlighted: true,
            onTap: () => widget.onOpen(next),
          )
        else
          const Text('Belum ada kegiatan mendatang.'),
        const SizedBox(height: NeoSpace.md),
        if (widget.repository.localReminders case final service?) ...[
          NotificationStatusNotice(service),
          ListenableBuilder(
            listenable: service,
            builder: (context, _) {
              final reminders = service.dashboard.reminders;
              if (reminders.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: NeoSpace.sm),
                child: PreviewNotice(
                  title: 'Pengingat di Home',
                  message: '${reminders.first.title} · ${reminders.first.body}',
                  button: NeoButton(
                    label: 'Lihat pengingat',
                    variant: NeoButtonVariant.secondary,
                    onPressed: () => _reminders(context),
                  ),
                ),
              );
            },
          ),
        ] else if (!profile.notifications) ...[
          PreviewNotice(
            title: 'Notifikasi nonaktif',
            message: 'Pengingat tetap tersedia di Home.',
            icon: Icons.notifications_off_outlined,
            warning: true,
            button: NeoButton(
              label: 'Lihat pengingat',
              variant: NeoButtonVariant.secondary,
              onPressed: () => _reminders(context),
            ),
          ),
          const SizedBox(height: NeoSpace.md),
        ],
        if (conflicted != null) ...[
          PreviewNotice(
            title: '${conflicted.title} bentrok',
            message:
                '${eventTime(conflicted)} · ${conflicted.warning == ScheduleWarning.buffer ? 'Jeda antarkegiatan terlalu pendek.' : 'Ada kegiatan yang tumpang tindih.'}',
            icon: Icons.warning_amber_rounded,
            warning: true,
          ),
          const SizedBox(height: NeoSpace.md),
        ],
        if (overdue.isNotEmpty) ...[
          PreviewNotice(
            title: '${overdue.length} tugas overdue',
            message: overdue
                .map(
                  (entry) =>
                      '${entry.title} · ${dateLabel(entry.start)} ${eventTime(entry)}',
                )
                .join('\n'),
            icon: Icons.warning_amber_rounded,
            warning: true,
          ),
          const SizedBox(height: NeoSpace.md),
        ],
        if (pending.isNotEmpty) ...[
          const Text('Menunggu Konfirmasi', style: NeoType.section),
          const SizedBox(height: NeoSpace.xs),
          for (final entry in pending)
            Padding(
              padding: const EdgeInsets.only(bottom: NeoSpace.xs),
              child: ActivityCard(
                title: entry.title,
                time:
                    '${dateLabel(entry.start)} · ${eventTime(entry)} · Sudah berakhir',
                status: NeoStatus.pending,
                onTap: () => widget.onConfirm(entry),
              ),
            ),
          const SizedBox(height: NeoSpace.xs),
        ] else if (daily.total > 0 && daily.open == 0) ...[
          const PreviewNotice(
            title: 'Semua aktivitas selesai',
            message: 'Semua aktivitas hari ini sudah dikonfirmasi selesai.',
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: NeoSpace.md),
        ],
        if (widget.repository.usesStoredCalendar)
          TextButton(
            onPressed: () async {
              await _olderConfirmations(context);
            },
            child: const Text('Konfirmasi tanggal sebelumnya'),
          ),
        if (routineTargets.isNotEmpty) ...[
          const Text('Target rutinitas hari ini', style: NeoType.section),
          const SizedBox(height: NeoSpace.xs),
          for (final target in routineTargets)
            Padding(
              padding: const EdgeInsets.only(bottom: NeoSpace.xs),
              child: ActivityCard(
                title: target.title,
                time: 'Target harian',
                onTap: () =>
                    widget.onOpenRoutine?.call(target.routineId!, target.day),
              ),
            ),
        ],
        if (daily.agenda.isEmpty && routineTargets.isEmpty)
          PreviewNotice(
            title: 'Agenda masih kosong',
            message: 'Tambahkan kegiatan, tugas, atau rutinitas untuk memulai.',
            icon: Icons.event_busy_outlined,
            button: NeoButton(
              label: 'Tambah aktivitas',
              onPressed: widget.onAdd,
            ),
          )
        else if (daily.agenda.isNotEmpty) ...[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Agenda hari ini', style: NeoType.section),
              TextButton(
                onPressed: widget.onCalendar,
                child: const Text('Lihat kalender'),
              ),
            ],
          ),
          for (final entry in daily.agenda)
            Padding(
              padding: const EdgeInsets.only(bottom: NeoSpace.xs),
              child: ActivityCard(
                title: entry.title,
                time: dateOnly(entry.start) == widget.repository.today
                    ? eventTime(entry)
                    : '${eventTime(entry)} · Lintas hari',
                category: entry.options.category.isEmpty
                    ? null
                    : entry.options.category,
                recurring: entry.series != null,
                status: agendaStatus(entry),
                onTap: () => widget.onOpen(entry),
              ),
            ),
          Text(
            'Zona tampilan · ${widget.repository.calendarZoneLabel}',
            style: NeoType.caption.copyWith(color: NeoColors.muted),
          ),
        ],
      ],
    );
  }

  Future<void> _olderConfirmations(BuildContext context) async {
    final previous = widget.repository.homeEntries
        .map((entry) => entry.id)
        .toSet();
    try {
      await widget.repository.loadEarlierConfirmations();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konfirmasi sebelumnya belum dapat dibaca.'),
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final earlier = widget.repository.homeEntries
        .where(
          (entry) =>
              !previous.contains(entry.id) &&
              entry.kind == PreviewKind.activity &&
              entry.state == PreviewEventState.pending,
        )
        .toList()
        .reversed;
    await showNeoBottomSheet<void>(
      context,
      builder: (sheet) => NeoBottomSheet(
        title: 'Konfirmasi tanggal sebelumnya',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (earlier.isEmpty)
              const Text(
                'Tidak ada kegiatan yang menunggu pada rentang sebelumnya.',
              ),
            for (final item in earlier)
              ActivityCard(
                title: item.title,
                time: '${dateLabel(item.start)} · ${eventTime(item)}',
                status: NeoStatus.pending,
                onTap: () {
                  Navigator.pop(sheet);
                  widget.onConfirm(item);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _reminders(BuildContext context) {
    if (widget.repository.localReminders case final service?) {
      return showReminderInbox(context, service, pending: _pendingReminders);
    }
    return showNeoBottomSheet<void>(
      context,
      builder: (sheet) => NeoBottomSheet(
        title: 'Pengingat',
        description: widget.repository.profile!.notifications
            ? 'Aktivitas yang menunggu konfirmasi.'
            : 'Notifikasi nonaktif. Pengingat tetap tersedia di Home.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._pendingReminders(sheet),
            if (!widget.repository.homeEntries.any(
              (entry) =>
                  entry.kind == PreviewKind.activity &&
                  entry.state == PreviewEventState.pending,
            ))
              const Text('Belum ada pengingat.'),
          ],
        ),
      ),
    );
  }

  List<Widget> _pendingReminders(BuildContext sheet) => [
    for (final entry in widget.repository.homeEntries)
      if (entry.kind == PreviewKind.activity &&
          entry.state == PreviewEventState.pending)
        Padding(
          padding: const EdgeInsets.only(bottom: NeoSpace.xs),
          child: ActivityCard(
            title: entry.title,
            time: eventTime(entry),
            status: NeoStatus.pending,
            onTap: () {
              Navigator.pop(sheet);
              widget.onConfirm(entry);
            },
          ),
        ),
  ];
}

class _HomeKpis extends StatelessWidget {
  const _HomeKpis({this.daily, required this.onStats});
  final DailyPreview? daily;
  final VoidCallback onStats;

  @override
  Widget build(BuildContext context) {
    final progress = daily?.progress;
    final narrow = MediaQuery.of(context).size.width < 360;
    final enlarged = MediaQuery.textScalerOf(context).scale(14) > 19;
    return NeoCard(
      tone: NeoCardTone.accent,
      emphasis: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: NeoSpace.xs,
            runSpacing: NeoSpace.xs,
            children: [
              const Text('Penyelesaian hari ini', style: NeoType.item),
              NeoButton(
                label: 'Statistik',
                icon: Icons.bar_chart,
                variant: NeoButtonVariant.secondary,
                onPressed: onStats,
              ),
            ],
          ),
          const SizedBox(height: NeoSpace.xs),
          if (progress == null)
            Text(
              daily == null ? '—' : 'Tidak Ada Aktivitas',
              style: NeoType.section,
            )
          else ...[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: NeoSpace.xs,
              runSpacing: NeoSpace.xs,
              children: [
                Text(
                  completionPercentage(progress),
                  style: NeoType.metric.copyWith(
                    fontSize: narrow || enlarged ? 42 : 58,
                  ),
                ),
                Text(
                  '${daily!.completed} dari ${daily!.total} selesai',
                  style: NeoType.badge,
                ),
              ],
            ),
            const SizedBox(height: NeoSpace.xxs),
            NeoProgressBar(
              value: progress,
              label: 'Penyelesaian hari ini',
              onAccent: true,
            ),
          ],
          const SizedBox(height: NeoSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, label, value) in [
                (0, 'Total', daily?.total),
                (1, 'Selesai', daily?.completed),
                (2, 'Belum selesai', daily?.open),
              ])
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: index == 0
                          ? null
                          : const Border(left: NeoLine.thin),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : NeoSpace.xs,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value?.toString() ?? '—',
                            style: NeoType.metric.copyWith(fontSize: 24),
                          ),
                          Text(label, style: NeoType.badge),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
