import 'dart:typed_data';

import 'package:routina/data/backup_cipher.dart';
import 'package:routina/domain/backup.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';

enum RestoreMode { replace, merge }

enum BackupChoice { local, backup }

class VerifiedBackup {
  const VerifiedBackup._(this.archive);
  final BackupArchive archive;
}

class BackupConflict {
  const BackupConflict(this.local, this.backup);
  final BackupEntity local, backup;
  String get key => local.id;
}

class BackupReview {
  BackupReview._(
    this.mode,
    this.local,
    this.backup,
    this._uncontested,
    List<BackupConflict> conflicts,
  ) : conflicts = List.unmodifiable(conflicts);
  final RestoreMode mode;
  final BackupSnapshot local;
  final VerifiedBackup backup;
  final BackupSnapshot _uncontested;
  final List<BackupConflict> conflicts;
}

class BackupWorkspace {
  const BackupWorkspace({
    required this.openStore,
    required this.now,
    this.cipher = const BackupCipher(),
  });
  final Future<PlannerStore> Function() openStore;
  final DateTime Function() now;
  final BackupCipher cipher;

  Future<({Map<String, int> counts, PlannerPreferences preferences})>
  summary() async {
    final store = await openStore();
    return store.transaction(
      (data) async => (
        counts: (await data.readBackup()).counts,
        preferences: (await data.profiles.all()).single.preferences,
      ),
    );
  }

  Future<Uint8List> export(String password) async {
    if (password.isEmpty) throw BackupIssue.passwordRequired;
    final store = await openStore();
    final original = await store.readBackup();
    final capturedAt = now().toUtc();
    final snapshot = BackupSnapshot(
      original.schemaVersion,
      original.entities.values.map((item) => _pauseTimer(item, capturedAt)),
    );
    await store.validateBackup(snapshot);
    return cipher.seal(BackupArchive(capturedAt, snapshot), password);
  }

  Future<VerifiedBackup> openEncrypted(Uint8List file, String password) async {
    final store = await openStore();
    final archive = await cipher.open(
      file,
      password,
      expectedSchema: store.backupSchemaVersion,
    );
    await store.validateBackup(archive.snapshot);
    return VerifiedBackup._(archive);
  }

  Future<BackupReview> review(VerifiedBackup verified, RestoreMode mode) async {
    final local = await (await openStore()).readBackup();
    final incoming = verified.archive.snapshot;
    if (mode == RestoreMode.replace) {
      return BackupReview._(mode, local, verified, incoming, const []);
    }

    _checkTrashMerge(local, incoming);
    final rows = {...local.entities};
    final conflicts = <BackupConflict>[];
    final profile = local.entities.values.singleWhere(
      (row) => row.kind == RecordKind.profile,
    );
    for (final row in incoming.entities.values) {
      final match = local.entities[row.id];
      if (match != null && match.kind != row.kind) {
        throw BackupIssue.incompatibleMerge;
      }
      final previous = row.kind == RecordKind.profile ? profile : match;
      if (previous == null) {
        rows[row.id] = row;
      } else if (!previous.sameAs(row)) {
        rows.remove(previous.id);
        conflicts.add(BackupConflict(previous, row));
      }
    }
    return BackupReview._(
      mode,
      local,
      verified,
      BackupSnapshot(local.schemaVersion, rows.values),
      conflicts,
    );
  }

  Future<void> apply(
    BackupReview review,
    Map<String, BackupChoice> choices,
  ) async {
    final conflicts = review.conflicts;
    if (choices.length != conflicts.length ||
        conflicts.any((conflict) => !choices.containsKey(conflict.key))) {
      throw BackupIssue.incompleteChoices;
    }
    final store = await openStore();
    final merged = BackupSnapshot(review.local.schemaVersion, [
      ...review._uncontested.entities.values,
      for (final conflict in conflicts)
        choices[conflict.key] == BackupChoice.local
            ? conflict.local
            : conflict.backup,
    ]);
    if (review.mode == RestoreMode.merge) {
      try {
        _checkLoggedSchedules(review, merged);
        await store.validateBackup(merged);
      } on BackupIssue {
        throw BackupIssue.incompatibleMerge;
      }
    }
    try {
      await store.commitBackup(review.local, merged);
    } on BackupIssue catch (error) {
      if (error == BackupIssue.staleReview) rethrow;
      throw BackupIssue.applyFailed;
    } catch (_) {
      throw BackupIssue.applyFailed;
    }
  }

  Future<void> recordExport() {
    final current = now().toUtc();
    return _settings(
      (preferences) => preferences.copyWith(
        lastBackupAt: current,
        backupReminderSince: current,
      ),
    );
  }

  Future<void> setReminder(int? days) {
    if (days != null) RangeError.checkValueInInterval(days, 1, 365);
    return _settings(
      (preferences) => preferences.copyWith(
        backupReminderDays: days,
        disableBackupReminder: days == null,
        backupReminderSince: now().toUtc(),
      ),
    );
  }

  Future<void> _settings(
    PlannerPreferences Function(PlannerPreferences) change,
  ) async => (await openStore()).transaction((data) async {
    final profile = (await data.profiles.all()).single;
    await data.profiles.save(
      Profile(
        profile.metadata,
        name: profile.name,
        notificationsEnabled: profile.notificationsEnabled,
        weekStartsOn: profile.weekStartsOn,
        defaultBuffer: profile.defaultBuffer,
        quietHours: profile.quietHours,
        onboardingStep: profile.onboardingStep,
        onboardingCompleted: profile.onboardingCompleted,
        preferences: change(profile.preferences),
        activeHours: profile.activeHours,
        activityPreferences: profile.activityPreferences,
      ),
    );
  });
}

// Independently created Trash entries have their own IDs. A row-by-row union
// would hide the shared target even when the user kept its local version.
void _checkTrashMerge(BackupSnapshot local, BackupSnapshot incoming) {
  Set<(String, String, String?)> activeEntries(BackupSnapshot source) => {
    for (final row in source.entities.values)
      if (row.kind == RecordKind.trashEntry &&
          row.data['restored_at_us'] == null)
        (
          row.id,
          row.data['target_id'] as String,
          row.data['series_cut'] as String?,
        ),
  };
  final left = activeEntries(local);
  final right = activeEntries(incoming);
  for (final entry in [...left.difference(right), ...right.difference(left)]) {
    if (local.entities.containsKey(entry.$2) &&
        incoming.entities.containsKey(entry.$2)) {
      throw BackupIssue.trashConflict;
    }
  }
}

void _checkLoggedSchedules(BackupReview review, BackupSnapshot merged) {
  const fields = [
    'start_us',
    'end_us',
    'zone_id',
    'time_mode',
    'start_local',
    'end_local',
  ];
  for (final log in merged.entities.values.where(
    (row) => row.kind == RecordKind.timeLog,
  )) {
    final target = log.data['target_id'];
    final chosen = merged.entities[target];
    for (final source in [review.local, review.backup.archive.snapshot]) {
      if (source.entities[log.id]?.sameAs(log) != true) continue;
      final original = source.entities[target];
      if (chosen == null ||
          original == null ||
          fields.any((field) => chosen.data[field] != original.data[field])) {
        throw BackupIssue.incompatibleMerge;
      }
    }
  }
}

BackupEntity _pauseTimer(BackupEntity item, DateTime capturedAt) {
  final timer = item.timer;
  if (timer == null || timer['running_since_us'] is! int) return item;
  final startedAt = timer['running_since_us'] as int;
  final elapsed = capturedAt.microsecondsSinceEpoch - startedAt;
  return BackupEntity(
    record: item.record,
    data: item.data,
    timer: {
      ...timer,
      'running_since_us': null,
      'accumulated_us':
          (timer['accumulated_us'] as int) + (elapsed > 0 ? elapsed : 0),
    },
    goalEvent: item.goalEvent?['reached_at_us'] == null ? null : item.goalEvent,
  );
}
