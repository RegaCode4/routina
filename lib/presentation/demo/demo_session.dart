import 'package:flutter/foundation.dart' show ChangeNotifier, VoidCallback;
import 'package:routina/application/planner_preview.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';

class DemoSlot {
  DemoSlot(
    this.start,
    this.minutes, {
    this.history = false,
    this.conflict = false,
    this.eventId,
    this.actual,
  });
  final DateTime start;
  final int minutes;
  final bool history;
  final bool conflict;
  final String? eventId;
  final int? actual;
  DateTime get end => start.add(Duration(minutes: minutes));
}

class DemoTask {
  DemoTask({
    this.id = '',
    this.title = '',
    this.date,
    this.time,
    this.category = 'Tanpa kategori',
    this.priority = 'Sedang',
    this.description = '',
    this.zone = 'WIB',
    this.reminder = 'Tanpa pengingat',
    this.estimate,
    this.remaining,
    this.completed = false,
    Map<String, bool>? checklist,
    List<DemoSlot>? slots,
  }) : checklist = {...?checklist},
       slots = [...?slots];

  String id;
  String? deadlineEventId;
  String title;
  DateTime? date;
  int? time;
  String category;
  String priority;
  String description;
  String zone;
  String reminder;
  int? estimate;
  int? remaining;
  bool completed;
  final Map<String, bool> checklist;
  final List<DemoSlot> slots;

  DateTime? get deadline => date == null || time == null
      ? null
      : dateOnly(date!).add(Duration(minutes: time!));
  int get checked => checklist.values.where((value) => value).length;
  int get actual => slots.fold(0, (total, slot) => total + (slot.actual ?? 0));
  List<DemoSlot> get upcoming => slots.where((slot) => !slot.history).toList();

  DemoTask copy() => DemoTask(
    id: id,
    title: title,
    date: date,
    time: time,
    category: category,
    priority: priority,
    description: description,
    zone: zone,
    reminder: reminder,
    estimate: estimate,
    remaining: remaining,
    completed: completed,
    checklist: checklist,
    slots: slots,
  )..deadlineEventId = deadlineEventId;
}

enum DemoRoutineType {
  duration('Durasi', 'menit'),
  amount('Jumlah', 'kali'),
  checklist('Checklist', 'item');

  const DemoRoutineType(this.label, this.unit);
  final String label;
  final String unit;
}

class DemoRoutine {
  DemoRoutine({
    this.id = '',
    this.title = '',
    this.type = DemoRoutineType.duration,
    this.goal = 20,
    this.actual = 0,
    this.frequency = 'Setiap hari',
    this.schedule = 'Pagi',
    this.timeMode,
    this.category = 'Tanpa kategori',
    this.reminder = 'Tanpa pengingat',
    this.completed = false,
    Map<String, bool>? checklist,
    List<({DateTime day, int value})>? log,
    Stopwatch? timer,
    this.timerOpened = false,
  }) : checklist = {...?checklist},
       log = [...?log],
       timer = timer ?? Stopwatch();

  String id;
  String title;
  DemoRoutineType type;
  int goal;
  int actual;
  String frequency;
  String schedule;
  TimeMode? timeMode;
  String category;
  String reminder;
  bool completed;
  final Map<String, bool> checklist;
  final List<({DateTime day, int value})> log;
  final Stopwatch timer;
  bool timerOpened;

  int get target => type == DemoRoutineType.checklist ? checklist.length : goal;
  int get progress => type == DemoRoutineType.checklist
      ? checklist.values.where((item) => item).length
      : actual;

  DemoRoutine copy() => DemoRoutine(
    id: id,
    title: title,
    type: type,
    goal: goal,
    actual: actual,
    frequency: frequency,
    schedule: schedule,
    timeMode: timeMode,
    category: category,
    reminder: reminder,
    completed: completed,
    checklist: checklist,
    log: log,
    timer: timer,
    timerOpened: timerOpened,
  );
}

enum DemoFeed { ready, empty, loading, error }

class DemoTrash {
  const DemoTrash({
    required this.id,
    required this.title,
    required this.kind,
    required this.deleted,
    this.task,
    this.routine,
    this.event,
  });
  final String id;
  final String title;
  final String kind;
  final DateTime deleted;
  final DemoTask? task;
  final DemoRoutine? routine;
  final PreviewEvent? event;
}

/// Session-only fixtures and mutations for interactive previews on SC-11–30.
class DemoSession extends ChangeNotifier {
  DemoSession(this.planner, this.scenario) {
    if (feed('tasks') != DemoFeed.empty) {
      tasks.addAll([
        DemoTask(
          id: 'deadline',
          title: 'Mengerjakan Laporan E-Commerce',
          date: today,
          time: 1020,
          category: 'Pekerjaan',
          priority: 'Tinggi',
          description: 'Rangkum penjualan dan siapkan bahan presentasi tim.',
          estimate: 120,
          remaining: switch (scenario) {
            'smart-surplus' => 30,
            'smart-balanced' => 45,
            _ => 90,
          },
          checklist: {
            'Kumpulkan data': true,
            'Susun kerangka': true,
            'Tulis rangkuman': false,
          },
          slots: [
            DemoSlot(
              shiftDay(today, -1).add(const Duration(hours: 10)),
              30,
              history: true,
              actual: 25,
            ),
            DemoSlot(
              shiftDay(today, 1).add(const Duration(hours: 10)),
              45,
              conflict:
                  scenario == 'smart-conflict' ||
                  scenario == 'smart-multi-conflict',
            ),
            if (scenario == 'smart-multi-conflict')
              DemoSlot(
                shiftDay(today, 1).add(const Duration(hours: 15)),
                45,
                conflict: true,
              ),
          ],
        ),
        DemoTask(
          id: 'sample-note',
          title: 'Rangkum materi Desain UI',
          date: shiftDay(today, -2),
          time: 960,
          category: 'Belajar',
          priority: 'Tinggi',
        ),
        DemoTask(
          id: 'sample-book',
          title: 'Beli buku catatan',
          date: shiftDay(today, 3),
          time: 1080,
          category: 'Pribadi',
          priority: 'Rendah',
        ),
        DemoTask(
          id: 'sample-done',
          title: 'Kirim ringkasan mingguan',
          date: shiftDay(today, -1),
          time: 840,
          completed: true,
          category: 'Pekerjaan',
        ),
      ]);
      final deadline = planner.events
          .where((entry) => entry.id == 'deadline')
          .firstOrNull;
      if (deadline != null) {
        tasks.first
          ..deadlineEventId = deadline.id
          ..date = dateOnly(deadline.start)
          ..time = minutesAt(deadline.start);
      }
    }
    if (feed('routines') != DemoFeed.empty) {
      final reading = DemoRoutine(
        id: 'study',
        title: 'Belajar Flutter',
        actual: 12,
        category: 'Belajar',
        log: [
          (day: shiftDay(today, -1), value: 20),
          (day: shiftDay(today, -2), value: 20),
        ],
      );
      if (scenario == 'routine-restored') {
        reading.timerOpened = true;
        reading.timer.start();
      }
      routines.addAll([
        reading,
        DemoRoutine(
          id: 'workout',
          title: 'Olahraga ringan',
          goal: 30,
          actual: 30,
          completed: true,
          frequency: 'Hari kerja',
          category: 'Pribadi',
        ),
        DemoRoutine(
          id: 'sample-water',
          title: 'Minum air putih',
          type: DemoRoutineType.amount,
          goal: 8,
          actual: scenario == 'routine-missed' ? 0 : 3,
          category: 'Pribadi',
        ),
      ]);
    }
    if (feed('trash') != DemoFeed.empty) {
      final task = DemoTask(
        id: 'deleted-task',
        title: 'Draf rencana bulanan',
        date: today,
        time: 960,
      );
      final routine = DemoRoutine(
        id: 'deleted-routine',
        title: 'Membaca 10 halaman',
      );
      trash.addAll([
        DemoTrash(
          id: task.id,
          title: task.title,
          kind: 'Tugas',
          deleted: shiftDay(today, -6),
          task: task,
        ),
        DemoTrash(
          id: routine.id,
          title: routine.title,
          kind: 'Rutinitas',
          deleted: shiftDay(today, -29),
          routine: routine,
        ),
      ]);
    }
    if (scenario == 'notifications-off') {
      permission = 'Ditolak';
    } else if (scenario.isNotEmpty &&
        scenario != 'notifications-not-requested' &&
        planner.profile?.notifications == true) {
      permission = 'Diizinkan';
    }
  }

  final PlannerPreviewRepository planner;
  final String scenario;
  final tasks = <DemoTask>[];
  final routines = <DemoRoutine>[];
  final trash = <DemoTrash>[];
  final removedEvents = <String>{};
  final dismissedFeeds = <String>{};
  String permission = 'Belum diminta';
  String? lastBackup;
  int _id = 0;
  int revision = 0;
  Future<void> _profileSave = Future.value();
  bool _disposed = false;

  DateTime get today => planner.today;
  PlannerPreferences get preferences =>
      planner.profile?.preferences ?? const PlannerPreferences();
  bool get quiet =>
      preferences.quietEnabled ?? (planner.profile?.quietHours != null);
  int get quietStart => planner.profile?.quietHours?.startMinute ?? 22 * 60;
  int get quietEnd => planner.profile?.quietHours?.endMinute ?? 7 * 60;
  int get buffer => planner.profile?.defaultBuffer?.inMinutes ?? 0;
  int? get backupReminder => preferences.backupReminderDays;
  List<Category> get categories => planner.categories;
  List<String> get categoryNames =>
      categories.map((category) => category.name).toList();
  String preferredTimeForCategory(String categoryName) {
    final profile = planner.profile;
    if (profile == null) return '';
    final category = categories
        .where((item) => item.name == categoryName)
        .firstOrNull;
    return profile.categoryTimes[category?.id] ?? profile.other;
  }

  Map<String, String> get eventCategories => {
    for (final category in categories)
      category.name: _colorName(category.color),
  };
  DemoTask? taskFor(String eventId) => tasks
      .where(
        (task) =>
            task.deadlineEventId == eventId ||
            task.slots.any((slot) => slot.eventId == eventId),
      )
      .firstOrNull;
  bool slotConflicts(DemoSlot slot) =>
      slot.conflict ||
      (!slot.history &&
          planner.events.any(
            (event) =>
                event.id != slot.eventId &&
                event.state != PreviewEventState.trashed &&
                event.kind != PreviewKind.deadline &&
                event.options.availability != DayAvailability.free &&
                slot.start
                    .subtract(Duration(minutes: buffer + event.options.after))
                    .isBefore(event.end) &&
                event.start.isBefore(
                  slot.end.add(
                    Duration(minutes: buffer + event.options.before),
                  ),
                ),
          ));
  DemoFeed feed(String name) => dismissedFeeds.contains(name)
      ? DemoFeed.ready
      : DemoFeed.values
                .where((value) => '$name-${value.name}' == scenario)
                .firstOrNull ??
            DemoFeed.ready;

  void change(VoidCallback mutation) {
    mutation();
    if (!_disposed) notifyListeners();
  }

  Future<void> updateProfile(PreviewProfile Function(PreviewProfile) edit) {
    final write = _profileSave.then((_) async {
      await planner.saveProfile(edit(planner.profile!));
      change(() => revision++);
    });
    _profileSave = write.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return write;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void retry(String name) => change(() => dismissedFeeds.add(name));

  void saveTask(DemoTask task) {
    change(() {
      if (task.id.isEmpty) task.id = 'demo-task-${++_id}';
      final position = tasks.indexWhere((item) => item.id == task.id);
      if (position < 0) {
        tasks.insert(0, task);
      } else {
        tasks[position] = task;
      }
      _syncDeadline(task);
      revision++;
    });
  }

  void _syncDeadline(DemoTask task) {
    if (task.deadline case final date?) {
      final saved = planner.saveEvent(
        PreviewEvent(
          id: task.deadlineEventId ?? '',
          title: task.title,
          start: date,
          end: date.add(const Duration(minutes: 1)),
          kind: PreviewKind.deadline,
          state: task.completed
              ? PreviewEventState.done
              : PreviewEventState.upcoming,
          options: EventOptions(category: task.category, zone: task.zone),
        ),
      );
      task.deadlineEventId = saved.id;
    } else if (task.deadlineEventId case final id?) {
      planner.setEventState(id, PreviewEventState.trashed);
      removedEvents.add(id);
    }
  }

  void saveRoutine(DemoRoutine routine) {
    change(() {
      if (routine.id.isEmpty) routine.id = 'demo-routine-${++_id}';
      final index = routines.indexWhere((item) => item.id == routine.id);
      if (index < 0) {
        routines.insert(0, routine);
      } else {
        routines[index] = routine;
      }
    });
  }

  void completeRoutine(DemoRoutine routine) => change(() {
    routine.completed = true;
    routine.log.insert(0, (day: today, value: routine.progress));
    _setExistingEventState(routine.id, PreviewEventState.done);
  });

  void discardTask(DemoTask task) => change(() {
    tasks.remove(task);
    trash.insert(
      0,
      DemoTrash(
        id: task.id,
        title: task.title,
        kind: 'Tugas',
        deleted: today,
        task: task,
      ),
    );
    if (task.deadlineEventId case final id?) {
      planner.setEventState(id, PreviewEventState.trashed);
      removedEvents.add(id);
    }
    for (final slot in task.upcoming) {
      if (slot.eventId case final id?) {
        planner.setEventState(id, PreviewEventState.trashed);
        removedEvents.add(id);
      }
    }
    revision++;
  });

  void discardRoutine(DemoRoutine routine) => change(() {
    routine.timer.stop();
    routines.remove(routine);
    trash.insert(
      0,
      DemoTrash(
        id: routine.id,
        title: routine.title,
        kind: 'Rutinitas',
        deleted: today,
        routine: routine,
      ),
    );
    _setExistingEventState(routine.id, PreviewEventState.trashed);
    removedEvents.add(routine.id);
  });

  List<DemoTrash> get bin => [
    ...trash,
    for (final event in planner.events)
      if (event.state == PreviewEventState.trashed &&
          !removedEvents.contains(event.id))
        DemoTrash(
          id: event.id,
          title: event.title,
          kind: 'Kegiatan',
          deleted: today,
          event: event,
        ),
  ];

  void restore(DemoTrash entry, {DateTime? moveTo}) {
    change(() {
      trash.remove(entry);
      if (entry.task case final task?) {
        task.date = moveTo ?? task.date;
        tasks.insert(0, task);
        _syncDeadline(task);
        for (final slot in task.upcoming) {
          if (slot.eventId case final id?) {
            planner.setEventState(id, PreviewEventState.upcoming);
          }
        }
      }
      if (entry.routine case final routine?) {
        routines.insert(0, routine);
        _setExistingEventState(routine.id, PreviewEventState.upcoming);
      }
      if (entry.event case final event?) {
        if (moveTo == null) {
          planner.setEventState(event.id, PreviewEventState.upcoming);
        } else {
          final start = moveTo.add(Duration(minutes: minutesAt(event.start)));
          planner.saveEvent(
            PreviewEvent(
              id: event.id,
              title: event.title,
              start: start,
              end: start.add(event.end.difference(event.start)),
              kind: event.kind,
              options: event.options,
              series: event.series,
            ),
          );
        }
      }
      revision++;
    });
  }

  void removePermanently(DemoTrash entry) => change(() {
    trash.remove(entry);
    removedEvents.add(entry.id);
  });

  void _setExistingEventState(String id, PreviewEventState state) {
    if (planner.events.any((event) => event.id == id)) {
      planner.setEventState(id, state);
    }
  }

  void completeTask(DemoTask task, {required bool cancelFuture}) {
    change(() {
      if (cancelFuture) removeSlots(task, task.upcoming);
      task.completed = true;
      _syncDeadline(task);
      revision++;
    });
  }

  void removeSlots(DemoTask task, Iterable<DemoSlot> slots) {
    for (final slot in slots.toList()) {
      task.slots.remove(slot);
      if (slot.eventId case final id?) {
        planner.setEventState(id, PreviewEventState.trashed);
        removedEvents.add(id);
      }
    }
  }

  void applySlots(
    DemoTask task,
    List<DemoSlot> slots, {
    List<DemoSlot> replace = const [],
  }) => change(() {
    removeSlots(task, replace);
    for (final slot in slots) {
      final saved = planner.saveEvent(
        PreviewEvent(
          id: 'demo-slot-${++_id}',
          title: task.title,
          start: slot.start,
          end: slot.end,
          kind: PreviewKind.session,
          options: EventOptions(category: task.category),
        ),
      );
      task.slots.add(DemoSlot(slot.start, slot.minutes, eventId: saved.id));
    }
    revision++;
  });

  Future<void> saveCategory(Category category) async {
    final previous = categories
        .where((item) => item.id == category.id)
        .firstOrNull;
    final saved = await planner.saveCategory(category);
    change(() {
      if (previous != null) {
        _reassign(previous.name, saved.name, color: _colorName(saved.color));
      }
    });
  }

  Future<void> deleteCategory(
    Category category, {
    Category? replacement,
  }) async {
    await planner.deleteCategory(category, replacement: replacement);
    change(
      () => _reassign(
        category.name,
        replacement?.name ?? 'Tanpa kategori',
        color: replacement == null ? null : _colorName(replacement.color),
      ),
    );
  }

  void _reassign(String before, String after, {String? color}) {
    planner.reassignCategory(
      before,
      after == 'Tanpa kategori' ? '' : after,
      color: color,
    );
    for (final task in [...tasks, ...trash.map((item) => item.task).nonNulls]) {
      if (task.category == before) task.category = after;
    }
    for (final routine in [
      ...routines,
      ...trash.map((item) => item.routine).nonNulls,
    ]) {
      if (routine.category == before) routine.category = after;
    }
  }
}

String _colorName(int color) =>
    previewCategoryPalette.entries
        .where((entry) => entry.value == color)
        .firstOrNull
        ?.key ??
    'Biru';
