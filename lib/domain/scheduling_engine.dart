import 'dart:math' as math;

typedef SchedulingSlot = ({DateTime start, DateTime end});

typedef BusyInterval = ({
  String id,
  String title,
  SchedulingSlot slot,
  Duration before,
  Duration after,
});

enum SlotFailure { activeHours, busy, buffer, insufficient, minimum, maximum }

Duration slotDuration(SchedulingSlot slot) => slot.end.difference(slot.start);

Duration totalSlotDuration(Iterable<SchedulingSlot> slots) =>
    slots.fold(Duration.zero, (total, slot) => total + slotDuration(slot));

bool containsSlot(SchedulingSlot window, SchedulingSlot slot) =>
    !slot.start.isBefore(window.start) && !slot.end.isAfter(window.end);

bool overlapsSlot(SchedulingSlot a, SchedulingSlot b) =>
    a.start.isBefore(b.end) && b.start.isBefore(a.end);

SchedulingSlot bufferedSlot(
  BusyInterval interval, {
  Duration before = Duration.zero,
  Duration after = Duration.zero,
}) => (
  start: interval.slot.start.subtract(interval.before + after),
  end: interval.slot.end.add(interval.after + before),
);

SchedulingSlot? intersectSlots(SchedulingSlot a, SchedulingSlot b) {
  final start = a.start.isAfter(b.start) ? a.start : b.start;
  final end = a.end.isBefore(b.end) ? a.end : b.end;
  return start.isBefore(end) ? (start: start, end: end) : null;
}

class SlotSearchResult {
  const SlotSearchResult({
    this.slots = const [],
    this.failure,
    this.available = Duration.zero,
  });

  final List<SchedulingSlot> slots;
  final SlotFailure? failure;
  final Duration available;
}

/// All inputs use instants. Active windows are disjoint and stay within a
/// single civil day. The caller clips them to the allowed planning period.
SlotSearchResult findWorkSlots({
  required List<SchedulingSlot> active,
  required List<BusyInterval> busy,
  required Duration duration,
  required Duration minimum,
  required int maximum,
  Duration before = Duration.zero,
  Duration after = Duration.zero,
  List<SchedulingSlot> preferred = const [],
}) {
  assert(duration >= Duration.zero && minimum > Duration.zero);
  if (duration == Duration.zero) return const SlotSearchResult();
  if (active.isEmpty) {
    return const SlotSearchResult(failure: SlotFailure.activeHours);
  }
  final free = _subtract(
    active,
    busy.map((row) => bufferedSlot(row, before: before, after: after)),
  );
  final available = totalSlotDuration(free);
  SlotSearchResult failure(SlotFailure reason) =>
      SlotSearchResult(failure: reason, available: available);
  if (available < duration) {
    final unbuffered = totalSlotDuration(
      _subtract(active, busy.map((row) => row.slot)),
    );
    if (unbuffered >= duration && available < unbuffered) {
      return failure(SlotFailure.buffer);
    }
    return failure(
      available == Duration.zero ? SlotFailure.busy : SlotFailure.insufficient,
    );
  }

  final candidates = [
    for (final gap in free)
      if (slotDuration(gap) >= minimum)
        (gap: gap, preferred: _preferredPart(gap, preferred)),
  ];
  Duration capacity(({SchedulingSlot gap, SchedulingSlot? preferred}) row) =>
      slotDuration(row.gap);
  int byPreference(
    ({SchedulingSlot gap, SchedulingSlot? preferred}) a,
    ({SchedulingSlot gap, SchedulingSlot? preferred}) b,
  ) {
    final aTime = a.preferred == null
        ? Duration.zero
        : slotDuration(a.preferred!);
    final bTime = b.preferred == null
        ? Duration.zero
        : slotDuration(b.preferred!);
    final overlap = math
        .min(duration.inMicroseconds, bTime.inMicroseconds)
        .compareTo(math.min(duration.inMicroseconds, aTime.inMicroseconds));
    return overlap == 0 ? a.gap.start.compareTo(b.gap.start) : overlap;
  }

  // With a uniform minimum, a set of k windows is feasible exactly when
  // k * minimum <= duration <= their combined capacity.
  final viableCount = math.min(
    candidates.length,
    duration.inMicroseconds ~/ minimum.inMicroseconds,
  );
  final largest = [...candidates]
    ..sort((a, b) {
      final result = capacity(b).compareTo(capacity(a));
      return result == 0 ? byPreference(a, b) : result;
    });
  Duration capacityOf(int count) =>
      totalSlotDuration(largest.take(count).map((row) => row.gap));
  if (capacityOf(viableCount) < duration) return failure(SlotFailure.minimum);
  final maxCount = math.min(math.max(0, maximum), viableCount);
  if (capacityOf(maxCount) < duration) return failure(SlotFailure.maximum);

  var count = 0;
  var sum = Duration.zero;
  while (sum < duration) {
    sum += capacity(largest[count++]);
  }
  final ordered =
      candidates
          .where((row) => count != 1 || capacity(row) >= duration)
          .toList()
        ..sort(byPreference);
  var selected = ordered.take(count).toList();
  if (totalSlotDuration(selected.map((row) => row.gap)) < duration) {
    // Start with the most capacity and swap in higher-ranked windows when
    // their inclusion still leaves enough time for the confirmed estimate.
    final reserve = largest.take(count).toSet();
    var total = sum;
    var smallest = count - 1;
    selected = [];
    for (final candidate in ordered) {
      if (reserve.remove(candidate)) {
        selected.add(candidate);
      } else {
        while (!reserve.contains(largest[smallest])) {
          smallest--;
        }
        final displaced = largest[smallest];
        final revised = total - capacity(displaced) + capacity(candidate);
        if (revised >= duration) {
          reserve.remove(displaced);
          selected.add(candidate);
          total = revised;
        }
      }
      if (selected.length == count) break;
    }
  }
  final lengths = List.filled(count, minimum);
  var remaining = duration - minimum * count;
  void allocate(int index, Duration limit) {
    final extra = limit - lengths[index];
    if (extra <= Duration.zero) return;
    final used = extra < remaining ? extra : remaining;
    lengths[index] += used;
    remaining -= used;
  }

  for (final (i, row) in selected.indexed) {
    if (row.preferred case final window?) allocate(i, slotDuration(window));
  }
  for (final (i, row) in selected.indexed) {
    allocate(i, capacity(row));
  }
  final slots = [
    for (final (i, row) in selected.indexed)
      _place(row.gap, lengths[i], row.preferred),
  ]..sort((a, b) => a.start.compareTo(b.start));
  final gap = before + after;
  if (_hasClearance(slots, gap)) {
    return SlotSearchResult(slots: slots, available: available);
  }
  // Gaps cut by a Busy interval already provide clearance. Adjacent active
  // windows (for example two full active days) can need extra separation.
  final adjusted = _withClearance(
    selected.map((row) => row.gap).toList(),
    duration,
    minimum,
    gap,
  );
  if (adjusted != null) {
    return SlotSearchResult(slots: adjusted, available: available);
  }
  final alternative = _searchWithClearance(
    candidates.map((row) => row.gap).toList(),
    count: count,
    maxCount: maxCount,
    duration: duration,
    minimum: minimum,
    gap: gap,
  );
  return alternative == null
      ? failure(SlotFailure.buffer)
      : SlotSearchResult(slots: alternative, available: available);
}

/// Shortens or removes existing sessions with fixed starts. Keeps the largest
/// feasible number of sessions, including when manual sessions overlap.
SlotSearchResult trimWorkSlots({
  required List<SchedulingSlot> windows,
  required Duration duration,
  required Duration minimum,
  required int maximum,
  required Duration separation,
}) {
  if (duration == Duration.zero) return const SlotSearchResult();
  final candidates = windows
      .where((row) => slotDuration(row) >= minimum)
      .toList();
  final count = math.min(
    candidates.length,
    duration.inMicroseconds ~/ minimum.inMicroseconds,
  );
  final levels = math.min(count, maximum);
  final totalBefore = List<List<Duration?>>.generate(
    levels,
    (_) => List.filled(candidates.length, null),
  );
  final predecessors = List.generate(
    levels,
    (_) => List.filled(candidates.length, -1),
  );
  var bestLevel = -1;
  var last = -1;
  var available = Duration.zero;
  DateTime cutoff(SchedulingSlot first, SchedulingSlot next) {
    final limit = next.start.subtract(separation);
    return limit.isBefore(first.end) ? limit : first.end;
  }

  for (var level = 0; level < levels; level++) {
    for (var i = level; i < candidates.length; i++) {
      if (level == 0) totalBefore[level][i] = Duration.zero;
      for (var j = level - 1; level > 0 && j < i; j++) {
        final previous = totalBefore[level - 1][j];
        if (previous == null) continue;
        final width = cutoff(
          candidates[j],
          candidates[i],
        ).difference(candidates[j].start);
        final capacity = previous + width;
        if (width >= minimum &&
            capacity >
                (totalBefore[level][i] ?? const Duration(microseconds: -1))) {
          totalBefore[level][i] = capacity;
          predecessors[level][i] = j;
        }
      }
      final previous = totalBefore[level][i];
      if (previous == null) continue;
      final capacity = previous + slotDuration(candidates[i]);
      if (capacity > available) available = capacity;
      if (capacity >= duration && level > bestLevel) {
        bestLevel = level;
        last = i;
      }
    }
  }
  if (last < 0) {
    return SlotSearchResult(
      failure: duration < minimum || (windows.isNotEmpty && candidates.isEmpty)
          ? SlotFailure.minimum
          : maximum == 0
          ? SlotFailure.maximum
          : SlotFailure.insufficient,
      available: available,
    );
  }
  final kept = <SchedulingSlot>[];
  for (var level = bestLevel; level >= 0; level--) {
    final window = candidates[last];
    kept.add((
      start: window.start,
      end: kept.isEmpty ? window.end : cutoff(window, kept.last),
    ));
    last = predecessors[level][last];
  }
  var extra = duration - minimum * kept.length;
  final slots = <SchedulingSlot>[];
  for (final row in kept.reversed) {
    final capacity = slotDuration(row) - minimum;
    final used = extra < capacity ? extra : capacity;
    slots.add((start: row.start, end: row.start.add(minimum + used)));
    extra -= used;
  }
  return SlotSearchResult(available: available, slots: slots);
}

bool _hasClearance(List<SchedulingSlot> slots, Duration gap) {
  for (var i = 1; i < slots.length; i++) {
    if (slots[i].start.difference(slots[i - 1].end) < gap) return false;
  }
  return true;
}

List<SchedulingSlot>? _withClearance(
  List<SchedulingSlot> windows,
  Duration duration,
  Duration minimum,
  Duration gap,
) {
  windows.sort((a, b) => a.start.compareTo(b.start));
  final latest = List<DateTime>.filled(windows.length, windows.last.end);
  for (var i = windows.length - 1; i >= 0; i--) {
    var end = windows[i].end;
    if (i + 1 < windows.length) {
      final cutoff = latest[i + 1].subtract(gap);
      if (cutoff.isBefore(end)) end = cutoff;
    }
    latest[i] = end.subtract(minimum);
    if (latest[i].isBefore(windows[i].start)) return null;
  }
  final slots = <SchedulingSlot>[];
  var extra = duration - minimum * windows.length;
  for (final (i, window) in windows.indexed) {
    var start = window.start;
    if (slots.isNotEmpty) {
      final earliest = slots.last.end.add(gap);
      if (earliest.isAfter(start)) start = earliest;
    }
    final maxExtra = latest[i].difference(start);
    final used = extra < maxExtra ? extra : maxExtra;
    extra -= used;
    slots.add((start: start, end: start.add(minimum + used)));
  }
  return extra == Duration.zero ? slots : null;
}

class _Placement {
  const _Placement(this.window, this.start, this.before, this.previous);

  final SchedulingSlot window;
  final DateTime start;
  final Duration before;
  final _Placement? previous;

  Duration get capacity => before + window.end.difference(start);
}

List<SchedulingSlot>? _searchWithClearance(
  List<SchedulingSlot> windows, {
  required int count,
  required int maxCount,
  required Duration duration,
  required Duration minimum,
  required Duration gap,
}) {
  var previous = [
    for (final window in windows)
      [_Placement(window, window.start, Duration.zero, null)],
  ];
  for (var size = 2; size <= maxCount; size++) {
    final current = List.generate(windows.length, (_) => <_Placement>[]);
    for (var i = size - 1; i < windows.length; i++) {
      final window = windows[i];
      final candidates = <_Placement>[];
      for (var j = size - 2; j < i; j++) {
        for (final prior in previous[j]) {
          final earliest = prior.start.add(minimum + gap);
          final start = earliest.isAfter(window.start)
              ? earliest
              : window.start;
          if (start.add(minimum).isAfter(window.end)) continue;
          final limit = start.subtract(gap);
          final cutoff = limit.isBefore(prior.window.end)
              ? limit
              : prior.window.end;
          final before = prior.before + cutoff.difference(prior.start);
          final placed = _Placement(window, start, before, prior);
          if (size >= count && placed.capacity >= duration) {
            return _backtrack(placed, duration, minimum);
          }
          candidates.add(placed);
        }
      }

      // In this window, capacity grows by one minute per additional minute
      // of allowed end time. An earlier state with greater full capacity
      // therefore dominates a later one at every feasible end time.
      candidates.sort((a, b) {
        final start = a.start.compareTo(b.start);
        return start == 0 ? b.capacity.compareTo(a.capacity) : start;
      });
      for (final candidate in candidates) {
        if (current[i].isEmpty ||
            candidate.capacity > current[i].last.capacity) {
          current[i].add(candidate);
        }
      }
    }
    previous = current;
  }
  return null;
}

List<SchedulingSlot> _backtrack(
  _Placement placement,
  Duration target,
  Duration minimum,
) {
  final slots = <SchedulingSlot>[];
  for (_Placement? step = placement; step != null; step = step.previous) {
    final needed = target - step.before;
    final length = needed < minimum ? minimum : needed;
    slots.add((start: step.start, end: step.start.add(length)));
    target -= length;
  }
  return slots.reversed.toList();
}

SchedulingSlot _place(
  SchedulingSlot gap,
  Duration length,
  SchedulingSlot? preference,
) {
  var start = preference?.start ?? gap.start;
  final latestStart = gap.end.subtract(length);
  if (start.isAfter(latestStart)) start = latestStart;
  return (start: start, end: start.add(length));
}

SchedulingSlot? _preferredPart(
  SchedulingSlot gap,
  List<SchedulingSlot> windows,
) {
  // Search the first preference window that could overlap this gap.
  var lo = 0;
  var hi = windows.length;
  while (lo < hi) {
    final mid = (lo + hi) ~/ 2;
    if (windows[mid].end.isAfter(gap.start)) {
      hi = mid;
    } else {
      lo = mid + 1;
    }
  }
  SchedulingSlot? best;
  for (
    var i = lo;
    i < windows.length && windows[i].start.isBefore(gap.end);
    i++
  ) {
    final part = intersectSlots(gap, windows[i]);
    if (part != null &&
        (best == null || slotDuration(part) > slotDuration(best))) {
      best = part;
    }
  }
  return best;
}

List<SchedulingSlot> _subtract(
  List<SchedulingSlot> active,
  Iterable<SchedulingSlot> blocked,
) {
  final cuts = blocked.toList()..sort((a, b) => a.start.compareTo(b.start));
  final free = <SchedulingSlot>[];
  var first = 0;
  for (final window in active) {
    var cursor = window.start;
    while (first < cuts.length && !cuts[first].end.isAfter(cursor)) {
      first++;
    }
    for (
      var i = first;
      i < cuts.length && cuts[i].start.isBefore(window.end);
      i++
    ) {
      final cut = cuts[i];
      if (cursor.isBefore(cut.start)) {
        free.add((start: cursor, end: cut.start));
      }
      if (cut.end.isAfter(cursor)) cursor = cut.end;
      if (!cursor.isBefore(window.end)) break;
    }
    if (cursor.isBefore(window.end)) free.add((start: cursor, end: window.end));
  }
  return free;
}
