import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/activity_calendar.dart';
import 'package:routina/application/calendar_zones.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/data/stored_planner_profile.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/domain/productivity.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DateTime date(int day, [int hour = 0, int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

void main() {
  setUpAll(sqfliteFfiInit);
  late DateTime now;
  late String deviceZone;
  late SqlitePlannerStore store;
  late StoredPlannerProfile repository;
  final utc = CalendarZones(deviceZoneId: 'UTC');

  setUp(() async {
    now = date(14, 8);
    deviceZone = 'UTC';
    store = await SqlitePlannerStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      now: () => now,
    );
    repository = StoredPlannerProfile(
      today: now,
      now: () => now,
      openStore: () async => store,
      readDeviceZone: () async => deviceZone,
    );
    await repository.saveProfile(PreviewProfile(name: 'Nara'));
  });

  tearDown(() => store.close());

  ScheduledInterval schedule(DateTime start, DateTime end) =>
      utc.interval(start, end, 'UTC', TimeMode.originalZone);

  Future<EventOccurrence> event(
    String title,
    DateTime start,
    DateTime end, {
    ActivityStatus status = ActivityStatus.planned,
    String? category,
    String? supersedes,
    String? routineOccurrence,
  }) => store.events.save(
    EventOccurrence(
      RecordMetadata.create(),
      title: title,
      schedule: schedule(start, end),
      status: status,
      categoryId: category,
      supersedesId: supersedes,
      routineOccurrenceId: routineOccurrence,
    ),
  );

  Future<ProductivityReport> read(ProductivityQuery query) =>
      repository.productivityReader(query);
  Future<ProductivitySummary> day(int day) async => (await read(
    ProductivityQuery(period: ProductivityPeriod.day, anchor: date(day)),
  )).selected;

  test(
    'Home and reports share dates, deduplication and explicit confirmation',
    () async {
      final work = await repository.saveCategory(
        Category(RecordMetadata.create(), name: 'Kerja', color: 0xFF537BFF),
      );
      final routine = await repository.routineWorkspace.save(
        Routine(
          RecordMetadata.create(),
          title: 'Target hari kerja',
          targetType: RoutineTargetType.count,
          targetAmount: 2,
          frequencyRule: 'FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR',
          categoryId: work.id,
        ),
      );
      final night = await event(
        'Lintas tengah malam',
        date(15, 23),
        date(16, 1),
        status: ActivityStatus.skipped,
      );
      final task = await store.tasks.save(
        Task(
          RecordMetadata.create(),
          title: 'Tenggat tugas',
          deadline: utc.atWall(date(16, 17), 'UTC', TimeMode.originalZone),
          status: ActivityStatus.completed,
          categoryId: work.id,
        ),
      );
      for (final d in [15, 16, 17]) {
        await store.workSessions.save(
          WorkSession(
            RecordMetadata.create(),
            taskId: task.id,
            schedule: schedule(date(d, 10), date(d, 11)),
            status: ActivityStatus.completed,
          ),
        );
      }
      now = date(16, 8);
      await repository.routineWorkspace.setCount(routine.id, date(16), 2);
      final target = (await repository.routineWorkspace.read(
        routine.id,
        date(16),
      ))!.occurrence!;
      final original = await event(
        'Blok target ditunda',
        date(16, 7),
        date(16, 8),
        status: ActivityStatus.postponed,
        routineOccurrence: target.id,
      );
      final postponement = await event(
        'Acara asal',
        date(16, 9),
        date(16, 10),
        status: ActivityStatus.postponed,
        category: work.id,
      );
      await event(
        'Pengganti acara',
        date(17, 9),
        date(17, 10),
        status: ActivityStatus.completed,
        supersedes: postponement.id,
        category: work.id,
      );
      final replacement = await event(
        'Pengganti blok',
        date(17, 10),
        date(17, 11),
        status: ActivityStatus.postponed,
        supersedes: original.id,
      );
      await event(
        'Pengganti akhir pekan',
        date(21, 10),
        date(21, 11),
        status: ActivityStatus.completed,
        supersedes: replacement.id,
      );
      final first = await event(
        'Kegiatan terdekat',
        date(16, 16),
        date(16, 16, 30),
      );
      final trashed = await event(
        'Di tong sampah',
        date(16, 14),
        date(16, 15),
        status: ActivityStatus.completed,
      );
      await store.softDelete((
        kind: RecordKind.eventOccurrence,
        id: trashed.id,
      ));
      await event(
        'Batal',
        date(16, 11),
        date(16, 12),
        status: ActivityStatus.cancelled,
      );
      await store.tasks.save(
        Task(RecordMetadata.create(), title: 'Tanpa tenggat'),
      );

      await repository.load(PreviewSurface.home);
      final home = repository.homeProductivity!;
      expect(repository.homeNextEvent!.id, first.id);
      expect(home.tally.total, 4);
      expect(home.tally.completed, 1);
      expect(home.tally.open, 3);
      expect(home.tally.ratio, .25);
      expect(home.tally.postponed, 1);
      expect(home.history.map((item) => item.id), isNot(contains(night.id)));
      expect(
        home.history.singleWhere((item) => item.id == original.id).status,
        ActivityStatus.postponed,
      );
      expect(
        repository.homeEntries.map((entry) => entry.id),
        contains(night.id),
      );
      expect((await day(15)).tally.skipped, 1);
      expect(
        (await day(16)).history.map((item) => item.id),
        home.history.map((item) => item.id),
      );

      now = date(23, 8);
      final next = await day(17);
      expect(next.tally.ratio, .5);
      expect(
        next.history
            .singleWhere((item) => item.id == replacement.id)
            .isCalendarBlock,
        isTrue,
      );
      expect(
        next.history.where((item) => item.isUnscheduledTarget).single.routineId,
        routine.id,
      );
      expect((await day(21)).history.single.isCalendarBlock, isFalse);
      expect((await day(21)).tally.ratio, 1);
      expect((await day(22)).tally.ratio, isNull);

      await repository.routineWorkspace.confirm(
        routine.id,
        date(16),
        ActivityStatus.completed,
      );
      expect((await day(16)).tally.ratio, .5);
      final filtered = await read(
        ProductivityQuery(
          period: ProductivityPeriod.week,
          anchor: date(16),
          filter: ProductivityFilter(
            categoryId: work.id,
            kind: ProductivityKind.task,
          ),
        ),
      );
      expect(filtered.selected.tally.ratio, 1);
      expect(filtered.selected.history.single.id, task.id);
    },
  );

  test(
    'Sunday and Monday regroup historical data without editing records',
    () async {
      final sunday = await event(
        'Akhir pekan',
        date(15, 8),
        date(15, 9),
        status: ActivityStatus.completed,
      );
      final monday = await event(
        'Awal pekan',
        date(16, 8),
        date(16, 9),
        status: ActivityStatus.skipped,
      );
      now = date(28);
      final query = ProductivityQuery(anchor: date(16), compare: true);
      final before = await read(query);
      expect(before.windows.nominal.start, date(16));
      expect(before.selected.tally.ratio, 0);
      expect(before.comparison!.tally.ratio, 1);
      final sundayFirst = PreviewProfile(name: 'Nara', sundayFirst: true);
      await repository.saveProfile(sundayFirst);
      final after = await read(query);
      expect(after.windows.nominal.start, date(15));
      expect(after.selected.tally.ratio, .5);
      expect(after.comparison!.tally.ratio, isNull);
      expect(after.selected.history.map((item) => item.id), [
        monday.id,
        sunday.id,
      ]);
      final saved = (await store.events.find(sunday.id))!;
      expect(saved.metadata.revision, sunday.metadata.revision);
      expect(saved.schedule.start.instant, sunday.schedule.start.instant);
      expect(saved.status, sunday.status);
    },
  );

  test(
    'reporting zone follows projected instants and retains all-day dates',
    () async {
      now = date(18);
      final original = await event(
        'Zona asal',
        date(15, 23),
        date(16, 1),
        status: ActivityStatus.completed,
      );
      final floating = await store.tasks.save(
        Task(
          RecordMetadata.create(),
          title: 'Deadline lokal',
          deadline: utc.atWall(date(15, 23), 'UTC', TimeMode.localWallTime),
        ),
      );
      final allDay = await store.events.save(
        EventOccurrence(
          RecordMetadata.create(),
          title: 'Sepanjang hari',
          schedule: schedule(date(15), date(17)),
          availability: EventAvailability.allDayFree,
          allDayStart: LocalDate.parse('2026-11-15'),
          allDayEndExclusive: LocalDate.parse('2026-11-17'),
        ),
      );
      expect((await day(15)).tally.total, 3);
      expect((await day(16)).tally.ratio, isNull);

      deviceZone = 'Asia/Jakarta';
      final first = await day(15);
      final second = await day(16);
      expect(first.history.map((item) => item.id), [allDay.id, floating.id]);
      expect(second.history.single.id, original.id);
      expect(first.tally.ratio, 0);
      expect(second.tally.ratio, 1);

      await repository.saveProfile(
        PreviewProfile(
          name: 'Nara',
          preferences: const PlannerPreferences(calendarZoneId: 'UTC'),
        ),
      );
      expect((await day(15)).history.map((item) => item.id).toSet(), {
        allDay.id,
        floating.id,
        original.id,
      });
      expect((await day(16)).tally.ratio, isNull);
      expect(
        (await store.tasks.find(floating.id))!.deadline!.instant,
        date(15, 23),
      );
    },
  );

  test(
    'cadence edits preserve older targets and trash suppresses inferred targets',
    () async {
      final routine = await repository.routineWorkspace.save(
        Routine(
          RecordMetadata.create(),
          title: 'Latihan',
          targetType: RoutineTargetType.frequency,
          targetAmount: 3,
          frequencyRule: 'FREQ=DAILY',
        ),
      );
      now = date(16, 10);
      final edited = await repository.routineWorkspace.save(
        Routine(
          routine.metadata,
          title: 'Latihan',
          targetType: RoutineTargetType.frequency,
          targetAmount: 3,
          frequencyRule: 'FREQ=WEEKLY',
        ),
      );
      expect(edited.cadenceHistory.length, 2);
      expect((await day(13)).tally.ratio, isNull);
      expect((await day(14)).tally.total, 1);
      expect((await day(15)).tally.total, 1);
      expect((await day(16)).tally.ratio, isNull);
      await repository.routineWorkspace.setCount(routine.id, date(16), 1);
      final occurrence = (await repository.routineWorkspace.read(
        routine.id,
        date(16),
      ))!.occurrence!;
      expect((await day(16)).tally.total, 1);
      await store.softDelete((
        kind: RecordKind.routineOccurrence,
        id: occurrence.id,
      ));
      expect((await day(16)).tally.ratio, isNull);
      await store.softDelete((kind: RecordKind.routine, id: routine.id));
      expect((await day(15)).tally.ratio, isNull);
    },
  );

  test(
    'Home finds the next recurrence outside the agenda window after a deleted instance',
    () async {
      final calendar = ActivityCalendar(store, utc, now: () => now);
      final first = await calendar.save(
        PreviewEvent(
          id: '',
          title: 'Agenda berkala',
          start: date(1, 11),
          end: date(1, 12),
          options: EventOptions(
            rule: EventRecurrence(RepeatFrequency.monthly, interval: 2),
          ),
        ),
      );
      // January 1 is the next occurrence. Delete only that occurrence.
      final january = (await calendar.read(
        DateTime.utc(2027, 1, 1),
        DateTime.utc(2027, 1, 2),
      )).single;
      await calendar.change(
        january,
        PreviewEventState.trashed,
        scope: SeriesScope.occurrence,
      );
      await event(
        'Acara April',
        DateTime.utc(2027, 4, 1),
        DateTime.utc(2027, 4, 1, 1),
      );
      await repository.load(PreviewSurface.home);
      expect(first.title, repository.homeNextEvent!.title);
      expect(repository.homeNextEvent!.start, DateTime.utc(2027, 3, 1, 11));
      expect(repository.homeProductivity!.tally.ratio, isNull);
    },
  );
}
