import 'package:routina/application/calendar_zones.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';

List<RoutineCadence> routineCadenceHistory(
  Routine routine,
  CalendarZones zones,
) {
  final createdAt = routine.metadata.createdAt;
  if (routine.cadenceHistory.isNotEmpty || createdAt == null) {
    return routine.cadenceHistory;
  }
  return [
    RoutineCadence(
      LocalDate.parse(civilKey(zones.wall(createdAt, zones.displayId))),
      routine.frequencyRule,
    ),
  ];
}

bool matchesRoutineCadence(List<RoutineCadence> history, DateTime date) {
  final key = civilKey(date);
  final rule = history.reversed
      .where((version) => version.from.value.compareTo(key) <= 0)
      .firstOrNull
      ?.rule;
  if (rule == null) return false;
  final fields = rule.split(';');
  if (fields.first != 'FREQ=DAILY' && fields.first != 'FREQ=WEEKLY') {
    return false;
  }
  final byDay = fields.where((field) => field.startsWith('BYDAY=')).firstOrNull;
  if (byDay == null) return fields.first == 'FREQ=DAILY';
  const weekdays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
  return byDay
      .substring('BYDAY='.length)
      .split(',')
      .contains(weekdays[date.weekday - 1]);
}
