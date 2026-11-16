import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/task_workspace.dart';
import 'package:routina/domain/planner_records.dart';

void main() {
  test(
    'checklist, session plan, actual logs and task status are independent',
    () {
      const task = Task(
        RecordMetadata(id: 'task'),
        title: 'Tugas',
        confirmedRemainingEstimate: Duration(minutes: 25),
      );
      final now = DateTime.utc(2026, 11, 16, 8);
      final schedule = ScheduledInterval(
        ZonedTime(instant: now, zoneId: 'UTC', mode: TimeMode.originalZone),
        ZonedTime(
          instant: now.add(const Duration(hours: 1)),
          zoneId: 'UTC',
          mode: TimeMode.originalZone,
        ),
      );
      final session = WorkSession(
        const RecordMetadata(id: 'session'),
        taskId: task.id,
        schedule: schedule,
      );
      final view = TaskView(
        task: task,
        subtasks: [
          Subtask(
            const RecordMetadata(id: 'subtask'),
            taskId: task.id,
            title: 'Subtugas',
            checked: true,
          ),
        ],
        sessions: [session],
        logs: [
          TimeLog(
            const RecordMetadata(id: 'log'),
            target: (kind: RecordKind.workSession, id: session.id),
            actualDuration: const Duration(minutes: 35),
            recordedAt: now,
            source: TimeLogSource.manual,
          ),
        ],
        reminders: const [],
        deadline: null,
        displayDeadline: null,
        upcoming: const [],
        overdue: false,
      );

      expect(view.progress, 1);
      expect(view.completed, isFalse);
      expect(view.planned, const Duration(hours: 1));
      expect(view.actual, const Duration(minutes: 35));
      expect(view.task.confirmedRemainingEstimate, const Duration(minutes: 25));
    },
  );
}
