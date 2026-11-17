import 'package:routina/application/local_reminders.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/application/routine_workspace.dart';
import 'package:routina/application/task_workspace.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';
import 'package:routina/domain/preview_event.dart';

enum PreviewFixture {
  standard,
  empty,
  allDone,
  conflict,
  buffer,
  crossMidnight,
  overdue,
  active,
  outsideHours,
}

class MemoryPlannerPreview implements PlannerPreviewRepository {
  @override
  LocalReminders? get localReminders => null;
  @override
  TaskWorkspace? get taskWorkspace => null;

  @override
  RoutineWorkspace? get routineWorkspace => null;

  MemoryPlannerPreview({
    required DateTime today,
    PreviewProfile? profile,
    int onboardingStep = 0,
    PreviewFixture fixture = PreviewFixture.standard,
    Set<PreviewSurface> failOnce = const {},
    bool seedCategories = true,
    this.latency = const Duration(milliseconds: 250),
  }) : today = dateOnly(today),
       _profile = profile,
       _step = onboardingStep,
       _failOnce = Set.of(failOnce) {
    final days = (DateTime.tuesday - today.weekday + 7) % 7;
    calendarDay = shiftDay(today, days == 0 ? 7 : days);
    _events = fixture == PreviewFixture.empty ? [] : _samples(fixture);
    if (seedCategories) {
      final names = {
        'Pekerjaan',
        'Belajar',
        'Pribadi',
        ..._events
            .map((event) => event.options.category)
            .where((name) => name.isNotEmpty),
      };
      final colors = previewCategoryPalette.values.toList();
      for (final name in names) {
        _categories.add(
          Category(
            RecordMetadata.create(),
            name: name,
            color: colors[_categories.length % colors.length],
            icon: 'label',
          ),
        );
      }
    }
  }

  @override
  final DateTime today;
  @override
  late final DateTime calendarDay;
  final Duration latency;
  final Set<PreviewSurface> _failOnce;
  late final List<PreviewEvent> _events;
  final _categories = <Category>[];
  PreviewProfile? _profile;
  int _step;
  int _nextId = 0;

  @override
  List<PreviewEvent> get events => List.unmodifiable(_events);
  @override
  List<PreviewEvent> get homeEntries => events;
  @override
  bool get usesStoredCalendar => false;
  @override
  String get calendarZoneLabel => 'WIB · Asia/Jakarta';
  @override
  Future<List<PreviewEvent>> readCalendar(DateTime from, DateTime until) async {
    await load(PreviewSurface.calendar);
    return events;
  }

  @override
  Future<void> loadEarlierConfirmations() async {}
  @override
  Future<EventReplacement?> suggestReplacement(PreviewEvent event) async =>
      null;

  @override
  Future<PreviewEvent> approveReplacement(EventReplacement proposal) async =>
      throw UnsupportedError('Penjadwalan ulang memerlukan kalender lokal.');
  @override
  Future<List<PreviewEvent>> readTrashedActivities() async => events
      .where((event) => event.state == PreviewEventState.trashed)
      .toList();
  @override
  Future<List<ScheduleWarning>> activityWarnings(
    PreviewEvent event, {
    SeriesScope? scope,
  }) async => previewWarnings(this, event);

  @override
  Future<PreviewEvent> saveActivity(
    PreviewEvent event, {
    SeriesScope? scope,
    Set<ScheduleWarning> approved = const {},
  }) async {
    final warnings = previewWarnings(this, event);
    if (!approved.containsAll(warnings)) throw ActivityWarnings(warnings);
    return saveEvent(
      event.withState(event.state, scheduleWarning: warnings.firstOrNull),
      scope: scope,
    );
  }

  @override
  Future<PreviewEvent> changeActivity(
    PreviewEvent event,
    PreviewEventState state, {
    SeriesScope? scope,
  }) async {
    setEventState(event.id, state, scope: scope);
    return events.firstWhere((item) => item.id == event.id);
  }

  @override
  List<Category> get categories => List.unmodifiable(_categories);
  @override
  PreviewProfile? get profile => _profile;
  @override
  int get onboardingStep => _step;

  @override
  Future<void> load(PreviewSurface surface) async {
    await Future<void>.delayed(latency);
    if (_failOnce.remove(surface)) throw StateError('Kegagalan baca contoh');
  }

  @override
  Future<void> rememberStep(int step) async => _step = step;

  @override
  Future<void> saveProfile(PreviewProfile profile) async => _profile = profile;

  @override
  Future<Category> saveCategory(Category category) async {
    if (!isCategoryNameAvailable(
      category.name,
      _categories,
      editingId: category.id,
    )) {
      throw const FormatException('Nama kategori tidak tersedia.');
    }
    final index = _categories.indexWhere((item) => item.id == category.id);
    if (index == -1) {
      _categories.add(category);
    } else {
      _categories[index] = category;
    }
    return category;
  }

  @override
  Future<void> deleteCategory(
    Category category, {
    Category? replacement,
  }) async {
    if (replacement != null &&
        (replacement.id == category.id ||
            !_categories.any((item) => item.id == replacement.id))) {
      throw StaleRecord(replacement.id);
    }
    _categories.removeWhere((item) => item.id == category.id);
  }

  @override
  PreviewEvent saveEvent(PreviewEvent event, {SeriesScope? scope}) {
    final previous = _events.where((entry) => entry.id == event.id).firstOrNull;
    if (previous == null) {
      final id = 'preview-${_nextId++}';
      final newEvent = _copy(
        event,
        id: id,
        series: event.options.recurrence == 'Sekali' ? null : id,
      );
      _events.add(newEvent);
      return newEvent;
    }
    final replacement = _copy(
      event,
      series: scope == SeriesScope.following
          ? 'split-${previous.id}'
          : previous.series ?? event.series,
      state: scope == SeriesScope.occurrence
          ? PreviewEventState.exception
          : event.state,
    );
    for (var index = 0; index < _events.length; index++) {
      final item = _events[index];
      if (item.id == previous.id) {
        _events[index] = replacement;
      } else if (_matches(item, previous, scope)) {
        final offset = item.start.difference(previous.start);
        _events[index] = _copy(
          replacement,
          id: item.id,
          state: item.state,
          start: replacement.start.add(offset),
          end: replacement.end.add(offset),
          series: scope == SeriesScope.following
              ? 'split-${previous.id}'
              : item.series,
        );
      }
    }
    return replacement;
  }

  @override
  void setEventState(String id, PreviewEventState state, {SeriesScope? scope}) {
    final target = _events.firstWhere((event) => event.id == id);
    for (var index = 0; index < _events.length; index++) {
      final event = _events[index];
      if (event.id == id || _matches(event, target, scope)) {
        _events[index] = event.withState(state);
      }
    }
  }

  @override
  void reassignCategory(String previous, String next, {String? color}) {
    for (var index = 0; index < _events.length; index++) {
      final event = _events[index];
      if (event.options.category != previous) continue;
      _events[index] = _copy(
        event,
        options: event.options.withCategory(next, color: color),
      );
    }
  }

  bool _matches(PreviewEvent item, PreviewEvent target, SeriesScope? scope) =>
      target.series != null &&
      item.series == target.series &&
      (scope == SeriesScope.entire ||
          (scope == SeriesScope.following &&
              !item.start.isBefore(target.start)));

  PreviewEvent _copy(
    PreviewEvent event, {
    String? id,
    String? series,
    PreviewEventState? state,
    DateTime? start,
    DateTime? end,
    EventOptions? options,
  }) => PreviewEvent(
    id: id ?? event.id,
    title: event.title,
    start: start ?? event.start,
    end: end ?? event.end,
    kind: event.kind,
    state: state ?? event.state,
    options: options ?? event.options,
    series: series ?? event.series,
    warning: event.warning,
    recurrenceKey: event.recurrenceKey,
    supersedesId: event.supersedesId,
    isException: event.isException,
    obligationId: event.obligationId,
  );

  List<PreviewEvent> _samples(PreviewFixture fixture) {
    final tuesday = calendarDay;
    final monday = shiftDay(tuesday, -1);
    final friday = shiftDay(tuesday, 3);
    final sunday = shiftDay(tuesday, 5);
    DateTime at(DateTime date, int hour, [int minute = 0]) =>
        DateTime(date.year, date.month, date.day, hour, minute);
    const course = EventOptions(
      category: 'Kuliah',
      location: 'Gedung B · Ruang 204',
      recurrence: 'Mingguan · Selasa',
      reminders: ['30 menit sebelumnya'],
      description: 'Persiapan: bawa ringkasan rencana usaha kelompok.',
      link: 'https://example.com/materi',
      note: 'Diskusi rencana peluncuran toko.',
    );
    final entries = [
      PreviewEvent(
        id: 'workout',
        title: 'Workout Pagi',
        start: at(today, 7),
        end: at(today, 7, 30),
        kind: PreviewKind.routine,
        state: PreviewEventState.done,
        options: const EventOptions(category: 'Kesehatan'),
      ),
      PreviewEvent(
        id: 'review',
        title: 'Review brief tugas',
        start: at(today, 8, 30),
        end: at(today, 9, 15),
        state: PreviewEventState.pending,
        options: const EventOptions(category: 'Belajar'),
      ),
      PreviewEvent(
        id: 'notes',
        title: 'Catat materi',
        start: at(today, 10),
        end: at(today, 10, 25),
        state: PreviewEventState.done,
        options: const EventOptions(category: 'Kuliah'),
      ),
      PreviewEvent(
        id: 'walk',
        title: 'Jalan sore',
        start: at(today, 16),
        end: at(today, 16, 30),
        kind: PreviewKind.routine,
        state: PreviewEventState.done,
        options: const EventOptions(category: 'Kesehatan'),
      ),
      PreviewEvent(
        id: 'meeting',
        title: 'Rapat Kelompok',
        start: at(today, 19),
        end: at(today, 20),
        options: const EventOptions(
          category: 'Kegiatan',
          location: 'Ruang diskusi',
        ),
        warning: fixture == PreviewFixture.conflict
            ? ScheduleWarning.overlap
            : null,
      ),
      PreviewEvent(
        id: 'course',
        title: 'Kuliah E-Commerce dan Kewirausahaan',
        start: at(tuesday, 13),
        end: at(tuesday, 16),
        options: course,
        series: 'course-series',
      ),
      PreviewEvent(
        id: 'course-next',
        title: 'Kuliah E-Commerce dan Kewirausahaan',
        start: at(shiftDay(tuesday, 7), 13),
        end: at(shiftDay(tuesday, 7), 16),
        options: course,
        series: 'course-series',
      ),
      PreviewEvent(
        id: 'fair',
        title: 'Pekan Kewirausahaan',
        start: tuesday,
        end: shiftDay(tuesday, 1),
        options: const EventOptions(
          availability: DayAvailability.free,
          category: 'Kampus',
        ),
      ),
      PreviewEvent(
        id: 'campus',
        title: 'Pameran Kampus',
        start: friday,
        end: shiftDay(friday, 1),
        options: const EventOptions(
          availability: DayAvailability.busy,
          category: 'Kampus',
        ),
      ),
      PreviewEvent(
        id: 'study',
        title: 'Belajar Flutter',
        start: at(tuesday, 17),
        end: at(tuesday, 17, 30),
        kind: PreviewKind.routine,
        options: const EventOptions(category: 'Rutinitas'),
      ),
      PreviewEvent(
        id: 'session1',
        title: 'Sesi 1',
        start: at(shiftDay(tuesday, 1), 15),
        end: at(shiftDay(tuesday, 1), 16),
        kind: PreviewKind.session,
        options: const EventOptions(category: 'Sesi kerja'),
      ),
      PreviewEvent(
        id: 'session2',
        title: 'Sesi 2',
        start: at(shiftDay(tuesday, 2), 17),
        end: at(shiftDay(tuesday, 2), 18),
        kind: PreviewKind.session,
        options: const EventOptions(category: 'Sesi kerja'),
      ),
      PreviewEvent(
        id: 'deadline',
        title: 'Tenggat laporan',
        start: at(shiftDay(tuesday, 2), 17),
        end: at(shiftDay(tuesday, 2), 17, 1),
        kind: PreviewKind.deadline,
        options: const EventOptions(zone: 'WITA (UTC+8) · Zona asal'),
      ),
      if (fixture == PreviewFixture.crossMidnight)
        PreviewEvent(
          id: 'overnight',
          title: 'Sesi persiapan',
          start: at(sunday, 22, 30),
          end: at(shiftDay(sunday, 1), 1),
          options: const EventOptions(category: 'Belajar'),
          state: PreviewEventState.exception,
        ),
      if (fixture == PreviewFixture.buffer)
        PreviewEvent(
          id: 'buffer-sample',
          title: 'Persiapan materi',
          start: at(monday, 11),
          end: at(monday, 12),
          options: const EventOptions(after: 15, category: 'Belajar'),
          warning: ScheduleWarning.buffer,
        ),
      if (fixture == PreviewFixture.active)
        PreviewEvent(
          id: 'active',
          title: 'Rapat sedang berlangsung',
          start: at(today, 12),
          end: at(today, 13),
          state: PreviewEventState.active,
        ),
      if (fixture == PreviewFixture.outsideHours)
        PreviewEvent(
          id: 'outside',
          title: 'Diskusi malam',
          start: at(tuesday, 22),
          end: at(tuesday, 23),
          warning: ScheduleWarning.activeHours,
        ),
      if (fixture == PreviewFixture.conflict)
        PreviewEvent(
          id: 'overlap',
          title: 'Belajar Flutter',
          start: at(today, 19),
          end: at(today, 19, 30),
          kind: PreviewKind.session,
          warning: ScheduleWarning.overlap,
        ),
      if (fixture == PreviewFixture.conflict)
        PreviewEvent(
          id: 'course-overlap',
          title: 'Diskusi tim',
          start: at(tuesday, 14),
          end: at(tuesday, 15),
          warning: ScheduleWarning.overlap,
        ),
      if (fixture == PreviewFixture.crossMidnight)
        PreviewEvent(
          id: 'cross-demo',
          title: 'Mulai kemarin · Selesai 01.00',
          start: at(shiftDay(today, -1), 22, 30),
          end: at(today, 1),
          options: const EventOptions(category: 'Belajar'),
        ),
      if (fixture == PreviewFixture.overdue)
        PreviewEvent(
          id: 'overdue',
          title: 'Unggah ringkasan',
          start: at(shiftDay(today, -1), 23, 59),
          end: at(today, 0),
          kind: PreviewKind.deadline,
          state: PreviewEventState.pending,
        ),
    ];
    return [
      for (final entry in entries)
        if (fixture == PreviewFixture.allDone && dateOnly(entry.start) == today)
          entry.withState(PreviewEventState.done)
        else
          entry,
    ];
  }
}
