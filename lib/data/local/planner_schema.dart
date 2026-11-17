import 'dart:convert';

import 'package:sqflite/sqflite.dart';

const plannerSchemaVersion = 9;
const _status = "('planned','completed','postponed','skipped','cancelled')";
const _mode = "('originalZone','localWallTime')";
const _activity =
    "('eventSeries','eventOccurrence','task','workSession','routine','routineOccurrence')";
const _id =
    'id TEXT PRIMARY KEY NOT NULL REFERENCES records(id) ON DELETE RESTRICT';
const _title = 'title TEXT NOT NULL CHECK (length(trim(title)) > 0)';
const _category =
    'category_id TEXT REFERENCES categories(id) ON DELETE RESTRICT';
const _statusColumn = 'status TEXT NOT NULL CHECK (status IN $_status)';
const _interval = '''
  start_us INTEGER,
  end_us INTEGER,
  zone_id TEXT,
  time_mode TEXT,
  start_local TEXT,
  end_local TEXT
''';
const _intervalValid =
    '''
  start_us IS NOT NULL AND end_us IS NOT NULL AND start_us < end_us
  AND zone_id IS NOT NULL AND length(trim(zone_id)) > 0
  AND time_mode IS NOT NULL AND time_mode IN $_mode
  AND (time_mode <> 'localWallTime' OR (start_local IS NOT NULL AND end_local IS NOT NULL))
''';

Future<void> createPlannerSchemaV1(Database db) async {
  final statements = [
    '''
    CREATE TABLE records (
      id TEXT PRIMARY KEY NOT NULL CHECK (length(trim(id)) > 0),
      kind TEXT NOT NULL CHECK (kind IN (
        'profile','category','eventSeries','eventOccurrence','task','subtask',
        'workSession','routine','routineOccurrence','timeLog','reminderRule',
        'statusHistory','trashEntry'
      )),
      parent_id TEXT REFERENCES records(id) ON DELETE RESTRICT,
      revision INTEGER NOT NULL CHECK (revision > 0),
      created_at_us INTEGER NOT NULL,
      updated_at_us INTEGER NOT NULL CHECK (updated_at_us >= created_at_us),
      UNIQUE (id, kind),
      CHECK (parent_id IS NULL OR parent_id <> id)
    )
    ''',
    '''
    CREATE TABLE profiles (
      $_id,
      singleton INTEGER NOT NULL DEFAULT 1 UNIQUE CHECK (singleton = 1),
      name TEXT,
      notifications_enabled INTEGER CHECK (notifications_enabled IN (0,1)),
      week_starts_on INTEGER CHECK (week_starts_on IN (1,7)),
      default_buffer_us INTEGER CHECK (default_buffer_us >= 0),
      quiet_start_min INTEGER,
      quiet_end_min INTEGER,
      active_hours TEXT NOT NULL,
      activity_preferences TEXT NOT NULL,
      CHECK ((quiet_start_min IS NULL AND quiet_end_min IS NULL) OR
        (quiet_start_min IS NOT NULL AND quiet_end_min IS NOT NULL
         AND quiet_start_min BETWEEN 0 AND 1439 AND quiet_end_min BETWEEN 0 AND 1439
         AND quiet_start_min <> quiet_end_min))
    )
    ''',
    '''
    CREATE TABLE categories (
      $_id,
      name TEXT NOT NULL CHECK (length(trim(name)) > 0),
      color INTEGER NOT NULL CHECK (color BETWEEN 0 AND 4294967295),
      icon TEXT
    )
    ''',
    '''
    CREATE TABLE event_series (
      $_id,
      $_title,
      recurrence_rule TEXT NOT NULL CHECK (length(trim(recurrence_rule)) > 0),
      zone_id TEXT NOT NULL CHECK (length(trim(zone_id)) > 0),
      time_mode TEXT NOT NULL CHECK (time_mode IN $_mode),
      $_category,
      split_from_id TEXT REFERENCES event_series(id) ON DELETE RESTRICT,
      CHECK (split_from_id IS NULL OR split_from_id <> id)
    )
    ''',
    '''
    CREATE TABLE tasks (
      $_id,
      $_title,
      $_category,
      description TEXT,
      priority TEXT,
      $_statusColumn,
      initial_estimate_us INTEGER CHECK (initial_estimate_us >= 0),
      deadline_us INTEGER,
      deadline_zone TEXT,
      deadline_mode TEXT,
      deadline_local TEXT,
      CHECK (
        (deadline_us IS NULL AND deadline_zone IS NULL AND deadline_mode IS NULL AND deadline_local IS NULL)
        OR (deadline_us IS NOT NULL AND deadline_zone IS NOT NULL AND length(trim(deadline_zone)) > 0
            AND deadline_mode IS NOT NULL AND deadline_mode IN $_mode
            AND (deadline_mode <> 'localWallTime' OR deadline_local IS NOT NULL))
      )
    )
    ''',
    '''
    CREATE TABLE subtasks (
      $_id,
      task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE RESTRICT,
      $_title,
      sort_order INTEGER NOT NULL CHECK (sort_order >= 0),
      checked INTEGER NOT NULL CHECK (checked IN (0,1))
    )
    ''',
    '''
    CREATE TABLE routines (
      $_id,
      $_title,
      $_category,
      target_type TEXT NOT NULL CHECK (target_type IN ('duration','count','checklist','frequency')),
      target_amount INTEGER CHECK (target_amount > 0),
      target_duration_us INTEGER CHECK (target_duration_us > 0),
      frequency_rule TEXT,
      checklist TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE routine_occurrences (
      $_id,
      routine_id TEXT NOT NULL REFERENCES routines(id) ON DELETE RESTRICT,
      local_day TEXT NOT NULL CHECK (length(local_day) = 10),
      $_statusColumn,
      recorded_count INTEGER CHECK (recorded_count >= 0),
      checked_items TEXT NOT NULL,
      $_interval,
      CHECK ((start_us IS NULL AND end_us IS NULL AND zone_id IS NULL AND
              time_mode IS NULL AND start_local IS NULL AND end_local IS NULL) OR ($_intervalValid)),
      UNIQUE (routine_id, local_day)
    )
    ''',
    '''
    CREATE TABLE event_occurrences (
      $_id,
      $_title,
      $_category,
      description TEXT,
      buffer_before_us INTEGER CHECK (buffer_before_us >= 0),
      buffer_after_us INTEGER CHECK (buffer_after_us >= 0),
      $_statusColumn,
      availability TEXT NOT NULL CHECK (availability IN ('timed','allDayBusy','allDayFree')),
      all_day_start TEXT,
      all_day_end_exclusive TEXT,
      series_id TEXT REFERENCES event_series(id) ON DELETE RESTRICT,
      recurrence_key TEXT,
      supersedes_id TEXT REFERENCES event_occurrences(id) ON DELETE RESTRICT,
      routine_occurrence_id TEXT REFERENCES routine_occurrences(id) ON DELETE RESTRICT,
      $_interval,
      CHECK ($_intervalValid),
      CHECK ((series_id IS NULL AND recurrence_key IS NULL) OR
             (series_id IS NOT NULL AND recurrence_key IS NOT NULL AND length(trim(recurrence_key)) > 0)),
      CHECK (supersedes_id IS NULL OR supersedes_id <> id),
      CHECK ((availability = 'timed' AND all_day_start IS NULL AND all_day_end_exclusive IS NULL) OR
             (availability <> 'timed' AND all_day_start IS NOT NULL AND all_day_end_exclusive IS NOT NULL
              AND length(all_day_start) = 10 AND length(all_day_end_exclusive) = 10
              AND all_day_start < all_day_end_exclusive)),
      UNIQUE (series_id, recurrence_key)
    )
    ''',
    '''
    CREATE TABLE work_sessions (
      $_id,
      task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE RESTRICT,
      $_statusColumn,
      supersedes_id TEXT REFERENCES work_sessions(id) ON DELETE RESTRICT,
      routine_occurrence_id TEXT REFERENCES routine_occurrences(id) ON DELETE RESTRICT,
      $_interval,
      CHECK ($_intervalValid),
      CHECK (supersedes_id IS NULL OR supersedes_id <> id)
    )
    ''',
    '''
    CREATE TABLE time_logs (
      $_id,
      target_id TEXT NOT NULL,
      target_kind TEXT NOT NULL CHECK (target_kind IN ('workSession','routineOccurrence')),
      actual_us INTEGER NOT NULL CHECK (actual_us > 0),
      recorded_at_us INTEGER NOT NULL,
      source TEXT NOT NULL CHECK (source IN ('manual','timer')),
      started_at_us INTEGER,
      ended_at_us INTEGER,
      CHECK ((started_at_us IS NULL AND ended_at_us IS NULL) OR
             (started_at_us IS NOT NULL AND ended_at_us IS NOT NULL AND started_at_us < ended_at_us)),
      FOREIGN KEY (target_id, target_kind) REFERENCES records(id, kind) ON DELETE RESTRICT
    )
    ''',
    '''
    CREATE TABLE reminder_rules (
      $_id,
      target_id TEXT NOT NULL,
      target_kind TEXT NOT NULL CHECK (target_kind IN $_activity),
      anchor TEXT NOT NULL CHECK (anchor IN ('start','deadline','confirmation')),
      offset_us INTEGER NOT NULL,
      enabled INTEGER NOT NULL CHECK (enabled IN (0,1)),
      FOREIGN KEY (target_id, target_kind) REFERENCES records(id, kind) ON DELETE RESTRICT
    )
    ''',
    '''
    CREATE TABLE status_history (
      $_id,
      target_id TEXT NOT NULL,
      target_kind TEXT NOT NULL CHECK (target_kind IN $_activity),
      previous TEXT NOT NULL CHECK (previous IN $_status),
      $_statusColumn,
      changed_at_us INTEGER NOT NULL,
      replacement_id TEXT,
      replacement_kind TEXT,
      CHECK (previous <> status),
      CHECK ((replacement_id IS NULL AND replacement_kind IS NULL) OR
             (replacement_id IS NOT NULL AND replacement_kind IS NOT NULL
              AND replacement_id <> target_id AND replacement_kind = target_kind)),
      FOREIGN KEY (target_id, target_kind) REFERENCES records(id, kind) ON DELETE RESTRICT,
      FOREIGN KEY (replacement_id, replacement_kind) REFERENCES records(id, kind) ON DELETE RESTRICT
    )
    ''',
    '''
    CREATE TABLE trash_entries (
      $_id,
      target_id TEXT NOT NULL UNIQUE,
      target_kind TEXT NOT NULL CHECK (target_kind NOT IN ('timeLog','statusHistory','trashEntry')),
      deleted_at_us INTEGER NOT NULL,
      restored_at_us INTEGER CHECK (restored_at_us >= deleted_at_us),
      FOREIGN KEY (target_id, target_kind) REFERENCES records(id, kind) ON DELETE RESTRICT
    )
    ''',
    'CREATE INDEX records_parent ON records(parent_id)',
    'CREATE INDEX records_kind ON records(kind, id)',
    'CREATE INDEX trash_active ON trash_entries(target_id) WHERE restored_at_us IS NULL',
    '''
    CREATE VIEW hidden_records AS
    WITH RECURSIVE hidden(id) AS (
      SELECT target_id FROM trash_entries WHERE restored_at_us IS NULL
      UNION
      SELECT r.id FROM records r INNER JOIN hidden h ON r.parent_id = h.id
    )
    SELECT id FROM hidden
    ''',
    'CREATE INDEX subtasks_task ON subtasks(task_id, sort_order)',
    'CREATE INDEX logs_target_time ON time_logs(target_id, recorded_at_us)',
    'CREATE INDEX reminders_target ON reminder_rules(target_id)',
    'CREATE INDEX history_target_time ON status_history(target_id, changed_at_us)',
  ];
  for (final statement in statements) {
    await db.execute(statement);
  }
}

Future<void> migratePlannerSchema(Database db, int from, int to) async {
  if (from < 2 && to >= 2) {
    await db.execute(
      'ALTER TABLE tasks ADD COLUMN confirmed_remaining_us INTEGER CHECK (confirmed_remaining_us >= 0)',
    );
    await db.execute('''
      ALTER TABLE tasks ADD COLUMN remaining_confirmed_at_us INTEGER
      CHECK ((confirmed_remaining_us IS NULL) = (remaining_confirmed_at_us IS NULL))
      ''');
    await db.execute(
      'CREATE INDEX tasks_deadline ON tasks(deadline_us) WHERE deadline_us IS NOT NULL',
    );
    for (final table in [
      'event_occurrences',
      'work_sessions',
      'routine_occurrences',
    ]) {
      await db.execute(
        'CREATE INDEX ${table}_calendar ON $table(end_us, start_us)',
      );
      await db.execute('''
        CREATE TRIGGER ${table}_protect_history BEFORE UPDATE ON $table
        WHEN (OLD.status <> 'planned' OR EXISTS (
          SELECT 1 FROM time_logs log WHERE log.target_id = OLD.id
        )) AND (
          NEW.start_us IS NOT OLD.start_us OR NEW.end_us IS NOT OLD.end_us OR
          NEW.zone_id IS NOT OLD.zone_id OR NEW.time_mode IS NOT OLD.time_mode OR
          NEW.start_local IS NOT OLD.start_local OR NEW.end_local IS NOT OLD.end_local
          ${table == 'event_occurrences' ? '''
           OR NEW.availability IS NOT OLD.availability OR NEW.all_day_start IS NOT OLD.all_day_start
           OR NEW.all_day_end_exclusive IS NOT OLD.all_day_end_exclusive
          ''' : ''}
        )
        BEGIN SELECT RAISE(ABORT, 'Historical schedule is immutable'); END
        ''');
      await db.execute('''
        CREATE TRIGGER ${table}_protect_outcome BEFORE UPDATE ON $table
        WHEN OLD.status <> 'planned' AND NEW.status IS NOT OLD.status
        BEGIN SELECT RAISE(ABORT, 'Historical outcome is immutable'); END
        ''');
    }
  }
  if (from < 3 && to >= 3) {
    await db.execute('''
      ALTER TABLE profiles ADD COLUMN onboarding_completed INTEGER NOT NULL
      DEFAULT 1 CHECK (onboarding_completed IN (0, 1))
      ''');
    await db.execute('''
      ALTER TABLE profiles ADD COLUMN onboarding_step INTEGER NOT NULL
      DEFAULT 0 CHECK (onboarding_step BETWEEN 0 AND 2)
      ''');
    await db.execute(
      "ALTER TABLE profiles ADD COLUMN preferences TEXT NOT NULL DEFAULT '{}'",
    );
  }
  if (from < 4 && to >= 4) {
    await db.execute('ALTER TABLE event_series ADD COLUMN template TEXT');
    await db.execute('ALTER TABLE event_series ADD COLUMN ends_before TEXT');
    await db.execute(
      "ALTER TABLE event_occurrences ADD COLUMN details TEXT NOT NULL DEFAULT '{}'",
    );
  }
  if (from < 5 && to >= 5) {
    await db.execute('ALTER TABLE routines ADD COLUMN preferred_time TEXT');
    await db.execute('ALTER TABLE routines ADD COLUMN routine_time_mode TEXT');
    await db.execute('ALTER TABLE routine_occurrences ADD COLUMN goal TEXT');
    final existing = await db.rawQuery('''
      SELECT o.id, r.target_type, r.target_amount, r.target_duration_us, r.checklist
      FROM routine_occurrences o JOIN routines r ON o.routine_id = r.id
      ''');
    for (final row in existing) {
      await db.update(
        'routine_occurrences',
        {
          'goal': jsonEncode({
            'type': row['target_type'],
            'amount': row['target_amount'],
            'durationUs': row['target_duration_us'],
            'checklist': jsonDecode(row['checklist'] as String),
          }),
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    await db.execute('''
      CREATE TABLE routine_timers (
        occurrence_id TEXT PRIMARY KEY NOT NULL REFERENCES routine_occurrences(id),
        id TEXT NOT NULL UNIQUE,
        accumulated_us INTEGER NOT NULL CHECK (accumulated_us >= 0),
        running_since_us INTEGER
      )
      ''');
    await db.execute('''
      CREATE TABLE routine_goal_events (
        occurrence_id TEXT PRIMARY KEY NOT NULL REFERENCES routine_occurrences(id),
        due_at_us INTEGER NOT NULL,
        reached_at_us INTEGER CHECK (reached_at_us >= due_at_us)
      )
      ''');
  }
  if (from < 6 && to >= 6) {
    await db.execute(
      'ALTER TABLE tasks ADD COLUMN remaining_actual_us INTEGER',
    );
    await db.execute('''
      ALTER TABLE tasks ADD COLUMN minimum_session_minutes INTEGER
      CHECK (minimum_session_minutes > 0)
      ''');
    await db.execute('''
      ALTER TABLE tasks ADD COLUMN maximum_sessions INTEGER
      CHECK (maximum_sessions > 0 AND
        (maximum_sessions IS NULL) = (minimum_session_minutes IS NULL))
      ''');
  }
  if (from < 7 && to >= 7) {
    await db.execute('''
      CREATE TABLE reminder_progress (
        id TEXT PRIMARY KEY NOT NULL,
        first_seen_us INTEGER,
        snoozed_until_us INTEGER
      )
      ''');
  }
  if (from < 8 && to >= 8) {
    await db.execute(
      "ALTER TABLE routines ADD COLUMN cadence_history TEXT NOT NULL DEFAULT '[]'",
    );
  }
  if (from < 9 && to >= 9) {
    await db.execute(
      'ALTER TABLE trash_entries ADD COLUMN expires_at_us INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'UPDATE trash_entries SET expires_at_us = deleted_at_us + 2592000000000',
    );
    await db.execute('ALTER TABLE trash_entries ADD COLUMN series_cut TEXT');
    await db.execute(
      'ALTER TABLE trash_entries ADD COLUMN previous_series_end TEXT',
    );
    await db.execute('''
      ALTER TABLE trash_entries ADD COLUMN archive_id TEXT REFERENCES trash_entries(id)
      ''');
    await db.execute('CREATE INDEX trash_archive ON trash_entries(archive_id)');
    await db.execute('''
      CREATE VIEW record_dependents AS
      SELECT parent_id, id FROM records WHERE parent_id IS NOT NULL
      UNION ALL
      SELECT routine_occurrence_id, id FROM event_occurrences WHERE routine_occurrence_id IS NOT NULL
      UNION ALL
      SELECT routine_occurrence_id, id FROM work_sessions WHERE routine_occurrence_id IS NOT NULL
      ''');
    await db.execute('DROP VIEW hidden_records');
    await db.execute('''
      CREATE VIEW hidden_records AS
      WITH RECURSIVE hidden(id) AS (
        SELECT target_id FROM trash_entries WHERE restored_at_us IS NULL AND series_cut IS NULL
        UNION
        SELECT d.id FROM record_dependents d JOIN hidden h ON d.parent_id = h.id
      )
      SELECT id FROM hidden
      ''');
  }
}
