import 'package:routina/domain/planner_records.dart';

abstract interface class RecordReader<T extends PlannerRecord> {
  Future<T?> find(String id, {bool includeDeleted = false});
  Future<List<T>> all({bool includeDeleted = false});
}

abstract interface class RecordRepository<T extends PlannerRecord>
    implements RecordReader<T> {
  /// Inserts with revision zero or updates the exact stored revision.
  Future<T> save(T record);
}

abstract interface class PlannerData {
  RecordRepository<Profile> get profiles;
  RecordRepository<Category> get categories;
  RecordRepository<EventSeries> get eventSeries;
  RecordRepository<EventOccurrence> get events;
  RecordRepository<Task> get tasks;
  RecordRepository<Subtask> get subtasks;
  RecordRepository<WorkSession> get workSessions;
  RecordRepository<Routine> get routines;
  RecordRepository<RoutineOccurrence> get routineOccurrences;
  RecordRepository<TimeLog> get timeLogs;
  RecordRepository<ReminderRule> get reminderRules;
  RecordReader<StatusHistory> get statusHistory;
  RecordReader<TrashEntry> get trashEntries;
  Future<List<RoutineTimer>> routineTimers();
  Future<void> saveRoutineTimer(RoutineTimer timer);
  Future<void> removeRoutineTimer(String occurrenceId);
  Future<List<RoutineGoalEvent>> routineGoalEvents();
  Future<void> saveRoutineGoalEvent(RoutineGoalEvent event);
  Future<void> removeRoutineGoalEvent(String occurrenceId);
  Future<Map<String, ReminderProgress>> reminderProgress();
  Future<void> saveReminderProgress(Map<String, ReminderProgress> progress);

  /// Calendar intervals overlap a half-open range. Deadlines are points.
  Future<List<CalendarEntry>> calendar(DateTime from, DateTime until);
  Future<TrashEntry> softDelete(RecordRef ref);
  Future<void> archiveEventRange(
    EventSeries series,
    LocalDate cut,
    List<String> occurrences,
  );
  Future<TrashEntry> deleteCategory(String id, {String? replacementId});
  Future<Set<String>> restore(String trashEntryId, {int? expectedRevision});
  Future<void> permanentlyDelete(
    String trashEntryId, {
    required int expectedRevision,
  });
}

bool isCategoryNameAvailable(
  String name,
  Iterable<Category> categories, {
  String? editingId,
}) {
  final normalized = name.trim().toLowerCase();
  return normalized.isNotEmpty &&
      normalized != 'tanpa kategori' &&
      !categories.any(
        (category) =>
            category.id != editingId &&
            category.name.trim().toLowerCase() == normalized,
      );
}

abstract interface class PlannerStore implements PlannerData {
  /// Called after a successful mutation, outside the SQLite transaction.
  set afterCommit(Future<void> Function()? callback);

  /// Use the supplied data access for every operation inside the transaction.
  Future<T> transaction<T>(Future<T> Function(PlannerData data) action);
  Future<void> close();
}

class StaleRecord implements Exception {
  const StaleRecord(this.id);
  final String id;
  @override
  String toString() => 'Record is unavailable or revision is stale: $id';
}

enum TrashProblem implements Exception {
  expired,
  alreadyArchived,
  unavailableParent,
  seriesChanged,
  referenced,
  invalidSchedule,
}
