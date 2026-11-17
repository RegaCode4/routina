import 'package:flutter/material.dart';
import 'package:routina/application/local_reminders.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/demo/demo_widgets.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

Future<Set<Duration>?> pickReminderOffsets(
  BuildContext context, {
  required String title,
  required String Function(Duration) label,
  required Set<Duration> selected,
  required List<Duration> presets,
  bool custom = true,
}) {
  final values = {...presets, ...selected};
  final picked = {...selected};
  return showNeoBottomSheet<Set<Duration>>(
    context,
    builder: (sheet) => StatefulBuilder(
      builder: (context, update) => NeoBottomSheet(
        title: title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final offset
                in (values.toList()..sort((a, b) => b.compareTo(a))))
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: picked.contains(offset),
                title: Text(label(offset)),
                onChanged: (value) => update(() {
                  if (value == true) {
                    picked.add(offset);
                  } else {
                    picked.remove(offset);
                  }
                }),
              ),
            if (custom)
              NeoButton(
                label: 'Tambah waktu pengingat',
                variant: NeoButtonVariant.secondary,
                onPressed: () async {
                  final minutes = await demoNumber(
                    context,
                    'Menit sebelum jadwal',
                    max: 10080,
                  );
                  if (!context.mounted || minutes == null) return;
                  update(() {
                    final offset = Duration(minutes: minutes);
                    values.add(offset);
                    picked.add(offset);
                  });
                },
              ),
            const SizedBox(height: NeoSpace.sm),
            NeoButton(
              label: 'Terapkan pengingat',
              onPressed: () => Navigator.pop(sheet, picked),
            ),
          ],
        ),
      ),
    ),
  );
}

class NotificationStatusNotice extends StatelessWidget {
  const NotificationStatusNotice(
    this.service, {
    this.showAuthorized = false,
    super.key,
  });
  final LocalReminders service;
  final bool showAuthorized;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) {
      final status = service.dashboard;
      if (status.loading) {
        return showAuthorized
            ? const PreviewNotice(
                title: 'Memeriksa izin notifikasi',
                message: 'Membaca pengaturan perangkat.',
                loading: true,
              )
            : const SizedBox.shrink();
      }
      final (title, message, label, action) = switch (status.permission) {
        NotificationPermission.denied => (
          'Notifikasi nonaktif di perangkat',
          'Pengingat tetap dapat dilihat di Home.',
          'Buka Pengaturan Sistem',
          service.openSettings,
        ),
        NotificationPermission.notDetermined => (
          'Izin notifikasi belum diminta',
          'Izinkan saat ingin menerima pengingat dari perangkat.',
          'Minta izin',
          service.requestPermission,
        ),
        NotificationPermission.authorized when !status.enabled => (
          'Pengingat sistem dinonaktifkan',
          'Pengingat tetap dapat dilihat di Home.',
          null,
          null,
        ),
        NotificationPermission.authorized => (
          'Izin notifikasi aktif',
          'Mode Fokus, Jangan Ganggu, atau pengaturan daya perangkat dapat membatasi pengiriman.',
          'Buka Pengaturan Sistem',
          service.openSettings,
        ),
        NotificationPermission.unavailable => (
          'Status izin tidak tersedia',
          'Pengingat tetap dapat dilihat di Home.',
          'Coba lagi',
          service.refresh,
        ),
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showAuthorized || !status.sendsToSystem)
            PreviewNotice(
              title: title,
              message: message,
              warning: status.permission == NotificationPermission.denied,
              button:
                  label == null ||
                      !status.enabled &&
                          !showAuthorized &&
                          status.permission ==
                              NotificationPermission.notDetermined
                  ? null
                  : NeoButton(
                      label: label,
                      onPressed: () => reminderAction(context, action!),
                    ),
            ),
          if (status.failed)
            PreviewNotice(
              title: 'Pengingat gagal dijadwalkan',
              message:
                  'Periksa kembali pengiriman sistem. Pengingat tersedia di Home.',
              warning: true,
              button: NeoButton(label: 'Coba lagi', onPressed: service.refresh),
            ),
        ],
      );
    },
  );
}

Future<void> reminderAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengingat belum dapat diperbarui. Coba lagi.'),
        ),
      );
    }
  }
}

Future<void> showReminderInbox(
  BuildContext context,
  LocalReminders service, {
  List<Widget> Function(BuildContext)? pending,
}) => showNeoBottomSheet<void>(
  context,
  builder: (sheet) => ListenableBuilder(
    listenable: service,
    builder: (context, _) {
      final status = service.dashboard;
      final awaiting = pending?.call(sheet) ?? [];
      final current = service.now().toUtc();
      return NeoBottomSheet(
        title: 'Pengingat di Home',
        description:
            'Pengingat yang jatuh tempo dan yang akan datang dalam 24 jam.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (status.loading)
              const CircularProgressIndicator(
                semanticsLabel: 'Memuat pengingat',
              ),
            if (!status.loading && status.reminders.isEmpty && awaiting.isEmpty)
              const Text('Belum ada pengingat.'),
            for (final row in status.reminders) ...[
              NeoCard(
                tone: row.quiet ? NeoCardTone.highlighted : NeoCardTone.plain,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.title, style: NeoType.item),
                    Text(row.body),
                    Text(
                      '${dateLabel(row.at.toLocal())} · ${clockLabel(minutesAt(row.at.toLocal()))}',
                    ),
                    if (row.quiet) const Text('Dalam Jam Tenang'),
                    if (!row.at.isAfter(current))
                      TextButton(
                        onPressed: () =>
                            reminderAction(context, () => service.snooze(row)),
                        child: const Text('Tunda 10 menit'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: NeoSpace.xs),
            ],
            ...awaiting,
          ],
        ),
      );
    },
  ),
);
