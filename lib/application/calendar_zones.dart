import 'dart:math' as math;

import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/scheduling_engine.dart';
import 'package:timezone/data/latest_all.dart' as data;
import 'package:timezone/timezone.dart' as tz;

class CalendarZones {
  CalendarZones({required String deviceZoneId, String? displayZoneId}) {
    if (!_initialized) {
      data.initializeTimeZones();
      _initialized = true;
    }
    device = _location(deviceZoneId) ?? tz.UTC;
    display = _location(displayZoneId) ?? device;
  }

  static bool _initialized = false;
  late final tz.Location device;
  late final tz.Location display;

  tz.Location _byName(String id) => _location(id) ?? device;
  static tz.Location? _location(String? id) =>
      id == null ? null : tz.timeZoneDatabase.locations[id];

  String get deviceId => device.name;
  String get displayId => display.name;

  DateTime wall(DateTime instant, String zone) =>
      civilTime(tz.TZDateTime.from(instant, _byName(zone)));

  String abbreviation(DateTime instant, String zone) =>
      tz.TZDateTime.from(instant, _byName(zone)).timeZoneName;

  DateTime instant(DateTime wall, String zone) => tz.TZDateTime(
    _byName(zone),
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
    wall.millisecond,
    wall.microsecond,
  ).toUtc();

  DateTime effectiveTime(ZonedTime time) => time.mode == TimeMode.localWallTime
      ? instant(DateTime.parse(time.localWallTime!), deviceId)
      : time.instant;

  /// Preimage of a civil interval, including both occurrences of a repeated
  /// hour and excluding any civil minutes skipped by an offset change.
  Iterable<SchedulingSlot> deviceWallWindows(
    DateTime start,
    DateTime end,
  ) sync* {
    var cursor = civilTime(start).subtract(const Duration(days: 2));
    final limit = civilTime(end).add(const Duration(days: 2));
    SchedulingSlot? pending;
    while (cursor.isBefore(limit)) {
      final period = device.lookupTimeZone(cursor.millisecondsSinceEpoch);
      final until = period.end < limit.millisecondsSinceEpoch
          ? DateTime.fromMillisecondsSinceEpoch(period.end, isUtc: true)
          : limit;
      final offset = Duration(milliseconds: period.timeZone.offset);
      final part = intersectSlots(
        (start: cursor, end: until),
        (
          start: civilTime(start).subtract(offset),
          end: civilTime(end).subtract(offset),
        ),
      );
      if (part != null) {
        if (pending == null) {
          pending = part;
        } else if (pending.end == part.start) {
          pending = (start: pending.start, end: part.end);
        } else {
          yield pending;
          pending = part;
        }
      }
      cursor = until;
    }
    if (pending != null) yield pending;
  }

  ZonedTime atWall(DateTime wall, String zone, TimeMode mode) => ZonedTime(
    instant: instant(wall, zone),
    zoneId: zone,
    mode: mode,
    localWallTime: civilTime(wall).toIso8601String().replaceFirst('Z', ''),
  );

  ScheduledInterval interval(
    DateTime start,
    DateTime end,
    String zone,
    TimeMode mode,
  ) {
    final first = atWall(start, zone, mode);
    final adjustment = wall(first.instant, zone).difference(civilTime(start));
    final last = instant(civilTime(end).add(adjustment), zone);
    final duration = civilTime(end).difference(civilTime(start));
    return ScheduledInterval(
      first,
      ZonedTime(
        instant: last.isAfter(first.instant)
            ? last
            : first.instant.add(duration),
        zoneId: zone,
        mode: mode,
        localWallTime: civilTime(end).toIso8601String().replaceFirst('Z', ''),
      ),
    );
  }
}

DateTime nextSchedulingMinute(DateTime current) =>
    DateTime.fromMillisecondsSinceEpoch(
      (current.millisecondsSinceEpoch ~/ 60000 + 1) * 60000,
      isUtc: true,
    );

List<SchedulingSlot> schedulingWindows(
  CalendarZones zones,
  Map<int, DailyHours> hours,
  SchedulingSlot range,
) {
  if (!range.start.isBefore(range.end) || hours.isEmpty) return [];
  final first = civilDate(zones.wall(range.start, zones.deviceId));
  final last = civilDate(zones.wall(range.end, zones.deviceId));
  final result = <SchedulingSlot>[];
  for (
    var day = first;
    !day.isAfter(last);
    day = day.add(const Duration(days: 1))
  ) {
    final bounds = hours[day.weekday];
    if (bounds == null) continue;
    result.addAll([
      for (final piece in zones.deviceWallWindows(
        day.add(Duration(minutes: bounds.startMinute)),
        day.add(Duration(minutes: bounds.endMinute)),
      ))
        ?intersectSlots(piece, range),
    ]);
  }
  return result;
}

List<SchedulingSlot> preferredSchedulingWindows(
  CalendarZones zones,
  Map<int, DailyHours> hours,
  String preference,
  SchedulingSlot range,
) {
  final preferred = switch (preference) {
    'Pagi' => (startMinute: 360, endMinute: 720),
    'Siang' => (startMinute: 720, endMinute: 900),
    'Sore' => (startMinute: 900, endMinute: 1080),
    'Malam' => (startMinute: 1080, endMinute: 1440),
    _ => null,
  };
  if (preferred == null) return [];
  return schedulingWindows(zones, {
    for (final e in hours.entries)
      if (math.max(e.value.startMinute, preferred.startMinute) <
          math.min(e.value.endMinute, preferred.endMinute))
        e.key: (
          startMinute: math.max(e.value.startMinute, preferred.startMinute),
          endMinute: math.min(e.value.endMinute, preferred.endMinute),
        ),
  }, range);
}
