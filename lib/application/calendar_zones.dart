import 'package:routina/domain/event_recurrence.dart';
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
}
