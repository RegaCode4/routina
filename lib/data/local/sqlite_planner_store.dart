import 'dart:convert';
import 'dart:io';

import 'package:routina/data/local/planner_schema.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';
import 'package:sqflite/sqflite.dart';

part 'planner_mapping.dart';

class SqlitePlannerStore extends _SqliteData implements PlannerStore {
  SqlitePlannerStore._(Database super.db, super.now);

  static Future<SqlitePlannerStore> open({
    DatabaseFactory? factory,
    String? path,
    DateTime Function()? now,
  }) async {
    final selected = factory ?? databaseFactory;
    final db = await selected.openDatabase(
      path ??
          '${await selected.getDatabasesPath()}${Platform.pathSeparator}routina.db',
      options: OpenDatabaseOptions(
        version: plannerSchemaVersion,
        // The owner controls the lifetime, including closing before reopening.
        singleInstance: false,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          final enabled = Sqflite.firstIntValue(
            await db.rawQuery('PRAGMA foreign_keys'),
          );
          if (enabled != 1) {
            throw StateError('SQLite foreign keys are unavailable');
          }
        },
        onCreate: (db, version) async {
          await createPlannerSchemaV1(db);
          await migratePlannerSchema(db, 1, version);
        },
        onUpgrade: migratePlannerSchema,
        onDowngrade: (_, from, to) {
          throw StateError(
            'Database version $from is newer than supported version $to',
          );
        },
      ),
    );
    return SqlitePlannerStore._(db, now ?? DateTime.now);
  }

  Database get _database => _executor as Database;

  @override
  Future<T> transaction<T>(Future<T> Function(PlannerData data) action) {
    return _database.transaction((txn) async {
      final data = _SqliteData(txn, _now);
      final result = await action(data);
      if (data._writeFailure case (final error, final stack)) {
        Error.throwWithStackTrace(error, stack);
      }
      return result;
    });
  }

  @override
  Future<void> close() => _database.close();
}

class _SqliteData implements PlannerData {
  _SqliteData(this._executor, this._now);

  final DatabaseExecutor _executor;
  final DateTime Function() _now;
  (Object, StackTrace)? _writeFailure;

  Future<T> _write<T>(Future<T> Function(DatabaseExecutor) action) async {
    final executor = _executor;
    if (executor is Database) return executor.transaction(action);
    try {
      return await action(executor);
    } catch (error, stack) {
      // A failed sequence can have written earlier statements in this scope.
      _writeFailure ??= (error, stack);
      rethrow;
    }
  }

  @override
  late final RecordRepository<Profile> profiles = _SqliteRepository(
    this,
    _profile,
  );
  @override
  late final RecordRepository<Category> categories = _SqliteRepository(
    this,
    _category,
  );
  @override
  late final RecordRepository<EventSeries> eventSeries = _SqliteRepository(
    this,
    _eventSeries,
  );
  @override
  late final RecordRepository<EventOccurrence> events = _SqliteRepository(
    this,
    _event,
  );
  @override
  late final RecordRepository<Task> tasks = _SqliteRepository(this, _task);
  @override
  late final RecordRepository<Subtask> subtasks = _SqliteRepository(
    this,
    _subtask,
  );
  @override
  late final RecordRepository<WorkSession> workSessions = _SqliteRepository(
    this,
    _workSession,
  );
  @override
  late final RecordRepository<Routine> routines = _SqliteRepository(
    this,
    _routine,
  );
  @override
  late final RecordRepository<RoutineOccurrence> routineOccurrences =
      _SqliteRepository(this, _routineOccurrence);
  @override
  late final RecordRepository<TimeLog> timeLogs = _SqliteRepository(
    this,
    _timeLog,
  );
  @override
  late final RecordRepository<ReminderRule> reminderRules = _SqliteRepository(
    this,
    _reminder,
  );
  @override
  late final RecordReader<StatusHistory> statusHistory = _SqliteRepository(
    this,
    _statusHistory,
  );
  @override
  late final RecordReader<TrashEntry> trashEntries = _SqliteRepository(
    this,
    _trash,
  );

  @override
  Future<List<CalendarEntry>> calendar(DateTime from, DateTime until) async {
    if (!from.isBefore(until)) throw ArgumentError('Invalid calendar range');
    final rows = await _executor.rawQuery(_calendarQuery, [
      from.microsecondsSinceEpoch,
      until.microsecondsSinceEpoch,
    ]);
    return rows
        .map(
          (row) => CalendarEntry(
            kind: CalendarEntryKind.values.byName(row.text('entry_kind')),
            id: row.text('id'),
            obligationId: row.text('obligation_id'),
            title: row.text('title'),
            start: row.instant('start_us'),
            end: row.optionalInstant('end_us'),
            status: row.status,
            categoryId: row.optionalText('category_id'),
            availability: row['availability'] == null
                ? null
                : EventAvailability.values.byName(row.text('availability')),
          ),
        )
        .toList();
  }

  @override
  Future<TrashEntry> softDelete(RecordRef ref) => _write((db) async {
    final target = await _metadata(db, ref);
    if (target == null) throw StaleRecord(ref.id);
    final entry = await _tombstone(db, ref.id);
    if (entry != null && entry.restoredAt == null) return entry;
    if (ref.kind == RecordKind.category) {
      for (final table in [
        'event_series',
        'event_occurrences',
        'tasks',
        'routines',
      ]) {
        final used = await db.rawQuery(
          '''
          SELECT 1 FROM $table WHERE category_id = ? AND id NOT IN (SELECT id FROM hidden_records)
          LIMIT 1
        ''',
          [ref.id],
        );
        if (used.isNotEmpty) {
          throw StateError(
            'Reassign active category references before deletion',
          );
        }
      }
    }
    final now = _modifiedAt(target, _now());
    final result = await _save(
      db,
      _trash,
      TrashEntry(
        entry?.metadata ?? RecordMetadata.create(),
        target: ref,
        deletedAt: now,
      ),
      now,
    );
    await _updateMetadata(db, target, now);
    return result;
  });

  @override
  Future<void> restore(String trashEntryId) => _write((db) async {
    final row = await _find(db, _trash, trashEntryId, includeDeleted: true);
    if (row == null) throw StaleRecord(trashEntryId);
    final entry = _decode(_trash, row);
    if (entry.restoredAt != null) return;
    final target = await _metadata(db, entry.target);
    if (target == null) throw StaleRecord(entry.target.id);
    final now = _modifiedAt(target, _now());
    await _save(
      db,
      _trash,
      TrashEntry(
        entry.metadata,
        target: entry.target,
        deletedAt: entry.deletedAt,
        restoredAt: now,
      ),
      now,
    );
    await _updateMetadata(db, target, now);
  });

  Future<TrashEntry?> _tombstone(DatabaseExecutor db, String targetId) async {
    final rows = await db.rawQuery(
      '${_select(_trash)} WHERE item.target_id = ?',
      [targetId],
    );
    return rows.isEmpty ? null : _decode(_trash, rows.single);
  }
}

class _SqliteRepository<T extends PlannerRecord>
    implements RecordRepository<T> {
  _SqliteRepository(this._data, this._table);
  final _SqliteData _data;
  final _Table<T> _table;

  @override
  Future<T?> find(String id, {bool includeDeleted = false}) async {
    final row = await _find(
      _data._executor,
      _table,
      id,
      includeDeleted: includeDeleted,
    );
    return row == null ? null : _decode(_table, row);
  }

  @override
  Future<List<T>> all({bool includeDeleted = false}) async {
    final filter = includeDeleted
        ? ''
        : 'WHERE item.id NOT IN (SELECT id FROM hidden_records)';
    final rows = await _data._executor.rawQuery(
      '${_select(_table)} $filter ORDER BY r.created_at_us, item.id',
    );
    return rows.map((row) => _decode(_table, row)).toList();
  }

  @override
  Future<T> save(T record) =>
      _data._write((db) => _save(db, _table, record, _data._now()));
}

String _select<T extends PlannerRecord>(_Table<T> table) =>
    '''
  SELECT item.*, r.revision, r.created_at_us, r.updated_at_us, r.parent_id
  FROM ${table.name} item INNER JOIN records r ON r.id = item.id
''';

Future<_Row?> _find<T extends PlannerRecord>(
  DatabaseExecutor db,
  _Table<T> table,
  String id, {
  required bool includeDeleted,
}) async {
  final filter = includeDeleted
      ? ''
      : 'AND item.id NOT IN (SELECT id FROM hidden_records)';
  final rows = await db.rawQuery(
    '${_select(table)} WHERE item.id = ? $filter',
    [id],
  );
  return rows.firstOrNull;
}

RecordMetadata _readMetadata(_Row row) => RecordMetadata(
  id: row.text('id'),
  revision: row.number('revision'),
  createdAt: row.instant('created_at_us'),
  updatedAt: row.instant('updated_at_us'),
);

T _decode<T extends PlannerRecord>(_Table<T> table, _Row row) =>
    table.decode(_readMetadata(row), row);

Future<RecordMetadata?> _metadata(DatabaseExecutor db, RecordRef ref) async {
  final rows = await db.query(
    'records',
    where: 'id = ? AND kind = ?',
    whereArgs: [ref.id, ref.kind.name],
  );
  return rows.isEmpty ? null : _readMetadata(rows.single);
}

DateTime _modifiedAt(RecordMetadata metadata, DateTime now) {
  final previous = metadata.updatedAt;
  return previous != null && previous.isAfter(now) ? previous : now.toUtc();
}

Future<void> _updateMetadata(
  DatabaseExecutor db,
  RecordMetadata stored,
  DateTime now, {
  String? parent,
  bool changeParent = false,
}) async {
  final updated = await db.update(
    'records',
    {
      'revision': stored.revision + 1,
      'updated_at_us': _instant(now),
      if (changeParent) 'parent_id': parent,
    },
    where: 'id = ? AND revision = ?',
    whereArgs: [stored.id, stored.revision],
  );
  if (updated != 1) throw StaleRecord(stored.id);
}

Future<void> _requireActive(DatabaseExecutor db, String id) async {
  final rows = await db.rawQuery(
    'SELECT id FROM records WHERE id = ? AND id NOT IN (SELECT id FROM hidden_records)',
    [id],
  );
  if (rows.isEmpty) throw StaleRecord(id);
}

Future<T> _save<T extends PlannerRecord>(
  DatabaseExecutor db,
  _Table<T> table,
  T value,
  DateTime clock,
) async {
  final id = value.id;
  final before = await _find(db, table, id, includeDeleted: true);
  final columns = table.encode(value);
  final parent = table.parent?.call(value);
  final timestamp = before == null
      ? clock.toUtc()
      : _modifiedAt(_readMetadata(before), clock);
  for (final referenced in [
    parent,
    columns['category_id'] as String?,
    columns['routine_occurrence_id'] as String?,
  ].nonNulls) {
    await _requireActive(db, referenced);
  }

  if (before == null) {
    if (value.metadata.revision != 0) throw StaleRecord(id);
    await db.insert('records', {
      'id': id,
      'kind': table.kind.name,
      'parent_id': parent,
      'revision': 1,
      'created_at_us': _instant(timestamp),
      'updated_at_us': _instant(timestamp),
    });
    await db.insert(table.name, {'id': id, ...columns});
  } else {
    if (table.kind == RecordKind.timeLog ||
        table.kind == RecordKind.statusHistory) {
      throw StateError('Historical records are append-only');
    }
    final stored = _readMetadata(before);
    if (value.metadata.revision != stored.revision) throw StaleRecord(id);
    await _requireActive(db, id);
    if (table.kind == RecordKind.eventOccurrence &&
        before['status'] != ActivityStatus.planned.name &&
        (before['series_id'] != columns['series_id'] ||
            before['recurrence_key'] != columns['recurrence_key'])) {
      throw StateError('Historical occurrence identity is immutable');
    }
    if (table.kind == RecordKind.workSession &&
            before['task_id'] != columns['task_id'] ||
        table.kind == RecordKind.routineOccurrence &&
            (before['routine_id'] != columns['routine_id'] ||
                before['local_day'] != columns['local_day'])) {
      throw StateError('Occurrence parent identity is immutable');
    }
    await _updateMetadata(
      db,
      stored,
      timestamp,
      parent: parent,
      changeParent: true,
    );
    await db.update(table.name, columns, where: 'id = ?', whereArgs: [id]);

    if (before['status'] != null && before['status'] != columns['status']) {
      RecordRef? replacement;
      if (table.kind == RecordKind.eventOccurrence ||
          table.kind == RecordKind.workSession) {
        final rows = await db.query(
          table.name,
          columns: ['id'],
          where: 'supersedes_id = ?',
          whereArgs: [id],
          limit: 2,
        );
        if (rows.singleOrNull case final row?) {
          replacement = (kind: table.kind, id: row.text('id'));
        }
      }
      await _save(
        db,
        _statusHistory,
        StatusHistory(
          RecordMetadata.create(),
          target: (kind: table.kind, id: id),
          previous: before.status,
          status: ActivityStatus.values.byName(columns['status']! as String),
          changedAt: timestamp,
          replacement: replacement,
        ),
        timestamp,
      );
    }
  }
  return _decode(table, (await _find(db, table, id, includeDeleted: true))!);
}

const _calendarQuery = '''
WITH range(from_us, until_us) AS (VALUES (?, ?)),
hidden AS (SELECT id FROM hidden_records)
SELECT * FROM (
  SELECT 'event' entry_kind, e.id, COALESCE(e.routine_occurrence_id, e.id) obligation_id,
    e.title, e.start_us, e.end_us, e.status, COALESCE(e.category_id, s.category_id) category_id, e.availability
  FROM event_occurrences e
  JOIN range ON e.end_us > range.from_us AND e.start_us < range.until_us
  LEFT JOIN event_series s ON s.id = e.series_id
  WHERE e.id NOT IN (SELECT id FROM hidden)
    AND (e.routine_occurrence_id IS NULL OR e.routine_occurrence_id NOT IN (SELECT id FROM hidden))
  UNION ALL
  SELECT 'deadline', t.id, t.id, t.title, t.deadline_us, NULL, t.status, t.category_id, NULL
  FROM tasks t JOIN range ON t.deadline_us >= range.from_us AND t.deadline_us < range.until_us
  WHERE t.id NOT IN (SELECT id FROM hidden)
  UNION ALL
  SELECT 'workSession', w.id, t.id, t.title, w.start_us, w.end_us, w.status, t.category_id, NULL
  FROM work_sessions w JOIN range ON w.end_us > range.from_us AND w.start_us < range.until_us
  JOIN tasks t ON t.id = w.task_id
  WHERE w.id NOT IN (SELECT id FROM hidden)
  UNION ALL
  SELECT 'routine', r.id, r.id, p.title, r.start_us, r.end_us, r.status, p.category_id, NULL
  FROM routine_occurrences r JOIN range ON r.end_us > range.from_us AND r.start_us < range.until_us
  JOIN routines p ON p.id = r.routine_id
  WHERE r.id NOT IN (SELECT id FROM hidden)
)
ORDER BY start_us, entry_kind, id
''';
