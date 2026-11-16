import 'dart:math';

enum RecordKind {
  profile,
  category,
  eventSeries,
  eventOccurrence,
  task,
  subtask,
  workSession,
  routine,
  routineOccurrence,
  timeLog,
  reminderRule,
  statusHistory,
  trashEntry,
}

typedef RecordRef = ({RecordKind kind, String id});

class RecordMetadata {
  const RecordMetadata({
    required this.id,
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory RecordMetadata.create() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return RecordMetadata(
      id: '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}',
    );
  }

  final String id;
  final int revision;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

abstract class PlannerRecord {
  const PlannerRecord(this.metadata);
  final RecordMetadata metadata;
  String get id => metadata.id;
}

enum TimeMode { originalZone, localWallTime }

enum ActivityStatus { planned, completed, postponed, skipped, cancelled }

enum EventAvailability { timed, allDayBusy, allDayFree }

enum RoutineTargetType { duration, count, checklist, frequency }

enum TimeLogSource { manual, timer }

enum ReminderAnchor { start, deadline, confirmation }

class LocalDate {
  LocalDate(int year, int month, int day)
    : value =
          '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}' {
    final resolved = DateTime.utc(year, month, day);
    if (year < 1 ||
        year > 9999 ||
        resolved.year != year ||
        resolved.month != month ||
        resolved.day != day) {
      throw ArgumentError('Invalid local date');
    }
  }

  factory LocalDate.parse(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw FormatException('Invalid local date', value);
    }
    final parts = value.split('-').map(int.parse).toList();
    return LocalDate(parts[0], parts[1], parts[2]);
  }

  final String value;
}

class ZonedTime {
  const ZonedTime({
    required this.instant,
    required this.zoneId,
    required this.mode,
    this.localWallTime,
  });

  final DateTime instant;
  final String zoneId;
  final TimeMode mode;

  /// ISO local date/time without an offset. Required for floating schedules.
  final String? localWallTime;
}

class ScheduledInterval {
  ScheduledInterval(this.start, this.end) {
    if (!start.instant.isBefore(end.instant) ||
        start.zoneId != end.zoneId ||
        start.mode != end.mode) {
      throw ArgumentError('Invalid scheduled interval');
    }
  }

  final ZonedTime start;
  final ZonedTime end;
  Duration get duration => end.instant.difference(start.instant);
}

typedef DailyHours = ({int startMinute, int endMinute});

enum ReminderKind { event, deadline, workSession, routine }

class PlannerPreferences {
  const PlannerPreferences({
    this.calendarZoneId,
    this.eventTimeMode = TimeMode.originalZone,
    this.routineTimeMode = TimeMode.localWallTime,
    this.deadlineTimeMode = TimeMode.originalZone,
    this.quietEnabled,
    this.reminderTypes = const {},
    this.quietExceptions = const {},
    this.quietExceptionsEnabled = false,
    this.backupReminderDays,
  });

  final String? calendarZoneId;
  final TimeMode eventTimeMode;
  final TimeMode routineTimeMode;
  final TimeMode deadlineTimeMode;
  final bool? quietEnabled;
  final Map<ReminderKind, bool> reminderTypes;
  final Set<ReminderKind> quietExceptions;
  final bool quietExceptionsEnabled;
  final int? backupReminderDays;

  PlannerPreferences copyWith({
    String? calendarZoneId,
    bool useDeviceZone = false,
    TimeMode? eventTimeMode,
    TimeMode? routineTimeMode,
    TimeMode? deadlineTimeMode,
    bool? quietEnabled,
    Map<ReminderKind, bool>? reminderTypes,
    Set<ReminderKind>? quietExceptions,
    bool? quietExceptionsEnabled,
    int? backupReminderDays,
    bool disableBackupReminder = false,
  }) => PlannerPreferences(
    calendarZoneId: useDeviceZone
        ? null
        : calendarZoneId ?? this.calendarZoneId,
    eventTimeMode: eventTimeMode ?? this.eventTimeMode,
    routineTimeMode: routineTimeMode ?? this.routineTimeMode,
    deadlineTimeMode: deadlineTimeMode ?? this.deadlineTimeMode,
    quietEnabled: quietEnabled ?? this.quietEnabled,
    reminderTypes: reminderTypes ?? this.reminderTypes,
    quietExceptions: quietExceptions ?? this.quietExceptions,
    quietExceptionsEnabled:
        quietExceptionsEnabled ?? this.quietExceptionsEnabled,
    backupReminderDays: disableBackupReminder
        ? null
        : backupReminderDays ?? this.backupReminderDays,
  );
}

class Profile extends PlannerRecord {
  Profile(
    super.metadata, {
    this.name,
    this.notificationsEnabled,
    this.weekStartsOn,
    this.defaultBuffer,
    this.quietHours,
    this.onboardingStep = 0,
    this.onboardingCompleted = true,
    this.preferences = const PlannerPreferences(),
    Map<int, DailyHours> activeHours = const {},
    Map<String, String> activityPreferences = const {},
  }) : activeHours = Map.unmodifiable(activeHours),
       activityPreferences = Map.unmodifiable(activityPreferences);

  final String? name;
  final bool? notificationsEnabled;
  final int? weekStartsOn;
  final Duration? defaultBuffer;
  final DailyHours? quietHours;
  final int onboardingStep;
  final bool onboardingCompleted;
  final PlannerPreferences preferences;
  final Map<int, DailyHours> activeHours;
  final Map<String, String> activityPreferences;
}

class Category extends PlannerRecord {
  const Category(
    super.metadata, {
    required this.name,
    required this.color,
    this.icon,
  });
  final String name;
  final int color;
  final String? icon;
}

class EventSeries extends PlannerRecord {
  const EventSeries(
    super.metadata, {
    required this.title,
    required this.recurrenceRule,
    required this.zoneId,
    required this.timeMode,
    this.categoryId,
    this.splitFromId,
  });

  final String title;
  final String recurrenceRule;
  final String zoneId;
  final TimeMode timeMode;
  final String? categoryId;
  final String? splitFromId;
}

class EventOccurrence extends PlannerRecord {
  const EventOccurrence(
    super.metadata, {
    required this.title,
    required this.schedule,
    this.availability = EventAvailability.timed,
    this.status = ActivityStatus.planned,
    this.categoryId,
    this.seriesId,
    this.recurrenceKey,
    this.supersedesId,
    this.routineOccurrenceId,
    this.allDayStart,
    this.allDayEndExclusive,
    this.description,
    this.bufferBefore,
    this.bufferAfter,
  });

  final String title;
  final ScheduledInterval schedule;
  final EventAvailability availability;
  final ActivityStatus status;
  final String? categoryId;
  final String? seriesId;
  final String? recurrenceKey;
  final String? supersedesId;
  final String? routineOccurrenceId;
  final LocalDate? allDayStart;
  final LocalDate? allDayEndExclusive;
  final String? description;
  final Duration? bufferBefore;
  final Duration? bufferAfter;
}

class Task extends PlannerRecord {
  const Task(
    super.metadata, {
    required this.title,
    this.deadline,
    this.categoryId,
    this.description,
    this.priority,
    this.status = ActivityStatus.planned,
    this.initialEstimate,
    this.confirmedRemainingEstimate,
    this.remainingConfirmedAt,
  });

  final String title;
  final ZonedTime? deadline;
  final String? categoryId;
  final String? description;
  final String? priority;
  final ActivityStatus status;
  final Duration? initialEstimate;
  final Duration? confirmedRemainingEstimate;
  final DateTime? remainingConfirmedAt;
}

class Subtask extends PlannerRecord {
  const Subtask(
    super.metadata, {
    required this.taskId,
    required this.title,
    this.order = 0,
    this.checked = false,
  });

  final String taskId;
  final String title;
  final int order;
  final bool checked;
}

class WorkSession extends PlannerRecord {
  const WorkSession(
    super.metadata, {
    required this.taskId,
    required this.schedule,
    this.status = ActivityStatus.planned,
    this.supersedesId,
    this.routineOccurrenceId,
  });

  final String taskId;
  final ScheduledInterval schedule;
  final ActivityStatus status;
  final String? supersedesId;
  final String? routineOccurrenceId;

  Duration get scheduledDuration => schedule.duration;
}

class Routine extends PlannerRecord {
  Routine(
    super.metadata, {
    required this.title,
    required this.targetType,
    this.targetAmount,
    this.targetDuration,
    this.frequencyRule,
    this.categoryId,
    List<String> checklist = const [],
  }) : checklist = List.unmodifiable(checklist);

  final String title;
  final RoutineTargetType targetType;
  final int? targetAmount;
  final Duration? targetDuration;
  final String? frequencyRule;
  final String? categoryId;
  final List<String> checklist;
}

class RoutineOccurrence extends PlannerRecord {
  RoutineOccurrence(
    super.metadata, {
    required this.routineId,
    required this.day,
    this.schedule,
    this.status = ActivityStatus.planned,
    this.recordedCount,
    List<String> checkedItems = const [],
  }) : checkedItems = List.unmodifiable(checkedItems);

  final String routineId;
  final LocalDate day;
  final ScheduledInterval? schedule;
  final ActivityStatus status;
  final int? recordedCount;
  final List<String> checkedItems;
}

class TimeLog extends PlannerRecord {
  const TimeLog(
    super.metadata, {
    required this.target,
    required this.actualDuration,
    required this.recordedAt,
    required this.source,
    this.startedAt,
    this.endedAt,
  });

  final RecordRef target;
  final Duration actualDuration;
  final DateTime recordedAt;
  final TimeLogSource source;
  final DateTime? startedAt;
  final DateTime? endedAt;
}

class ReminderRule extends PlannerRecord {
  const ReminderRule(
    super.metadata, {
    required this.target,
    required this.anchor,
    required this.offset,
    required this.enabled,
  });

  final RecordRef target;
  final ReminderAnchor anchor;
  final Duration offset;
  final bool enabled;
}

class StatusHistory extends PlannerRecord {
  const StatusHistory(
    super.metadata, {
    required this.target,
    required this.previous,
    required this.status,
    required this.changedAt,
    this.replacement,
  });

  final RecordRef target;
  final ActivityStatus previous;
  final ActivityStatus status;
  final DateTime changedAt;
  final RecordRef? replacement;
}

class TrashEntry extends PlannerRecord {
  const TrashEntry(
    super.metadata, {
    required this.target,
    required this.deletedAt,
    this.restoredAt,
  });

  final RecordRef target;
  final DateTime deletedAt;
  final DateTime? restoredAt;
}

enum CalendarEntryKind { event, deadline, workSession, routine }

class CalendarEntry {
  const CalendarEntry({
    required this.kind,
    required this.id,
    required this.obligationId,
    required this.title,
    required this.start,
    required this.status,
    this.end,
    this.categoryId,
    this.availability,
  });

  final CalendarEntryKind kind;
  final String id;

  /// Shared by representations of the same obligation.
  final String obligationId;
  final String title;
  final DateTime start;

  /// Null for a deadline, which is a point in time.
  final DateTime? end;
  final ActivityStatus status;
  final String? categoryId;
  final EventAvailability? availability;
}
