import 'package:routina/application/calendar_zones.dart';
import 'package:routina/application/routine_workspace.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/preview_event.dart';

enum AgendaOrder {
  chronological('Waktu terawal'),
  reverseChronological('Waktu terakhir');

  const AgendaOrder(this.label);
  final String label;

  int compare(DateTime? left, DateTime? right) {
    if (left == null) return right == null ? 0 : 1;
    if (right == null) return -1;
    return this == chronological
        ? left.compareTo(right)
        : right.compareTo(left);
  }
}

enum CalendarStatus {
  upcoming('Belum dimulai'),
  active('Berlangsung'),
  pending('Menunggu konfirmasi'),
  completed('Selesai'),
  postponed('Ditunda'),
  skipped('Dilewatkan'),
  overdue('Overdue');

  const CalendarStatus(this.label);
  final String label;

  static CalendarStatus? of(PreviewEvent entry) => switch (entry.state) {
    PreviewEventState.upcoming => upcoming,
    PreviewEventState.active => active,
    PreviewEventState.pending =>
      entry.kind == PreviewKind.deadline ? overdue : pending,
    PreviewEventState.done => completed,
    PreviewEventState.postponed => postponed,
    PreviewEventState.skipped => skipped,
    PreviewEventState.exception || PreviewEventState.trashed => null,
  };
}

List<PreviewEvent> searchCalendar(
  Iterable<PreviewEvent> entries, {
  required String title,
  String? categoryId,
  CalendarStatus? status,
  DateTime? day,
  ({DateTime from, DateTime until})? period,
  AgendaOrder order = AgendaOrder.chronological,
}) {
  final query = title.trim().toLowerCase();
  final matches = entries.where((entry) {
    return entry.state != PreviewEventState.trashed &&
        entry.title.toLowerCase().contains(query) &&
        _inCategory(categoryId, entry.categoryId) &&
        (status == null || CalendarStatus.of(entry) == status) &&
        (day == null || appearsOn(entry, day)) &&
        (period == null ||
            (civilTime(entry.start).isBefore(civilTime(period.until)) &&
                civilTime(entry.end).isAfter(civilTime(period.from))));
  }).toList();
  matches.sort((left, right) {
    final byTime = order.compare(
      left.startInstant ?? civilTime(left.start),
      right.startInstant ?? civilTime(right.start),
    );
    return byTime == 0 ? left.id.compareTo(right.id) : byTime;
  });
  return matches;
}

List<RoutineView> searchRoutines(
  Iterable<RoutineView> rows, {
  required String title,
  required CalendarZones zones,
  required DateTime now,
  String? categoryId,
  RoutineStatus? status,
  AgendaOrder? order,
}) {
  final query = title.trim().toLowerCase();
  final matches = rows.where((row) {
    return row.routine.title.toLowerCase().contains(query) &&
        _inCategory(categoryId, row.routine.categoryId) &&
        (status == null || row.statusAt(now) == status);
  }).toList();
  if (order == null) return matches;
  DateTime? scheduledTime(RoutineView row) =>
      switch (row.occurrence?.schedule?.start) {
        final start? => zones.effectiveTime(start),
        null => null,
      };
  final times = {for (final row in matches) row: scheduledTime(row)};
  matches.sort((left, right) {
    final byTime = order.compare(times[left], times[right]);
    if (byTime != 0) return byTime;
    final byTitle = left.routine.title.toLowerCase().compareTo(
      right.routine.title.toLowerCase(),
    );
    return byTitle == 0 ? left.routine.id.compareTo(right.routine.id) : byTitle;
  });
  return matches;
}

// null selects every category, while an empty ID selects uncategorized rows.
bool _inCategory(String? filter, String? id) =>
    filter == null || filter == (id ?? '');
