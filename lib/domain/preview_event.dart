import 'package:routina/domain/planner_records.dart';

enum PreviewKind { activity, deadline, routine, session }

enum PreviewEventState {
  upcoming,
  active,
  pending,
  done,
  postponed,
  skipped,
  trashed,
  exception,
}

enum ScheduleWarning { overlap, buffer, activeHours }

enum DayAvailability { timed, busy, free }

enum SeriesScope {
  occurrence('Hanya kejadian ini'),
  following('Ini dan berikutnya'),
  entire('Seluruh rangkaian');

  const SeriesScope(this.label);
  final String label;
}

class ActiveInterval {
  const ActiveInterval(this.start, this.end);
  final int start;
  final int end;
  bool get isValid => start >= 0 && start < end && end <= 1440;
}

class PreviewProfile {
  PreviewProfile({
    this.name = '',
    Map<int, ActiveInterval> activeHours = const {},
    this.study = 'Sore',
    this.workout = 'Pagi',
    this.other = '',
    this.sundayFirst = false,
    this.notifications = true,
    this.defaultBuffer,
    this.quietHours,
    this.preferences = const PlannerPreferences(),
    Map<String, String> categoryTimes = const {},
  }) : activeHours = Map.unmodifiable(activeHours),
       categoryTimes = Map.unmodifiable(categoryTimes);

  final String name;
  final Map<int, ActiveInterval> activeHours;
  final String study;
  final String workout;
  final String other;
  final Map<String, String> categoryTimes;
  final bool sundayFirst;
  final bool notifications;
  final Duration? defaultBuffer;
  final DailyHours? quietHours;
  final PlannerPreferences preferences;

  PreviewProfile copyWith({
    String? name,
    Map<int, ActiveInterval>? activeHours,
    String? study,
    String? workout,
    String? other,
    Map<String, String>? categoryTimes,
    bool? sundayFirst,
    bool? notifications,
    Duration? defaultBuffer,
    DailyHours? quietHours,
    PlannerPreferences? preferences,
  }) => PreviewProfile(
    name: name ?? this.name,
    activeHours: activeHours ?? this.activeHours,
    study: study ?? this.study,
    workout: workout ?? this.workout,
    other: other ?? this.other,
    categoryTimes: categoryTimes ?? this.categoryTimes,
    sundayFirst: sundayFirst ?? this.sundayFirst,
    notifications: notifications ?? this.notifications,
    defaultBuffer: defaultBuffer ?? this.defaultBuffer,
    quietHours: quietHours ?? this.quietHours,
    preferences: preferences ?? this.preferences,
  );
}

class EventOptions {
  const EventOptions({
    this.availability = DayAvailability.timed,
    this.category = '',
    this.categoryColor = 'Biru',
    this.recurrence = 'Sekali',
    this.reminders = const [],
    this.description = '',
    this.location = '',
    this.note = '',
    this.link = '',
    this.zone = 'Pertahankan zona asal (WIB)',
    this.before = 0,
    this.after = 0,
  });

  final DayAvailability availability;
  final String category;
  final String categoryColor;
  final String recurrence;
  final List<String> reminders;
  final String description;
  final String location;
  final String note;
  final String link;
  final String zone;
  final int before;
  final int after;

  EventOptions withCategory(String next, {String? color}) => EventOptions(
    availability: availability,
    category: next,
    categoryColor: color ?? categoryColor,
    recurrence: recurrence,
    reminders: reminders,
    description: description,
    location: location,
    note: note,
    link: link,
    zone: zone,
    before: before,
    after: after,
  );
}

class PreviewEvent {
  const PreviewEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.kind = PreviewKind.activity,
    this.state = PreviewEventState.upcoming,
    this.options = const EventOptions(),
    this.series,
    this.warning,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final PreviewKind kind;
  final PreviewEventState state;
  final EventOptions options;
  final String? series;
  final ScheduleWarning? warning;

  bool get allDay => options.availability != DayAvailability.timed;

  PreviewEvent withState(PreviewEventState state) => PreviewEvent(
    id: id,
    title: title,
    start: start,
    end: end,
    kind: kind,
    state: state,
    options: options,
    series: series,
    warning: warning,
  );
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime shiftDay(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);

int minutesAt(DateTime value) => value.hour * 60 + value.minute;

bool appearsOn(PreviewEvent entry, DateTime date) =>
    entry.start.isBefore(shiftDay(date, 1)) &&
    entry.end.isAfter(dateOnly(date));
