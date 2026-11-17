import 'package:flutter/material.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/domain/productivity.dart';
import 'package:routina/presentation/design_system/neo_badges.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

class ProductivityStatistics extends StatefulWidget {
  const ProductivityStatistics({required this.read, super.key});

  final Future<ProductivityReport> Function(ProductivityQuery) read;

  @override
  State<ProductivityStatistics> createState() => _ProductivityStatisticsState();
}

enum _Comparison {
  previous('Periode sebelumnya'),
  manual('Pilih periode manual'),
  off('Matikan perbandingan');

  const _Comparison(this.label);
  final String label;
}

class _ProductivityStatisticsState extends State<ProductivityStatistics> {
  ProductivityPeriod _period = ProductivityPeriod.week;
  ProductivityFilter _filter = const ProductivityFilter();
  DateTime? _anchor, _comparisonAnchor;
  bool _compare = false;
  late Future<ProductivityReport> _result = _read();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => _update());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<ProductivityReport> _read() => widget.read(
    ProductivityQuery(
      period: _period,
      anchor: _anchor,
      compare: _compare,
      comparisonAnchor: _comparisonAnchor,
      filter: _filter,
    ),
  );

  void _update([VoidCallback? change]) {
    setState(() {
      change?.call();
      _result = _read();
    });
  }

  Future<DateTime?> _date(
    DateTime today,
    DateTime initial,
    String title, {
    ReportingDates? exclude,
  }) {
    final last = dateOnly(today);
    final first = DateTime(1900);
    final initialDay = civilDate(initial);
    final candidate = initialDay.isAfter(today) ? today : initialDay;
    final selected = exclude?.contains(candidate) == true
        ? exclude!.start.subtract(const Duration(days: 1))
        : candidate;
    return showDatePicker(
      context: context,
      helpText: title,
      firstDate: first,
      lastDate: last,
      currentDate: last,
      initialDate: selected.isBefore(civilDate(first))
          ? null
          : dateOnly(selected),
      selectableDayPredicate: exclude == null
          ? null
          : (day) => !exclude.contains(day),
    );
  }

  Future<void> _choosePeriod(ProductivityReport report) async {
    final chosen = await _date(
      report.today,
      _anchor ?? report.today,
      'Pilih periode',
    );
    if (!mounted || chosen == null) return;
    _update(() {
      _anchor = chosen;
      if (_comparisonAnchor != null &&
          reportingPeriod(
            _period,
            chosen,
            sundayFirst: report.sundayFirst,
          ).contains(_comparisonAnchor!)) {
        _comparisonAnchor = null;
      }
    });
  }

  Future<void> _chooseCategory(ProductivityReport report) async {
    final options = [
      (id: null, uncategorized: false, label: 'Semua kategori'),
      (id: null, uncategorized: true, label: 'Tanpa kategori'),
      for (final category in report.categories)
        (id: category.id, uncategorized: false, label: category.name),
    ];
    final choice = await previewChoices(
      context,
      'Kategori',
      options,
      (item) => item.label,
    );
    if (!mounted || choice == null) return;
    _update(
      () => _filter = ProductivityFilter(
        categoryId: choice.id,
        uncategorized: choice.uncategorized,
        kind: _filter.kind,
      ),
    );
  }

  Future<void> _chooseKind() async {
    final options = [
      (kind: null, label: 'Semua jenis'),
      for (final kind in ProductivityKind.values)
        (kind: kind, label: kind.label),
    ];
    final choice = await previewChoices(
      context,
      'Jenis aktivitas',
      options,
      (item) => item.label,
    );
    if (!mounted || choice == null) return;
    _update(
      () => _filter = ProductivityFilter(
        categoryId: _filter.categoryId,
        uncategorized: _filter.uncategorized,
        kind: choice.kind,
      ),
    );
  }

  Future<void> _chooseComparison(ProductivityReport report) async {
    final choice = await previewChoices(context, 'Perbandingan', [
      _Comparison.previous,
      _Comparison.manual,
      if (_compare) _Comparison.off,
    ], (value) => value.label);
    if (!mounted || choice == null) return;
    final DateTime? manual;
    if (choice == _Comparison.manual) {
      manual = await _date(
        report.today,
        _comparisonAnchor ??
            report.windows.nominal.start.subtract(const Duration(days: 1)),
        'Pilih periode pembanding',
        exclude: report.windows.nominal,
      );
      if (!mounted || manual == null) return;
    } else {
      manual = null;
    }
    _update(() {
      _compare = choice != _Comparison.off;
      _comparisonAnchor = manual;
    });
  }

  @override
  Widget build(BuildContext context) => PreviewPage(
    title: 'Statistik',
    body: FutureBuilder<ProductivityReport>(
      future: _result,
      builder: (context, snapshot) {
        final report = snapshot.data;
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            NeoSpace.page,
            NeoSpace.sm,
            NeoSpace.page,
            NeoSpace.section,
          ),
          children: [
            _PeriodControl(
              selected: _period,
              onSelect: (period) {
                if (period == _period) return;
                _update(() {
                  _period = period;
                  _comparisonAnchor = null;
                });
              },
            ),
            const SizedBox(height: NeoSpace.page),
            if (snapshot.connectionState != ConnectionState.done)
              const PreviewNotice(
                title: 'Memuat statistik',
                message: 'Sedang membaca riwayat aktivitas.',
                loading: true,
              )
            else if (snapshot.hasError || report == null)
              PreviewNotice(
                title: 'Statistik belum tersedia',
                message: 'Riwayat belum dapat dibaca. Coba muat ulang.',
                warning: true,
                button: NeoButton(label: 'Muat ulang', onPressed: _update),
              )
            else
              ..._report(report),
          ],
        );
      },
    ),
  );

  List<Widget> _report(ProductivityReport report) {
    final selected = report.selected;
    final dates = report.windows.nominal;
    final category = _filter.uncategorized
        ? 'Tanpa kategori'
        : _category(report.categories, _filter.categoryId);
    final prior = report.comparison;
    return [
      InkWell(
        onTap: () => _choosePeriod(report),
        borderRadius: NeoRadius.small,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: NeoSize.touch),
          child: Row(
            children: [
              Expanded(child: Text(_dateRange(dates), style: NeoType.section)),
              const Icon(
                Icons.calendar_today_outlined,
                size: 19,
                semanticLabel: 'Pilih periode',
              ),
            ],
          ),
        ),
      ),
      Wrap(
        spacing: NeoSpace.xs,
        runSpacing: NeoSpace.xxs,
        children: [
          CategoryChip(
            label: category ?? 'Kategori',
            selected: category != null,
            onSelected: (_) => _chooseCategory(report),
          ),
          CategoryChip(
            label: _filter.kind?.label ?? 'Jenis aktivitas',
            selected: _filter.kind != null,
            onSelected: (_) => _chooseKind(),
          ),
          CategoryChip(
            label: 'Bandingkan',
            selected: _compare,
            onSelected: (_) => _chooseComparison(report),
          ),
        ],
      ),
      if (_period == ProductivityPeriod.week ||
          selected.dates.length < dates.length) ...[
        const SizedBox(height: NeoSpace.xs),
        Text(
          [
            if (_period == ProductivityPeriod.week)
              'Awal minggu ${report.sundayFirst ? 'Minggu' : 'Senin'}',
            if (selected.dates.length < dates.length && !selected.dates.isEmpty)
              'Data hingga ${dateLabel(selected.dates.last)}',
          ].join(' · '),
          style: NeoType.caption,
        ),
      ],
      const SizedBox(height: NeoSpace.md),
      if (selected.tally.ratio == null)
        PreviewNotice(
          title: 'Tidak Ada Aktivitas',
          message: category != null || _filter.kind != null
              ? 'Belum ada kewajiban yang cocok dengan filter ini.'
              : 'Periode ini tidak memiliki aktivitas yang menjadi kewajiban.',
          icon: Icons.bar_chart,
          button: NeoButton(
            label: 'Ubah pilihan',
            onPressed: () => _choosePeriod(report),
          ),
        )
      else ...[
        _Metrics(
          summary: selected,
          showAverage: _period != ProductivityPeriod.day,
        ),
        const SizedBox(height: NeoSpace.page),
        Text(switch (_period) {
          ProductivityPeriod.day => 'Penyelesaian per jenis',
          ProductivityPeriod.week => 'Penyelesaian per hari',
          ProductivityPeriod.month => 'Penyelesaian per kelompok tanggal',
        }, style: NeoType.section),
        const SizedBox(height: NeoSpace.xs),
        _CompletionChart(
          period: _period,
          dates: dates,
          summary: selected,
          today: report.today,
        ),
        const SizedBox(height: NeoSpace.sm),
        Text(_statusTotals(selected.tally), style: NeoType.caption),
      ],
      if (prior != null) ...[
        const SizedBox(height: NeoSpace.page),
        _ComparisonCard(
          selected: report.compared!,
          comparison: prior,
          manual: _comparisonAnchor != null,
        ),
        const SizedBox(height: NeoSpace.sm),
        NeoButton(
          label: 'Ubah periode pembanding',
          variant: NeoButtonVariant.secondary,
          onPressed: () => _chooseComparison(report),
        ),
      ],
      if (selected.history.isNotEmpty) ...[
        const SizedBox(height: NeoSpace.page),
        NeoButton(
          label: 'Lihat rincian aktivitas',
          variant: NeoButtonVariant.secondary,
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => _ActivityBreakdown(report: report),
            ),
          ),
        ),
      ],
      const SizedBox(height: NeoSpace.sm),
      Text(
        'Zona tampilan · ${report.zone}',
        style: NeoType.caption.copyWith(color: NeoColors.muted),
      ),
    ];
  }
}

class _PeriodControl extends StatelessWidget {
  const _PeriodControl({required this.selected, required this.onSelect});

  final ProductivityPeriod selected;
  final ValueChanged<ProductivityPeriod> onSelect;

  @override
  Widget build(BuildContext context) => Material(
    color: NeoColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: NeoRadius.input,
      side: NeoLine.thin,
    ),
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          for (final period in ProductivityPeriod.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: period == selected,
                child: Ink(
                  decoration: BoxDecoration(
                    color: period == selected ? NeoColors.yellow : null,
                    borderRadius: NeoRadius.small,
                  ),
                  child: InkWell(
                    onTap: () => onSelect(period),
                    borderRadius: NeoRadius.small,
                    child: Container(
                      padding: const EdgeInsets.all(NeoSpace.xxs),
                      constraints: const BoxConstraints(
                        minHeight: NeoSize.touch,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        period.label,
                        textAlign: TextAlign.center,
                        style: NeoType.item,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.summary, required this.showAverage});

  final ProductivitySummary summary;
  final bool showAverage;

  @override
  Widget build(BuildContext context) => NeoCard(
    tone: NeoCardTone.accent,
    emphasis: true,
    child: LayoutBuilder(
      builder: (context, box) {
        final total = _metric(
          'Penyelesaian total',
          completionPercentage(summary.tally.ratio),
          '${summary.tally.completed} / ${summary.tally.total} aktivitas selesai',
          37,
        );
        if (!showAverage) return total;
        final average = _metric(
          'Rata-rata harian',
          completionPercentage(summary.averageDailyRate),
          'Hari dengan aktivitas',
          25,
        );
        if (box.maxWidth < MediaQuery.textScalerOf(context).scale(275)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              total,
              const Divider(color: NeoColors.ink),
              average,
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 5, child: total),
            Expanded(
              flex: 4,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(left: NeoLine.thin),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: NeoSpace.sm),
                  child: average,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _metric(String title, String value, String caption, double size) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: NeoType.item),
          const SizedBox(height: NeoSpace.xxs),
          Text(value, style: NeoType.metric.copyWith(fontSize: size)),
          Text(caption, style: NeoType.caption),
        ],
      );
}

typedef _ChartPoint = ({
  String label,
  String detail,
  double? ratio,
  bool future,
  bool today,
});

class _CompletionChart extends StatelessWidget {
  const _CompletionChart({
    required this.period,
    required this.dates,
    required this.summary,
    required this.today,
  });

  final ProductivityPeriod period;
  final ReportingDates dates;
  final ProductivitySummary summary;
  final DateTime today;
  static const _height = 102.0;

  Iterable<_ChartPoint> _points() sync* {
    switch (period) {
      case ProductivityPeriod.day:
        for (final kind in ProductivityKind.values) {
          yield (
            label: kind.label,
            detail: kind.label,
            ratio: summary.breakdown[kind]!.ratio,
            future: false,
            today: false,
          );
        }
      case ProductivityPeriod.week:
        for (final day in dates.days) {
          yield (
            label: shortDays[day.weekday - 1],
            detail: dateLabel(day),
            ratio: summary.daily[day]?.ratio,
            future: day.isAfter(today),
            today: day == today,
          );
        }
      case ProductivityPeriod.month:
        for (var offset = 0; offset < dates.length; offset += 7) {
          final start = dates.start.add(Duration(days: offset));
          final end = dates.first((offset + 7).clamp(0, dates.length)).until;
          final bucket = ReportingDates(start, end);
          final tally = bucket.days.fold(
            const CompletionTally(),
            (value, day) =>
                value + (summary.daily[day] ?? const CompletionTally()),
          );
          yield (
            label: '${start.day}–${bucket.last.day}',
            detail: _dateRange(bucket),
            ratio: tally.ratio,
            future: start.isAfter(today),
            today: bucket.contains(today),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _points().toList();
    return NeoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final minimum = MediaQuery.textScalerOf(
                context,
              ).scale(31 * points.length + 38);
              final width = box.maxWidth < minimum ? minimum : box.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: SizedBox(
                          height: _height,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (final mark in ['100%', '50%', '0%'])
                                Text(mark, style: NeoType.caption),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: NeoSpace.xxs),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: _height,
                              child: ExcludeSemantics(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: List.generate(
                                    3,
                                    (_) => const Divider(
                                      height: 1,
                                      color: NeoColors.line,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final point in points)
                                  Expanded(child: _column(point)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (points.any((point) => point.ratio == null && !point.future))
            const Text('○  Tidak Ada Aktivitas', style: NeoType.caption),
          if (points.any((point) => point.future))
            const Text('–  Tanggal mendatang', style: NeoType.caption),
        ],
      ),
    );
  }

  Widget _column(_ChartPoint point) {
    final ratio = point.ratio;
    final detail = point.future
        ? 'Tanggal mendatang'
        : completionPercentage(ratio);
    return Semantics(
      label: '${point.detail}, $detail',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: _height,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ratio == null
                  ? Text(point.future ? '–' : '○')
                  : Container(
                      width: 24,
                      height: (ratio * _height).clamp(2, _height).toDouble(),
                      decoration: BoxDecoration(
                        color: point.today ? NeoColors.yellow : NeoColors.blue,
                        borderRadius: NeoRadius.small,
                        border: Border.all(color: NeoColors.ink),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: NeoSpace.xxs),
          Text(
            point.label,
            textAlign: TextAlign.center,
            style: NeoType.caption,
          ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.selected,
    required this.comparison,
    required this.manual,
  });

  final ProductivitySummary selected, comparison;
  final bool manual;

  @override
  Widget build(BuildContext context) {
    final result = selected.tally.ratio;
    final baseline = comparison.tally.ratio;
    final sameLength = selected.dates.length == comparison.dates.length;
    final delta = result == null || baseline == null
        ? null
        : (result - baseline) * 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          sameLength
              ? 'Perbandingan ${selected.dates.length} hari'
              : 'Perbandingan periode',
          style: NeoType.section,
        ),
        const SizedBox(height: NeoSpace.xs),
        NeoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row('Periode terpilih', selected, NeoColors.blue),
              const SizedBox(height: NeoSpace.sm),
              _row(
                manual ? 'Periode pembanding manual' : 'Periode sebelumnya',
                comparison,
                NeoColors.coral,
              ),
            ],
          ),
        ),
        if (delta != null) ...[
          const SizedBox(height: NeoSpace.xs),
          Text(
            'Perubahan penyelesaian total ${delta >= 0 ? '+' : '−'}${decimalMetric(delta.abs())} poin persentase.',
            style: NeoType.caption,
          ),
        ],
      ],
    );
  }

  Widget _row(String label, ProductivitySummary summary, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: NeoType.item),
      Text(
        '${_dateRange(summary.dates)} · ${summary.dates.length} hari',
        style: NeoType.caption,
      ),
      if (summary.tally.ratio case final rate?)
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: rate,
                color: color,
                backgroundColor: NeoColors.disabled,
                borderRadius: NeoRadius.small,
                minHeight: NeoSize.progress,
                semanticsLabel: label,
              ),
            ),
            const SizedBox(width: NeoSpace.xs),
            Text(completionPercentage(rate), style: NeoType.numericCaption),
          ],
        )
      else
        const Text('Tidak Ada Aktivitas', style: NeoType.body),
    ],
  );
}

class _ActivityBreakdown extends StatelessWidget {
  const _ActivityBreakdown({required this.report});
  final ProductivityReport report;

  @override
  Widget build(BuildContext context) {
    final summary = report.selected;
    final history = summary.history;
    return PreviewPage(
      title: 'Rincian aktivitas',
      body: ListView.builder(
        padding: const EdgeInsets.all(NeoSpace.page),
        itemCount: history.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_dateRange(summary.dates), style: NeoType.section),
                const SizedBox(height: NeoSpace.sm),
                NeoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in summary.breakdown.entries) ...[
                        Text(entry.key.label, style: NeoType.item),
                        Text(
                          entry.value.ratio == null
                              ? 'Tidak Ada Aktivitas'
                              : '${entry.value.completed} / ${entry.value.total} selesai · ${completionPercentage(entry.value.ratio)}',
                        ),
                        if (entry.key != ProductivityKind.values.last)
                          const Divider(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: NeoSpace.page),
                const Text('Riwayat', style: NeoType.section),
              ],
            );
          }
          final item = history[index - 1];
          final newDay = index == 1 || history[index - 2].day != item.day;
          return Padding(
            padding: const EdgeInsets.only(top: NeoSpace.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (newDay) ...[
                  Text(dateLabel(item.day, long: true), style: NeoType.item),
                  const SizedBox(height: NeoSpace.xxs),
                ],
                NeoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: NeoType.item),
                      Text(
                        [
                          item.kind.label,
                          if (item.time case final time?)
                            clockLabel(minutesAt(time)),
                          ?_category(report.categories, item.categoryId),
                          if (item.isCalendarBlock) 'Blok terkait',
                        ].join(' · '),
                        style: NeoType.caption,
                      ),
                      Text(_statusLabel(item.status)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String? _category(List<Category> categories, String? id) =>
    categories.where((category) => category.id == id).firstOrNull?.name;

String _dateRange(ReportingDates dates) {
  if (dates.isEmpty) return 'Tanggal belum terukur';
  if (dates.length == 1) return dateLabel(dates.start, year: true);
  final start = dates.start;
  final last = dates.last;
  final startLabel = start.year != last.year
      ? '${start.day} ${monthNames[start.month - 1]} ${start.year}'
      : start.month != last.month
      ? '${start.day} ${monthNames[start.month - 1]}'
      : '${start.day}';
  return '$startLabel–${last.day} ${monthNames[last.month - 1]} ${last.year}';
}

String _statusTotals(CompletionTally tally) =>
    '${tally.completed} selesai · ${tally.postponed} ditunda · ${tally.skipped} dilewatkan · ${tally.pending} belum selesai';

String _statusLabel(ActivityStatus status) => switch (status) {
  ActivityStatus.planned => 'Belum selesai',
  ActivityStatus.completed => 'Selesai',
  ActivityStatus.postponed => 'Ditunda',
  ActivityStatus.skipped => 'Dilewatkan',
  ActivityStatus.cancelled => 'Dibatalkan',
};
