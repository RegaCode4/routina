import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/activity_search.dart';
import 'package:routina/application/calendar_zones.dart';
import 'package:routina/application/routine_workspace.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';

DateTime _date(int day, [int hour = 0]) => DateTime.utc(2026, 11, day, hour);

PreviewEvent _event(
  String id,
  DateTime start,
  DateTime end, {
  String? categoryId = 'work',
  PreviewEventState state = PreviewEventState.done,
  PreviewKind kind = PreviewKind.activity,
  DateTime? instant,
}) => PreviewEvent(
  id: id,
  title: 'Rapat $id',
  start: start,
  end: end,
  categoryId: categoryId,
  state: state,
  kind: kind,
  startInstant: instant,
);

void main() {
  test('calendar sorts repeated wall hours by their actual instants', () {
    final first = _event(
      'awal',
      _date(1, 1).add(const Duration(minutes: 45)),
      _date(1, 2),
      instant: _date(1, 5).add(const Duration(minutes: 45)),
    );
    final second = _event(
      'akhir',
      _date(1, 1).add(const Duration(minutes: 15)),
      _date(1, 2),
      instant: _date(1, 6).add(const Duration(minutes: 15)),
    );
    expect(searchCalendar([second, first], title: ''), [first, second]);
  });

  test('calendar composes title, stable category, status, day and order', () {
    final overnight = _event('malam', _date(16, 23), _date(17, 1));
    final morning = _event('pagi', _date(17, 8), _date(17, 9));
    final outside = _event('sebelumnya', _date(16, 8), _date(17));
    final uncategorized = _event(
      'bebas',
      _date(17, 10),
      _date(17, 11),
      categoryId: null,
    );
    final archived = _event(
      'arsip',
      _date(17, 12),
      _date(17, 13),
      state: PreviewEventState.trashed,
    );
    final pending = _event(
      'tunggu',
      _date(17, 10),
      _date(17, 11),
      state: PreviewEventState.pending,
    );
    final entries = [
      overnight,
      morning,
      outside,
      uncategorized,
      archived,
      pending,
    ];
    expect(
      searchCalendar(
        entries,
        title: '  RAPAT ',
        categoryId: 'work',
        status: CalendarStatus.completed,
        day: _date(17),
        order: AgendaOrder.reverseChronological,
      ),
      [morning, overnight],
    );
    expect(searchCalendar(entries, title: '', categoryId: ''), [uncategorized]);
    expect(searchCalendar(entries, title: 'xyz'), isEmpty);
    expect(searchCalendar(entries, title: 'arsip'), isEmpty);
  });

  test(
    'calendar respects half-open periods and distinguishes overdue deadlines',
    () {
      final pending = _event(
        'event',
        _date(17, 8),
        _date(17, 9),
        state: PreviewEventState.pending,
      );
      final overdue = _event(
        'task',
        _date(17, 8),
        _date(17, 9),
        state: PreviewEventState.pending,
        kind: PreviewKind.deadline,
      );
      final startsAtEnd = _event('next', _date(18), _date(18, 1));
      final entries = [pending, overdue, startsAtEnd];
      expect(
        searchCalendar(entries, title: '', status: CalendarStatus.overdue),
        [overdue],
      );
      expect(
        searchCalendar(entries, title: '', status: CalendarStatus.pending),
        [pending],
      );
      expect(
        searchCalendar(
          entries,
          title: '',
          period: (from: _date(17), until: _date(18)),
        ),
        [pending, overdue],
      );
    },
  );

  test(
    'routine filters use occurrence status and put unscheduled routines last',
    () {
      final zones = CalendarZones(
        deviceZoneId: 'Asia/Jakarta',
        displayZoneId: 'UTC',
      );
      RoutineView row(
        String title,
        int? hour, {
        String? categoryId = 'gym',
        ActivityStatus status = ActivityStatus.completed,
        bool floating = false,
        int count = 0,
      }) {
        final routine = Routine(
          RecordMetadata.create(),
          title: title,
          targetType: RoutineTargetType.count,
          targetAmount: 2,
          categoryId: categoryId,
        );
        return RoutineView(
          routine: routine,
          day: _date(17),
          occurrence: RoutineOccurrence(
            RecordMetadata.create(),
            routineId: routine.id,
            day: LocalDate.parse('2026-11-17'),
            schedule: hour == null
                ? null
                : zones.interval(
                    _date(17, hour),
                    _date(17, hour + 1),
                    floating ? 'Asia/Jakarta' : 'UTC',
                    floating ? TimeMode.localWallTime : TimeMode.originalZone,
                  ),
            status: status,
            recordedCount: count,
          ),
          logs: const [],
          timer: null,
          weeklyCount: 0,
          activeDay: null,
        );
      }

      final early = row('Lari lokal', 10, floating: true);
      final late = row('Lari tetap', 8);
      final unscheduled = row('Lari bebas', null);
      final other = row('Lari lain', 9, categoryId: 'other');
      final goalReached = row(
        'Lari target',
        10,
        status: ActivityStatus.planned,
        count: 2,
      );
      final now = _date(17, 12);
      expect(goalReached.statusAt(now), RoutineStatus.pending);
      expect(
        searchRoutines(
          [other, goalReached, unscheduled, early, late],
          title: '  LaRi ',
          categoryId: 'gym',
          status: RoutineStatus.completed,
          order: AgendaOrder.reverseChronological,
          zones: zones,
          now: now,
        ),
        [late, early, unscheduled],
      );
    },
  );
}
