import 'package:routina/application/activity_calendar.dart';
import 'package:routina/domain/event_recurrence.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';

enum TrashKind {
  event('Kegiatan'),
  task('Tugas'),
  routine('Rutinitas'),
  series('Seri kegiatan');

  const TrashKind(this.label);
  final String label;
}

class TrashItem {
  const TrashItem({
    required this.entry,
    required this.title,
    required this.kind,
    this.description,
    this.category,
    this.scheduleDay,
    this.canMove = false,
  });

  final TrashEntry entry;
  final String title;
  final TrashKind kind;
  final String? description, category;
  final DateTime? scheduleDay;
  final bool canMove;
}

class TrashList {
  const TrashList(this.items, this.observedAt, this.zone);
  final List<TrashItem> items;
  final DateTime observedAt;
  final String zone;
}

class RecoveryProposal {
  const RecoveryProposal._(this.item, this.moveTo, this.check);
  final TrashItem item;
  final DateTime? moveTo;
  final RecoveryCheck check;
}

class TrashWorkspace {
  const TrashWorkspace({
    required this.openStore,
    required this.openCalendar,
    required this.now,
  });

  final Future<PlannerStore> Function() openStore;
  final Future<ActivityCalendar> Function() openCalendar;
  final DateTime Function() now;

  Future<TrashList> list() async {
    final store = await openStore();
    final calendar = await openCalendar();
    return store.transaction((data) async {
      final local = await calendar.withLatestProfile(data);
      final logs = {
        for (final row in await data.timeLogs.all(includeDeleted: true))
          if (row.target.kind == RecordKind.eventOccurrence) row.target.id,
      };
      final categories = {for (final row in local.categories) row.id: row.name};
      final items = <TrashItem>[];
      for (final entry in await data.trashEntries.all()) {
        if (entry.restoredAt == null &&
            entry.archiveId == null &&
            _kind(entry) != null) {
          items.add(await _item(data, local, entry, logs, categories));
        }
      }
      items.sort((a, b) {
        final dates = b.entry.deletedAt.compareTo(a.entry.deletedAt);
        return dates == 0 ? a.title.compareTo(b.title) : dates;
      });
      return TrashList(
        List.unmodifiable(items),
        now().toUtc(),
        local.zones.displayId,
      );
    });
  }

  Future<RecoveryProposal> review(TrashItem item, {DateTime? moveTo}) async {
    final store = await openStore();
    final calendar = await openCalendar();
    try {
      // Use the same mutations and queries as approval. The review exception
      // forces sqflite to roll back the transaction and skips afterCommit.
      return await store.transaction<RecoveryProposal>((data) async {
        final local = await calendar.withLatestProfile(data);
        final checked = await local.checkRecovery(
          data,
          item.entry,
          moveTo: moveTo,
        );
        throw _Reviewed(RecoveryProposal._(item, moveTo, checked));
      });
    } on _Reviewed catch (result) {
      return result.proposal;
    }
  }

  Future<void> approve(RecoveryProposal proposal) async {
    final store = await openStore();
    final calendar = await openCalendar();
    await store.transaction((data) async {
      final local = await calendar.withLatestProfile(data);
      final check = await local.checkRecovery(
        data,
        proposal.item.entry,
        moveTo: proposal.moveTo,
      );
      final previous = proposal.check;
      if (check.displayZone != previous.displayZone ||
          check.deviceZone != previous.deviceZone ||
          check.checksRecurring != previous.checksRecurring ||
          !_sameMembers(check.removedCategories, previous.removedCategories) ||
          !_sameMembers(check.conflicts, previous.conflicts)) {
        throw StaleRecord(proposal.item.entry.id);
      }
    });
  }

  Future<void> permanentlyDelete(TrashItem item) async =>
      (await openStore()).permanentlyDelete(
        item.entry.id,
        expectedRevision: item.entry.metadata.revision,
      );

  Future<TrashItem> _item(
    PlannerData data,
    ActivityCalendar calendar,
    TrashEntry entry,
    Set<String> loggedEvents,
    Map<String, String> categories,
  ) async {
    final target = entry.target.id;
    final kind = _kind(entry)!;
    final zones = calendar.zones;
    DateTime? local(ZonedTime? time) => time == null
        ? null
        : zones.wall(zones.effectiveTime(time), zones.displayId);
    final (title, categoryId, description, date, canMove) = switch (kind) {
      TrashKind.event => switch (await data.events.find(
        target,
        includeDeleted: true,
      )) {
        final row? => (
          row.title,
          row.categoryId,
          row.description,
          row.allDayStart != null
              ? DateTime.parse(row.allDayStart!.value)
              : row.status == ActivityStatus.planned
              ? local(row.schedule.start)
              : zones.wall(row.schedule.start.instant, zones.displayId),
          canMoveRecoveredEvent(row, hasLogs: loggedEvents.contains(target)),
        ),
        null => throw StaleRecord(target),
      },
      TrashKind.task => switch (await data.tasks.find(
        target,
        includeDeleted: true,
      )) {
        final row? => (
          row.title,
          row.categoryId,
          row.description,
          row.status == ActivityStatus.completed && row.deadline != null
              ? zones.wall(row.deadline!.instant, zones.displayId)
              : local(row.deadline),
          false,
        ),
        null => throw StaleRecord(target),
      },
      TrashKind.routine => switch (await data.routines.find(
        target,
        includeDeleted: true,
      )) {
        final row? => (row.title, row.categoryId, null, null, false),
        null => throw StaleRecord(target),
      },
      TrashKind.series => switch (await data.eventSeries.find(
        target,
        includeDeleted: true,
      )) {
        final row? => (
          row.title,
          row.categoryId,
          null,
          DateTime.parse(entry.seriesCut!.value),
          false,
        ),
        null => throw StaleRecord(target),
      },
    };
    return TrashItem(
      entry: entry,
      title: title,
      kind: kind,
      description: description,
      category: categories[categoryId],
      scheduleDay: date == null ? null : civilDate(date),
      canMove: canMove,
    );
  }
}

bool _sameMembers<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

TrashKind? _kind(TrashEntry entry) => switch (entry.target.kind) {
  RecordKind.eventOccurrence => TrashKind.event,
  RecordKind.task => TrashKind.task,
  RecordKind.routine => TrashKind.routine,
  RecordKind.eventSeries when entry.seriesCut != null => TrashKind.series,
  _ => null,
};

class _Reviewed implements Exception {
  const _Reviewed(this.proposal);
  final RecoveryProposal proposal;
}
