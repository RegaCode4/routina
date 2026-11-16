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

  /// Calendar intervals overlap a half-open range. Deadlines are points.
  Future<List<CalendarEntry>> calendar(DateTime from, DateTime until);
  Future<TrashEntry> softDelete(RecordRef ref);
  Future<void> restore(String trashEntryId);
}

abstract interface class PlannerStore implements PlannerData {
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
