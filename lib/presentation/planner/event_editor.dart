import 'dart:async';

import 'package:flutter/material.dart';
import 'package:routina/application/activity_calendar.dart' show repeatLabel;
import 'package:routina/application/planner_preview.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/design_system/neo_button.dart';
import 'package:routina/presentation/design_system/neo_card.dart';
import 'package:routina/presentation/design_system/neo_form_field.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';
import 'package:routina/presentation/planner/preview_ui.dart';

class EventDraft {
  EventDraft({
    this.date,
    this.title = '',
    this.zone = 'Pertahankan zona asal (WIB)',
    this.timeMode,
    this.zoneId,
    this.supersedesId,
    this.before = 0,
    this.after = 0,
  });
  EventDraft.fromEvent(PreviewEvent event)
    : id = event.id,
      state = event.state,
      series = event.series,
      recurrenceKey = event.recurrenceKey,
      supersedesId = event.supersedesId,
      title = event.title,
      date = dateOnly(event.options.editorStart ?? event.start),
      endDate = dateOnly(
        event.allDay
            ? shiftDay(event.options.editorEnd ?? event.end, -1)
            : event.options.editorEnd ?? event.end,
      ),
      start = event.allDay
          ? null
          : minutesAt(event.options.editorStart ?? event.start),
      end = event.allDay
          ? null
          : minutesAt(event.options.editorEnd ?? event.end),
      availability = event.options.availability,
      category = event.options.category,
      categoryColor = event.options.categoryColor,
      recurrence = event.options.recurrence,
      rule = event.options.rule,
      reminders = List.of(event.options.reminders),
      description = event.options.description,
      location = event.options.location,
      note = event.options.note,
      link = event.options.link,
      zone = event.options.zone,
      zoneId = event.options.zoneId,
      timeMode = event.options.timeMode,
      before = event.options.before,
      after = event.options.after;

  String id = '';
  String? series;
  String? recurrenceKey;
  String? supersedesId;
  PreviewEventState state = PreviewEventState.upcoming;
  String title;
  DateTime? date;
  DateTime? endDate;
  int? start;
  int? end;
  DayAvailability availability = DayAvailability.timed;
  String category = '';
  String categoryColor = 'Biru';
  String recurrence = 'Sekali';
  EventRecurrence? rule;
  List<String> reminders = [];
  String description = '';
  String location = '';
  String note = '';
  String link = '';
  String zone;
  String? zoneId;
  TimeMode? timeMode;
  int before;
  int after;

  bool get allDay => availability != DayAvailability.timed;
  bool get started =>
      title.trim().isNotEmpty ||
      date != null ||
      start != null ||
      end != null ||
      allDay;
  bool get invalidLink {
    if (link.trim().isEmpty) return false;
    final uri = Uri.tryParse(link.trim());
    return uri == null ||
        !const ['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty;
  }

  PreviewEvent? candidate({ScheduleWarning? warning}) {
    final day = date;
    final starts = start;
    final ends = end;
    if (day == null || (!allDay && (starts == null || ends == null))) {
      return null;
    }
    final last = endDate ?? day;
    DateTime at(DateTime date, int minutes) =>
        DateTime(date.year, date.month, date.day, minutes ~/ 60, minutes % 60);
    return PreviewEvent(
      id: id,
      title: title.trim(),
      start: allDay ? day : at(day, starts!),
      end: allDay ? shiftDay(last, 1) : at(last, ends!),
      state: state,
      series: series,
      recurrenceKey: recurrenceKey,
      supersedesId: supersedesId,
      warning: warning,
      options: EventOptions(
        availability: availability,
        category: category,
        categoryColor: categoryColor,
        recurrence: recurrence,
        rule: rule,
        reminders: List.unmodifiable(reminders),
        description: description.trim(),
        location: location.trim(),
        note: note.trim(),
        link: link.trim(),
        zone: zone,
        zoneId: zoneId,
        timeMode: timeMode,
        before: before,
        after: after,
      ),
    );
  }
}

class EventEditor extends StatefulWidget {
  const EventEditor({
    required this.repository,
    required this.draft,
    this.full = false,
    this.scope,
    this.categories,
    super.key,
  });
  final PlannerPreviewRepository repository;
  final EventDraft draft;
  final bool full;
  final SeriesScope? scope;
  final Map<String, String>? categories;

  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  EventDraft get _draft => widget.draft;
  late final _title = TextEditingController(text: _draft.title);
  bool _submitted = false;
  bool _confirming = false;
  bool _saved = false;
  String? _saveError;
  Timer? _warningTimer;
  int _warningRevision = 0;
  List<ScheduleWarning> _activityWarnings = const [];

  @override
  void initState() {
    super.initState();
    _refreshWarnings();
  }

  @override
  void dispose() {
    _warningTimer?.cancel();
    _title.dispose();
    super.dispose();
  }

  void _change(VoidCallback change) {
    setState(change);
    _refreshWarnings();
  }

  void _refreshWarnings() {
    if (!widget.repository.usesStoredCalendar) return;
    _warningTimer?.cancel();
    final revision = ++_warningRevision;
    final proposed = _draft.candidate();
    if (proposed == null ||
        proposed.title.isEmpty ||
        !proposed.end.isAfter(proposed.start)) {
      _activityWarnings = const [];
      return;
    }
    if (_confirming || _saved) return;
    _warningTimer = Timer(const Duration(milliseconds: 250), () async {
      List<ScheduleWarning> warnings;
      try {
        warnings = await widget.repository.activityWarnings(
          proposed,
          scope: widget.scope,
        );
      } on Exception {
        warnings = const [];
      } on StateError {
        warnings = const [];
      }
      if (mounted && revision == _warningRevision) {
        setState(() => _activityWarnings = warnings);
      }
    });
  }

  Future<void> _date(bool end) async {
    final value = await pickPreviewDate(
      context,
      widget.repository.today,
      selected: end ? _draft.endDate ?? _draft.date : _draft.date,
    );
    if (!mounted || value == null) return;
    _change(() {
      if (end) {
        _draft.endDate = value;
      } else {
        _draft.date = value;
        if (!widget.full) _draft.endDate = null;
      }
    });
  }

  Future<void> _time(bool end) async {
    final value = await pickPreviewTime(
      context,
      initial: end ? _draft.end : _draft.start,
    );
    if (!mounted || value == null) return;
    _change(() {
      if (end) {
        _draft.end = value;
      } else {
        _draft.start = value;
      }
    });
  }

  Future<void> _choose(
    String title,
    List<String> choices,
    ValueChanged<String> assign,
  ) async {
    final chosen = await previewChoices(
      context,
      title,
      choices,
      (value) => value,
    );
    if (mounted && chosen != null) _change(() => assign(chosen));
  }

  Future<void> _buffer(bool end) async {
    final minutes = await previewChoices<int>(
      context,
      end ? 'Jeda sesudah' : 'Jeda sebelum',
      [0, 5, 10, 15, 30],
      (value) => value == 0 ? 'Tanpa jeda' : '$value menit',
    );
    if (mounted && minutes != null) {
      _change(() {
        if (end) {
          _draft.after = minutes;
        } else {
          _draft.before = minutes;
        }
      });
    }
  }

  Future<void> _reminders() async {
    const values = ['1 hari sebelumnya', '30 menit sebelumnya', 'Saat mulai'];
    final selected = {..._draft.reminders};
    final next = await showNeoBottomSheet<List<String>>(
      context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => NeoBottomSheet(
          title: 'Pengingat lokal',
          description: widget.repository.usesStoredCalendar
              ? 'Waktu pengingat disimpan untuk kegiatan ini.'
              : 'Pilihan berlaku pada pratinjau selama sesi.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final option in values)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selected.contains(option),
                  title: Text(option),
                  onChanged: (checked) => update(() {
                    if (checked == true) {
                      selected.add(option);
                    } else {
                      selected.remove(option);
                    }
                  }),
                ),
              NeoButton(
                label: 'Terapkan pengingat',
                onPressed: () => Navigator.pop(
                  context,
                  values.where(selected.contains).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted && next != null) _change(() => _draft.reminders = next);
  }

  Future<void> _recurrence() async {
    final option = await previewChoices(context, 'Pola pengulangan', [
      'Sekali',
      'Harian',
      'Mingguan',
      'Bulanan',
      'Kustom bulanan',
      'Interval khusus',
    ], (value) => value);
    if (!mounted || option == null) return;
    if (option != 'Kustom bulanan' && option != 'Interval khusus') {
      _change(() {
        _draft.recurrence = option;
        _draft.rule = switch (option) {
          'Harian' => EventRecurrence(
            RepeatFrequency.daily,
            until: _draft.rule?.until,
          ),
          'Mingguan · Selasa' || 'Mingguan' => EventRecurrence(
            RepeatFrequency.weekly,
            until: _draft.rule?.until,
          ),
          'Bulanan' => EventRecurrence(
            RepeatFrequency.monthly,
            until: _draft.rule?.until,
          ),
          _ => null,
        };
      });
      return;
    }
    final choice = await showNeoBottomSheet<EventRecurrence>(
      context,
      builder: (_) => _CustomCycle(
        today: widget.repository.today,
        customUnits: option == 'Interval khusus',
        until: _draft.rule?.until,
      ),
    );
    if (mounted && choice != null) {
      _change(() {
        _draft.rule = choice;
        _draft.recurrence = repeatLabel(choice);
      });
    }
  }

  Future<void> _chooseUntil() async {
    final rule = _draft.rule!;
    final choice = await previewChoices(context, 'Akhir pengulangan', [
      'Pilih tanggal akhir',
      'Tanpa tanggal akhir',
    ], (value) => value);
    if (!mounted || choice == null) return;
    final until = choice == 'Tanpa tanggal akhir'
        ? null
        : await pickPreviewDate(
            context,
            widget.repository.today,
            selected: rule.until ?? _draft.date,
          );
    if (!mounted || (choice != 'Tanpa tanggal akhir' && until == null)) return;
    _change(
      () => _draft.rule = EventRecurrence(
        rule.frequency,
        interval: rule.interval,
        until: until,
      ),
    );
  }

  Future<void> _openFull() async {
    final event = await Navigator.of(context).push<PreviewEvent>(
      MaterialPageRoute(
        builder: (_) => EventEditor(
          repository: widget.repository,
          draft: _draft,
          full: true,
          scope: widget.scope,
          categories: widget.categories,
        ),
      ),
    );
    if (!mounted) return;
    if (event != null) {
      Navigator.pop(context, event);
      return;
    }
    if (_title.text != _draft.title) _title.text = _draft.title;
    setState(() {});
  }

  Future<void> _save() async {
    if (_confirming || _saved) return;
    _change(() {
      _submitted = true;
      _saveError = null;
    });
    final proposed = _draft.candidate();
    if (proposed == null ||
        proposed.title.isEmpty ||
        !proposed.end.isAfter(proposed.start) ||
        _draft.invalidLink) {
      return;
    }
    _change(() => _confirming = true);
    try {
      var approved = <ScheduleWarning>{};
      PreviewEvent result;
      while (true) {
        try {
          result = await widget.repository.saveActivity(
            proposed,
            scope: widget.scope,
            approved: approved,
          );
          break;
        } on ActivityWarnings catch (conflict) {
          if (!mounted) return;
          final yes = await showNeoDialog(
            context,
            title: 'Simpan meski ada peringatan?',
            message: conflict.warnings.map(warningBody).join('\n'),
            confirmLabel: 'Simpan dengan peringatan',
          );
          if (!mounted || yes != true) return;
          approved = conflict.warnings.toSet();
        }
      }
      if (!mounted) return;
      _change(() => _saved = true);
      if (_draft.id.isEmpty) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => _SavedEvent(
              title: result.title,
              stored: widget.repository.usesStoredCalendar,
            ),
          ),
        );
      }
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (mounted) {
        _change(
          () => _saveError = error is FormatException || error is StateError
              ? (error is FormatException
                    ? error.message
                    : (error as StateError).message)
              : 'Kegiatan belum dapat disimpan. Coba lagi.',
        );
      }
    } finally {
      if (mounted) _change(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.full;
    final proposed = _draft.candidate();
    final timeError = proposed != null && !proposed.end.isAfter(proposed.start);
    final warnings = widget.repository.usesStoredCalendar
        ? _activityWarnings
        : proposed != null && !timeError
        ? previewWarnings(widget.repository, proposed)
        : <ScheduleWarning>[];
    final buttons = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeoButton(
          label: 'Simpan kegiatan',
          onPressed: _draft.started && !_confirming && !_saved ? _save : null,
        ),
        if (!full) ...[
          const SizedBox(height: NeoSpace.sm),
          NeoButton(
            label: 'Buka Form Lengkap',
            variant: NeoButtonVariant.secondary,
            onPressed: _openFull,
          ),
        ],
      ],
    );
    return PreviewPage(
      title: full
          ? (_draft.id.isEmpty ? 'Form kegiatan' : 'Edit kegiatan')
          : 'Tambah kegiatan',
      footer: full ? null : buttons,
      body: ListView(
        padding: const EdgeInsets.all(NeoSpace.page),
        children: [
          Text(
            full ? 'FORM LENGKAP' : 'Quick Add',
            style: full ? NeoType.badge : NeoType.display,
          ),
          if (!full) ...[
            const SizedBox(height: NeoSpace.xs),
            const Text('Isi judul, tanggal, dan waktu kegiatan.'),
          ],
          const SizedBox(height: NeoSpace.page),
          if (widget.scope case final scope?) ...[
            PreviewNotice(title: 'Cakupan perubahan', message: scope.label),
            const SizedBox(height: NeoSpace.md),
          ],
          NeoFormField(
            label: 'Judul',
            hint: 'Masukkan judul',
            controller: _title,
            labelAbove: true,
            errorText: _submitted && _draft.title.trim().isEmpty
                ? 'Judul wajib diisi.'
                : null,
            onChanged: (value) => _change(() => _draft.title = value),
          ),
          const SizedBox(height: NeoSpace.md),
          if (full) const _SectionTitle('Waktu'),
          _dateField(full ? 'Tanggal mulai' : 'Tanggal', _draft.date, false),
          if (full) ...[
            const SizedBox(height: NeoSpace.md),
            _dateField('Tanggal selesai', _draft.endDate ?? _draft.date, true),
          ],
          if (!_draft.allDay) ...[
            const SizedBox(height: NeoSpace.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _timeField('Mulai', _draft.start, false)),
                const SizedBox(width: NeoSpace.sm),
                Expanded(child: _timeField('Selesai', _draft.end, true)),
              ],
            ),
          ],
          if (timeError || (_submitted && proposed == null)) ...[
            const SizedBox(height: NeoSpace.md),
            PreviewNotice(
              title: timeError
                  ? 'Waktu selesai lebih awal'
                  : 'Jadwal belum lengkap',
              message: timeError
                  ? 'Waktu selesai harus sesudah waktu mulai.'
                  : 'Lengkapi tanggal dan waktu kegiatan.',
              warning: true,
              icon: Icons.warning_amber_rounded,
            ),
          ],
          if (_saveError case final error?) ...[
            const SizedBox(height: NeoSpace.sm),
            PreviewNotice(
              title: 'Kegiatan belum tersimpan',
              message: error,
              warning: true,
            ),
          ],
          for (final warning in warnings) ...[
            const SizedBox(height: NeoSpace.md),
            PreviewNotice(
              title: warningTitle(warning),
              message: warningBody(warning),
              warning: true,
              icon: Icons.warning_amber_rounded,
            ),
          ],
          if (full) ...[
            const SizedBox(height: NeoSpace.md),
            NeoCard(
              dense: true,
              child: SwitchListTile(
                title: const Text('Kegiatan sepanjang hari'),
                contentPadding: EdgeInsets.zero,
                value: _draft.allDay,
                onChanged: (value) => _change(
                  () => _draft.availability = value
                      ? DayAvailability.busy
                      : DayAvailability.timed,
                ),
                subtitle: Text(
                  _draft.allDay
                      ? (_draft.availability == DayAvailability.busy
                            ? 'Sibuk · memblokir rekomendasi'
                            : 'Tersedia · hanya informasi')
                      : 'Tampilkan waktu mulai dan selesai',
                ),
              ),
            ),
            if (_draft.allDay) ...[
              const SizedBox(height: NeoSpace.sm),
              Wrap(
                spacing: NeoSpace.xs,
                runSpacing: NeoSpace.xs,
                children: [
                  for (final (availability, label) in [
                    (DayAvailability.busy, 'Sibuk'),
                    (DayAvailability.free, 'Tersedia'),
                  ])
                    NeoButton(
                      label: label,
                      variant: _draft.availability == availability
                          ? NeoButtonVariant.primary
                          : NeoButtonVariant.secondary,
                      onPressed: () =>
                          _change(() => _draft.availability = availability),
                    ),
                ],
              ),
            ],
            const SizedBox(height: NeoSpace.md),
            PreviewField(
              label: 'Zona waktu',
              value: _draft.timeMode == null
                  ? _draft.zone
                  : timeModeLabel(_draft.timeMode!),
              onTap: () async {
                final mode = await previewChoices(
                  context,
                  'Zona waktu',
                  TimeMode.values,
                  timeModeLabel,
                );
                if (mounted && mode != null) {
                  _change(() {
                    _draft.timeMode = mode;
                    _draft.zone = timeModeLabel(mode);
                  });
                }
              },
            ),
            const SizedBox(height: NeoSpace.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PreviewField(
                    label: 'Jeda sebelum',
                    value: '${_draft.before} menit',
                    icon: Icons.schedule,
                    onTap: () => _buffer(false),
                  ),
                ),
                const SizedBox(width: NeoSpace.sm),
                Expanded(
                  child: PreviewField(
                    label: 'Jeda sesudah',
                    value: '${_draft.after} menit',
                    icon: Icons.schedule,
                    onTap: () => _buffer(true),
                  ),
                ),
              ],
            ),
            const _SectionTitle('Kategori'),
            PreviewField(
              label: 'Kategori',
              value: _draft.category.isEmpty
                  ? 'Tanpa kategori'
                  : _draft.category,
              onTap: () => _choose(
                'Kategori',
                [
                  'Tanpa kategori',
                  ...widget.categories?.keys ??
                      ['Kuliah', 'Belajar', 'Kegiatan', 'Kesehatan'],
                ],
                (value) {
                  _draft.category = value == 'Tanpa kategori' ? '' : value;
                  _draft.categoryColor =
                      widget.categories?[value] ?? _draft.categoryColor;
                },
              ),
            ),
            const SizedBox(height: NeoSpace.md),
            PreviewField(
              label: 'Warna',
              value: _draft.categoryColor,
              onTap: () => _choose('Warna kategori', [
                'Biru',
                'Kuning',
                'Coral',
              ], (value) => _draft.categoryColor = value),
            ),
            const _SectionTitle('Pengulangan'),
            if (widget.scope == SeriesScope.occurrence &&
                widget.repository.usesStoredCalendar)
              const Text('Hanya kejadian ini · pola seri tetap berlaku.')
            else ...[
              PreviewField(
                label: 'Pola',
                value: _draft.recurrence,
                onTap: _recurrence,
              ),
              if (_draft.rule case final rule?) ...[
                const SizedBox(height: NeoSpace.sm),
                PreviewField(
                  label: 'Akhir pengulangan',
                  value: rule.until == null
                      ? 'Tanpa tanggal akhir'
                      : dateLabel(rule.until!, year: true),
                  onTap: _chooseUntil,
                ),
                if (widget.repository.usesStoredCalendar)
                  const Text(
                    'Bentrok seri diperiksa untuk 90 hari pertama.',
                    style: NeoType.caption,
                  ),
              ],
            ],
            const _SectionTitle('Pengingat'),
            PreviewField(
              label: 'Pengingat lokal',
              value: _draft.reminders.isEmpty
                  ? 'Belum diatur'
                  : _draft.reminders.join(' + '),
              onTap: _reminders,
            ),
            const _SectionTitle('Detail tambahan'),
            _extra(
              'Deskripsi',
              _draft.description,
              (value) => _draft.description = value,
              maxLines: 3,
            ),
            _extra(
              'Lokasi (opsional)',
              _draft.location,
              (value) => _draft.location = value,
            ),
            _extra(
              'Catatan (opsional)',
              _draft.note,
              (value) => _draft.note = value,
              maxLines: 3,
            ),
            _extra(
              'Tautan (opsional)',
              _draft.link,
              (value) => _draft.link = value,
              isLink: true,
            ),
            const SizedBox(height: NeoSpace.md),
            buttons,
          ] else ...[
            const SizedBox(height: NeoSpace.page),
            Text(
              'Ketuk tanggal dan jam untuk mengisi kegiatan.',
              style: NeoType.caption.copyWith(color: NeoColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, bool end) => PreviewField(
    label: label,
    value: value == null ? 'Pilih tanggal' : dateLabel(value, year: true),
    icon: Icons.calendar_today_outlined,
    onTap: () => _date(end),
  );
  Widget _timeField(String label, int? value, bool end) => PreviewField(
    label: label,
    value: value == null ? 'Pilih jam' : clockLabel(value),
    numeric: true,
    icon: Icons.schedule,
    onTap: () => _time(end),
  );
  Widget _extra(
    String label,
    String initial,
    ValueChanged<String> update, {
    int maxLines = 1,
    bool isLink = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: NeoSpace.md),
    child: NeoFormField(
      label: label,
      labelAbove: true,
      initialValue: initial,
      maxLines: maxLines,
      keyboardType: isLink ? TextInputType.url : null,
      errorText: isLink && _draft.invalidLink
          ? 'Gunakan tautan HTTP atau HTTPS yang valid.'
          : null,
      helper: isLink && !_draft.invalidLink && _draft.link.trim().isNotEmpty
          ? 'Format tautan valid.'
          : null,
      onChanged: (value) => _change(() => update(value)),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: NeoSpace.md, bottom: NeoSpace.sm),
    child: Text(label, style: NeoType.section),
  );
}

class _CustomCycle extends StatefulWidget {
  const _CustomCycle({
    required this.today,
    this.customUnits = false,
    this.until,
  });
  final DateTime today;
  final bool customUnits;
  final DateTime? until;
  @override
  State<_CustomCycle> createState() => _CustomCycleState();
}

class _CustomCycleState extends State<_CustomCycle> {
  int _interval = 2;
  late DateTime? _until = widget.until;
  late RepeatFrequency _frequency = widget.customUnits
      ? RepeatFrequency.weekly
      : RepeatFrequency.monthly;

  String _unit(RepeatFrequency value) => switch (value) {
    RepeatFrequency.daily => 'hari',
    RepeatFrequency.weekly => 'minggu',
    RepeatFrequency.monthly => 'bulan',
  };

  @override
  Widget build(BuildContext context) => NeoBottomSheet(
    title: widget.customUnits
        ? 'Interval khusus'
        : 'Pengulangan bulanan kustom',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.customUnits) ...[
          PreviewField(
            label: 'Satuan',
            value: _unit(_frequency),
            onTap: () async {
              final value = await previewChoices(
                context,
                'Satuan interval',
                RepeatFrequency.values,
                _unit,
              );
              if (mounted && value != null) setState(() => _frequency = value);
            },
          ),
          const SizedBox(height: NeoSpace.sm),
        ],
        PreviewField(
          label: 'Interval',
          value: '$_interval ${_unit(_frequency)}',
          onTap: () async {
            final value = await previewChoices<int>(
              context,
              'Jumlah interval',
              [1, 2, 3, 6, 12],
              (value) => '$value ${_unit(_frequency)}',
            );
            if (mounted && value != null) setState(() => _interval = value);
          },
        ),
        const SizedBox(height: NeoSpace.md),
        PreviewField(
          label: 'Sampai (opsional)',
          value: _until == null
              ? 'Tanpa tanggal akhir'
              : dateLabel(_until!, year: true),
          icon: Icons.calendar_today_outlined,
          onTap: () async {
            final value = await pickPreviewDate(
              context,
              widget.today,
              selected: _until,
            );
            if (mounted && value != null) setState(() => _until = value);
          },
        ),
        const SizedBox(height: NeoSpace.md),
        NeoButton(
          label: 'Terapkan pengulangan',
          onPressed: () => Navigator.pop(
            context,
            EventRecurrence(_frequency, interval: _interval, until: _until),
          ),
        ),
      ],
    ),
  );
}

class _SavedEvent extends StatelessWidget {
  const _SavedEvent({required this.title, required this.stored});
  final String title;
  final bool stored;
  @override
  Widget build(BuildContext context) => PreviewPage(
    title: 'Kegiatan',
    footer: NeoButton(
      label: 'Lihat kalender',
      onPressed: () => Navigator.pop(context),
    ),
    body: ListView(
      padding: const EdgeInsets.all(NeoSpace.page),
      children: [
        const Icon(Icons.check_circle_outline, size: 56),
        const SizedBox(height: NeoSpace.page),
        const Text('Kegiatan tersimpan', style: NeoType.display),
        const SizedBox(height: NeoSpace.xs),
        Text(
          stored
              ? '$title ditambahkan ke kalender lokal.'
              : '$title ditambahkan ke agenda sesi pratinjau.',
        ),
      ],
    ),
  );
}
