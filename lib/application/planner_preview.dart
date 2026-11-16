import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';

enum PreviewSurface { startup, home, calendar }

const previewCategoryPalette = {
  'Biru': 0xFF537BFF,
  'Kuning': 0xFFFFE65B,
  'Koral': 0xFFFF8C82,
  'Hijau': 0xFFD5ECBE,
};

abstract interface class PlannerPreviewRepository {
  DateTime get today;
  DateTime get calendarDay;
  PreviewProfile? get profile;
  int get onboardingStep;
  List<PreviewEvent> get events;
  List<PreviewEvent> get homeEntries;
  List<Category> get categories;
  bool get usesStoredCalendar;
  String get calendarZoneLabel;

  Future<void> load(PreviewSurface surface);
  Future<void> rememberStep(int step);
  Future<void> saveProfile(PreviewProfile profile);
  Future<Category> saveCategory(Category category);
  Future<void> deleteCategory(Category category, {Category? replacement});
  Future<List<PreviewEvent>> readCalendar(DateTime from, DateTime until);
  Future<void> loadEarlierConfirmations();
  Future<List<ScheduleWarning>> activityWarnings(
    PreviewEvent event, {
    SeriesScope? scope,
  });
  Future<PreviewEvent> saveActivity(
    PreviewEvent event, {
    SeriesScope? scope,
    Set<ScheduleWarning> approved = const {},
  });
  Future<PreviewEvent> changeActivity(
    PreviewEvent event,
    PreviewEventState state, {
    SeriesScope? scope,
  });
  Future<DateTime?> suggestReplacement(PreviewEvent event);
  Future<List<PreviewEvent>> readTrashedActivities();
  PreviewEvent saveEvent(PreviewEvent event, {SeriesScope? scope});
  void setEventState(String id, PreviewEventState state, {SeriesScope? scope});
  void reassignCategory(String previous, String next, {String? color});
}

class ActivityWarnings implements Exception {
  const ActivityWarnings(this.warnings);
  final List<ScheduleWarning> warnings;
}

List<ScheduleWarning> previewWarnings(
  PlannerPreviewRepository repository,
  PreviewEvent proposed,
) {
  if (proposed.options.availability == DayAvailability.free) return [];
  final warnings = <ScheduleWarning>{};
  for (final existing in repository.events) {
    if (existing.id == proposed.id ||
        existing.state == PreviewEventState.trashed ||
        existing.kind == PreviewKind.deadline ||
        existing.options.availability == DayAvailability.free) {
      continue;
    }
    if (proposed.start.isBefore(existing.end) &&
        proposed.end.isAfter(existing.start)) {
      warnings.add(ScheduleWarning.overlap);
    } else if (proposed.start
            .subtract(
              Duration(
                minutes: proposed.options.before + existing.options.after,
              ),
            )
            .isBefore(existing.end) &&
        proposed.end
            .add(
              Duration(
                minutes: proposed.options.after + existing.options.before,
              ),
            )
            .isAfter(existing.start)) {
      warnings.add(ScheduleWarning.buffer);
    }
  }
  if (!proposed.allDay) {
    final interval = repository.profile?.activeHours[proposed.start.weekday];
    if (interval != null &&
        (dateOnly(proposed.start) != dateOnly(proposed.end) ||
            minutesAt(proposed.start) < interval.start ||
            minutesAt(proposed.end) > interval.end)) {
      warnings.add(ScheduleWarning.activeHours);
    }
  }
  return ScheduleWarning.values.where(warnings.contains).toList();
}

class DailyPreview {
  DailyPreview(List<PreviewEvent> entries, DateTime day)
    : agenda =
          entries
              .where(
                (entry) =>
                    entry.state != PreviewEventState.trashed &&
                    appearsOn(entry, day),
              )
              .toList()
            ..sort((a, b) => a.start.compareTo(b.start)) {
    final obligations = agenda
        .where(
          (entry) =>
              entry.kind != PreviewKind.session &&
              dateOnly(entry.start) == dateOnly(day),
        )
        .toList();
    total = obligations
        .map((entry) => entry.obligationId ?? entry.id)
        .toSet()
        .length;
    completed = obligations
        .where((entry) => entry.state == PreviewEventState.done)
        .map((entry) => entry.obligationId ?? entry.id)
        .toSet()
        .length;
    final upcoming =
        entries
            .where(
              (entry) =>
                  entry.kind == PreviewKind.activity &&
                  entry.state == PreviewEventState.upcoming &&
                  !civilTime(entry.start).isBefore(civilDate(day)),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    next = upcoming.firstOrNull;
  }

  final List<PreviewEvent> agenda;
  late final int total;
  late final int completed;
  late final PreviewEvent? next;
  int get open => total - completed;
  double? get progress => total == 0 ? null : completed / total;
}
