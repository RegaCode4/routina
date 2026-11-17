import 'dart:math' as math;

enum RepeatFrequency { daily, weekly, monthly }

/// A recurrence is anchored to an event's first civil date.
class EventRecurrence {
  EventRecurrence(this.frequency, {this.interval = 1, this.until}) {
    RangeError.checkValueInInterval(interval, 1, 366);
  }

  final RepeatFrequency frequency;
  final int interval;

  /// Inclusive last civil date. A null date leaves the series open.
  final DateTime? until;

  String encode() => [
    'FREQ=${frequency.name.toUpperCase()}',
    if (interval != 1) 'INTERVAL=$interval',
    if (until case final end?) 'UNTIL=${civilKey(end)}',
  ].join(';');

  static EventRecurrence decode(String rule) {
    final parts = {
      for (final value in rule.split(';').map((part) => part.split('=')))
        if (value.length == 2) value.first: value.last,
    };
    return EventRecurrence(
      RepeatFrequency.values.byName(parts['FREQ']!.toLowerCase()),
      interval: int.parse(parts['INTERVAL'] ?? '1'),
      until: parts['UNTIL'] == null ? null : DateTime.parse(parts['UNTIL']!),
    );
  }

  /// Expands only the requested civil window. Monthly dates absent from a
  /// month are skipped so the original day remains the anchor.
  Iterable<DateTime> dates(
    DateTime anchor,
    DateTime from,
    DateTime until,
  ) sync* {
    final first = civilDate(anchor);
    final lower = civilDate(from);
    final upper = civilDate(until);
    final limit = this.until == null ? null : civilDate(this.until!);
    if (frequency == RepeatFrequency.monthly) {
      final delta = (lower.year - first.year) * 12 + lower.month - first.month;
      var offset = math.max(0, delta ~/ interval) * interval;
      while (true) {
        final month = DateTime.utc(first.year, first.month + offset);
        if (!month.isBefore(upper)) break;
        final day = DateTime.utc(month.year, month.month, first.day);
        if (limit != null && day.isAfter(limit)) break;
        if (day.month == month.month &&
            !day.isBefore(lower) &&
            day.isBefore(upper)) {
          yield day;
        }
        offset += interval;
      }
      return;
    }
    final step = interval * (frequency == RepeatFrequency.weekly ? 7 : 1);
    final initial = math.max(0, lower.difference(first).inDays);
    var day = first.add(Duration(days: ((initial + step - 1) ~/ step) * step));
    while (day.isBefore(upper) && (limit == null || !day.isAfter(limit))) {
      yield day;
      day = day.add(Duration(days: step));
    }
  }
}

DateTime civilDate(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

DateTime civilWeekStart(DateTime value, {required bool sundayFirst}) {
  final day = civilDate(value);
  final offset = sundayFirst ? day.weekday % 7 : day.weekday - 1;
  return day.subtract(Duration(days: offset));
}

DateTime civilTime(DateTime value) => DateTime.utc(
  value.year,
  value.month,
  value.day,
  value.hour,
  value.minute,
  value.second,
  value.millisecond,
  value.microsecond,
);
String civilKey(DateTime value) =>
    civilDate(value).toIso8601String().substring(0, 10);
