part of 'sqlite_planner_store.dart';

typedef _Row = Map<String, Object?>;

class _Table<T extends PlannerRecord> {
  const _Table(this.name, this.kind, this.encode, this.decode, {this.parent});

  final String name;
  final RecordKind kind;
  final _Row Function(T) encode;
  final T Function(RecordMetadata, _Row) decode;
  final String? Function(T)? parent;
}

int? _instant(DateTime? value) => value?.microsecondsSinceEpoch;
DateTime? _date(int? value) => value == null
    ? null
    : DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true);
Duration? _duration(int? value) =>
    value == null ? null : Duration(microseconds: value);
int? _bool(bool? value) => value == null ? null : (value ? 1 : 0);

extension on _Row {
  String text(String key) => this[key] as String;
  String? optionalText(String key) => this[key] as String?;
  int number(String key) => this[key] as int;
  int? optionalNumber(String key) => this[key] as int?;
  DateTime instant(String key) => _date(number(key))!;
  DateTime? optionalInstant(String key) => _date(optionalNumber(key));
  Duration? duration(String key) => _duration(optionalNumber(key));
  LocalDate? day(String key) =>
      optionalText(key) == null ? null : LocalDate.parse(text(key));
  RecordRef ref(String prefix) => (
    id: text('${prefix}_id'),
    kind: RecordKind.values.byName(text('${prefix}_kind')),
  );
  ActivityStatus get status => ActivityStatus.values.byName(text('status'));
}

_Row _interval(ScheduledInterval? schedule) => {
  'start_us': _instant(schedule?.start.instant),
  'end_us': _instant(schedule?.end.instant),
  'zone_id': schedule?.start.zoneId,
  'time_mode': schedule?.start.mode.name,
  'start_local': _wallTime(schedule?.start),
  'end_local': _wallTime(schedule?.end),
};

String? _wallTime(ZonedTime? time) {
  final value = time?.localWallTime;
  if (time?.mode == TimeMode.localWallTime && value == null) {
    throw ArgumentError('Local wall time is required');
  }
  if (value != null) {
    if (!_localTimePattern.hasMatch(value)) {
      throw ArgumentError('Invalid local wall time');
    }
    LocalDate.parse(value.substring(0, 10));
  }
  return value;
}

final _localTimePattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d{1,6})?)?$',
);

ScheduledInterval? _readInterval(_Row row) {
  if (row['start_us'] == null) return null;
  final zone = row.text('zone_id');
  final mode = TimeMode.values.byName(row.text('time_mode'));
  return ScheduledInterval(
    ZonedTime(
      instant: row.instant('start_us'),
      zoneId: zone,
      mode: mode,
      localWallTime: row.optionalText('start_local'),
    ),
    ZonedTime(
      instant: row.instant('end_us'),
      zoneId: zone,
      mode: mode,
      localWallTime: row.optionalText('end_local'),
    ),
  );
}

List<String> _readList(_Row row, String key) =>
    (jsonDecode(row.text(key)) as List<dynamic>).cast<String>();

String _writeHours(Map<int, DailyHours> hours) {
  for (final entry in hours.entries) {
    final (:startMinute, :endMinute) = entry.value;
    if (entry.key < 1 ||
        entry.key > 7 ||
        startMinute < 0 ||
        endMinute > 1440 ||
        startMinute >= endMinute) {
      throw ArgumentError('Invalid active hours');
    }
  }
  return jsonEncode({
    for (final entry in hours.entries)
      entry.key.toString(): [entry.value.startMinute, entry.value.endMinute],
  });
}

Map<int, DailyHours> _readHours(String value) => {
  for (final entry in (jsonDecode(value) as Map<String, dynamic>).entries)
    int.parse(entry.key): (
      startMinute: (entry.value as List<dynamic>)[0] as int,
      endMinute: (entry.value as List<dynamic>)[1] as int,
    ),
};

final _profile = _Table<Profile>(
  'profiles',
  RecordKind.profile,
  (value) => {
    'name': value.name,
    'notifications_enabled': _bool(value.notificationsEnabled),
    'week_starts_on': value.weekStartsOn,
    'default_buffer_us': value.defaultBuffer?.inMicroseconds,
    'quiet_start_min': value.quietHours?.startMinute,
    'quiet_end_min': value.quietHours?.endMinute,
    'active_hours': _writeHours(value.activeHours),
    'activity_preferences': jsonEncode(value.activityPreferences),
    'onboarding_completed': _bool(value.onboardingCompleted),
    'onboarding_step': value.onboardingStep,
    'preferences': _writePreferences(value.preferences),
  },
  (meta, row) => Profile(
    meta,
    name: row.optionalText('name'),
    notificationsEnabled: row['notifications_enabled'] == null
        ? null
        : row.number('notifications_enabled') == 1,
    weekStartsOn: row.optionalNumber('week_starts_on'),
    onboardingCompleted: row.number('onboarding_completed') == 1,
    onboardingStep: row.number('onboarding_step'),
    preferences: _readPreferences(row.text('preferences')),
    defaultBuffer: row.duration('default_buffer_us'),
    quietHours: row['quiet_start_min'] == null
        ? null
        : (
            startMinute: row.number('quiet_start_min'),
            endMinute: row.number('quiet_end_min'),
          ),
    activeHours: _readHours(row.text('active_hours')),
    activityPreferences:
        (jsonDecode(row.text('activity_preferences')) as Map<String, dynamic>)
            .cast<String, String>(),
  ),
);

SessionLimits? _sessionLimits(int? minimum, int? maximum) =>
    minimum == null || maximum == null
    ? null
    : (minimumMinutes: minimum, maximumSessions: maximum);

String _writePreferences(PlannerPreferences value) => jsonEncode({
  'calendarZoneId': value.calendarZoneId,
  'eventTimeMode': value.eventTimeMode.name,
  'routineTimeMode': value.routineTimeMode.name,
  'deadlineTimeMode': value.deadlineTimeMode.name,
  'quietEnabled': value.quietEnabled,
  'reminderTypes': {
    for (final entry in value.reminderTypes.entries)
      entry.key.name: entry.value,
  },
  'quietExceptions': value.quietExceptions.map((kind) => kind.name).toList(),
  'quietExceptionsEnabled': value.quietExceptionsEnabled,
  'backupReminderDays': value.backupReminderDays,
  'minimumSessionMinutes': value.sessionLimits?.minimumMinutes,
  'maximumSessions': value.sessionLimits?.maximumSessions,
});

PlannerPreferences _readPreferences(String source) {
  final values = jsonDecode(source) as Map<String, dynamic>;
  TimeMode mode(String key, TimeMode fallback) =>
      TimeMode.values.where((mode) => mode.name == values[key]).firstOrNull ??
      fallback;
  final reminderTypes =
      values['reminderTypes'] as Map<String, dynamic>? ?? const {};
  final quietExceptions =
      values['quietExceptions'] as List<dynamic>? ?? const [];
  return PlannerPreferences(
    sessionLimits: _sessionLimits(
      values['minimumSessionMinutes'] as int?,
      values['maximumSessions'] as int?,
    ),
    calendarZoneId: values['calendarZoneId'] as String?,
    eventTimeMode: mode('eventTimeMode', TimeMode.originalZone),
    routineTimeMode: mode('routineTimeMode', TimeMode.localWallTime),
    deadlineTimeMode: mode('deadlineTimeMode', TimeMode.originalZone),
    quietEnabled: values['quietEnabled'] as bool?,
    reminderTypes: {
      for (final kind in ReminderKind.values)
        if (reminderTypes[kind.name] case final bool enabled) kind: enabled,
    },
    quietExceptions: ReminderKind.values
        .where((kind) => quietExceptions.contains(kind.name))
        .toSet(),
    quietExceptionsEnabled: values['quietExceptionsEnabled'] as bool? ?? false,
    backupReminderDays: values['backupReminderDays'] as int?,
  );
}

final _category = _Table<Category>(
  'categories',
  RecordKind.category,
  (value) => {'name': value.name, 'color': value.color, 'icon': value.icon},
  (meta, row) => Category(
    meta,
    name: row.text('name'),
    color: row.number('color'),
    icon: row.optionalText('icon'),
  ),
);

final _eventSeries = _Table<EventSeries>(
  'event_series',
  RecordKind.eventSeries,
  (value) => {
    'title': value.title,
    'recurrence_rule': value.recurrenceRule,
    'zone_id': value.zoneId,
    'time_mode': value.timeMode.name,
    'category_id': value.categoryId,
    'split_from_id': value.splitFromId,
    'template': value.template,
    'ends_before': value.endsBefore?.value,
  },
  (meta, row) => EventSeries(
    meta,
    title: row.text('title'),
    recurrenceRule: row.text('recurrence_rule'),
    zoneId: row.text('zone_id'),
    timeMode: TimeMode.values.byName(row.text('time_mode')),
    categoryId: row.optionalText('category_id'),
    splitFromId: row.optionalText('split_from_id'),
    template: row.optionalText('template'),
    endsBefore: row.day('ends_before'),
  ),
);

final _event = _Table<EventOccurrence>(
  'event_occurrences',
  RecordKind.eventOccurrence,
  (value) => {
    'title': value.title,
    'description': value.description,
    'buffer_before_us': value.bufferBefore?.inMicroseconds,
    'buffer_after_us': value.bufferAfter?.inMicroseconds,
    'availability': value.availability.name,
    'status': value.status.name,
    'category_id': value.categoryId,
    'series_id': value.seriesId,
    'recurrence_key': value.recurrenceKey,
    'supersedes_id': value.supersedesId,
    'routine_occurrence_id': value.routineOccurrenceId,
    'all_day_start': value.allDayStart?.value,
    'all_day_end_exclusive': value.allDayEndExclusive?.value,
    'details': jsonEncode({
      'location': value.details.location,
      'note': value.details.note,
      'link': value.details.link,
      'color': value.details.color,
      'reminders': value.details.reminders,
      'exception': value.details.isException,
      'warnings': value.details.warnings,
    }),
    ..._interval(value.schedule),
  },
  (meta, row) => EventOccurrence(
    meta,
    title: row.text('title'),
    schedule: _readInterval(row)!,
    availability: EventAvailability.values.byName(row.text('availability')),
    status: row.status,
    categoryId: row.optionalText('category_id'),
    seriesId: row.optionalText('series_id'),
    recurrenceKey: row.optionalText('recurrence_key'),
    supersedesId: row.optionalText('supersedes_id'),
    routineOccurrenceId: row.optionalText('routine_occurrence_id'),
    allDayStart: row.day('all_day_start'),
    allDayEndExclusive: row.day('all_day_end_exclusive'),
    description: row.optionalText('description'),
    bufferBefore: row.duration('buffer_before_us'),
    bufferAfter: row.duration('buffer_after_us'),
    details: _eventDetails(row.text('details')),
  ),
  parent: (value) => value.seriesId,
);

EventDetails _eventDetails(String encoded) {
  final fields = jsonDecode(encoded) as Map<String, dynamic>;
  return EventDetails(
    location: fields['location'] as String? ?? '',
    note: fields['note'] as String? ?? '',
    link: fields['link'] as String? ?? '',
    color: fields['color'] as String? ?? 'Biru',
    reminders:
        (fields['reminders'] as List<dynamic>?)?.cast<String>() ?? const [],
    isException: fields['exception'] as bool? ?? false,
    warnings:
        (fields['warnings'] as List<dynamic>?)?.cast<String>() ?? const [],
  );
}

final _task = _Table<Task>(
  'tasks',
  RecordKind.task,
  (value) => {
    'title': value.title,
    'category_id': value.categoryId,
    'description': value.description,
    'priority': value.priority,
    'status': value.status.name,
    'initial_estimate_us': value.initialEstimate?.inMicroseconds,
    'confirmed_remaining_us': value.confirmedRemainingEstimate?.inMicroseconds,
    'remaining_actual_us': value.remainingActualAtConfirmation?.inMicroseconds,
    'minimum_session_minutes': value.sessionLimits?.minimumMinutes,
    'maximum_sessions': value.sessionLimits?.maximumSessions,
    'remaining_confirmed_at_us': _instant(value.remainingConfirmedAt),
    'deadline_us': _instant(value.deadline?.instant),
    'deadline_zone': value.deadline?.zoneId,
    'deadline_mode': value.deadline?.mode.name,
    'deadline_local': _wallTime(value.deadline),
  },
  (meta, row) => Task(
    meta,
    title: row.text('title'),
    categoryId: row.optionalText('category_id'),
    description: row.optionalText('description'),
    priority: row.optionalText('priority'),
    status: row.status,
    initialEstimate: row.duration('initial_estimate_us'),
    confirmedRemainingEstimate: row.duration('confirmed_remaining_us'),
    remainingActualAtConfirmation: row.duration('remaining_actual_us'),
    sessionLimits: _sessionLimits(
      row.optionalNumber('minimum_session_minutes'),
      row.optionalNumber('maximum_sessions'),
    ),
    remainingConfirmedAt: row.optionalInstant('remaining_confirmed_at_us'),
    deadline: row['deadline_us'] == null
        ? null
        : ZonedTime(
            instant: row.instant('deadline_us'),
            zoneId: row.text('deadline_zone'),
            mode: TimeMode.values.byName(row.text('deadline_mode')),
            localWallTime: row.optionalText('deadline_local'),
          ),
  ),
);

final _subtask = _Table<Subtask>(
  'subtasks',
  RecordKind.subtask,
  (value) => {
    'task_id': value.taskId,
    'title': value.title,
    'sort_order': value.order,
    'checked': _bool(value.checked),
  },
  (meta, row) => Subtask(
    meta,
    taskId: row.text('task_id'),
    title: row.text('title'),
    order: row.number('sort_order'),
    checked: row.number('checked') == 1,
  ),
  parent: (value) => value.taskId,
);

final _workSession = _Table<WorkSession>(
  'work_sessions',
  RecordKind.workSession,
  (value) => {
    'task_id': value.taskId,
    'status': value.status.name,
    'supersedes_id': value.supersedesId,
    'routine_occurrence_id': value.routineOccurrenceId,
    ..._interval(value.schedule),
  },
  (meta, row) => WorkSession(
    meta,
    taskId: row.text('task_id'),
    schedule: _readInterval(row)!,
    status: row.status,
    supersedesId: row.optionalText('supersedes_id'),
    routineOccurrenceId: row.optionalText('routine_occurrence_id'),
  ),
  parent: (value) => value.taskId,
);

final _routine = _Table<Routine>(
  'routines',
  RecordKind.routine,
  (value) => {
    'title': value.title,
    'category_id': value.categoryId,
    'target_type': value.targetType.name,
    'target_amount': value.targetAmount,
    'target_duration_us': value.targetDuration?.inMicroseconds,
    'frequency_rule': value.frequencyRule,
    'checklist': jsonEncode(value.checklist),
    'preferred_time': value.preferredTime,
    'routine_time_mode': value.timeMode?.name,
  },
  (meta, row) => Routine(
    meta,
    title: row.text('title'),
    categoryId: row.optionalText('category_id'),
    targetType: RoutineTargetType.values.byName(row.text('target_type')),
    targetAmount: row.optionalNumber('target_amount'),
    targetDuration: row.duration('target_duration_us'),
    frequencyRule: row.optionalText('frequency_rule'),
    checklist: _readList(row, 'checklist'),
    preferredTime: row.optionalText('preferred_time'),
    timeMode: row['routine_time_mode'] == null
        ? null
        : TimeMode.values.byName(row.text('routine_time_mode')),
  ),
);

final _routineOccurrence = _Table<RoutineOccurrence>(
  'routine_occurrences',
  RecordKind.routineOccurrence,
  (value) => {
    'routine_id': value.routineId,
    'local_day': value.day.value,
    'status': value.status.name,
    'recorded_count': value.recordedCount,
    'checked_items': jsonEncode(value.checkedItems),
    'goal': value.goal == null ? null : _encodeRoutineGoal(value.goal!),
    ..._interval(value.schedule),
  },
  (meta, row) => RoutineOccurrence(
    meta,
    routineId: row.text('routine_id'),
    day: LocalDate.parse(row.text('local_day')),
    status: row.status,
    schedule: _readInterval(row),
    recordedCount: row.optionalNumber('recorded_count'),
    checkedItems: _readList(row, 'checked_items'),
    goal: row['goal'] == null ? null : _decodeRoutineGoal(row.text('goal')),
  ),
  parent: (value) => value.routineId,
);

String _encodeRoutineGoal(RoutineGoal goal) => jsonEncode({
  'type': goal.type.name,
  'amount': goal.amount,
  'durationUs': goal.duration?.inMicroseconds,
  'checklist': goal.checklist,
});

RoutineGoal _decodeRoutineGoal(String source) {
  final item = jsonDecode(source) as Map<String, dynamic>;
  final micros = item['durationUs'] as int?;
  return RoutineGoal(
    RoutineTargetType.values.byName(item['type'] as String),
    amount: item['amount'] as int?,
    duration: micros == null ? null : Duration(microseconds: micros),
    checklist: (item['checklist'] as List).cast<String>(),
  );
}

final _timeLog = _Table<TimeLog>(
  'time_logs',
  RecordKind.timeLog,
  (value) => {
    'target_id': value.target.id,
    'target_kind': value.target.kind.name,
    'recorded_at_us': _instant(value.recordedAt),
    'actual_us': value.actualDuration.inMicroseconds,
    'source': value.source.name,
    'started_at_us': _instant(value.startedAt),
    'ended_at_us': _instant(value.endedAt),
  },
  (meta, row) => TimeLog(
    meta,
    target: row.ref('target'),
    recordedAt: row.instant('recorded_at_us'),
    actualDuration: row.duration('actual_us')!,
    source: TimeLogSource.values.byName(row.text('source')),
    startedAt: row.optionalInstant('started_at_us'),
    endedAt: row.optionalInstant('ended_at_us'),
  ),
  parent: (value) => value.target.id,
);

final _reminder = _Table<ReminderRule>(
  'reminder_rules',
  RecordKind.reminderRule,
  (value) => {
    'target_id': value.target.id,
    'target_kind': value.target.kind.name,
    'anchor': value.anchor.name,
    'offset_us': value.offset.inMicroseconds,
    'enabled': _bool(value.enabled),
  },
  (meta, row) => ReminderRule(
    meta,
    target: row.ref('target'),
    anchor: ReminderAnchor.values.byName(row.text('anchor')),
    offset: row.duration('offset_us')!,
    enabled: row.number('enabled') == 1,
  ),
  parent: (value) => value.target.id,
);

final _statusHistory = _Table<StatusHistory>(
  'status_history',
  RecordKind.statusHistory,
  (value) => {
    'target_id': value.target.id,
    'target_kind': value.target.kind.name,
    'previous': value.previous.name,
    'status': value.status.name,
    'changed_at_us': _instant(value.changedAt),
    'replacement_id': value.replacement?.id,
    'replacement_kind': value.replacement?.kind.name,
  },
  (meta, row) => StatusHistory(
    meta,
    target: row.ref('target'),
    previous: ActivityStatus.values.byName(row.text('previous')),
    status: row.status,
    changedAt: row.instant('changed_at_us'),
    replacement: row['replacement_id'] == null ? null : row.ref('replacement'),
  ),
  parent: (value) => value.target.id,
);

final _trash = _Table<TrashEntry>(
  'trash_entries',
  RecordKind.trashEntry,
  (value) => {
    'target_id': value.target.id,
    'target_kind': value.target.kind.name,
    'deleted_at_us': _instant(value.deletedAt),
    'restored_at_us': _instant(value.restoredAt),
  },
  (meta, row) => TrashEntry(
    meta,
    target: row.ref('target'),
    deletedAt: row.instant('deleted_at_us'),
    restoredAt: row.optionalInstant('restored_at_us'),
  ),
);
