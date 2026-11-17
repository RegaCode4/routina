import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/activity_calendar.dart';
import 'package:routina/application/calendar_zones.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/application/task_workspace.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temp;
  late String path;
  late SqlitePlannerStore store;
  late CalendarZones zones;
  late DateTime clock;
  late ActivityCalendar calendar;
  late TaskWorkspace workspace;
  PreviewProfile? profile;

  DateTime day(int day, [int hour = 0, int minute = 0]) =>
      DateTime.utc(2026, 11, day, hour, minute);

  ZonedTime deadline(
    DateTime value, {
    TimeMode mode = TimeMode.originalZone,
    String? zone,
  }) => zones.atWall(value, zone ?? zones.displayId, mode);

  void useCalendar() {
    calendar = ActivityCalendar(
      store,
      zones,
      now: () => clock,
      profile: profile,
    );
  }

  Future<Task> addTask(
    String title,
    DateTime due, {
    TimeMode mode = TimeMode.originalZone,
  }) => workspace.save(
    title: title,
    deadline: deadline(due, mode: mode),
    subtasks: const [],
  );

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('routina-tasks-');
    path = '${temp.path}/tasks.db';
    store = await SqlitePlannerStore.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    zones = CalendarZones(deviceZoneId: 'UTC');
    clock = day(16, 8);
    profile = null;
    useCalendar();
    workspace = TaskWorkspace(
      openStore: () async => store,
      openCalendar: () async => calendar,
      readZones: () => zones,
      now: () => clock,
    );
  });
  tearDown(() async {
    await store.close();
    await temp.delete(recursive: true);
  });

  test(
    'task and checklist edits, reminders and soft delete persist in SQLite',
    () async {
      final category = await store.categories.save(
        Category(
          RecordMetadata.create(),
          name: 'Kuliah',
          color: 0xFF537BFF,
          icon: 'school',
        ),
      );
      final task = await workspace.save(
        title: ' Laporan ',
        description: ' Ringkasan ',
        categoryId: category.id,
        priority: 'Tinggi',
        deadline: deadline(day(18, 10)),
        estimate: const Duration(minutes: 135),
        subtasks: const [(existing: null, title: 'Kumpulkan data')],
        reminders: {const Duration(hours: 1), const Duration(days: 1)},
      );
      final first = (await workspace.read(task.id))!.subtasks.single;
      expect((await workspace.read(task.id))!.progress, 0);
      await workspace.toggle(first, true);
      final checked = (await workspace.read(task.id))!;
      expect(checked.progress, 1);
      expect(checked.completed, isFalse);

      final changed = await workspace.save(
        previous: checked.task,
        title: 'Laporan revisi',
        deadline: checked.task.deadline!,
        categoryId: category.id,
        priority: 'Sedang',
        description: checked.task.description,
        estimate: checked.task.initialEstimate,
        subtasks: [
          (existing: checked.subtasks.single, title: 'Data bersih'),
          (existing: null, title: 'Analisis'),
        ],
        reminders: {const Duration(days: 1)},
      );
      await store.close();
      store = await SqlitePlannerStore.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      useCalendar();

      final reopened = (await workspace.read(changed.id))!;
      expect(reopened.task.title, 'Laporan revisi');
      expect(reopened.task.description, 'Ringkasan');
      expect(reopened.task.priority, 'Sedang');
      expect(reopened.task.categoryId, category.id);
      expect(reopened.task.initialEstimate, const Duration(minutes: 135));
      expect(reopened.subtasks.first.id, first.id);
      expect(reopened.subtasks.first.title, 'Data bersih');
      expect(reopened.progress, .5);
      expect(reopened.reminders.single.offset, const Duration(days: 1));

      final reduced = await workspace.save(
        previous: reopened.task,
        title: reopened.task.title,
        deadline: reopened.task.deadline!,
        subtasks: [
          (
            existing: reopened.subtasks.first,
            title: reopened.subtasks.first.title,
          ),
        ],
      );
      expect((await workspace.read(reduced.id))!.subtasks.length, 1);
      await workspace.delete(reduced);
      expect(await workspace.list(), isEmpty);
      expect(await workspace.read(task.id), isNull);
      expect((await workspace.trash()).single.title, 'Laporan revisi');
      expect(
        (await store.subtasks.find(first.id, includeDeleted: true))!.checked,
        isTrue,
      );
    },
  );

  test(
    'moving deadline and session are independent and Calendar KPI counts task once',
    () async {
      final task = await addTask('Ulas dokumen', day(18, 14));
      final session = await workspace.saveSession(
        task.id,
        day(17, 9),
        day(17, 10),
      );
      final deadlineBefore = (await store.tasks.find(
        task.id,
      ))!.deadline!.instant;
      final moved = await workspace.saveSession(
        task.id,
        day(18, 11),
        day(18, 12),
        previous: session,
      );
      expect(moved.id, session.id);
      expect(
        (await store.tasks.find(task.id))!.deadline!.instant,
        deadlineBefore,
      );

      final updated = await workspace.moveDeadline(task, deadline(day(18, 16)));
      final still = (await store.workSessions.find(moved.id))!;
      expect(still.schedule.start.instant, day(18, 11));
      expect(still.schedule.end.instant, day(18, 12));
      expect(still.metadata.revision, moved.metadata.revision);
      expect(updated.deadline!.instant, day(18, 16));
      final rows = await calendar.read(day(18), day(19));
      expect(rows.map((row) => row.kind), [
        PreviewKind.session,
        PreviewKind.deadline,
      ]);
      expect(rows.map((row) => row.obligationId), everyElement(task.id));
      expect(DailyPreview(rows, day(18)).total, 1);
      expect(
        DailyPreview(
          rows.where((row) => row.kind == PreviewKind.session).toList(),
          day(18),
        ).total,
        0,
      );

      await workspace.delete(updated);
      expect(await calendar.read(day(18), day(19)), isEmpty);
      expect(await store.workSessions.find(session.id), isNull);
      expect(
        (await store.workSessions.find(
          session.id,
          includeDeleted: true,
        ))!.taskId,
        task.id,
      );
    },
  );

  test(
    'completion revalidates reviewed sessions and cancels only future unstarted rows',
    () async {
      final task = await addTask('Selesai eksplisit', day(19, 12));
      final past = await workspace.saveSession(
        task.id,
        day(16, 9),
        day(16, 10),
      );
      final underway = await workspace.saveSession(
        task.id,
        day(16, 11),
        day(16, 12),
      );
      final future = await workspace.saveSession(
        task.id,
        day(17, 9),
        day(17, 10),
      );
      clock = day(16, 11, 30);
      final log = await store.timeLogs.save(
        TimeLog(
          RecordMetadata.create(),
          target: (kind: RecordKind.workSession, id: past.id),
          actualDuration: const Duration(minutes: 35),
          recordedAt: clock,
          source: TimeLogSource.manual,
        ),
      );
      await workspace.markSessionHeld(past);
      await expectLater(
        workspace.complete(task, reviewedFutureIds: {}, cancelFuture: true),
        throwsA(isA<TaskIssue>()),
      );
      expect((await store.tasks.find(task.id))!.status, ActivityStatus.planned);
      expect(
        (await store.workSessions.find(future.id))!.status,
        ActivityStatus.planned,
      );
      await workspace.complete(
        task,
        reviewedFutureIds: {future.id},
        cancelFuture: true,
      );

      final completed = (await workspace.read(task.id))!;
      expect(completed.completed, isTrue);
      expect(completed.actual, const Duration(minutes: 35));
      expect(completed.planned, const Duration(hours: 2));
      expect(completed.logs.single.id, log.id);
      expect(completed.sessions.map((row) => row.status), [
        ActivityStatus.completed,
        ActivityStatus.planned,
        ActivityStatus.cancelled,
      ]);
      expect(
        completed.sessions.first.schedule.start.instant,
        past.schedule.start.instant,
      );
      expect(
        (await calendar.read(
          day(17),
          day(18),
        )).where((row) => row.id == future.id),
        isEmpty,
      );
      final history = await store.statusHistory.all();
      expect(
        history.map((row) => row.target.id),
        containsAll([task.id, future.id, past.id]),
      );
      await expectLater(
        workspace.saveSession(
          task.id,
          day(18, 9),
          day(18, 10),
          previous: underway,
        ),
        throwsA(isA<TaskIssue>()),
      );
    },
  );

  test(
    'keeping future sessions leaves their revision and calendar row intact',
    () async {
      final task = await addTask('Pertahankan', day(19, 12));
      final work = await workspace.saveSession(
        task.id,
        day(17, 9),
        day(17, 10),
      );
      await workspace.complete(
        task,
        reviewedFutureIds: {work.id},
        cancelFuture: false,
      );
      final view = (await workspace.read(task.id))!;
      expect(view.completed, isTrue);
      expect(view.actual, isNull);
      expect(view.upcoming.single.metadata.revision, work.metadata.revision);
      expect((await calendar.read(day(17), day(18))).single.id, work.id);
      expect(
        DailyPreview(await calendar.read(day(17), day(18)), day(17)).total,
        0,
      );
    },
  );

  test(
    'overdue and daily deadline projection follow fixed or floating mode',
    () async {
      zones = CalendarZones(
        deviceZoneId: 'Pacific/Kiritimati',
        displayZoneId: 'UTC',
      );
      useCalendar();
      clock = day(15, 0);
      final local = await workspace.save(
        title: 'Jam lokal',
        deadline: deadline(
          day(16, 6),
          mode: TimeMode.localWallTime,
          zone: zones.deviceId,
        ),
        subtasks: const [],
      );
      final fixed = await workspace.save(
        title: 'Zona asal',
        deadline: deadline(day(16, 6), zone: zones.deviceId),
        subtasks: const [],
      );
      expect(
        (await calendar.read(day(15), day(16))).map((row) => row.id),
        containsAll([local.id, fixed.id]),
      );

      zones = CalendarZones(
        deviceZoneId: 'America/Los_Angeles',
        displayZoneId: 'UTC',
      );
      useCalendar();
      clock = day(16, 13, 59);
      final projected = (await calendar.read(day(16), day(17))).single;
      expect(projected.id, local.id);
      expect(projected.start, day(16, 14));
      expect((await workspace.read(fixed.id))!.overdue, isTrue);
      expect((await workspace.read(local.id))!.overdue, isFalse);
      clock = day(16, 14, 1);
      expect((await workspace.read(local.id))!.overdue, isTrue);
      await expectLater(
        addTask('Tenggat lampau', day(16, 14)),
        throwsA(isA<PastTaskDeadline>()),
      );
    },
  );

  test(
    'manual overlap, active hours, and deadline warnings require approval',
    () async {
      profile = PreviewProfile(
        name: '',
        activeHours: {DateTime.monday: ActiveInterval(8 * 60, 12 * 60)},
        defaultBuffer: Duration(minutes: 5),
      );
      useCalendar();
      final task = await addTask('Sesi disetujui', day(16, 12));
      await calendar.save(
        PreviewEvent(
          id: '',
          title: 'Kegiatan sibuk',
          start: day(16, 9),
          end: day(16, 11),
          options: const EventOptions(before: 0, after: 0),
        ),
      );
      await expectLater(
        workspace.saveSession(task.id, day(16, 10, 50), day(16, 13)),
        throwsA(
          isA<SessionWarnings>()
              .having((value) => value.afterDeadline, 'setelah tenggat', isTrue)
              .having(
                (value) => value.schedule,
                'peringatan',
                containsAll([
                  ScheduleWarning.overlap,
                  ScheduleWarning.activeHours,
                ]),
              ),
        ),
      );
      expect(await store.workSessions.all(), isEmpty);
      final saved = await workspace.saveSession(
        task.id,
        day(16, 8, 15),
        day(16, 8, 55),
      );
      expect(saved.taskId, task.id);
    },
  );
}
