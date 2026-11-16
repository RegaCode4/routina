import 'package:routina/application/planner_preview.dart';
import 'package:routina/data/memory_planner_preview.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';
import 'package:routina/domain/preview_event.dart';

/// Keeps the established preview routes while the local profile uses SQLite.
class StoredPlannerProfile extends MemoryPlannerPreview {
  StoredPlannerProfile({
    required super.today,
    required Future<PlannerStore> Function() openStore,
  }) : _openStore = openStore;

  final Future<PlannerStore> Function() _openStore;
  PlannerStore? _store;

  @override
  Future<void> load(PreviewSurface surface) async {
    if (surface == PreviewSurface.startup) {
      final store = _store ??= await _openStore();
      final record = (await store.profiles.all()).singleOrNull;
      if (record != null) {
        await super.saveProfile(
          PreviewProfile(
            name: record.name ?? '',
            notifications: record.notificationsEnabled ?? false,
            sundayFirst: record.weekStartsOn == DateTime.sunday,
            study: record.activityPreferences['study'] ?? 'Sore',
            workout: record.activityPreferences['workout'] ?? 'Pagi',
            activeHours: {
              for (final entry in record.activeHours.entries)
                entry.key: ActiveInterval(
                  entry.value.startMinute,
                  entry.value.endMinute,
                ),
            },
          ),
        );
      }
    }
    await super.load(surface);
  }

  @override
  Future<void> saveProfile(PreviewProfile profile) async {
    final store = _store ??= await _openStore();
    await store.transaction((data) async {
      final previous = (await data.profiles.all()).singleOrNull;
      await data.profiles.save(
        Profile(
          previous?.metadata ?? RecordMetadata.create(),
          name: profile.name,
          notificationsEnabled: profile.notifications,
          weekStartsOn: profile.sundayFirst ? DateTime.sunday : DateTime.monday,
          defaultBuffer: previous?.defaultBuffer,
          quietHours: previous?.quietHours,
          activeHours: {
            for (final entry in profile.activeHours.entries)
              entry.key: (
                startMinute: entry.value.start,
                endMinute: entry.value.end,
              ),
          },
          activityPreferences: {
            ...?previous?.activityPreferences,
            'study': profile.study,
            'workout': profile.workout,
          },
        ),
      );
    });
    await super.saveProfile(profile);
  }
}
