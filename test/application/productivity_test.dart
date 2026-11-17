import 'package:flutter_test/flutter_test.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/productivity.dart';

DateTime date(int day) => DateTime.utc(2026, 11, day);

ProductivityItem item(
  String id,
  int day,
  ActivityStatus status, {
  String? category,
  ProductivityKind kind = ProductivityKind.event,
  bool linked = false,
}) => ProductivityItem(
  id: id,
  kind: kind,
  title: id,
  day: date(day),
  status: status,
  categoryId: category,
  isCalendarBlock: linked,
);

void main() {
  const all = ProductivityFilter();

  test('3/11 overall and 60% mean when Monday is 1/1 and Tuesday 2/10', () {
    final source = [
      item('Senin', 16, ActivityStatus.completed),
      item('Selesai', 17, ActivityStatus.completed, category: 'Kerja'),
      item(
        'Tenggat',
        17,
        ActivityStatus.completed,
        kind: ProductivityKind.task,
      ),
      item('Lanjut', 17, ActivityStatus.postponed, category: 'Kerja'),
      item('Lewat', 17, ActivityStatus.skipped),
      for (var i = 0; i < 6; i++)
        item('Terjadwal $i', 17, ActivityStatus.planned),
      item('Blok kalender', 17, ActivityStatus.completed, linked: true),
      item('Lanjut', 17, ActivityStatus.postponed, category: 'Kerja'),
      item('Batal', 17, ActivityStatus.cancelled),
      item('Di luar periode', 23, ActivityStatus.completed),
    ];
    final dates = ReportingDates(date(16), date(23));
    final summary = ProductivitySummary(dates, source, all);
    expect(summary.tally.total, 11);
    expect(summary.tally.completed, 3);
    expect(summary.tally.open, 8);
    expect(summary.tally.postponed, 1);
    expect(summary.tally.skipped, 1);
    expect(summary.tally.pending, 6);
    expect(summary.tally.ratio, closeTo(3 / 11, 1e-10));
    expect(summary.averageDailyRate, closeTo(.6, 1e-10));
    expect(summary.daily[date(18)]!.ratio, isNull);
    expect(summary.breakdown[ProductivityKind.task]!.ratio, 1);
    expect(summary.history.length, 12);

    final filtered = ProductivitySummary(
      dates,
      source,
      const ProductivityFilter(
        categoryId: 'Kerja',
        kind: ProductivityKind.event,
      ),
    );
    expect(filtered.tally.ratio, .5);
    expect(filtered.daily[date(16)]!.ratio, isNull);
    expect(filtered.history.map((row) => row.id), ['Lanjut', 'Selesai']);
    final withoutCategory = ProductivitySummary(
      dates,
      source,
      const ProductivityFilter(
        uncategorized: true,
        kind: ProductivityKind.task,
      ),
    );
    expect(withoutCategory.history.single.id, 'Tenggat');
  });

  test(
    'a day with 0% completion participates in the mean, an empty day does not',
    () {
      final dates = ReportingDates(date(16), date(19));
      final summary = ProductivitySummary(dates, [
        item('Selesai', 16, ActivityStatus.completed),
        item('Dilewatkan', 17, ActivityStatus.skipped),
      ], all);
      expect(summary.daily[date(17)]!.ratio, 0);
      expect(summary.daily[date(18)]!.ratio, isNull);
      expect(summary.averageDailyRate, .5);
      final empty = ProductivitySummary(dates, [], all);
      expect(empty.tally.ratio, isNull);
      expect(empty.averageDailyRate, isNull);
    },
  );

  test(
    'active week compares the first two dates to the prior week, including today',
    () {
      final windows = ProductivityWindows(
        const ProductivityQuery(compare: true),
        date(17).add(const Duration(hours: 8)),
        sundayFirst: false,
      );
      expect(windows.nominal.days, [for (var d = 16; d <= 22; d++) date(d)]);
      expect(windows.selected.days, [date(16), date(17)]);
      expect(windows.compared!.days, [date(16), date(17)]);
      expect(windows.comparison!.days, [date(9), date(10)]);
    },
  );

  test(
    'manual comparison snaps to its period and uses configured first weekday',
    () {
      final query = ProductivityQuery(
        anchor: date(16),
        compare: true,
        comparisonAnchor: date(4),
      );
      final windows = ProductivityWindows(query, date(17), sundayFirst: true);
      expect(windows.selected.days, [date(15), date(16), date(17)]);
      expect(windows.comparison!.days, [date(1), date(2), date(3)]);
      final completed = ProductivityWindows(query, date(26), sundayFirst: true);
      expect(completed.compared!.days, [
        for (var d = 15; d <= 21; d++) date(d),
      ]);
      expect(completed.comparison!.days, [
        for (var d = 1; d <= 7; d++) date(d),
      ]);
    },
  );

  test(
    'active month clips both comparison ranges at the shorter month boundary',
    () {
      final windows = ProductivityWindows(
        const ProductivityQuery(
          period: ProductivityPeriod.month,
          compare: true,
        ),
        DateTime.utc(2024, 3, 30),
        sundayFirst: false,
      );
      expect(windows.selected.length, 30);
      expect(windows.compared!.last, DateTime.utc(2024, 3, 29));
      expect(windows.comparison!.start, DateTime.utc(2024, 2, 1));
      expect(windows.comparison!.last, DateTime.utc(2024, 2, 29));
    },
  );

  test(
    'completed months compare their whole civil spans and days cross year boundaries',
    () {
      final monthly = ProductivityWindows(
        ProductivityQuery(
          period: ProductivityPeriod.month,
          anchor: DateTime.utc(2026, 2, 24),
          compare: true,
        ),
        date(26),
        sundayFirst: false,
      );
      expect(monthly.compared!.length, 28);
      expect(monthly.comparison!.length, 31);
      expect(monthly.comparison!.last, DateTime.utc(2026, 1, 31));
      final daily = ProductivityWindows(
        const ProductivityQuery(period: ProductivityPeriod.day, compare: true),
        DateTime.utc(2026),
        sundayFirst: true,
      );
      expect(daily.comparison!.days, [DateTime.utc(2025, 12, 31)]);
    },
  );
}
