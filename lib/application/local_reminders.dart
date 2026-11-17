import 'package:flutter/foundation.dart';
import 'package:routina/application/activity_calendar.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';

enum NotificationPermission { notDetermined, denied, authorized, unavailable }

typedef QuietPolicy = ({DailyHours hours, Set<ReminderKind> exceptions});

abstract interface class NotificationPlatform {
  Future<NotificationPermission> permission();
  Future<void> requestPermission();
  Future<void> openSettings();
  Future<void> synchronize(List<LocalReminder> reminders, QuietPolicy? quiet);
}

class LocalReminder {
  const LocalReminder({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    required this.expires,
    this.deviceTime = false,
    this.catchUp = false,
    this.quiet = false,
  });

  final String id, title, body;
  final ReminderKind kind;
  final DateTime at, expires;
  final bool deviceTime, catchUp, quiet;

  LocalReminder withPolicy(DateTime? snoozed, bool quiet) => LocalReminder(
    id: id,
    kind: kind,
    title: title,
    body: body,
    at: snoozed ?? at,
    expires: snoozed == null ? expires : snoozed.add(const Duration(hours: 1)),
    deviceTime: deviceTime,
    catchUp: catchUp,
    quiet: quiet,
  );
}

class ReminderDashboard {
  const ReminderDashboard({
    this.permission = NotificationPermission.unavailable,
    this.enabled = false,
    this.loading = true,
    this.failed = false,
    this.reminders = const [],
  });
  final NotificationPermission permission;
  final bool enabled, loading, failed;
  final List<LocalReminder> reminders;

  bool get sendsToSystem =>
      enabled && permission == NotificationPermission.authorized;
}

/// SQLite owns reminder preferences and eligibility. The platform holds a
/// finite delivery queue derived from the latest committed snapshot.
class LocalReminders extends ChangeNotifier {
  LocalReminders({
    required this.platform,
    required this.openStore,
    required this.openCalendar,
    required this.now,
  });
  final NotificationPlatform platform;
  final Future<PlannerStore> Function() openStore;
  final Future<ActivityCalendar> Function() openCalendar;
  final DateTime Function() now;

  static const queueLimit = 60;
  static const snoozeDelay = Duration(minutes: 10);
  ReminderDashboard dashboard = const ReminderDashboard();
  Future<void>? _running;
  bool _requested = false;

  Future<void> refresh() {
    _requested = true;
    return _running ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_requested) {
        _requested = false;
        await _refresh();
      }
    } finally {
      _running = null;
    }
  }

  Future<void> _refresh() async {
    var permission = NotificationPermission.unavailable;
    var failed = false;
    try {
      permission = await platform.permission();
    } catch (_) {
      failed = true;
    }
    try {
      final store = await openStore();
      final calendar = await openCalendar();
      final snapshot = await store.transaction((data) => _plan(data, calendar));
      final enabled = snapshot.enabled;
      final permitted =
          enabled && permission == NotificationPermission.authorized;
      try {
        await platform.synchronize(
          permitted
              ? snapshot.reminders
                    .where((row) => !row.quiet)
                    .take(queueLimit)
                    .toList()
              : const [],
          snapshot.quiet,
        );
      } catch (_) {
        failed = true;
      }
      final current = now().toUtc();
      final dashboardEnd = current.add(const Duration(hours: 24));
      dashboard = ReminderDashboard(
        permission: permission,
        enabled: enabled,
        failed: failed,
        loading: false,
        reminders: List.unmodifiable(
          snapshot.reminders.where((row) => !row.at.isAfter(dashboardEnd)),
        ),
      );
    } catch (_) {
      try {
        await platform.synchronize(const [], null);
      } catch (_) {
        // The next resume or committed change will retry the platform.
      }
      dashboard = ReminderDashboard(
        permission: permission,
        enabled: dashboard.enabled,
        failed: true,
        loading: false,
      );
    }
    notifyListeners();
  }

  Future<void> requestPermission() async {
    if (await platform.permission() == NotificationPermission.notDetermined) {
      await platform.requestPermission();
    }
    await refresh();
  }

  Future<void> openSettings() => platform.openSettings();

  Future<void> snooze(LocalReminder reminder) async {
    final store = await openStore();
    final calendar = await openCalendar();
    await store.transaction((data) async {
      final snapshot = await _plan(data, calendar);
      final current = now().toUtc();
      if (!snapshot.reminders.any(
        (row) => row.id == reminder.id && !row.at.isAfter(current),
      )) {
        throw StaleRecord(reminder.id);
      }
      final progress = await data.reminderProgress();
      progress[reminder.id] = (
        firstSeen: progress[reminder.id]?.firstSeen,
        snoozedUntil: current.add(snoozeDelay),
      );
      await data.saveReminderProgress(progress);
    });
    await refresh();
  }

  Future<({bool enabled, QuietPolicy? quiet, List<LocalReminder> reminders})>
  _plan(PlannerData data, ActivityCalendar basis) async {
    final profile = (await data.profiles.all()).singleOrNull;
    if (profile == null || !profile.onboardingCompleted) {
      return (enabled: false, quiet: null, reminders: const <LocalReminder>[]);
    }
    final calendar = await basis.withLatestProfile(data);
    final zones = calendar.zones;
    final current = now().toUtc();
    final today = civilDate(zones.wall(current, zones.deviceId));
    final settings = profile.preferences;
    final interval = Duration(
      minutes: settings.confirmationIntervalMinutes.clamp(1, 1440),
    );
    final confirmationCount = settings.confirmationCount.clamp(0, 10);
    final from = current.subtract(
      interval * confirmationCount + const Duration(days: 3),
    );
    final end = current.add(const Duration(days: 45));
    final entries = await calendar.reminderCalendar(
      data,
      from,
      end.add(const Duration(days: 7)),
    );
    final hours = profile.quietHours;
    final quiet = hours != null && (settings.quietEnabled ?? true)
        ? (
            hours: hours,
            exceptions: settings.quietExceptionsEnabled
                ? settings.quietExceptions
                : const <ReminderKind>{},
          )
        : null;
    final byTarget = <String, List<ReminderRule>>{};
    for (final rule in await data.reminderRules.all()) {
      if (!rule.enabled) continue;
      (byTarget[rule.target.id] ??= []).add(rule);
    }
    final routines = {for (final row in await data.routines.all()) row.id: row};
    final occurrences = {
      for (final row in await data.routineOccurrences.all()) row.id: row,
    };
    final candidates = <String, LocalReminder>{};
    void add(
      ReminderKind kind,
      String owner,
      String title,
      String body,
      DateTime time,
      DateTime expires, {
      bool deviceTime = false,
      bool catchUp = false,
      bool beyondHorizon = false,
    }) {
      if (!settings.allowsReminder(kind) ||
          (!beyondHorizon && time.isAfter(end))) {
        return;
      }
      final id = '${kind.name}:$owner:${time.millisecondsSinceEpoch}';
      candidates[id] = LocalReminder(
        id: id,
        kind: kind,
        title: title,
        body: body,
        at: DateTime.fromMicrosecondsSinceEpoch(
          time.microsecondsSinceEpoch,
          isUtc: true,
        ),
        expires: DateTime.fromMicrosecondsSinceEpoch(
          expires.microsecondsSinceEpoch,
          isUtc: true,
        ),
        deviceTime: deviceTime,
        catchUp: catchUp,
      );
    }

    void anchored(
      ReminderCalendarItem row,
      ReminderKind kind,
      Duration offset,
      String title,
    ) {
      final at = row.start.subtract(offset);
      final hourAfter = at.add(const Duration(hours: 1));
      final expiry = offset != Duration.zero && row.start.isBefore(hourAfter)
          ? row.start
          : hourAfter;
      add(
        kind,
        '${row.id}:${row.start.millisecondsSinceEpoch}',
        title,
        row.title,
        at,
        expiry,
        deviceTime: row.deviceTime,
      );
    }

    final dayCounts = <DateTime, Set<String>>{};
    for (final row in entries.items) {
      if (row.status != ActivityStatus.planned) continue;
      final day = civilDate(zones.wall(row.start, zones.deviceId));
      (dayCounts[day] ??= {}).add(row.obligationId);
      switch (row.kind) {
        case CalendarEntryKind.event:
          for (final offset
              in row.reminders.map(eventReminderOffset).nonNulls.toSet()) {
            anchored(
              row,
              offset == Duration.zero
                  ? ReminderKind.eventStart
                  : ReminderKind.event,
              offset,
              offset == Duration.zero
                  ? 'Kegiatan dimulai'
                  : 'Kegiatan mendatang',
            );
          }
          for (
            var repetition = 1;
            repetition <= confirmationCount;
            repetition++
          ) {
            final at = row.end.add(interval * repetition);
            add(
              ReminderKind.confirmation,
              row.id,
              'Konfirmasi hasil kegiatan',
              row.title,
              at,
              at.add(interval),
              deviceTime: row.deviceTime,
            );
          }
        case CalendarEntryKind.deadline:
          for (final rule in byTarget[row.id] ?? const <ReminderRule>[]) {
            if (rule.anchor == ReminderAnchor.deadline &&
                rule.target.kind == RecordKind.task) {
              anchored(
                row,
                ReminderKind.deadline,
                rule.offset,
                rule.offset == Duration.zero
                    ? 'Tenggat tugas'
                    : 'Tenggat tugas mendekat',
              );
            }
          }
          for (
            var repetition = 1;
            repetition <= confirmationCount;
            repetition++
          ) {
            final at = row.start.add(interval * repetition);
            add(
              ReminderKind.deadline,
              row.id,
              'Tugas melewati tenggat',
              row.title,
              at,
              at.add(interval),
              deviceTime: row.deviceTime,
            );
          }
        case CalendarEntryKind.workSession:
          // A completed task can retain its future sessions as appointments.
          anchored(
            row,
            ReminderKind.workSession,
            Duration.zero,
            'Sesi pengerjaan dimulai',
          );
        case CalendarEntryKind.routine:
          final routine = occurrences[row.id]?.routineId;
          if (row.allDay || routine == null) continue;
          for (final rule in byTarget[routine] ?? const <ReminderRule>[]) {
            if (rule.anchor == ReminderAnchor.start &&
                rule.target.kind == RecordKind.routine) {
              anchored(
                row,
                ReminderKind.routine,
                rule.offset,
                'Pengingat rutinitas',
              );
            }
          }
      }
    }

    final previousProgress = await data.reminderProgress();
    final progress = {...previousProgress};
    final activeConflicts = <String>{};
    if (settings.allowsReminder(ReminderKind.conflict)) {
      for (final conflict in entries.conflicts) {
        if (!conflict.until.isAfter(current)) continue;
        final at = progress[conflict.key]?.firstSeen ?? current;
        activeConflicts.add(conflict.key);
        progress[conflict.key] = (firstSeen: at, snoozedUntil: null);
        final expiry = at.add(const Duration(hours: 2));
        add(
          ReminderKind.conflict,
          conflict.key,
          'Jadwal bentrok',
          conflict.title,
          at,
          conflict.until.isBefore(expiry) ? conflict.until : expiry,
          deviceTime: conflict.deviceTime,
          catchUp: true,
        );
      }
    }
    for (final goal in await data.routineGoalEvents()) {
      final occurrence = occurrences[goal.occurrenceId];
      if (occurrence == null || occurrence.status != ActivityStatus.planned) {
        continue;
      }
      final routine = routines[occurrence.routineId];
      if (routine == null) continue;
      add(
        ReminderKind.timerGoal,
        occurrence.id,
        'Target durasi tercapai',
        routine.title,
        goal.dueAt,
        goal.dueAt.add(const Duration(hours: 1)),
        catchUp: true,
      );
    }
    if (settings.morningMinute case final minute?
        when minute >= 0 && minute < 1440) {
      for (var index = -1; index < 14; index++) {
        final day = today.add(Duration(days: index));
        final at = zones.instant(
          day.add(Duration(minutes: minute)),
          zones.deviceId,
        );
        final count = dayCounts[day]?.length ?? 0;
        add(
          ReminderKind.morning,
          civilKey(day),
          'Ringkasan pagi',
          count == 0
              ? 'Agenda hari ini kosong.'
              : '$count agenda hari ini. Lihat rinciannya di Home.',
          at,
          zones.instant(day.add(const Duration(days: 1)), zones.deviceId),
          deviceTime: true,
        );
      }
    }
    final backupSince =
        settings.backupReminderSince ?? profile.metadata.createdAt;
    final backupDays = settings.backupReminderDays;
    if (backupDays != null && backupDays > 0 && backupSince != null) {
      final wall = zones.wall(backupSince, zones.deviceId);
      final passed = today.difference(civilDate(wall)).inDays;
      final previous = (passed ~/ backupDays).clamp(1, 1000000);
      for (final repetition in [previous, previous + 1]) {
        final at = zones.instant(
          wall.add(Duration(days: backupDays * repetition)),
          zones.deviceId,
        );
        add(
          ReminderKind.backup,
          '$backupDays',
          'Pengingat backup',
          'Waktunya menyiapkan salinan data lokal Routina.',
          at,
          at.add(Duration(days: backupDays)),
          deviceTime: true,
          beyondHorizon: true,
        );
      }
    }

    final notices = <LocalReminder>[];
    final stored = <String, ReminderProgress>{};
    for (final key in activeConflicts) {
      stored[key] = progress[key]!;
    }
    for (final row in candidates.values) {
      final snoozed = progress[row.id]?.snoozedUntil;
      final at = snoozed ?? row.at;
      final suppressed =
          quiet != null &&
          !quiet.exceptions.contains(row.kind) &&
          isQuietTime(zones.wall(at, zones.deviceId), quiet.hours);
      final notice = row.withPolicy(snoozed, suppressed);
      if (!notice.expires.isAfter(current)) continue;
      if (snoozed != null) stored[row.id] = progress[row.id]!;
      notices.add(notice);
    }
    if (!mapEquals(stored, previousProgress)) {
      await data.saveReminderProgress(stored);
    }
    notices.sort((a, b) {
      final time = a.at.compareTo(b.at);
      return time == 0 ? a.id.compareTo(b.id) : time;
    });
    return (
      enabled: profile.notificationsEnabled ?? false,
      quiet: quiet,
      reminders: notices,
    );
  }
}

bool isQuietTime(DateTime wall, DailyHours hours) {
  final minute = wall.hour * 60 + wall.minute;
  final (:startMinute, :endMinute) = hours;
  if (startMinute == endMinute) return false;
  return startMinute < endMinute
      ? minute >= startMinute && minute < endMinute
      : minute >= startMinute || minute < endMinute;
}

Duration? eventReminderOffset(String value) {
  if (value == 'Saat mulai') return Duration.zero;
  final parts = RegExp(
    r'^(\d+) (menit|jam|hari) sebelumnya$',
  ).firstMatch(value);
  if (parts == null) return null;
  final amount = int.tryParse(parts[1]!) ?? 0;
  if (amount < 1 || amount > 10080) return null;
  final offset = switch (parts[2]) {
    'hari' => Duration(days: amount),
    'jam' => Duration(hours: amount),
    _ => Duration(minutes: amount),
  };
  return offset > const Duration(days: 7) ? null : offset;
}
