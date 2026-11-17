part of 'sqlite_planner_store.dart';

const _activityTrashKinds = {
  RecordKind.eventOccurrence,
  RecordKind.task,
  RecordKind.routine,
};

EventSeries _seriesWithEnd(
  EventSeries series,
  LocalDate? end, {
  String? template,
}) => EventSeries(
  series.metadata,
  title: series.title,
  recurrenceRule: series.recurrenceRule,
  zoneId: series.zoneId,
  timeMode: series.timeMode,
  categoryId: series.categoryId,
  splitFromId: series.splitFromId,
  template: template ?? series.template,
  endsBefore: end,
);

Future<TrashEntry> _trashEntry(
  DatabaseExecutor db,
  String id,
  int? revision,
) async {
  final row = await _find(db, _trash, id, includeDeleted: true);
  if (row == null) throw StaleRecord(id);
  final entry = _decode(_trash, row);
  if (revision != null &&
      (entry.metadata.revision != revision || entry.restoredAt != null)) {
    throw StaleRecord(id);
  }
  if (entry.archiveId != null) throw TrashProblem.unavailableParent;
  return entry;
}

Future<EventSeries> _archivedSeries(
  DatabaseExecutor db,
  TrashEntry entry,
) async {
  final row = await _find(
    db,
    _eventSeries,
    entry.target.id,
    includeDeleted: false,
  );
  if (row == null) throw TrashProblem.unavailableParent;
  final series = _decode(_eventSeries, row);
  if (series.endsBefore?.value != entry.seriesCut?.value) {
    throw TrashProblem.seriesChanged;
  }
  return series;
}

Future<List<_Row>> _archiveMembers(DatabaseExecutor db, String id) =>
    db.rawQuery(
      '''${_select(_trash)}
     WHERE item.archive_id = ? AND item.restored_at_us IS NULL''',
      [id],
    );

Future<List<_Row>> _trashDescendants(
  DatabaseExecutor db,
  TrashEntry entry, {
  bool includeLinked = false,
}) => db.rawQuery(
  '''
  WITH RECURSIVE affected(id) AS (
    ${entry.seriesCut == null ? 'SELECT ?' : '''
      SELECT target_id FROM trash_entries WHERE archive_id = ? AND restored_at_us IS NULL
    '''}
    UNION
    SELECT d.id FROM ${includeLinked ? 'record_dependents' : 'records'} d
    JOIN affected a ON a.id = d.parent_id
  )
  SELECT r.* FROM records r JOIN affected a ON a.id = r.id
  ''',
  [entry.seriesCut == null ? entry.target.id : entry.id],
);

Future<void> _markRestored(
  DatabaseExecutor db,
  TrashEntry entry,
  DateTime clock,
) async {
  final target = await _metadata(db, entry.target);
  if (target == null) throw StaleRecord(entry.target.id);
  final now = _modifiedAt(target, clock);
  await _save(
    db,
    _trash,
    TrashEntry(
      entry.metadata,
      target: entry.target,
      deletedAt: entry.deletedAt,
      expiresAt: entry.expiresAt,
      restoredAt: now.isBefore(entry.deletedAt) ? entry.deletedAt : now,
      seriesCut: entry.seriesCut,
      previousSeriesEnd: entry.previousSeriesEnd,
    ),
    now,
  );
  await _updateMetadata(db, target, now);
}

Future<Set<String>> _restoreTrash(
  DatabaseExecutor db,
  String id,
  int? revision,
  DateTime now,
) async {
  final entry = await _trashEntry(db, id, revision);
  if (entry.restoredAt != null) return {};
  if (!entry.canRestoreAt(now)) throw TrashProblem.expired;
  final affected = await _trashDescendants(db, entry, includeLinked: true);
  final members = await _archiveMembers(db, id);
  if (entry.seriesCut != null) {
    await _archivedSeries(db, entry);
    await db.update(
      'event_series',
      {'ends_before': entry.previousSeriesEnd?.value},
      where: 'id = ?',
      whereArgs: [entry.target.id],
    );
  }
  for (final member in members) {
    await _markRestored(db, _decode(_trash, member), now);
  }
  await _markRestored(db, entry, now);
  final hidden = {
    for (final row in await db.query('hidden_records')) row.text('id'),
  };
  if (hidden.contains(entry.target.id) ||
      members.any((member) => hidden.contains(member.text('target_id')))) {
    throw TrashProblem.unavailableParent;
  }
  if (entry.target.kind == RecordKind.eventOccurrence &&
      (await db.rawQuery(
        '''
        SELECT 1 FROM event_occurrences e JOIN trash_entries t ON t.target_id = e.series_id
        WHERE e.id = ? AND t.restored_at_us IS NULL AND e.recurrence_key >= t.series_cut
        ''',
        [entry.target.id],
      )).isNotEmpty) {
    throw TrashProblem.unavailableParent;
  }
  if (entry.seriesCut != null) {
    final series = await _find(
      db,
      _eventSeries,
      entry.target.id,
      includeDeleted: false,
    );
    final template = series?.optionalText('template');
    if (template != null &&
        hidden.contains(
          (jsonDecode(template) as Map<String, dynamic>)['routineOccurrenceId'],
        )) {
      throw TrashProblem.unavailableParent;
    }
  }

  final categorized = <String, String>{
    for (final row in affected)
      if (!hidden.contains(row.text('id')) &&
          _categorizedKinds.containsKey(row.text('kind')))
        row.text('id'): _categorizedKinds[row.text('kind')]!,
    if (entry.seriesCut != null) entry.target.id: 'event_series',
  };
  final removed = <String>{};
  for (final item in categorized.entries) {
    final rows = await db.rawQuery(
      '''
      SELECT c.name FROM ${item.value} a JOIN categories c ON a.category_id = c.id
      WHERE a.id = ? AND c.id IN (SELECT id FROM hidden_records)
      ''',
      [item.key],
    );
    if (rows.isEmpty) continue;
    removed.add(rows.single.text('name'));
    await db.update(
      item.value,
      {'category_id': null},
      where: 'id = ?',
      whereArgs: [item.key],
    );
    final metadata = (await db.query(
      'records',
      where: 'id = ?',
      whereArgs: [item.key],
    )).single;
    await _updateMetadata(
      db,
      _readMetadata(metadata),
      _modifiedAt(_readMetadata(metadata), now),
    );
  }
  return removed;
}

const _categorizedKinds = {
  'eventSeries': 'event_series',
  'eventOccurrence': 'event_occurrences',
  'task': 'tasks',
  'routine': 'routines',
};

// Each table's owned dependents are removed before its records.
const _purgeTables = {
  'trashEntry': 'trash_entries',
  'statusHistory': 'status_history',
  'timeLog': 'time_logs',
  'reminderRule': 'reminder_rules',
  'subtask': 'subtasks',
  'workSession': 'work_sessions',
  'eventOccurrence': 'event_occurrences',
  'routineOccurrence': 'routine_occurrences',
  'task': 'tasks',
  'routine': 'routines',
};

Future<void> _purgeTrash(
  DatabaseExecutor db,
  String id,
  int revision,
  DateTime now,
) async {
  final entry = await _trashEntry(db, id, revision);
  if (entry.seriesCut == null &&
      !_activityTrashKinds.contains(entry.target.kind)) {
    throw ArgumentError('This trash item cannot be permanently deleted');
  }
  if (entry.seriesCut != null) await _archivedSeries(db, entry);
  final records = await _trashDescendants(db, entry);
  final targets = records.map((row) => row.text('id')).toSet();
  final grouped = <String, Set<String>>{};
  for (final row in records) {
    (grouped[row.text('kind')] ??= {}).add(row.text('id'));
  }
  final graves = <String>{};
  for (final item in await db.query('trash_entries')) {
    if (!targets.contains(item.text('target_id'))) continue;
    final archive = item.optionalText('archive_id');
    if (archive != null && archive != id) throw TrashProblem.unavailableParent;
    graves.add(item.text('id'));
  }
  graves.add(id);
  grouped['trashEntry'] = graves;

  final predecessors = <String, String>{};
  for (final (table, column) in [
    ('event_occurrences', 'supersedes_id'),
    ('event_occurrences', 'routine_occurrence_id'),
    ('work_sessions', 'supersedes_id'),
    ('work_sessions', 'routine_occurrence_id'),
    ('status_history', 'replacement_id'),
  ]) {
    for (final row in await db.query(
      table,
      columns: ['id', column],
      where: '$column IS NOT NULL',
    )) {
      final target = row.text(column);
      if (!targets.contains(target)) continue;
      final owner = row.text('id');
      if (!targets.contains(owner)) throw TrashProblem.referenced;
      if (column == 'supersedes_id') predecessors[owner] = target;
    }
  }
  if (grouped.containsKey('routineOccurrence')) {
    for (final row in await db.query(
      'event_series',
      columns: ['template'],
      where: 'template IS NOT NULL',
    )) {
      if (targets.contains(
        (jsonDecode(row.text('template'))
            as Map<String, dynamic>)['routineOccurrenceId'],
      )) {
        throw TrashProblem.referenced;
      }
    }
    for (final occurrence in grouped['routineOccurrence']!) {
      for (final table in ['routine_timers', 'routine_goal_events']) {
        await db.delete(
          table,
          where: 'occurrence_id = ?',
          whereArgs: [occurrence],
        );
      }
    }
  }

  // Preserve recurring exclusions without keeping the purged activity payload.
  final exclusions = <String, Set<String>>{};
  for (final row in await db.query(
    'event_occurrences',
    columns: ['id', 'series_id', 'recurrence_key'],
    where: 'series_id IS NOT NULL',
  )) {
    if (targets.contains(row.text('id'))) {
      (exclusions[row.text('series_id')] ??= {}).add(
        row.text('recurrence_key'),
      );
    }
  }
  for (final item in exclusions.entries) {
    final row = await _find(db, _eventSeries, item.key, includeDeleted: true);
    if (row == null) throw StaleRecord(item.key);
    final series = _decode(_eventSeries, row);
    if (series.template case final template?) {
      final json = jsonDecode(template) as Map<String, dynamic>;
      json['excluded'] = {
        ...(json['excluded'] as List).cast<String>(),
        ...item.value,
      }.toList();
      await db.update(
        'event_series',
        {'template': jsonEncode(json)},
        where: 'id = ?',
        whereArgs: [series.id],
      );
      await _updateMetadata(
        db,
        series.metadata,
        _modifiedAt(series.metadata, now),
      );
    }
  }

  for (final item in _purgeTables.entries) {
    final ids = grouped[item.key] ?? const <String>{};
    final ordered = item.key == 'trashEntry'
        ? [...ids.where((key) => key != id), id]
        : _referencesFirst(ids, predecessors);
    for (final key in ordered) {
      await db.delete(item.value, where: 'id = ?', whereArgs: [key]);
      await db.delete('records', where: 'id = ?', whereArgs: [key]);
    }
  }
}

List<String> _referencesFirst(Set<String> ids, Map<String, String> links) {
  final counts = <String, int>{};
  for (final id in ids) {
    if (links[id] case final target?) {
      counts.update(target, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  final ordered = ids.where((id) => !counts.containsKey(id)).toList();
  for (var i = 0; i < ordered.length; i++) {
    if (links[ordered[i]] case final target?) {
      if (counts.update(target, (n) => n - 1) == 0) ordered.add(target);
    }
  }
  if (ordered.length != ids.length) throw TrashProblem.referenced;
  return ordered;
}
