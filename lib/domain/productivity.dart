import 'dart:math' as math;

import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';

enum ProductivityKind {
  event('Kegiatan'),
  task('Tugas'),
  routine('Rutinitas');

  const ProductivityKind(this.label);
  final String label;
}

enum ProductivityPeriod {
  day('Hari'),
  week('Minggu'),
  month('Bulan');

  const ProductivityPeriod(this.label);
  final String label;
}

/// Date-only bounds in the reporting calendar. UTC is used as a civil date
/// representation so adding a day is independent of host and DST offsets.
class ReportingDates {
  ReportingDates(DateTime start, DateTime until)
    : start = civilDate(start),
      until = civilDate(until) {
    if (this.until.isBefore(this.start)) throw ArgumentError('Reversed dates');
  }

  final DateTime start, until;
  int get length => until.difference(start).inDays;
  bool get isEmpty => start == until;
  DateTime get last => until.subtract(const Duration(days: 1));
  ReportingDates first(int count) =>
      ReportingDates(start, start.add(Duration(days: count)));
  bool contains(DateTime day) {
    final date = civilDate(day);
    return !date.isBefore(start) && date.isBefore(until);
  }

  Iterable<DateTime> get days sync* {
    for (
      var day = start;
      day.isBefore(until);
      day = day.add(const Duration(days: 1))
    ) {
      yield day;
    }
  }
}

class ProductivityFilter {
  const ProductivityFilter({
    this.categoryId,
    this.uncategorized = false,
    this.kind,
  });

  final String? categoryId;
  final bool uncategorized;
  final ProductivityKind? kind;

  bool matches(ProductivityItem item) =>
      (kind == null || kind == item.kind) &&
      (!uncategorized || item.categoryId == null) &&
      (categoryId == null || categoryId == item.categoryId);
}

class ProductivityQuery {
  const ProductivityQuery({
    this.period = ProductivityPeriod.week,
    this.anchor,
    this.compare = false,
    this.comparisonAnchor,
    this.filter = const ProductivityFilter(),
  });

  final ProductivityPeriod period;
  final DateTime? anchor, comparisonAnchor;
  final bool compare;
  final ProductivityFilter filter;
}

class ProductivityWindows {
  ProductivityWindows(
    ProductivityQuery query,
    DateTime today, {
    required bool sundayFirst,
  }) : nominal = reportingPeriod(
         query.period,
         query.anchor ?? today,
         sundayFirst: sundayFirst,
       ) {
    selected = _observed(nominal, today);
    if (!query.compare) return;
    final other = reportingPeriod(
      query.period,
      query.comparisonAnchor ?? nominal.start.subtract(const Duration(days: 1)),
      sundayFirst: sundayFirst,
    );
    final prior = _observed(other, today);
    if (nominal.contains(today) || other.contains(today)) {
      final length = math.min(selected.length, prior.length);
      compared = selected.first(length);
      comparison = prior.first(length);
    } else {
      compared = selected;
      comparison = prior;
    }
  }

  final ReportingDates nominal;
  late final ReportingDates selected;
  ReportingDates? compared, comparison;

  static ReportingDates _observed(ReportingDates period, DateTime today) {
    final tomorrow = civilDate(today).add(const Duration(days: 1));
    if (!tomorrow.isAfter(period.start)) return period.first(0);
    return tomorrow.isBefore(period.until)
        ? ReportingDates(period.start, tomorrow)
        : period;
  }
}

ReportingDates reportingPeriod(
  ProductivityPeriod period,
  DateTime anchor, {
  required bool sundayFirst,
}) {
  final date = civilDate(anchor);
  switch (period) {
    case ProductivityPeriod.day:
      return ReportingDates(date, date.add(const Duration(days: 1)));
    case ProductivityPeriod.week:
      final first = civilWeekStart(date, sundayFirst: sundayFirst);
      return ReportingDates(first, first.add(const Duration(days: 7)));
    case ProductivityPeriod.month:
      return ReportingDates(
        DateTime.utc(date.year, date.month),
        DateTime.utc(date.year, date.month + 1),
      );
  }
}

class ProductivityItem {
  const ProductivityItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.day,
    required this.status,
    this.categoryId,
    this.routineId,
    this.time,
    this.isCalendarBlock = false,
    this.isUnscheduledTarget = false,
  });

  final String id, title;
  final ProductivityKind kind;
  final DateTime day;
  final ActivityStatus status;
  final String? categoryId, routineId;
  final DateTime? time;

  /// A linked event remains visible in history with its own outcome.
  final bool isCalendarBlock;
  final bool isUnscheduledTarget;

  bool get counts => !isCalendarBlock && status != ActivityStatus.cancelled;
}

class CompletionTally {
  const CompletionTally({
    this.total = 0,
    this.completed = 0,
    this.postponed = 0,
    this.skipped = 0,
  });

  factory CompletionTally.from(Iterable<ProductivityItem> items) {
    var counts = const CompletionTally();
    for (final item in items) {
      if (!item.counts) continue;
      counts += CompletionTally(
        total: 1,
        completed: item.status == ActivityStatus.completed ? 1 : 0,
        postponed: item.status == ActivityStatus.postponed ? 1 : 0,
        skipped: item.status == ActivityStatus.skipped ? 1 : 0,
      );
    }
    return counts;
  }

  final int total, completed, postponed, skipped;
  int get open => total - completed;
  int get pending => open - postponed - skipped;
  double? get ratio => total == 0 ? null : completed / total;

  CompletionTally operator +(CompletionTally other) => CompletionTally(
    total: total + other.total,
    completed: completed + other.completed,
    postponed: postponed + other.postponed,
    skipped: skipped + other.skipped,
  );
}

class ProductivitySummary {
  ProductivitySummary(
    this.dates,
    Iterable<ProductivityItem> source,
    ProductivityFilter filter,
  ) {
    final seen = <(ProductivityKind, String, DateTime, bool)>{};
    history = List.unmodifiable(
      <ProductivityItem>[
        for (final item in source)
          if (dates.contains(item.day) &&
              filter.matches(item) &&
              item.status != ActivityStatus.cancelled &&
              seen.add((
                item.kind,
                item.id,
                civilDate(item.day),
                item.isCalendarBlock,
              )))
            item,
      ]..sort((a, b) {
        final date = b.day.compareTo(a.day);
        if (date != 0) return date;
        final time = (a.time ?? a.day).compareTo(b.time ?? b.day);
        return time == 0 ? a.title.compareTo(b.title) : time;
      }),
    );
    final byDay = <DateTime, List<ProductivityItem>>{};
    final byKind = <ProductivityKind, List<ProductivityItem>>{};
    for (final item in history) {
      if (!item.counts) continue;
      (byDay[civilDate(item.day)] ??= []).add(item);
      (byKind[item.kind] ??= []).add(item);
    }
    daily = Map.unmodifiable({
      for (final day in dates.days)
        day: CompletionTally.from(byDay[day] ?? const []),
    });
    breakdown = Map.unmodifiable({
      for (final kind in ProductivityKind.values)
        kind: CompletionTally.from(byKind[kind] ?? const []),
    });
    tally = daily.values.fold(
      const CompletionTally(),
      (total, day) => total + day,
    );
    final rates = daily.values.map((day) => day.ratio).nonNulls.toList();
    averageDailyRate = rates.isEmpty
        ? null
        : rates.reduce((a, b) => a + b) / rates.length;
  }

  final ReportingDates dates;
  late final List<ProductivityItem> history;
  late final Map<DateTime, CompletionTally> daily;
  late final Map<ProductivityKind, CompletionTally> breakdown;
  late final CompletionTally tally;
  late final double? averageDailyRate;
}

class ProductivityReport {
  ProductivityReport({
    required this.windows,
    required this.today,
    required this.zone,
    required this.sundayFirst,
    required this.categories,
    required ProductivityFilter filter,
    required Iterable<ProductivityItem> items,
  }) : selected = ProductivitySummary(windows.selected, items, filter),
       compared = windows.compared == null
           ? null
           : ProductivitySummary(windows.compared!, items, filter),
       comparison = windows.comparison == null
           ? null
           : ProductivitySummary(windows.comparison!, items, filter);

  final ProductivityWindows windows;
  final DateTime today;
  final String zone;
  final bool sundayFirst;
  final List<Category> categories;
  final ProductivitySummary selected;
  final ProductivitySummary? compared, comparison;
}
