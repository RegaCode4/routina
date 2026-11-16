import 'package:flutter/material.dart';
import 'package:routina/application/planner_preview.dart';
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
  });
  EventDraft.fromEvent(PreviewEvent event)
    : id = event.id,
      state = event.state,
      series = event.series,
      title = event.title,
      date = dateOnly(event.start),
      endDate = dateOnly(event.allDay ? shiftDay(event.end, -1) : event.end),
      start = event.allDay ? null : minutesAt(event.start),
      end = event.allDay ? null : minutesAt(event.end),
      availability = event.options.availability,
      category = event.options.category,
      categoryColor = event.options.categoryColor,
      recurrence = event.options.recurrence,
      reminders = List.of(event.options.reminders),
      description = event.options.description,
      location = event.options.location,
      note = event.options.note,
      link = event.options.link,
      zone = event.options.zone,
      before = event.options.before,
      after = event.options.after;

  String id = '';
  String? series;
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
  List<String> reminders = [];
  String description = '';
  String location = '';
  String note = '';
  String link = '';
  String zone;
  int before = 0;
  int after = 0;

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
      warning: warning,
      options: EventOptions(
        availability: availability,
        category: category,
        categoryColor: categoryColor,
        recurrence: recurrence,
        reminders: List.unmodifiable(reminders),
        description: description.trim(),
        location: location.trim(),
        note: note.trim(),
        link: link.trim(),
        zone: zone,
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

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _change(VoidCallback change) => setState(change);

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
          description: 'Pilihan berlaku pada pratinjau selama sesi.',
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
      'Mingguan · Selasa',
      'Bulanan',
      'Kustom bulanan',
    ], (value) => value);
    if (!mounted || option == null) return;
    if (option != 'Kustom bulanan') {
      _change(() => _draft.recurrence = option);
      return;
    }
    final choice = await showNeoBottomSheet<String>(
      context,
      builder: (_) => _CustomCycle(today: widget.repository.today),
    );
    if (mounted && choice != null) _change(() => _draft.recurrence = choice);
  }

  Future<void> _openFull() async {
    final event = await Navigator.of(context).push<PreviewEvent>(
      MaterialPageRoute(
        builder: (_) => EventEditor(
          repository: widget.repository,
          draft: _draft,
          full: true,
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
    _change(() => _submitted = true);
    final proposed = _draft.candidate();
    if (proposed == null ||
        proposed.title.isEmpty ||
        !proposed.end.isAfter(proposed.start) ||
        _draft.invalidLink) {
      return;
    }
    final warnings = previewWarnings(widget.repository, proposed);
    if (warnings.isNotEmpty) {
      _change(() => _confirming = true);
      final yes = await showNeoDialog(
        context,
        title: 'Simpan meski ada peringatan?',
        message: warnings.map(warningBody).join('\n'),
        confirmLabel: 'Simpan dengan peringatan',
      );
      if (!mounted) return;
      _change(() => _confirming = false);
      if (yes != true) return;
    }
    final result = widget.repository.saveEvent(
      _draft.candidate(warning: warnings.firstOrNull)!,
      scope: widget.scope,
    );
    _change(() => _saved = true);
    if (_draft.id.isNotEmpty) {
      Navigator.pop(context, result);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _SavedEvent(title: result.title)),
    );
    if (mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.full;
    final proposed = _draft.candidate();
    final timeError = proposed != null && !proposed.end.isAfter(proposed.start);
    final warnings = proposed != null && !timeError
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
              value: _draft.zone,
              onTap: () => _choose(
                'Zona waktu',
                TimeMode.values.map(timeModeLabel).toList(),
                (value) => _draft.zone = value,
              ),
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
            PreviewField(
              label: 'Pola',
              value: _draft.recurrence,
              onTap: _recurrence,
            ),
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
  const _CustomCycle({required this.today});
  final DateTime today;
  @override
  State<_CustomCycle> createState() => _CustomCycleState();
}

class _CustomCycleState extends State<_CustomCycle> {
  int _interval = 2;
  DateTime? _until;

  @override
  Widget build(BuildContext context) => NeoBottomSheet(
    title: 'Pengulangan bulanan kustom',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PreviewField(
          label: 'Interval',
          value: '$_interval bulan',
          onTap: () async {
            final value = await previewChoices<int>(context, 'Interval bulan', [
              1,
              2,
              3,
              6,
              12,
            ], (value) => '$value bulan');
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
            'Setiap $_interval bulan${_until == null ? '' : ' · sampai ${dateLabel(_until!, year: true)}'}',
          ),
        ),
      ],
    ),
  );
}

class _SavedEvent extends StatelessWidget {
  const _SavedEvent({required this.title});
  final String title;
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
        Text('$title ditambahkan ke agenda sesi pratinjau.'),
      ],
    ),
  );
}
