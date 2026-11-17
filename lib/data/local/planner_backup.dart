part of 'sqlite_planner_store.dart';

// Dependencies between tables point to earlier tables. Self-references
// within a table are ordered separately so RESTRICT stays enabled.
final _backupTables = <RecordKind, _Table<PlannerRecord>>{
  RecordKind.profile: _profile,
  RecordKind.category: _category,
  RecordKind.eventSeries: _eventSeries,
  RecordKind.task: _task,
  RecordKind.routine: _routine,
  RecordKind.routineOccurrence: _routineOccurrence,
  RecordKind.eventOccurrence: _event,
  RecordKind.workSession: _workSession,
  RecordKind.subtask: _subtask,
  RecordKind.timeLog: _timeLog,
  RecordKind.reminderRule: _reminder,
  RecordKind.statusHistory: _statusHistory,
  RecordKind.trashEntry: _trash,
};

const _timers = 'routine_timers';
const _goals = 'routine_goal_events';
const _selfReference = {
  'records': 'parent_id',
  'event_series': 'split_from_id',
  'event_occurrences': 'supersedes_id',
  'work_sessions': 'supersedes_id',
  'trash_entries': 'archive_id',
};

Future<BackupSnapshot> _readBackup(DatabaseExecutor db) async {
  final count = Sqflite.firstIntValue(
    await db.rawQuery('SELECT COUNT(*) FROM records'),
  );
  if (count != null && count > BackupSnapshot.maxEntities) {
    throw BackupIssue.tooLarge;
  }
  final records = {
    for (final row in await db.query('records')) row.text('id'): row,
  };
  final timers = await _routineState(db, _timers);
  final goals = await _routineState(db, _goals);
  final entities = <BackupEntity>[];
  for (final spec in _backupTables.entries) {
    final table = spec.value.name;
    for (final row in await db.query(table, orderBy: 'id')) {
      final id = row.text('id');
      final record = records.remove(id);
      if (record == null || record['kind'] != spec.key.name) {
        throw BackupIssue.invalidData;
      }
      entities.add(
        BackupEntity(
          record: record,
          data: row,
          timer: timers.remove(id),
          goalEvent: goals.remove(id),
        ),
      );
    }
  }
  if (records.isNotEmpty || timers.isNotEmpty || goals.isNotEmpty) {
    throw BackupIssue.invalidData;
  }
  return BackupSnapshot(plannerSchemaVersion, entities);
}

Future<Map<String, BackupRow>> _routineState(
  DatabaseExecutor db,
  String table,
) async => {
  for (final row in await db.query(table)) row.text('occurrence_id'): row,
};

Future<void> _replaceBackup(
  DatabaseExecutor db,
  BackupSnapshot snapshot,
) async {
  if (snapshot.schemaVersion != plannerSchemaVersion) {
    throw BackupIssue.unsupportedSchema;
  }
  final tables = <String, List<BackupRow>>{
    'records': [],
    for (final table in _backupTables.values) table.name: [],
    _timers: [],
    _goals: [],
  };
  for (final item in snapshot.entities.values) {
    final spec = _backupTables[item.kind]!;
    tables['records']!.add(item.record);
    tables[spec.name]!.add(item.data);
    _attachRoutineState(tables[_timers]!, item, item.timer);
    _attachRoutineState(tables[_goals]!, item, item.goalEvent);
  }
  final profileRows = tables['profiles']!;
  if (profileRows.length != 1 ||
      profileRows.single['onboarding_completed'] != 1) {
    throw BackupIssue.invalidData;
  }
  for (final table in tables.entries) {
    await _validateColumns(db, table.key, table.value);
  }
  for (final item in snapshot.entities.values) {
    final table = _backupTables[item.kind]!;
    final model = _decode(table, {...item.record, ...item.data});
    final parent = table.parentId(model);
    if (item.record['parent_id'] != parent) throw BackupIssue.invalidData;
    if (model is EventSeries) _validateSeries(model, snapshot);
  }
  _validateHistory(snapshot);

  final batch = db.batch();
  batch.delete('reminder_progress');
  for (final table in tables.keys.toList().reversed) {
    final parent = _selfReference[table];
    if (parent == null) {
      batch.delete(table);
    } else {
      for (final row in _parentsFirst(await db.query(table), parent).reversed) {
        batch.delete(table, where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }
  for (final entry in tables.entries) {
    final parent = _selfReference[entry.key];
    final rows = parent == null
        ? entry.value
        : _parentsFirst(entry.value, parent);
    for (final row in rows) {
      batch.insert(entry.key, row);
    }
  }
  await batch.commit(noResult: true);
  if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
    throw BackupIssue.invalidData;
  }
  if ((await db.query(
    'hidden_records',
    where: 'id = ?',
    whereArgs: [profileRows.single['id']],
    limit: 1,
  )).isNotEmpty) {
    throw BackupIssue.invalidData;
  }
}

void _validateHistory(BackupSnapshot snapshot) {
  final latestTaskStatus = <String, (int, Set<String>)>{};
  for (final item in snapshot.entities.values) {
    if (item.kind != RecordKind.statusHistory) continue;
    final target = snapshot.entities[item.data['target_id']];
    if (target == null || !target.data.containsKey('status')) {
      throw BackupIssue.invalidData;
    }
    final status = item.data['status'] as String;
    if (target.kind != RecordKind.task) {
      // Event, session and occurrence outcomes are terminal in SQLite.
      if (target.data['status'] != status) throw BackupIssue.invalidData;
      continue;
    }
    final at = item.data['changed_at_us'] as int;
    final current = latestTaskStatus[target.id];
    if (current == null || at > current.$1) {
      latestTaskStatus[target.id] = (at, {status});
    } else if (at == current.$1) {
      current.$2.add(status);
    }
  }
  for (final row in latestTaskStatus.entries) {
    if (row.value.$2.length != 1 ||
        snapshot.entities[row.key]!.data['status'] != row.value.$2.single) {
      throw BackupIssue.invalidData;
    }
  }
}

void _attachRoutineState(
  List<BackupRow> rows,
  BackupEntity item,
  BackupRow? row,
) {
  if (row == null) return;
  if (item.kind != RecordKind.routineOccurrence ||
      row['occurrence_id'] != item.id) {
    throw BackupIssue.invalidData;
  }
  rows.add(row);
}

Future<void> _validateColumns(
  DatabaseExecutor db,
  String table,
  List<BackupRow> rows,
) async {
  // Table names come only from the installed whitelisted schema.
  final columns = await db.rawQuery('PRAGMA table_info($table)');
  for (final row in rows) {
    if (row.length != columns.length) throw BackupIssue.invalidData;
    for (final column in columns) {
      final name = column.text('name');
      if (!row.containsKey(name)) throw BackupIssue.invalidData;
      final value = row[name];
      final valid = switch (value) {
        null => column.number('notnull') == 0 && column.number('pk') == 0,
        int() => column.text('type') == 'INTEGER',
        String() => column.text('type') == 'TEXT',
        _ => false,
      };
      if (!valid) throw BackupIssue.invalidData;
    }
  }
}

List<BackupRow> _parentsFirst(Iterable<BackupRow> rows, String parentColumn) {
  final ready = <BackupRow>[];
  final children = <String, List<BackupRow>>{};
  var count = 0;
  for (final row in rows) {
    count++;
    if (row[parentColumn] case final String parent) {
      (children[parent] ??= []).add(row);
    } else {
      ready.add(row);
    }
  }
  for (var i = 0; i < ready.length; i++) {
    if (children[ready[i]['id']] case final next?) ready.addAll(next);
  }
  if (ready.length != count) throw BackupIssue.invalidData;
  return ready;
}

void _validateSeries(EventSeries series, BackupSnapshot snapshot) {
  EventRecurrence.decode(series.recurrenceRule);
  final template = series.template;
  if (template == null) return;
  final row = jsonDecode(template) as Map<String, dynamic>;
  final start = DateTime.parse(row['start'] as String);
  final end = DateTime.parse(row['end'] as String);
  EventAvailability.values.byName(row['availability'] as String);
  if (!start.isBefore(end) ||
      (row['before'] as int) < 0 ||
      (row['after'] as int) < 0) {
    throw BackupIssue.invalidData;
  }
  for (final key in ['description', 'location', 'note', 'link', 'color']) {
    if (row[key] is! String) throw BackupIssue.invalidData;
  }
  for (final key in ['reminders', 'warnings', 'excluded']) {
    if (row[key] is! List ||
        (row[key] as List).any((item) => item is! String)) {
      throw BackupIssue.invalidData;
    }
  }
  final link = row['routineOccurrenceId'];
  if (link != null &&
      snapshot.entities[link]?.kind != RecordKind.routineOccurrence) {
    throw BackupIssue.invalidData;
  }
}
