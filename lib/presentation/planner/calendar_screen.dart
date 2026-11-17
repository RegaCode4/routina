import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:routina/application/activity_search.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/design_system/neo_badges.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_navigation.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/design_system/planner_cards.dart';
import 'package:routina/presentation/planner/activity_search_controls.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

enum CalendarView {
  month('Bulan'),
  week('Minggu'),
  day('Hari');

  const CalendarView(this.label);
  final String label;
}

class PlannerCalendar extends StatefulWidget {
  const PlannerCalendar({
    required this.repository,
    required this.requestedDay,
    required this.requestedView,
    required this.selection,
    required this.onOpen,
    required this.onAdd,
    this.revision = 0,
    super.key,
  });
  final PlannerPreviewRepository repository;
  final DateTime? requestedDay;
  final CalendarView requestedView;
  final int selection;
  final int revision;
  final ValueChanged<PreviewEvent> onOpen;
  final ValueChanged<DateTime> onAdd;

  @override
  State<PlannerCalendar> createState() => _PlannerCalendarState();
}

class _PlannerCalendarState extends State<PlannerCalendar> {
  late DateTime _date = widget.requestedDay ?? widget.repository.calendarDay;
  late CalendarView _view = widget.requestedView;
  late Future<List<PreviewEvent>> _load = _read();
  final _scroll = ScrollController();
  final _query = TextEditingController();
  bool _searching = false;
  bool _dateFiltered = false;
  String? _categoryId;
  CalendarStatus? _status;
  AgendaOrder _order = AgendaOrder.chronological;
  bool _wita = false;

  @override
  void dispose() {
    _scroll.dispose();
    _query.dispose();
    super.dispose();
  }

  void _selectView(CalendarView value) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _view = value;
      if (widget.repository.usesStoredCalendar) _load = _read();
    });
  }

  @override
  void didUpdateWidget(covariant PlannerCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection) {
      _date = widget.requestedDay ?? widget.repository.calendarDay;
      _view = widget.requestedView;
      _searching = false;
      _clearSearch();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
    if (widget.repository.usesStoredCalendar &&
        (oldWidget.selection != widget.selection ||
            oldWidget.revision != widget.revision)) {
      _load = _read();
    }
    if (_categoryId?.isNotEmpty == true &&
        !widget.repository.categories.any((row) => row.id == _categoryId)) {
      _categoryId = null;
    }
  }

  void _clearSearch() {
    _query.clear();
    _categoryId = null;
    _status = null;
    _dateFiltered = false;
    _order = AgendaOrder.chronological;
  }

  void _toggleSearch() {
    FocusScope.of(context).unfocus();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _searching = !_searching;
      if (!_searching) _clearSearch();
    });
  }

  bool get _sunday => widget.repository.profile?.sundayFirst ?? false;
  DateTime _weekStart(DateTime day) =>
      shiftDay(day, -((day.weekday - (_sunday ? 7 : 1) + 7) % 7));

  Future<List<PreviewEvent>> _read() {
    final (start, days) = switch (_view) {
      CalendarView.month => (_weekStart(DateTime(_date.year, _date.month)), 42),
      CalendarView.week => (_weekStart(_date), 7),
      CalendarView.day => (dateOnly(_date), 1),
    };
    return widget.repository.readCalendar(start, shiftDay(start, days));
  }

  void _selectDay(DateTime day) => setState(() {
    final newMonth = _date.month != day.month || _date.year != day.year;
    _date = day;
    if (widget.repository.usesStoredCalendar &&
        (_view == CalendarView.day || newMonth)) {
      _load = _read();
    }
  });

  List<PreviewEvent> _entries(List<PreviewEvent> stored) => [
    for (final entry
        in widget.repository.usesStoredCalendar
            ? stored
            : widget.repository.events)
      if (entry.state != PreviewEventState.trashed)
        if (_wita && !entry.allDay)
          PreviewEvent(
            id: entry.id,
            title: entry.title,
            start: entry.start.add(const Duration(hours: 1)),
            end: entry.end.add(const Duration(hours: 1)),
            kind: entry.kind,
            state: entry.state,
            options: entry.options,
            series: entry.series,
            warning: entry.warning,
          )
        else
          entry,
  ];

  Future<void> _chooseDate({bool filter = false}) async {
    final value = await pickPreviewDate(
      context,
      widget.repository.today,
      selected: _date,
    );
    if (mounted && value != null) {
      setState(() {
        _date = value;
        if (filter) _dateFiltered = true;
        if (widget.repository.usesStoredCalendar) _load = _read();
      });
    }
  }

  Future<void> _pickDateFilter() async {
    FocusScope.of(context).unfocus();
    final filter = await previewChoices(
      context,
      'Tanggal aktivitas',
      [true, false],
      (filter) => filter ? 'Pilih tanggal' : 'Periode tampilan',
    );
    if (!mounted || filter == null) return;
    if (filter) {
      await _chooseDate(filter: true);
    } else {
      setState(() => _dateFiltered = false);
    }
  }

  Widget _searchControls() => ActivitySearchControls(
    label: 'Cari aktivitas kalender',
    controller: _query,
    onChanged: (_) => setState(() {}),
    chips: [
      CategoryChip(
        label: _dateFiltered ? dateLabel(_date) : 'Tanggal',
        selected: _dateFiltered,
        onSelected: (_) => _pickDateFilter(),
      ),
      SearchCategoryChip(
        categories: widget.repository.categories,
        selectedId: _categoryId,
        onSelected: (value) => setState(() => _categoryId = value),
      ),
      CategoryChip(
        label: _status?.label ?? 'Status',
        selected: _status != null,
        onSelected: (_) async {
          FocusScope.of(context).unfocus();
          final choices = [
            'Semua status',
            ...CalendarStatus.values.map((s) => s.label),
          ];
          final pick = await previewChoices(
            context,
            'Status aktivitas',
            choices,
            (label) => label,
          );
          if (mounted && pick != null) {
            setState(
              () => _status = CalendarStatus.values
                  .where((s) => s.label == pick)
                  .firstOrNull,
            );
          }
        },
      ),
      CategoryChip(
        label: _order == AgendaOrder.chronological ? 'Urutkan' : _order.label,
        selected: _order != AgendaOrder.chronological,
        onSelected: (_) async {
          FocusScope.of(context).unfocus();
          final pick = await previewChoices(
            context,
            'Urutkan aktivitas',
            AgendaOrder.values,
            (order) => order.label,
          );
          if (mounted && pick != null) setState(() => _order = pick);
        },
      ),
    ],
  );

  Widget _searchResults(List<PreviewEvent> entries) {
    final matches = searchCalendar(
      entries,
      title: _query.text,
      categoryId: _categoryId,
      status: _status,
      day: _dateFiltered ? _date : null,
      period: _view == CalendarView.month && !_dateFiltered
          ? (
              from: DateTime(_date.year, _date.month),
              until: DateTime(_date.year, _date.month + 1),
            )
          : null,
      order: _order,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _dateFiltered
              ? 'Hasil · ${dateLabel(_date)}'
              : 'Hasil · ${_period()}',
          style: NeoType.section,
        ),
        const SizedBox(height: NeoSpace.xs),
        if (matches.isEmpty)
          ActivitySearchEmpty(
            title: 'Aktivitas tidak ditemukan',
            onClear: () => setState(_clearSearch),
          ),
        for (final entry in matches)
          Padding(
            padding: const EdgeInsets.only(bottom: NeoSpace.xs),
            child: _entryCard(entry, showDate: true),
          ),
      ],
    );
  }

  Future<void> _chooseZone() async {
    final value = await previewChoices<bool>(context, 'Zona tampilan', [
      false,
      true,
    ], (value) => value ? 'WITA (UTC+8)' : 'WIB (UTC+7)');
    if (mounted && value != null) setState(() => _wita = value);
  }

  void _move(int direction) => setState(() {
    _date = switch (_view) {
      CalendarView.month => DateTime(_date.year, _date.month + direction, 1),
      CalendarView.week => shiftDay(_date, direction * 7),
      CalendarView.day => shiftDay(_date, direction),
    };
    if (widget.repository.usesStoredCalendar) _load = _read();
  });

  String _period() {
    if (_view == CalendarView.month) {
      return '${monthNames[_date.month - 1]} ${_date.year}';
    }
    if (_view == CalendarView.day) return dateLabel(_date);
    final first = _weekStart(_date);
    final last = shiftDay(first, 6);
    final start = first.month == last.month
        ? '${first.day}'
        : '${first.day} ${monthNames[first.month - 1]}';
    return '$start–${last.day} ${monthNames[last.month - 1]}';
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppHeader(
        title: 'Kalender',
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.repository.usesStoredCalendar) ...[
              NeoIconButton(
                icon: _searching ? Icons.close : Icons.search,
                label: _searching
                    ? 'Tutup pencarian kalender'
                    : 'Cari dan filter kalender',
                onPressed: _toggleSearch,
              ),
              const SizedBox(width: NeoSpace.xxs),
            ],
            NeoIconButton(
              icon: Icons.calendar_today_outlined,
              label: 'Pilih tanggal kalender',
              onPressed: _chooseDate,
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(NeoSpace.page, 2, NeoSpace.page, 0),
        child: _ViewControl(selected: _view, onSelect: _selectView),
      ),
      Expanded(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(
            NeoSpace.page,
            NeoSpace.xs,
            NeoSpace.page,
            NeoSize.fab + NeoSpace.section,
          ),
          children: [
            Row(
              children: [
                Expanded(child: Text(_period(), style: NeoType.section)),
                NeoIconButton(
                  icon: Icons.chevron_left,
                  label: 'Periode sebelumnya',
                  onPressed: () => _move(-1),
                ),
                const SizedBox(width: NeoSpace.xxs),
                NeoIconButton(
                  icon: Icons.chevron_right,
                  label: 'Periode berikutnya',
                  onPressed: () => _move(1),
                ),
              ],
            ),
            if (_view != CalendarView.month)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: InkWell(
                  onTap: widget.repository.usesStoredCalendar
                      ? null
                      : _chooseZone,
                  borderRadius: NeoRadius.small,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: NeoSpace.xs),
                    child: Text(
                      widget.repository.usesStoredCalendar
                          ? '${widget.repository.calendarZoneLabel}${_view == CalendarView.week ? ' · Minggu dimulai ${_sunday ? 'Minggu' : 'Senin'}' : ''}'
                          : _wita
                          ? 'Zona tampilan · WITA (UTC+8)'
                          : _view == CalendarView.week
                          ? 'WIB · Minggu dimulai ${_sunday ? 'Minggu' : 'Senin'}'
                          : 'WIB · Asia/Jakarta',
                      style: NeoType.caption.copyWith(color: NeoColors.muted),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: NeoSpace.sm),
            if (_searching) ...[
              _searchControls(),
              const SizedBox(height: NeoSpace.md),
            ],
            FutureBuilder<List<PreviewEvent>>(
              future: _load,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const PreviewNotice(
                    title: 'Memuat kalender',
                    message: 'Sedang membaca jadwal tanggal ini.',
                    loading: true,
                  );
                }
                if (snapshot.hasError) {
                  return PreviewNotice(
                    title: 'Kalender belum tersedia',
                    message: 'Coba lagi untuk membaca jadwal.',
                    icon: Icons.error_outline,
                    warning: true,
                    button: NeoButton(
                      label: 'Muat ulang kalender',
                      onPressed: () {
                        final retry = _read();
                        setState(() {
                          _load = retry;
                        });
                      },
                    ),
                  );
                }
                final entries = _entries(snapshot.data ?? const []);
                if (_searching) return _searchResults(entries);
                final dayEntries =
                    entries.where((item) => appearsOn(item, _date)).toList()
                      ..sort((a, b) => a.start.compareTo(b.start));
                return switch (_view) {
                  CalendarView.month => _month(entries, dayEntries),
                  CalendarView.week => _week(entries, dayEntries),
                  CalendarView.day => _day(dayEntries),
                };
              },
            ),
          ],
        ),
      ),
    ],
  );

  Widget _month(List<PreviewEvent> entries, List<PreviewEvent> dayEntries) {
    final month = DateTime(_date.year, _date.month);
    final first = _weekStart(month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeoCard(
          dense: true,
          child: Column(
            children: [
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Text(
                        shortDays[shiftDay(first, i).weekday - 1],
                        textAlign: TextAlign.center,
                        style: NeoType.badge,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: NeoSpace.xxs),
              for (var week = 0; week < 6; week++)
                Row(
                  children: [
                    for (var day = 0; day < 7; day++)
                      Expanded(
                        child: _monthCell(
                          shiftDay(first, week * 7 + day),
                          entries,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: NeoSpace.md),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: NeoSpace.xs,
          children: [
            Text(dateLabel(_date), style: NeoType.section),
            TextButton(
              onPressed: () => _selectView(CalendarView.day),
              child: const Text('Lihat hari'),
            ),
          ],
        ),
        _agenda(dayEntries),
        const SizedBox(height: NeoSpace.sm),
        const Text(
          '● Kegiatan    ● Tenggat    ▢ Hari ini',
          style: NeoType.caption,
        ),
      ],
    );
  }

  Widget _monthCell(DateTime date, List<PreviewEvent> entries) {
    final items = entries.where((event) => appearsOn(event, date)).toList();
    final picked = date == _date;
    final today = date == widget.repository.today;
    void onTap() => _selectDay(date);
    return Semantics(
      label:
          '${dateLabel(date, year: true)}${items.isEmpty ? '' : ', ${items.length} agenda'}',
      button: true,
      selected: picked,
      excludeSemantics: true,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Material(
          color: picked ? NeoColors.blue : NeoColors.paper,
          shape: RoundedRectangleBorder(
            borderRadius: NeoRadius.small,
            side: today ? NeoLine.thin : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: NeoRadius.small,
            onTap: onTap,
            excludeFromSemantics: true,
            child: SizedBox(
              height: 38,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${date.day}',
                        style: NeoType.numericCaption.copyWith(
                          color: date.month == _date.month || picked
                              ? NeoColors.ink
                              : NeoColors.muted,
                          fontWeight: picked
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  if (items.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (items.any(
                          (entry) => entry.kind != PreviewKind.deadline,
                        ))
                          const _Dot(NeoColors.blue),
                        if (items.any(
                          (entry) => entry.kind == PreviewKind.deadline,
                        ))
                          const _Dot(NeoColors.coral),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _week(List<PreviewEvent> entries, List<PreviewEvent> dayEntries) {
    final first = _weekStart(_date);
    final days = List.generate(7, (index) => shiftDay(first, index));
    final byDay = [
      for (final day in days)
        entries.where((entry) => appearsOn(entry, day)).toList(),
    ];
    final earliest = byDay
        .expand((day) => day)
        .where((entry) => !entry.allDay)
        .fold(8, (hour, entry) => math.min(hour, entry.start.hour));
    final crosses = byDay
        .expand((day) => day)
        .any(
          (entry) =>
              !entry.allDay &&
              dateOnly(entry.start) != dateOnly(entry.end) &&
              minutesAt(entry.end) != 0,
        );
    final startHour = crosses ? 0 : earliest;
    final latest = byDay
        .expand((day) => day)
        .where((entry) => !entry.allDay)
        .fold(
          21,
          (hour, entry) =>
              math.max(hour, entry.end.hour + (entry.end.minute > 0 ? 1 : 0)),
        );
    final rows = crosses
        ? 24
        : (latest - startHour + 1).clamp(1, 24 - startHour);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeoCard(
          dense: true,
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 36),
                  for (final day in days)
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDay(day),
                        borderRadius: NeoRadius.small,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: day == _date
                                ? NeoColors.yellow
                                : NeoColors.paper,
                            borderRadius: NeoRadius.small,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: NeoSpace.xs,
                            ),
                            child: Column(
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    dayNames[day.weekday - 1][0],
                                    style: NeoType.badge,
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${day.day}',
                                    style: NeoType.numericCaption,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 36,
                    child: Text('Sehari', style: TextStyle(fontSize: 8)),
                  ),
                  for (final list in byDay)
                    Expanded(
                      child: Column(
                        children: [
                          for (final entry in list.where(
                            (entry) => entry.allDay,
                          ))
                            _AllDayChip(
                              entry: entry,
                              onTap: () => widget.onOpen(entry),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: NeoSpace.xs),
              _TimeGrid(
                days: days,
                entries: byDay,
                startHour: startHour,
                hourCount: rows,
                hourHeight: crosses ? 18 : 23,
                weekly: true,
                onOpen: widget.onOpen,
              ),
            ],
          ),
        ),
        const SizedBox(height: NeoSpace.md),
        Text('Agenda ${dayNames[_date.weekday - 1]}', style: NeoType.section),
        const SizedBox(height: NeoSpace.xs),
        _agenda(dayEntries),
      ],
    );
  }

  Widget _day(List<PreviewEvent> entries) {
    if (entries.isEmpty) return _agenda(entries);
    final timed = entries.where((entry) => !entry.allDay).toList();
    final starts = timed.map((entry) => _startMinute(entry, _date)).toList();
    final ends = timed.map((entry) => _endMinute(entry, _date)).toList();
    final first = starts.isEmpty
        ? 8
        : math.max(0, starts.reduce(math.min) ~/ 60 - 1);
    final last = ends.isEmpty
        ? 18
        : math.min(24, (ends.reduce(math.max) / 60).ceil());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries.where((entry) => entry.allDay)) ...[
          _entryCard(entry),
          const SizedBox(height: NeoSpace.xs),
        ],
        if (timed.isNotEmpty) ...[
          const SizedBox(height: NeoSpace.sm),
          const Text('LINIMASA', style: NeoType.badge),
          const SizedBox(height: NeoSpace.xs),
          _TimeGrid(
            days: [_date],
            entries: [timed],
            startHour: first,
            hourCount: math.max(1, last - first + 1),
            weekly: false,
            hourHeight: 47,
            onOpen: widget.onOpen,
          ),
          const SizedBox(height: NeoSpace.md),
          if (timed.any((entry) => entry.warning != null))
            _agenda(timed.where((entry) => entry.warning != null).toList()),
          if (timed.any((entry) => entry.kind == PreviewKind.deadline))
            _agenda(
              timed
                  .where((entry) => entry.kind == PreviewKind.deadline)
                  .toList(),
            ),
        ],
      ],
    );
  }

  Widget _agenda(List<PreviewEvent> list) => list.isEmpty
      ? PreviewNotice(
          title: 'Tidak Ada Aktivitas',
          message: 'Pilih tanggal lain atau tambahkan kegiatan.',
          icon: Icons.event_busy_outlined,
          button: NeoButton(
            label: 'Tambah kegiatan',
            variant: NeoButtonVariant.secondary,
            onPressed: () => widget.onAdd(_date),
          ),
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in list)
              Padding(
                padding: const EdgeInsets.only(bottom: NeoSpace.xs),
                child: _entryCard(entry),
              ),
          ],
        );

  Widget _entryCard(PreviewEvent entry, {bool showDate = false}) =>
      ActivityCard(
        title: entry.title,
        time: showDate
            ? '${dateLabel(entry.start)} · ${eventTime(entry)}'
            : eventTime(entry),
        category: entry.kind == PreviewKind.deadline
            ? entry.options.zone
            : entry.kind == PreviewKind.session
            ? 'Sesi pengerjaan'
            : entry.warning != null
            ? warningTitle(entry.warning!)
            : entry.options.category.isEmpty
            ? null
            : entry.options.category,
        recurring: entry.series != null,
        status: agendaStatus(entry),
        highlighted: entry.options.availability == DayAvailability.busy,
        onTap: () => widget.onOpen(entry),
      );
}

class _ViewControl extends StatelessWidget {
  const _ViewControl({required this.selected, required this.onSelect});
  final CalendarView selected;
  final ValueChanged<CalendarView> onSelect;
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
          for (final view in CalendarView.values)
            Expanded(
              child: Semantics(
                selected: view == selected,
                button: true,
                child: InkWell(
                  onTap: () => onSelect(view),
                  borderRadius: NeoRadius.small,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: view == selected
                          ? NeoColors.yellow
                          : NeoColors.paper,
                      borderRadius: NeoRadius.small,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: NeoSize.touch,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(NeoSpace.xxs),
                          child: Text(
                            view.label,
                            textAlign: TextAlign.center,
                            style: NeoType.badge,
                          ),
                        ),
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

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(1),
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox.square(dimension: 4),
    ),
  );
}

class _AllDayChip extends StatelessWidget {
  const _AllDayChip({required this.entry, required this.onTap});
  final PreviewEvent entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final busy = entry.options.availability == DayAvailability.busy;
    return Semantics(
      label: '${entry.title}, ${busy ? 'Sibuk' : 'Tersedia'}',
      excludeSemantics: true,
      button: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: busy ? NeoColors.coralTint : NeoColors.blueTint,
              borderRadius: NeoRadius.small,
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(busy ? 'Sibuk' : 'Tersedia', style: NeoType.badge),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

int _startMinute(PreviewEvent entry, DateTime day) =>
    civilTime(entry.start).isBefore(civilDate(day))
    ? 0
    : minutesAt(entry.start);
int _endMinute(PreviewEvent entry, DateTime day) =>
    civilTime(entry.end).isBefore(civilDate(day).add(const Duration(days: 1)))
    ? minutesAt(entry.end)
    : 1440;

class _TimeGrid extends StatelessWidget {
  const _TimeGrid({
    required this.days,
    required this.entries,
    required this.startHour,
    required this.hourCount,
    required this.hourHeight,
    required this.weekly,
    required this.onOpen,
  });
  final List<DateTime> days;
  final List<List<PreviewEvent>> entries;
  final int startHour;
  final int hourCount;
  final double hourHeight;
  final bool weekly;
  final ValueChanged<PreviewEvent> onOpen;

  @override
  Widget build(BuildContext context) {
    final gutter = weekly ? 36.0 : 58.0;
    final height = hourCount * hourHeight;
    return LayoutBuilder(
      builder: (context, constraints) {
        final column = (constraints.maxWidth - gutter) / days.length;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              for (var hour = 0; hour < hourCount; hour++)
                Positioned(
                  top: hour * hourHeight,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      SizedBox(
                        width: gutter,
                        child: Text(
                          clockLabel((startHour + hour) * 60),
                          style: NeoType.numericCaption.copyWith(
                            fontSize: weekly ? 8 : 11,
                            color: NeoColors.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Expanded(
                        child: Divider(height: 1, color: NeoColors.line),
                      ),
                    ],
                  ),
                ),
              for (var day = 0; day < days.length; day++)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: gutter + day * column,
                  child: const VerticalDivider(width: 1, color: NeoColors.line),
                ),
              for (var day = 0; day < days.length; day++)
                ..._blocks(day, gutter, column, height),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _blocks(int day, double gutter, double column, double height) {
    final date = days[day];
    final items = entries[day].where((entry) => !entry.allDay).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final ends = <int>[];
    final tracks = <int>[];
    final minimum = weekly ? 18.0 : 52.0;
    for (final entry in items) {
      final start = _startMinute(entry, date);
      final occupied = math.max(
        _endMinute(entry, date),
        start + (minimum / hourHeight * 60).ceil(),
      );
      final free = ends.indexWhere((end) => end <= start);
      if (free < 0) {
        tracks.add(ends.length);
        ends.add(occupied);
      } else {
        tracks.add(free);
        ends[free] = occupied;
      }
    }
    final width = column / math.max(1, ends.length);
    final start = startHour * 60;
    return [
      for (var i = 0; i < items.length; i++)
        Builder(
          builder: (context) {
            final entry = items[i];
            final top = math.min(
              height - minimum,
              math.max(
                0.0,
                (_startMinute(entry, date) - start) / 60 * hourHeight,
              ),
            );
            final raw =
                (_endMinute(entry, date) - _startMinute(entry, date)) /
                60 *
                hourHeight;
            final blockHeight = math.min(height - top, math.max(minimum, raw));
            return Positioned(
              top: top,
              left: gutter + day * column + tracks[i] * width + 1,
              width: math.max(0, width - 3),
              height: blockHeight,
              child: _TimeBlock(
                entry: entry,
                compact: weekly,
                onTap: () => onOpen(entry),
              ),
            );
          },
        ),
    ];
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({
    required this.entry,
    required this.compact,
    required this.onTap,
  });
  final PreviewEvent entry;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final warning = entry.warning;
    final fill = warning != null || entry.kind == PreviewKind.deadline
        ? NeoColors.coralTint
        : entry.kind == PreviewKind.activity
        ? (compact ? NeoColors.blue : NeoColors.blueTint)
        : NeoColors.yellowTint;
    return Semantics(
      label:
          '${entry.title}, ${eventTime(entry)}${warning == null ? '' : ', ${warningTitle(warning)}'}',
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: fill,
        shape: const RoundedRectangleBorder(
          borderRadius: NeoRadius.small,
          side: NeoLine.thin,
        ),
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          borderRadius: NeoRadius.small,
          child: ClipRect(
            child: Padding(
              padding: EdgeInsets.all(compact ? 2 : NeoSpace.xs),
              child: LayoutBuilder(
                builder: (context, box) {
                  if (compact) {
                    final short = entry.title.startsWith('Kuliah')
                        ? 'Kuliah'
                        : entry.kind == PreviewKind.deadline
                        ? 'Tenggat'
                        : entry.title;
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        '${warning == null ? '' : '! '}$short',
                        style: NeoType.badge.copyWith(fontSize: 8),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textScaler: const TextScaler.linear(1),
                      ),
                    );
                  }
                  final enlarged =
                      MediaQuery.textScalerOf(context).scale(12) > 16;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          '${warning == null ? '' : '⚠ '}${entry.title}',
                          style: NeoType.item,
                          maxLines: box.maxHeight > 70 ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!enlarged && box.maxHeight >= 32)
                        Text(
                          eventTime(entry),
                          style: NeoType.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
