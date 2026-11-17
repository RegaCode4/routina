import 'package:flutter/material.dart';
import 'package:routina/application/local_reminders.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/presentation/demo/demo_session.dart';
import 'package:routina/presentation/demo/demo_widgets.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/preview_ui.dart';
import 'package:routina/presentation/planner/reminder_ui.dart';

class NotificationSettings extends StatelessWidget {
  const NotificationSettings(this.demo, this.service, {super.key});
  final DemoSession demo;
  final LocalReminders service;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: demo,
    builder: (context, _) {
      final profile = demo.planner.profile!;
      final hours = profile.quietHours;
      final quiet = profile.preferences.quietEnabled ?? (hours != null);
      return PreviewPage(
        title: 'Notifikasi',
        body: DemoList([
          const DemoHeading(
            'Atur pengingat',
            subtitle: 'Pengiriman mengikuti izin perangkat dan Jam Tenang.',
          ),
          NotificationStatusNotice(service, showAuthorized: true),
          NeoCard(
            child: ListenableBuilder(
              listenable: service,
              builder: (context, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pengingat lokal'),
                subtitle: Text(
                  !profile.notifications
                      ? 'Nonaktif di Routina.'
                      : service.dashboard.sendsToSystem
                      ? 'Aktif sesuai pengaturan perangkat.'
                      : 'Preferensi aktif. Pengiriman memerlukan izin perangkat.',
                ),
                value: profile.notifications,
                onChanged: (value) async {
                  final saved = await saveDemoProfile(
                    context,
                    demo,
                    (profile) => profile.copyWith(notifications: value),
                  );
                  if (context.mounted && saved && value) {
                    await reminderAction(context, service.requestPermission);
                  }
                },
              ),
            ),
          ),
          DemoRow(
            'Jenis dan jadwal pengingat',
            icon: Icons.tune,
            subtitle: 'Kegiatan, tenggat, timer, dan pengingat lainnya',
            onTap: () => openDemo<void>(context, _ReminderPreferences(demo)),
          ),
          DemoRow(
            'Jam Tenang',
            icon: Icons.bedtime_outlined,
            color: NeoColors.yellowTint,
            subtitle: quiet && hours != null
                ? '${clockLabel(hours.startMinute)}–${clockLabel(hours.endMinute)}'
                : 'Nonaktif',
            onTap: () => openDemo<void>(context, _QuietHours(demo)),
          ),
          DemoRow(
            'Pengingat di Home',
            icon: Icons.list_alt,
            subtitle: 'Lihat pengingat yang relevan dan tunda pengingat',
            onTap: () => showReminderInbox(context, service),
          ),
        ]),
      );
    },
  );
}

class _ReminderPreferences extends StatelessWidget {
  const _ReminderPreferences(this.demo);
  final DemoSession demo;

  Future<bool> _save(
    BuildContext context,
    PlannerPreferences Function(PlannerPreferences) edit,
  ) => saveDemoProfile(
    context,
    demo,
    (profile) => profile.copyWith(preferences: edit(profile.preferences)),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: demo,
    builder: (context, _) {
      final prefs = demo.preferences;
      return PreviewPage(
        title: 'Jenis pengingat',
        body: DemoList([
          const Text(
            'Atur waktu pengingat kegiatan, tenggat, dan rutinitas dari formulir masing-masing.',
          ),
          NeoCard(
            child: Column(
              children: [
                for (final kind in ReminderKind.values)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(kind.label),
                    value: prefs.allowsReminder(kind),
                    onChanged: (value) => _save(
                      context,
                      (latest) => latest.copyWith(
                        reminderTypes: {...latest.reminderTypes, kind: value},
                      ),
                    ),
                  ),
              ],
            ),
          ),
          PreviewField(
            label: 'Waktu ringkasan pagi',
            value: prefs.morningMinute == null
                ? 'Belum diatur'
                : clockLabel(prefs.morningMinute!),
            icon: Icons.schedule,
            onTap: () async {
              final time = await pickPreviewTime(
                context,
                initial: prefs.morningMinute,
              );
              if (context.mounted && time != null) {
                await _save(
                  context,
                  (latest) => latest.copyWith(morningMinute: time),
                );
              }
            },
          ),
          PreviewField(
            label: 'Batas pengingat konfirmasi dan overdue',
            value: '${prefs.confirmationCount} kali',
            icon: Icons.edit_outlined,
            onTap: () async {
              final count = await demoNumber(
                context,
                'Batas pengingat',
                value: prefs.confirmationCount,
                min: 0,
                max: 10,
              );
              if (context.mounted && count != null) {
                await _save(
                  context,
                  (latest) => latest.copyWith(confirmationCount: count),
                );
              }
            },
          ),
          PreviewField(
            label: 'Jeda antar pengingat konfirmasi dan overdue',
            value: '${prefs.confirmationIntervalMinutes} menit',
            icon: Icons.edit_outlined,
            onTap: () async {
              final minutes = await demoNumber(
                context,
                'Jeda pengingat (menit)',
                value: prefs.confirmationIntervalMinutes,
              );
              if (context.mounted && minutes != null) {
                await _save(
                  context,
                  (latest) =>
                      latest.copyWith(confirmationIntervalMinutes: minutes),
                );
              }
            },
          ),
          const Text('Interval pengingat backup tersedia di Backup & Restore.'),
        ]),
      );
    },
  );
}

class _QuietHours extends StatelessWidget {
  const _QuietHours(this.demo);
  final DemoSession demo;

  Future<void> _pick(BuildContext context, {required bool start}) async {
    final value = await pickPreviewTime(
      context,
      initial: start ? demo.quietStart : demo.quietEnd,
    );
    if (!context.mounted || value == null) return;
    final other = start ? demo.quietEnd : demo.quietStart;
    if (value == other) {
      demoFeedback(context, 'Jam mulai dan selesai harus berbeda.');
      return;
    }
    await saveDemoProfile(
      context,
      demo,
      (profile) => profile.copyWith(
        quietHours: (
          startMinute: start ? value : other,
          endMinute: start ? other : value,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: demo,
    builder: (context, _) => PreviewPage(
      title: 'Jam Tenang',
      body: DemoList([
        const DemoHeading(
          'Atur waktu tenang',
          subtitle: 'Jadwal ini berlaku setiap hari.',
        ),
        NeoCard(
          tone: NeoCardTone.selected,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Aktifkan Jam Tenang'),
            value: demo.quiet,
            onChanged: (value) => saveDemoProfile(
              context,
              demo,
              (profile) => profile.copyWith(
                preferences: profile.preferences.copyWith(quietEnabled: value),
                quietHours: value
                    ? (startMinute: demo.quietStart, endMinute: demo.quietEnd)
                    : null,
              ),
            ),
          ),
        ),
        if (demo.quiet) ...[
          DemoPair(
            PreviewField(
              label: 'Jam mulai',
              value: clockLabel(demo.quietStart),
              icon: Icons.schedule,
              onTap: () => _pick(context, start: true),
            ),
            PreviewField(
              label: 'Jam selesai',
              value: clockLabel(demo.quietEnd),
              icon: Icons.schedule,
              onTap: () => _pick(context, start: false),
            ),
          ),
          const Text('Pengecualian', style: NeoType.section),
          const Text(
            'Jenis yang dipilih boleh dikirim selama Jam Tenang jika izin sistem mengizinkan.',
          ),
          NeoCard(
            child: Column(
              children: [
                for (final kind in ReminderKind.values)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(kind.label),
                    value:
                        demo.preferences.quietExceptionsEnabled &&
                        demo.preferences.quietExceptions.contains(kind),
                    onChanged: (value) =>
                        saveDemoProfile(context, demo, (profile) {
                          final exceptions =
                              profile.preferences.quietExceptionsEnabled
                              ? {...profile.preferences.quietExceptions}
                              : <ReminderKind>{};
                          if (value == true) {
                            exceptions.add(kind);
                          } else {
                            exceptions.remove(kind);
                          }
                          return profile.copyWith(
                            preferences: profile.preferences.copyWith(
                              quietExceptions: exceptions,
                              quietExceptionsEnabled: exceptions.isNotEmpty,
                            ),
                          );
                        }),
                  ),
              ],
            ),
          ),
        ],
        const Text(
          'Mode Fokus dan Jangan Ganggu mengikuti pengaturan perangkat.',
        ),
      ]),
    ),
  );
}
