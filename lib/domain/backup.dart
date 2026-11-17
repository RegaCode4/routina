import 'dart:convert';

import 'package:routina/domain/planner_records.dart';

enum BackupIssue implements Exception {
  passwordRequired,
  invalidFile,
  unsupportedFormat,
  authentication,
  tooLarge,
  unsupportedSchema,
  invalidData,
  incompleteChoices,
  incompatibleMerge,
  staleReview,
  applyFailed,
}

typedef BackupRow = Map<String, Object?>;

/// An entity keeps its typed row, stable identity, and owned timer state
/// together so that one choice in a merge cannot mix versions of that entity.
class BackupEntity {
  BackupEntity({
    required BackupRow record,
    required BackupRow data,
    BackupRow? timer,
    BackupRow? goalEvent,
  }) : record = Map.unmodifiable(record),
       data = Map.unmodifiable(data),
       timer = timer == null ? null : Map.unmodifiable(timer),
       goalEvent = goalEvent == null ? null : Map.unmodifiable(goalEvent) {
    if (record['id'] case final String id when id.trim().isNotEmpty) {
      if (id == data['id']) return;
    }
    throw BackupIssue.invalidData;
  }

  factory BackupEntity.parse(Object? value) {
    final map = _object(value);
    final expected = {
      'record',
      'data',
      if (map.containsKey('timer')) 'timer',
      if (map.containsKey('goalEvent')) 'goalEvent',
    };
    if (!_keysMatch(map, expected)) throw BackupIssue.invalidData;
    return BackupEntity(
      record: _row(map['record']),
      data: _row(map['data']),
      timer: map.containsKey('timer') ? _row(map['timer']) : null,
      goalEvent: map.containsKey('goalEvent') ? _row(map['goalEvent']) : null,
    );
  }

  final BackupRow record, data;
  final BackupRow? timer, goalEvent;
  String get id => record['id'] as String;
  RecordKind get kind {
    final name = record['kind'];
    return RecordKind.values.where((kind) => kind.name == name).firstOrNull ??
        (throw BackupIssue.invalidData);
  }

  String get title => (data['title'] ?? data['name']) as String? ?? id;
  DateTime get updatedAt => DateTime.fromMicrosecondsSinceEpoch(
    record['updated_at_us'] as int,
    isUtc: true,
  );

  Map<String, Object?> toJson() => {
    'record': record,
    'data': data,
    if (timer != null) 'timer': timer,
    if (goalEvent != null) 'goalEvent': goalEvent,
  };

  bool sameAs(BackupEntity other) =>
      _sameRow(record, other.record) &&
      _sameRow(data, other.data) &&
      _sameRow(timer, other.timer) &&
      _sameRow(goalEvent, other.goalEvent);
}

class BackupSnapshot {
  BackupSnapshot(this.schemaVersion, Iterable<BackupEntity> entities)
    : entities = Map.unmodifiable(_byId(entities));

  static const maxEntities = 50000;
  final int schemaVersion;
  final Map<String, BackupEntity> entities;

  static Map<String, BackupEntity> _byId(Iterable<BackupEntity> rows) {
    final byId = <String, BackupEntity>{};
    for (final row in rows) {
      if (byId.containsKey(row.id)) throw BackupIssue.invalidData;
      if (byId.length >= maxEntities) throw BackupIssue.tooLarge;
      byId[row.id] = row;
    }
    return byId;
  }

  Map<String, int> get counts {
    final result = {for (final kind in RecordKind.values) kind.name: 0};
    for (final row in entities.values) {
      result.update(row.kind.name, (value) => value + 1);
    }
    return result;
  }

  bool sameAs(BackupSnapshot other) =>
      schemaVersion == other.schemaVersion &&
      entities.length == other.entities.length &&
      entities.entries.every(
        (row) => other.entities[row.key]?.sameAs(row.value) ?? false,
      );
}

class BackupArchive {
  const BackupArchive(this.createdAt, this.snapshot);
  final DateTime createdAt;
  final BackupSnapshot snapshot;

  String encode() => jsonEncode({
    'manifest': {
      'application': 'routina',
      'schemaVersion': snapshot.schemaVersion,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'counts': snapshot.counts,
    },
    'entities': snapshot.entities.values.map((row) => row.toJson()).toList(),
  });

  factory BackupArchive.decode(String json, {required int expectedSchema}) {
    final map = _object(jsonDecode(json));
    if (!_keysMatch(map, {'manifest', 'entities'})) {
      throw BackupIssue.invalidData;
    }
    final manifest = _object(map['manifest']);
    if (!_keysMatch(manifest, {
          'application',
          'schemaVersion',
          'createdAt',
          'counts',
        }) ||
        manifest['application'] != 'routina') {
      throw BackupIssue.invalidData;
    }
    final version = manifest['schemaVersion'];
    final createdAt = manifest['createdAt'];
    final rows = map['entities'];
    if (version is! int ||
        version <= 0 ||
        createdAt is! String ||
        rows is! List) {
      throw BackupIssue.invalidData;
    }
    if (version != expectedSchema) throw BackupIssue.unsupportedSchema;
    final date = DateTime.tryParse(createdAt);
    if (date == null || !date.isUtc || date.toIso8601String() != createdAt) {
      throw BackupIssue.invalidData;
    }
    if (rows.length > BackupSnapshot.maxEntities) throw BackupIssue.tooLarge;
    final snapshot = BackupSnapshot(version, rows.map(BackupEntity.parse));
    if (!_sameRow(_object(manifest['counts']), snapshot.counts)) {
      throw BackupIssue.invalidData;
    }
    return BackupArchive(date, snapshot);
  }
}

BackupRow _object(Object? value) =>
    value is Map<String, dynamic> ? value : throw BackupIssue.invalidData;

BackupRow _row(Object? value) {
  final map = _object(value);
  if (map.values.any(
    (value) => value != null && value is! String && value is! int,
  )) {
    throw BackupIssue.invalidData;
  }
  return map;
}

bool _keysMatch(BackupRow map, Set<String> keys) =>
    map.length == keys.length && map.keys.every(keys.contains);

bool _sameRow(BackupRow? a, BackupRow? b) {
  if (a == null || b == null) return a == b;
  return a.length == b.length &&
      a.entries.every(
        (entry) => b.containsKey(entry.key) && b[entry.key] == entry.value,
      );
}
