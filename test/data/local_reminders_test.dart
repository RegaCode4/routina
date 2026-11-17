import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/local_reminders.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/data/stored_planner_profile.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/fake_notifications.dart';

void main() {
  DateTime day(int date, [int hour = 0, int minute = 0]) =>
      DateTime.utc(2026, 11, date, hour, minute);
  late DateTime current;
  late String zone;
  late Directory directory;
  late SqlitePlannerStore store;
  late StoredPlannerProfile repository;
  late FakeNotifications platform;
  late LocalReminders reminders;

  Future<void> settings({
    bool enabled = true,
    DailyHours? quiet,
    PlannerPreferences preferences = const PlannerPreferences(),
  }) => repository.saveProfile(
    PreviewProfile(
      notifications: enabled,
      quietHours: quiet,
      preferences: preferences,
    ),
  );

  Future<PreviewEvent> event(
    String title,
    DateTime start,
    DateTime end, {
    List<String> offsets = const ['Saat mulai'],
    EventRecurrence? rule,
    TimeMode mode = TimeMode.originalZone,
  }) => repository.saveActivity(
    PreviewEvent(
      id: '',
      title: title,
      start: start,
      end: end,
      options: EventOptions(
        reminders: offsets,
        rule: rule,
        timeMode: mode,
        zoneId: mode == TimeMode.originalZone ? 'UTC' : zone,
      ),
    ),
    approved: ScheduleWarning.values.toSet(),
  );

  List<LocalReminder> ofKind(ReminderKind kind) =>
      platform.queued.where((row) => row.kind == kind).toList();

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    current = day(16, 8);
    zone = 'UTC';
    directory = await Directory.systemTemp.createTemp('routina-notifs-');
    store = await SqlitePlannerStore.open(
      factory: databaseFactoryFfi,
      path: '${directory.path}/planner.db',
      now: () => current,
    );
    platform = FakeNotifications();
    repository = StoredPlannerProfile(
      today: current,
      now: () => current,
      openStore: () async => store,
      notificationPlatform: platform,
      readDeviceZone: () async => zone,
    );
    reminders = repository.localReminders!;
    await settings();
  });
  tearDown(() async {
    await store.close();
    reminders.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'permission is requested only explicitly, denial keeps Home usable, and OS settings can be opened',
    () async {
      platform.access = NotificationPermission.notDetermined;
      await event('Rapat', day(16, 10), day(16, 11));
      expect(platform.requests, 0);
      expect(platform.queued, isEmpty);
      expect(
        reminders.dashboard.reminders.any((row) => row.body == 'Rapat'),
        isTrue,
      );
      await reminders.requestPermission();
      await reminders.requestPermission();
      expect(platform.requests, 1);
      expect(reminders.dashboard.permission, NotificationPermission.denied);
      expect(reminders.dashboard.sendsToSystem, isFalse);
      await reminders.openSettings();
      expect(platform.settingsOpens, 1);

      platform.access = NotificationPermission.authorized;
      await reminders.refresh();
      expect(ofKind(ReminderKind.eventStart).single.at, day(16, 10));
      await settings(enabled: false);
      expect(platform.queued, isEmpty);
      expect(
        reminders.dashboard.reminders.any((row) => row.body == 'Rapat'),
        isTrue,
      );
    },
  );

  test(
    'multiple event offsets follow recurring exceptions and a new date only after commit',
    () async {
      final original = await event(
        'Belajar',
        day(17, 10),
        day(17, 11),
        offsets: [
          '1 hari sebelumnya',
          '30 menit sebelumnya',
          'Saat mulai',
          '5 menit sebelumnya',
        ],
        rule: EventRecurrence(RepeatFrequency.weekly),
      );
      final firstBefore = ofKind(
        ReminderKind.event,
      ).where((row) => row.at.isBefore(day(18)));
      expect(firstBefore.map((row) => row.at), [
        day(16, 10),
        day(17, 9, 30),
        day(17, 9, 55),
      ]);
      expect(ofKind(ReminderKind.eventStart).first.at, day(17, 10));
      final moved = await repository.saveActivity(
        PreviewEvent(
          id: original.id,
          series: original.series,
          recurrenceKey: original.recurrenceKey,
          title: original.title,
          start: day(17, 12),
          end: day(17, 13),
          options: original.options,
        ),
        scope: SeriesScope.occurrence,
        approved: ScheduleWarning.values.toSet(),
      );
      expect(ofKind(ReminderKind.eventStart).first.at, day(17, 12));
      expect(
        ofKind(ReminderKind.eventStart).map((row) => row.at),
        contains(day(24, 10)),
      );
      current = day(17, 13);
      await repository.changeActivity(moved, PreviewEventState.postponed);
      expect(
        platform.queued.any(
          (row) => row.body == 'Belajar' && row.at.isBefore(day(18)),
        ),
        isFalse,
      );
      expect(ofKind(ReminderKind.eventStart).first.at, day(24, 10));
      final next = (await repository.readCalendar(day(24), day(25))).single;
      await repository.changeActivity(
        next,
        PreviewEventState.trashed,
        scope: SeriesScope.entire,
      );
      expect(platform.queued.where((row) => row.body == 'Belajar'), isEmpty);
    },
  );

  test(
    'task reminders reschedule with deadlines and cancel on completion or trash',
    () async {
      final workspace = repository.taskWorkspace;
      final zones = workspace.zones;
      final task = await workspace.save(
        title: 'Laporan',
        deadline: zones.atWall(day(16, 12), 'UTC', TimeMode.originalZone),
        subtasks: const [],
        reminders: {
          Duration.zero,
          const Duration(minutes: 20),
          const Duration(hours: 1),
        },
      );
      expect(ofKind(ReminderKind.deadline).map((row) => row.at), [
        day(16, 11),
        day(16, 11, 40),
        day(16, 12),
        day(16, 12, 30),
      ]);
      final moved = await workspace.moveDeadline(
        task,
        zones.atWall(day(16, 13), 'UTC', TimeMode.originalZone),
      );
      expect(ofKind(ReminderKind.deadline).first.at, day(16, 12));
      await workspace.complete(
        moved,
        reviewedFutureIds: {},
        cancelFuture: true,
      );
      expect(ofKind(ReminderKind.deadline), isEmpty);

      final other = await workspace.save(
        title: 'Tugas dihapus',
        deadline: zones.atWall(day(16, 14), 'UTC', TimeMode.originalZone),
        subtasks: const [],
        reminders: {Duration.zero},
      );
      expect(ofKind(ReminderKind.deadline), hasLength(2));
      await workspace.delete(other);
      expect(ofKind(ReminderKind.deadline), isEmpty);
    },
  );

  test(
    'quiet hours use the device zone, with independent types and half-open boundaries',
    () async {
      const quiet = (startMinute: 22 * 60, endMinute: 7 * 60);
      expect(isQuietTime(day(16, 22), quiet), isTrue);
      expect(isQuietTime(day(17, 6, 59), quiet), isTrue);
      expect(isQuietTime(day(17, 7), quiet), isFalse);
      expect(
        isQuietTime(day(16, 12), (startMinute: 600, endMinute: 780)),
        isTrue,
      );
      expect(
        isQuietTime(day(16, 13), (startMinute: 600, endMinute: 780)),
        isFalse,
      );

      zone = 'Asia/Jakarta';
      await settings(
        quiet: quiet,
        preferences: const PlannerPreferences(
          quietEnabled: true,
          quietExceptionsEnabled: true,
          quietExceptions: {ReminderKind.eventStart},
        ),
      );
      await event(
        'Rapat malam',
        day(16, 16),
        day(16, 17),
        offsets: ['30 menit sebelumnya', 'Saat mulai'],
      );
      expect(ofKind(ReminderKind.event), isEmpty);
      expect(ofKind(ReminderKind.eventStart).single.at, day(16, 16));
      expect(platform.quiet!.exceptions, {ReminderKind.eventStart});
      expect(
        reminders.dashboard.reminders
            .singleWhere((row) => row.kind == ReminderKind.event)
            .quiet,
        isTrue,
      );
      await settings(
        quiet: quiet,
        preferences: const PlannerPreferences(quietEnabled: false),
      );
      expect(ofKind(ReminderKind.event).single.at, day(16, 15, 30));
      await settings(
        preferences: const PlannerPreferences(
          reminderTypes: {ReminderKind.event: false},
        ),
      );
      expect(ofKind(ReminderKind.event), isEmpty);
      expect(ofKind(ReminderKind.eventStart).single.at, day(16, 16));
    },
  );

  test(
    'device travel recalculates floating reminders while keeping original-zone instants',
    () async {
      await event('Asal', day(17, 10), day(17, 11));
      await event(
        'Lokal',
        day(17, 12),
        day(17, 13),
        mode: TimeMode.localWallTime,
      );
      expect(ofKind(ReminderKind.eventStart).map((row) => row.at), [
        day(17, 10),
        day(17, 12),
      ]);
      zone = 'Asia/Jakarta';
      await reminders.refresh();
      final byTitle = {
        for (final row in ofKind(ReminderKind.eventStart)) row.body: row,
      };
      expect(byTitle['Asal']!.at, day(17, 10));
      expect(byTitle['Asal']!.deviceTime, isFalse);
      expect(byTitle['Lokal']!.at, day(17, 5));
      expect(byTitle['Lokal']!.deviceTime, isTrue);
    },
  );

  test(
    'confirmation uses a finite interval, and snooze persists until its source is confirmed',
    () async {
      await settings(
        preferences: const PlannerPreferences(
          confirmationCount: 2,
          confirmationIntervalMinutes: 15,
        ),
      );
      final original = await event('Kelas', day(16, 9), day(16, 10));
      expect(ofKind(ReminderKind.confirmation).map((row) => row.at), [
        day(16, 10, 15),
        day(16, 10, 30),
      ]);
      current = day(16, 10, 16);
      await reminders.refresh();
      final pending = reminders.dashboard.reminders.firstWhere(
        (row) => row.kind == ReminderKind.confirmation,
      );
      await reminders.snooze(pending);
      final snoozed = ofKind(ReminderKind.confirmation).first;
      expect(snoozed.id, pending.id);
      expect(snoozed.at, day(16, 10, 26));
      expect(
        (await store.reminderProgress())[pending.id]!.snoozedUntil,
        snoozed.at,
      );
      await expectLater(reminders.snooze(snoozed), throwsA(isA<StaleRecord>()));
      await repository.changeActivity(original, PreviewEventState.done);
      expect(ofKind(ReminderKind.confirmation), isEmpty);
      expect(await store.reminderProgress(), isEmpty);
    },
  );

  test(
    'conflict notices are deduplicated and timer forecast removal cancels its reminder',
    () async {
      final left = await event('Rapat pagi', day(16, 10), day(16, 11));
      await event('Sesi kedua', day(16, 10, 30), day(16, 11, 30));
      final conflict = ofKind(ReminderKind.conflict).single;
      expect(conflict.catchUp, isTrue);
      current = day(16, 8, 1);
      await reminders.refresh();
      expect(ofKind(ReminderKind.conflict).single.id, conflict.id);
      await repository.changeActivity(left, PreviewEventState.trashed);
      expect(ofKind(ReminderKind.conflict), isEmpty);

      final routine = await store.routines.save(
        Routine(
          RecordMetadata.create(),
          title: 'Latihan',
          targetType: RoutineTargetType.duration,
          targetDuration: const Duration(minutes: 20),
        ),
      );
      final occurrence = await store.routineOccurrences.save(
        RoutineOccurrence(
          RecordMetadata.create(),
          routineId: routine.id,
          day: LocalDate(2026, 11, 16),
          goal: routine.goal,
        ),
      );
      current = day(16, 8, 10);
      await repository.routineWorkspace.start(routine.id, day(16));
      final timer = (await store.routineTimers()).single;
      expect(timer.occurrenceId, occurrence.id);
      expect(ofKind(ReminderKind.timerGoal).single.at, day(16, 8, 30));
      current = day(16, 8, 12);
      await repository.routineWorkspace.pause(timer);
      expect(ofKind(ReminderKind.timerGoal), isEmpty);
      await repository.routineWorkspace.start(routine.id, day(16));
      expect(ofKind(ReminderKind.timerGoal).single.at, day(16, 8, 30));
    },
  );

  test(
    'morning uses agenda counts and backup cadence survives unrelated preference edits',
    () async {
      await settings(
        preferences: const PlannerPreferences(
          morningMinute: 9 * 60,
          backupReminderDays: 7,
        ),
      );
      await event('Rapat', day(16, 10), day(16, 11));
      expect(reminders.dashboard.failed, isFalse);
      expect(
        ofKind(ReminderKind.morning).map((row) => row.at),
        contains(day(16, 9)),
      );
      final morning = ofKind(
        ReminderKind.morning,
      ).singleWhere((row) => row.at == day(16, 9));
      expect(morning.body, contains('1 agenda'));
      expect(ofKind(ReminderKind.backup).first.at, day(23, 8));
      current = day(18, 8);
      await repository.saveProfile(repository.profile!.copyWith(name: 'Rana'));
      expect(ofKind(ReminderKind.backup).first.at, day(23, 8));
      await settings(
        preferences: const PlannerPreferences(backupReminderDays: 30),
      );
      expect(ofKind(ReminderKind.backup).first.at, day(48, 8));
    },
  );

  test(
    'failed post-commit scheduling leaves data saved and retry reconciles the current queue',
    () async {
      platform.failOnce = true;
      final row = await event('Tetap tersimpan', day(16, 10), day(16, 11));
      expect(await store.events.find(row.id), isNotNull);
      expect(reminders.dashboard.failed, isTrue);
      await reminders.refresh();
      expect(reminders.dashboard.failed, isFalse);
      expect(ofKind(ReminderKind.eventStart).single.body, 'Tetap tersimpan');

      final calls = platform.synchronizations;
      await expectLater(
        store.transaction<void>((data) async {
          await data.softDelete((kind: RecordKind.eventOccurrence, id: row.id));
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      expect(platform.synchronizations, calls);
      expect(await store.events.find(row.id), isNotNull);
    },
  );

  test(
    'dense recurring reminders fill the bounded queue in time order',
    () async {
      await event(
        'Harian',
        day(17, 10),
        day(17, 11),
        offsets: ['1 hari sebelumnya', '30 menit sebelumnya', 'Saat mulai'],
        rule: EventRecurrence(RepeatFrequency.daily),
      );
      expect(platform.queued, hasLength(LocalReminders.queueLimit));
      final order = platform.queued.map((row) => row.at).toList();
      expect(order, [...order]..sort());
      expect(order.first, day(16, 10));
    },
  );
}
