import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
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
