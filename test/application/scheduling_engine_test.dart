import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/calendar_zones.dart';
import 'package:routina/domain/scheduling_engine.dart';

void main() {
  final anchor = DateTime.utc(2026, 11, 16, 8);
  Duration minutes(int value) => Duration(minutes: value);
  SchedulingSlot slot(int from, int until) =>
      (start: anchor.add(minutes(from)), end: anchor.add(minutes(until)));
  BusyInterval busy(int from, int until, {int before = 0, int after = 0}) => (
    id: 'busy-$from',
    title: 'Busy',
    slot: slot(from, until),
    before: minutes(before),
    after: minutes(after),
  );

  SlotSearchResult search({
    List<SchedulingSlot>? active,
    List<BusyInterval> blocked = const [],
    List<SchedulingSlot> preferred = const [],
    int target = 50,
    int minimum = 10,
    int maximum = 3,
    int buffer = 0,
  }) => findWorkSlots(
    active: active ?? [slot(0, 120)],
    busy: blocked,
    duration: minutes(target),
    minimum: minutes(minimum),
    maximum: maximum,
    before: minutes(buffer),
    after: minutes(buffer),
    preferred: preferred,
  );

  test(
    'single session prefers the requested period and uses exact boundaries',
    () {
      final result = search(
        active: [slot(0, 80), slot(100, 220)],
        preferred: [slot(5, 15), slot(125, 175)],
      );
      expect(result.slots, [slot(125, 175)]);
      final boundary = search(
        blocked: [busy(65, 70, before: 10)],
        target: 50,
        buffer: 5,
      );
      expect(boundary.slots, [slot(0, 50)]);
    },
  );

  test(
    'split chooses a feasible subset and avoids a final fragment below minimum',
    () {
      final result = search(
        active: [slot(0, 35), slot(60, 120), slot(150, 205)],
        preferred: [slot(0, 35)],
        target: 100,
        minimum: 45,
        maximum: 2,
      );
      expect(result.slots, [slot(60, 115), slot(150, 195)]);
      expect(totalSlotDuration(result.slots), minutes(100));
    },
  );

  test(
    'overlapping Busy intervals with asymmetric buffers merge without double-counting',
    () {
      final result = search(
        active: [slot(0, 180)],
        blocked: [busy(35, 60, before: 5, after: 5), busy(50, 100, after: 20)],
        target: 80,
        buffer: 5,
      );
      expect(result.slots, [slot(0, 25), slot(125, 180)]);
    },
  );

  test(
    'a preferred split window is kept when a larger partner makes it viable',
    () {
      final result = search(
        active: [slot(0, 60), slot(70, 110), slot(120, 200), slot(210, 280)],
        preferred: [slot(0, 60), slot(70, 110)],
        target: 120,
        minimum: 20,
        maximum: 2,
      );
      expect(result.slots, [slot(0, 60), slot(120, 180)]);
    },
  );

  test(
    'failure distinguishes hours, occupancy, buffer, minimum, maximum and capacity',
    () {
      expect(search(active: []).failure, SlotFailure.activeHours);
      expect(search(blocked: [busy(-10, 120)]).failure, SlotFailure.busy);
      expect(
        search(
          active: [slot(0, 60)],
          blocked: [busy(60, 80)],
          buffer: 15,
        ).failure,
        SlotFailure.buffer,
      );
      expect(search(active: [slot(0, 45)]).failure, SlotFailure.insufficient);
      final gaps = [slot(0, 30), slot(40, 70), slot(80, 110)];
      expect(search(active: gaps, minimum: 31).failure, SlotFailure.minimum);
      expect(search(active: gaps, maximum: 1).failure, SlotFailure.maximum);
      expect(search(active: gaps, minimum: 26).failure, SlotFailure.minimum);
      expect(search(active: gaps, target: 0).slots, isEmpty);
    },
  );

  test(
    'sessions on adjacent active days keep both buffers and use alternative windows',
    () {
      final windows = [slot(0, 60), slot(60, 120), slot(140, 200)];
      final exact = search(
        active: windows,
        target: 120,
        minimum: 50,
        maximum: 2,
        buffer: 5,
      );
      expect(exact.slots, [slot(0, 60), slot(140, 200)]);
      final trim = search(
        active: windows.take(2).toList(),
        target: 110,
        maximum: 2,
        buffer: 5,
      );
      expect(trim.slots, [slot(0, 60), slot(70, 120)]);
      expect(
        search(
          active: windows.take(2).toList(),
          target: 111,
          maximum: 2,
          buffer: 5,
        ).failure,
        SlotFailure.buffer,
      );
    },
  );

  test(
    'small randomized calendars agree with exhaustive minute-level feasibility',
    () {
      final random = Random(721);
      for (var trial = 0; trial < 240; trial++) {
        final windows = [slot(0, 5), slot(5, 10), slot(11, 15)];
        final blocked = [
          for (var i = 0; i < 2; i++)
            if (random.nextBool())
              busy(i * 7 + random.nextInt(4), i * 7 + 5 + random.nextInt(3)),
        ];
        final target = random.nextInt(12) + 1;
        final minimum = random.nextInt(4) + 1;
        final maximum = random.nextInt(4) + 1;
        final buffer = random.nextInt(3);
        final candidates = [
          for (var start = 0; start < 15; start++)
            for (var end = start + minimum; end <= 15; end++)
              if (windows.any((item) => containsSlot(item, slot(start, end))) &&
                  !blocked.any(
                    (item) => overlapsSlot(
                      slot(start, end),
                      bufferedSlot(
                        item,
                        before: minutes(buffer),
                        after: minutes(buffer),
                      ),
                    ),
                  ))
                (start: start, end: end),
        ];
        bool feasible(int from, int left, int count) =>
            left == 0 ||
            (count > 0 &&
                candidates.any(
                  (item) =>
                      item.start >= from &&
                      item.end - item.start <= left &&
                      feasible(
                        item.end + 2 * buffer,
                        left - (item.end - item.start),
                        count - 1,
                      ),
                ));
        final result = search(
          active: windows,
          blocked: blocked,
          target: target,
          minimum: minimum,
          maximum: maximum,
          buffer: buffer,
        );
        expect(
          result.failure == null,
          feasible(0, target, maximum),
          reason: 'trial $trial',
        );
        if (result.failure != null) continue;
        expect(totalSlotDuration(result.slots), minutes(target));
        expect(result.slots.length, lessThanOrEqualTo(maximum));
        for (final (i, item) in result.slots.indexed) {
          expect(slotDuration(item), greaterThanOrEqualTo(minutes(minimum)));
          expect(windows.any((window) => containsSlot(window, item)), isTrue);
          expect(
            blocked.any(
              (row) => overlapsSlot(
                bufferedSlot(
                  row,
                  before: minutes(buffer),
                  after: minutes(buffer),
                ),
                item,
              ),
            ),
            isFalse,
          );
          if (i > 0) {
            expect(
              item.start.difference(result.slots[i - 1].end),
              greaterThanOrEqualTo(minutes(2 * buffer)),
            );
          }
        }
      }
    },
  );

  test(
    'DST wall windows repeat only allowed minutes and remove skipped minutes',
    () {
      final zones = CalendarZones(
        deviceZoneId: 'America/New_York',
        displayZoneId: 'Asia/Jakarta',
      );
      final fall = schedulingWindows(
        zones,
        {DateTime.sunday: (startMinute: 90, endMinute: 105)},
        (start: DateTime.utc(2026, 11, 1), end: DateTime.utc(2026, 11, 2)),
      );
      expect(fall, [
        (
          start: DateTime.utc(2026, 11, 1, 5, 30),
          end: DateTime.utc(2026, 11, 1, 5, 45),
        ),
        (
          start: DateTime.utc(2026, 11, 1, 6, 30),
          end: DateTime.utc(2026, 11, 1, 6, 45),
        ),
      ]);
      final spring = schedulingWindows(
        zones,
        {DateTime.sunday: (startMinute: 90, endMinute: 210)},
        (start: DateTime.utc(2026, 3, 8), end: DateTime.utc(2026, 3, 9)),
      );
      expect(totalSlotDuration(spring), minutes(60));
    },
  );

  test(
    'dense adjacent windows reject an impossible maximum without subset enumeration',
    () {
      final dense = List.generate(48, (i) => slot(i * 60, (i + 1) * 60));
      expect(
        search(
          active: dense,
          target: 25 * 60,
          minimum: 10,
          maximum: 25,
          buffer: 5,
        ).failure,
        SlotFailure.buffer,
      );
      expect(
        search(
          active: dense,
          target: 24 * 60,
          minimum: 10,
          maximum: 24,
          buffer: 5,
        ).slots,
        hasLength(24),
      );
    },
  );
}
