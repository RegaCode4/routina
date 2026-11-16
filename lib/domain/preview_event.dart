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
  bool get isValid => start < end;
}

class PreviewProfile {
  PreviewProfile({
    this.name = '',
    Map<int, ActiveInterval> activeHours = const {},
    this.study = 'Sore',
    this.workout = 'Pagi',
    this.sundayFirst = false,
    this.notifications = true,
  }) : activeHours = Map.unmodifiable(activeHours);

  final String name;
  final Map<int, ActiveInterval> activeHours;
  final String study;
  final String workout;
  final bool sundayFirst;
  final bool notifications;
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
