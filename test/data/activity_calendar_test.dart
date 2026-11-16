import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/activity_calendar.dart';
import 'package:routina/application/calendar_zones.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DateTime day(int date, [int hour = 0, int minute = 0]) =>
    DateTime.utc(2026, 11, date, hour, minute);
PreviewEvent draft(
  String title,
  DateTime start,
  DateTime end, {
  EventRecurrence? rule,
  DayAvailability availability = DayAvailability.timed,
  TimeMode mode = TimeMode.originalZone,
  String? zone,
  int before = 0,
  int after = 0,
  PreviewEvent? original,
  String? supersedesId,
}) => PreviewEvent(
  id: original?.id ?? '',
  title: title,
  start: start,
  end: end,
  series: original?.series,
  recurrenceKey: original?.recurrenceKey,
  supersedesId: supersedesId,
  options: EventOptions(
    availability: availability,
    rule: rule,
    timeMode: mode,
    zoneId: zone,
    before: before,
    after: after,
    location: 'Ruang 1',
    description: 'Deskripsi',
    note: 'Catatan',
    link: 'https://example.com',
    reminders: const ['10 menit sebelumnya'],
  ),
);

void main() {
  setUpAll(sqfliteFfiInit);
  late Directory directory;
  late String path;
  late SqlitePlannerStore store;
  late DateTime now;
  late CalendarZones zones;
  late ActivityCalendar calendar;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('routina-calendar-');
    path = '${directory.path}${Platform.pathSeparator}calendar.db';
    store = await SqlitePlannerStore.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    now = day(16, 6);
    zones = CalendarZones(deviceZoneId: 'UTC');
    calendar = ActivityCalendar(store, zones, now: () => now);
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  test(
    'large bounded ranges, inclusive end and monthly missing dates are deterministic',
    () {
      final monthly = EventRecurrence(
        RepeatFrequency.monthly,
        until: DateTime.utc(2028, 5, 31),
      );
      final dates = monthly.dates(
        DateTime.utc(2028, 1, 31),
        DateTime.utc(2028, 2),
        DateTime.utc(2028, 7),
      );
      expect(dates.map(civilKey), ['2028-03-31', '2028-05-31']);
      final weekly = EventRecurrence(
        RepeatFrequency.weekly,
        interval: 2,
        until: day(30),
      );
      expect(
        EventRecurrence.decode(
          weekly.encode(),
        ).dates(day(16), day(17), day(32)).toList(),
        [day(30)],
      );
      final daily = EventRecurrence(RepeatFrequency.daily);
      expect(daily.dates(DateTime.utc(1900), day(16), day(18)).toList(), [
        day(16),
        day(17),
      ]);
    },
  );

  test(
    'SQLite restart preserves cross-midnight events, all-day dates and form details',
    () async {
      final night = await calendar.save(
        draft('Lintas hari', day(16, 23), day(17, 2)),
      );
      await calendar.save(
        draft('Tersedia', day(17), day(18), availability: DayAvailability.free),
      );
      await store.close();
      store = await SqlitePlannerStore.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      calendar = ActivityCalendar(store, zones, now: () => now);
      final first = await calendar.read(day(16), day(17));
      final next = await calendar.read(day(17), day(18));
      expect(first.map((event) => event.id), [night.id]);
      expect(next.map((event) => event.id), contains(night.id));
      expect(
        next.singleWhere((entry) => entry.allDay).options.availability,
        DayAvailability.free,
      );
      expect(await calendar.read(day(18), day(19)), isEmpty);
      expect(DailyPreview(first, day(16)).total, 1);
      expect(DailyPreview(next, day(17)).total, 1);
      final saved = (await store.events.find(night.id))!;
      expect(saved.details.location, 'Ruang 1');
      expect(saved.details.note, 'Catatan');
      expect(saved.details.link, 'https://example.com');
      expect(saved.details.reminders, ['10 menit sebelumnya']);
    },
  );

  test(
    'Busy blocks, Free does not and saving overlap, buffer or hours requires approval',
    () async {
      calendar = ActivityCalendar(
        store,
        zones,
        now: () => now,
        profile: PreviewProfile(
          activeHours: {
            DateTime.monday: const ActiveInterval(8 * 60, 17 * 60),
            DateTime.tuesday: const ActiveInterval(8 * 60, 17 * 60),
          },
        ),
      );
      await calendar.save(draft('Dasar', day(16, 9), day(16, 10), after: 20));
      final overlap = draft('Bentrok', day(16, 9, 30), day(16, 10, 30));
      final buffer = draft('Buffer', day(16, 10, 5), day(16, 11));
      final outside = draft('Jam aktif', day(16, 16), day(17, 9));
      expect(await calendar.warnings(overlap), [ScheduleWarning.overlap]);
      expect(await calendar.warnings(buffer), [ScheduleWarning.buffer]);
      expect(await calendar.warnings(outside), [ScheduleWarning.activeHours]);
      await expectLater(
        calendar.save(overlap),
        throwsA(isA<ActivityWarnings>()),
      );
      expect((await store.events.all()).length, 1);
      await calendar.save(overlap, approved: {ScheduleWarning.overlap});
      await calendar.save(
        draft('Sibuk', day(18), day(19), availability: DayAvailability.busy),
      );
      await calendar.save(
        draft('Gratis', day(19), day(20), availability: DayAvailability.free),
      );
      expect(
        await calendar.warnings(draft('Ditahan', day(18, 12), day(18, 13))),
        [ScheduleWarning.overlap],
      );
      expect(
        await calendar.warnings(draft('Bebas', day(19, 12), day(19, 13))),
        isEmpty,
      );
      expect(
        await calendar.warnings(
          draft('Persis batas', day(16, 10, 30), day(16, 11, 30)),
        ),
        isEmpty,
      );
    },
  );

  test(
    'series exceptions, following split and entire delete preserve confirmed records',
    () async {
      final rule = EventRecurrence(RepeatFrequency.daily);
      await calendar.save(draft('Asal', day(16, 9), day(16, 10), rule: rule));
      final original = await calendar.read(day(16), day(23));
      expect(original.length, 7);
      expect(
        await store.events.all(),
        isEmpty,
        reason: 'Generated slots stay virtual until an explicit mutation',
      );
      await expectLater(
        calendar.change(original.first, PreviewEventState.done),
        throwsStateError,
      );
      now = day(18, 12);
      final pending = await calendar.read(day(16), day(17));
      expect(pending.single.state, PreviewEventState.pending);
      final historical = await calendar.change(
        pending.single,
        PreviewEventState.done,
      );
      expect(historical.id, original.first.id);
      final exception = await calendar.save(
        draft('Pengecualian', day(19, 11), day(19, 12), original: original[3]),
        scope: SeriesScope.occurrence,
      );
      expect(exception.isException, isTrue);
      expect(exception.id, original[3].id);
      await calendar.change(
        original[4],
        PreviewEventState.trashed,
        scope: SeriesScope.occurrence,
      );
      final split = await calendar.save(
        draft(
          'Seri baru',
          day(21, 12),
          day(21, 13),
          original: original[5],
          rule: rule,
        ),
        scope: SeriesScope.following,
      );
      expect(split.series, isNot(original.first.series));
      final fresh = await calendar.read(day(16), day(25));
      expect(
        fresh.where((row) => row.title == 'Asal').map((row) => row.start.day),
        [16, 17, 18],
      );
      expect(
        fresh.where((row) => row.title == 'Pengecualian').single.start.hour,
        11,
      );
      expect(fresh.where((row) => row.start.day == 20), isEmpty);
      expect(
        fresh
            .where((row) => row.title == 'Seri baru')
            .map((row) => row.start.day),
        [21, 22, 23, 24],
      );
      expect(
        (await store.eventSeries.find(split.series!))!.splitFromId,
        original.first.series,
      );

      await calendar.change(
        fresh.last,
        PreviewEventState.trashed,
        scope: SeriesScope.entire,
      );
      expect((await calendar.read(day(21), day(25))), isEmpty);
      expect(
        (await calendar.read(day(16), day(17))).single.state,
        PreviewEventState.done,
      );
      expect(
        (await store.statusHistory.all()).single.target.id,
        original.first.id,
      );
      expect(
        (await calendar.trash()).map((row) => row.id),
        contains(original[4].id),
      );
    },
  );

  test(
    'entire edit preserves earlier pending rows and avoids re-generating deleted days',
    () async {
      final rule = EventRecurrence(RepeatFrequency.daily);
      await calendar.save(draft('Asal', day(16, 9), day(16, 10), rule: rule));
      final original = await calendar.read(day(16), day(24));
      await calendar.change(
        original[4],
        PreviewEventState.trashed,
        scope: SeriesScope.occurrence,
      );
      now = day(18, 12);
      await calendar.save(
        draft(
          'Hari mendatang',
          day(22, 11),
          day(22, 12),
          rule: rule,
          original: original[6],
        ),
        scope: SeriesScope.entire,
      );
      final results = await calendar.read(day(16), day(24));
      expect(
        results.where((row) => row.title == 'Asal').map((row) => row.state),
        everyElement(PreviewEventState.pending),
      );
      expect(
        results
            .where((row) => row.title == 'Hari mendatang')
            .map((row) => row.start.day),
        [19, 21, 22, 23],
      );
      expect(
        results
            .where((row) => row.title == 'Hari mendatang')
            .map((row) => row.start.hour),
        everyElement(11),
      );
    },
  );

  test(
    'manual replacement is linked and old outcomes remain immutable',
    () async {
      final original = await calendar.save(
        draft('Asal', day(16, 8), day(16, 9)),
      );
      now = day(16, 10);
      final skipped = await calendar.change(
        original,
        PreviewEventState.skipped,
      );
      final replacement = await calendar.save(
        draft('Pengganti', day(17, 8), day(17, 9), supersedesId: skipped.id),
      );
      expect(
        (await store.events.find(replacement.id))!.supersedesId,
        original.id,
      );
      expect(
        (await store.events.find(original.id))!.status,
        ActivityStatus.skipped,
      );
      await expectLater(
        calendar.change(skipped, PreviewEventState.done),
        throwsStateError,
      );
    },
  );

  test(
    'weekly recurrence retains civil time across DST and device-local follows the device',
    () async {
      final ny = CalendarZones(
        deviceZoneId: 'America/New_York',
        displayZoneId: 'UTC',
      );
      now = DateTime.utc(2026, 2, 28);
      calendar = ActivityCalendar(store, ny, now: () => now);
      final weekly = EventRecurrence(RepeatFrequency.weekly);
      await calendar.save(
        draft(
          'Asal',
          DateTime.utc(2026, 3, 1, 9),
          DateTime.utc(2026, 3, 1, 10),
          rule: weekly,
          zone: 'America/New_York',
        ),
      );
      await calendar.save(
        draft(
          'Lokal',
          DateTime.utc(2026, 3, 1, 11),
          DateTime.utc(2026, 3, 1, 12),
          mode: TimeMode.localWallTime,
        ),
      );
      final beforeTravel = await calendar.read(
        DateTime.utc(2026, 3, 1),
        DateTime.utc(2026, 3, 9),
      );
      expect(
        beforeTravel
            .where((row) => row.title == 'Asal')
            .map((row) => row.start.hour),
        [14, 13],
      );
      expect(
        beforeTravel.singleWhere((row) => row.title == 'Lokal').start.hour,
        16,
      );
      final jakarta = CalendarZones(
        deviceZoneId: 'Asia/Jakarta',
        displayZoneId: 'UTC',
      );
      final atDestination = await ActivityCalendar(
        store,
        jakarta,
        now: () => now,
      ).read(DateTime.utc(2026, 3, 1), DateTime.utc(2026, 3, 9));
      expect(
        atDestination.singleWhere((row) => row.title == 'Lokal').start.hour,
        4,
      );
      expect(
        atDestination
            .where((row) => row.title == 'Asal')
            .map((row) => row.start.hour),
        [14, 13],
      );
      now = DateTime.utc(2026, 3, 1, 20);
      final destinationCalendar = ActivityCalendar(
        store,
        jakarta,
        now: () => now,
      );
      final floating = atDestination.singleWhere((row) => row.title == 'Lokal');
      await destinationCalendar.change(floating, PreviewEventState.done);
      final afterConfirmation = await calendar.read(
        DateTime.utc(2026, 3, 1),
        DateTime.utc(2026, 3, 2),
      );
      final completed = afterConfirmation.singleWhere(
        (row) => row.title == 'Lokal',
      );
      expect(completed.start.hour, 4);
      expect(completed.state, PreviewEventState.done);
    },
  );

  test('a DST gap never produces a reversed recurrence interval', () async {
    final zones = CalendarZones(
      deviceZoneId: 'America/New_York',
      displayZoneId: 'America/New_York',
    );
    now = DateTime.utc(2026, 3, 1);
    calendar = ActivityCalendar(store, zones, now: () => now);
    await calendar.save(
      draft(
        'Peralihan DST',
        DateTime.utc(2026, 3, 1, 2, 30),
        DateTime.utc(2026, 3, 1, 3, 15),
        rule: EventRecurrence(RepeatFrequency.weekly),
      ),
    );
    final rows = await calendar.read(
      DateTime.utc(2026, 3, 8),
      DateTime.utc(2026, 3, 9),
    );
    expect(
      rows.single.end.difference(rows.single.start),
      const Duration(minutes: 45),
    );
  });
}
