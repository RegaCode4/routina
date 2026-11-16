import 'package:flutter/material.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

import 'package:routina/presentation/demo/demo_session.dart';
import 'package:routina/presentation/demo/demo_widgets.dart';

enum _Period {
  day('Hari'),
  week('Minggu'),
  month('Bulan');

  const _Period(this.label);
  final String label;
}

class DemoStatistics extends StatefulWidget {
  const DemoStatistics(this.demo, {super.key});
  final DemoSession demo;
  @override
  State<DemoStatistics> createState() => _DemoStatisticsState();
}

class _DemoStatisticsState extends State<DemoStatistics> {
  _Period period = _Period.week;
  late DateTime anchor = widget.demo.today;
  String category = 'Semua kategori';
  bool compare = false;
  DateTime? comparison;

  List<DateTime> _days() {
    final date = dateOnly(anchor);
    return switch (period) {
      _Period.day => [date],
      _Period.week => [
        for (var i = 0; i < 7; i++)
          shiftDay(
            date,
            i -
                (widget.demo.planner.profile?.sundayFirst == true
                    ? date.weekday % 7
                    : date.weekday - 1),
          ),
      ],
      _Period.month => [
        for (var i = 1; i <= DateTime(date.year, date.month + 1, 0).day; i++)
          DateTime(date.year, date.month, i),
      ],
    };
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.demo,
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final demo = widget.demo;
    final dates = _days();
    final today = dateOnly(demo.today);
    final measured = dates.contains(today)
        ? dates.where((day) => !day.isAfter(today)).toList()
        : dates;
    final before = [
      for (var i = 0; i < measured.length; i++)
        shiftDay(comparison ?? shiftDay(dates.first, -dates.length), i),
    ];
    final empty = demo.feed('stats') == DemoFeed.empty;
    final events = empty
        ? <PreviewEvent>[]
        : demo.planner.events
              .where(
                (event) =>
                    event.state != PreviewEventState.trashed &&
                    (category == 'Semua kategori' ||
                        category == event.options.category),
              )
              .toList();
    List<PreviewEvent> rows(List<DateTime> dates) =>
        events.where((event) => dates.contains(dateOnly(event.start))).toList();
    final current = rows(measured);
    final previous = rows(before);
    final obligations = current
        .where((event) => event.kind != PreviewKind.session)
        .toList();
    final done = obligations
        .where((event) => event.state == PreviewEventState.done)
        .length;
    final grouped = <DateTime, List<PreviewEvent>>{};
    for (final row in obligations) {
      grouped.putIfAbsent(dateOnly(row.start), () => []).add(row);
    }
    final average = grouped.isEmpty
        ? null
        : grouped.values
                  .map(
                    (day) =>
                        day
                            .where((row) => row.state == PreviewEventState.done)
                            .length /
                        day.length,
                  )
                  .reduce((total, next) => total + next) /
              grouped.length;
    final recorded = empty
        ? <DemoSlot>[]
        : demo.tasks
              .where(
                (task) =>
                    category == 'Semua kategori' || category == task.category,
              )
              .expand((task) => task.slots)
              .where(
                (slot) =>
                    slot.history &&
                    slot.actual != null &&
                    measured.contains(dateOnly(slot.start)),
              )
              .toList();
    final actual = recorded.fold(0, (value, slot) => value + slot.actual!);
    final planned = recorded.fold(0, (value, slot) => value + slot.minutes);
    final recovery = demoFeed(demo, 'stats', 'Statistik');
    return PreviewPage(
      title: 'Statistik',
      body: DemoList([
        const DemoHeading(
          'Produktivitasmu',
          subtitle: 'Lihat pola penyelesaian dan waktu aktual yang tercatat.',
        ),
        DemoSegments(
          items: _Period.values,
          selected: period,
          label: (item) => item.label,
          onChange: (value) => setState(() => period = value),
        ),
        PreviewField(
          label: 'Periode',
          value: dates.length == 1
              ? dateLabel(dates.first, year: true)
              : '${dateLabel(dates.first)} – ${dateLabel(dates.last, year: true)}',
          icon: Icons.event_outlined,
          onTap: () async {
            final value = await pickPreviewDate(
              context,
              demo.today,
              selected: anchor,
            );
            if (mounted && value != null) setState(() => anchor = value);
          },
        ),
        PreviewField(
          label: 'Kategori',
          value: category,
          onTap: () => demoPick(context, 'Kategori', [
            'Semua kategori',
            ...demo.categoryNames,
          ], (value) => setState(() => category = value)),
        ),
        if (recovery != null)
          recovery
        else ...[
          NeoCard(
            tone: NeoCardTone.accent,
            emphasis: true,
            child: DemoPair(
              _metric(
                'Penyelesaian total',
                obligations.isEmpty
                    ? '—'
                    : '${(100 * done / obligations.length).round()}%',
                '$done/${obligations.length} aktivitas selesai',
              ),
              _metric(
                'Rata-rata harian',
                average == null ? '—' : '${(average * 100).round()}%',
                'Hari dengan aktivitas',
              ),
            ),
          ),
          const Text('Penyelesaian per hari', style: NeoType.section),
          if (obligations.isEmpty)
            const PreviewNotice(
              title: 'Tidak Ada Aktivitas',
              message: 'Hari tanpa aktivitas ditampilkan sebagai titik kosong.',
            ),
          NeoCard(
            child: Wrap(
              spacing: NeoSpace.xs,
              runSpacing: NeoSpace.sm,
              alignment: WrapAlignment.center,
              children: [
                for (final date in dates)
                  _DayBar(
                    day: date,
                    total: grouped[date]?.length ?? 0,
                    done:
                        grouped[date]
                            ?.where(
                              (event) => event.state == PreviewEventState.done,
                            )
                            .length ??
                        0,
                  ),
              ],
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bandingkan periode sebelumnya'),
            value: compare,
            onChanged: (value) => setState(() => compare = value),
          ),
          DemoFacts([
            (
              'Durasi aktual terhadap rencana',
              planned == 0
                  ? '— · Belum ada data durasi'
                  : '$actual/$planned menit · ${(100 * actual / planned).round()}%',
            ),
            ('Total aktivitas', '${obligations.length}'),
            for (final (status, label) in [
              (PreviewEventState.done, 'Selesai'),
              (PreviewEventState.postponed, 'Ditunda'),
              (PreviewEventState.skipped, 'Dilewatkan'),
            ])
              (
                label,
                '${obligations.where((row) => row.state == status).length}',
              ),
          ]),
          if (compare) ...[
            PreviewField(
              label: 'Mulai pembanding',
              value: dateLabel(before.first),
              icon: Icons.event_outlined,
              onTap: () async {
                final value = await pickPreviewDate(
                  context,
                  demo.today,
                  selected: before.first,
                );
                if (mounted && value != null) {
                  setState(() => comparison = dateOnly(value));
                }
              },
            ),
            DemoFacts([
              (
                'Periode terpilih',
                '${dateLabel(measured.first)} – ${dateLabel(measured.last)}',
              ),
              (
                'Pembanding · ${measured.length} hari',
                '${dateLabel(before.first)} – ${dateLabel(before.last)}',
              ),
              (
                'Aktivitas selesai',
                '${previous.where((event) => event.kind != PreviewKind.session && event.state == PreviewEventState.done).length} aktivitas',
              ),
            ]),
          ],
          DemoRow(
            'Rincian per jenis',
            icon: Icons.bar_chart,
            onTap: () => demoSheet<void>(
              context,
              'Rincian per jenis',
              (_) => [
                for (final (kind, label) in [
                  (PreviewKind.activity, 'Kegiatan'),
                  (PreviewKind.deadline, 'Tenggat tugas'),
                  (PreviewKind.session, 'Sesi pengerjaan'),
                  (PreviewKind.routine, 'Rutinitas'),
                ])
                  DemoFacts([
                    (
                      label,
                      '${current.where((event) => event.kind == kind).length} aktivitas',
                    ),
                  ]),
              ],
            ),
          ),
        ],
      ]),
    );
  }

  Widget _metric(String title, String value, String caption) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: NeoType.item),
      const SizedBox(height: NeoSpace.xxs),
      Text(value, style: NeoType.metric),
      Text(caption, style: NeoType.caption),
    ],
  );
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.day, required this.total, required this.done});
  final DateTime day;
  final int total;
  final int done;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${dateLabel(day)}, ${total == 0 ? 'tidak ada aktivitas' : '$done dari $total selesai'}',
    excludeSemantics: true,
    child: SizedBox(
      width: 30,
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: total == 0 ? 6 : 8 + 48 * done / total,
                width: total == 0 ? 6 : 16,
                decoration: BoxDecoration(
                  color: total == 0 ? NeoColors.paper : NeoColors.blue,
                  border: Border.all(color: NeoColors.ink),
                  borderRadius: NeoRadius.small,
                ),
              ),
            ),
          ),
          const SizedBox(height: NeoSpace.xxs),
          Text('${day.day}', style: NeoType.numericCaption),
        ],
      ),
    ),
  );
}
