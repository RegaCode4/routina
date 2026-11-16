import 'package:routina/application/activity_calendar.dart';
import 'package:routina/application/calendar_zones.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/data/memory_planner_preview.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/planner_store.dart';
import 'package:routina/domain/preview_event.dart';

/// Durable settings and activities alongside opt-in task and routine previews.
class StoredPlannerProfile extends MemoryPlannerPreview {
  StoredPlannerProfile({
    required super.today,
    required Future<PlannerStore> Function() openStore,
    Future<String> Function()? readDeviceZone,
    DateTime Function()? now,
  }) : _openStore = openStore,
       _readDeviceZone = readDeviceZone,
       _now = now ?? DateTime.now,
       super(seedCategories: false, fixture: PreviewFixture.empty);

  final Future<PlannerStore> Function() _openStore;
  final Future<String> Function()? _readDeviceZone;
  final DateTime Function() _now;
  PlannerStore? _store;
  List<Category> _savedCategories = const [];
  List<PreviewEvent> _homeEvents = const [];
  String _deviceZone = 'UTC';
  int _confirmationDays = 30;

  Future<PlannerStore> _database() async => _store ??= await _openStore();

  CalendarZones get _zones => CalendarZones(
    deviceZoneId: _deviceZone,
    displayZoneId: profile?.preferences.calendarZoneId,
  );
  Future<ActivityCalendar> _calendar() async => ActivityCalendar(
    await _database(),
    _zones,
    profile: profile,
    categories: categories,
    now: _now,
  );

  @override
  bool get usesStoredCalendar => true;
  @override
  String get calendarZoneLabel => _zones.displayId;
  @override
  DateTime get today => dateOnly(_zones.wall(_now(), _zones.displayId));
  @override
  DateTime get calendarDay => today;
  @override
  List<PreviewEvent> get homeEntries => List.unmodifiable(_homeEvents);
  @override
  List<PreviewEvent> get events => [..._homeEvents, ...super.events];

  @override
  Future<List<PreviewEvent>> readCalendar(
    DateTime from,
    DateTime until,
  ) async => (await _calendar()).read(from, until);

  @override
  Future<List<ScheduleWarning>> activityWarnings(
    PreviewEvent event, {
    SeriesScope? scope,
  }) async => (await _calendar()).warnings(event, scope: scope);

  @override
  Future<PreviewEvent> saveActivity(
    PreviewEvent event, {
    SeriesScope? scope,
    Set<ScheduleWarning> approved = const {},
  }) async => (await _calendar()).save(event, scope: scope, approved: approved);

  @override
  Future<PreviewEvent> changeActivity(
    PreviewEvent event,
    PreviewEventState state, {
    SeriesScope? scope,
  }) async => (await _calendar()).change(event, state, scope: scope);

  @override
  Future<DateTime?> suggestReplacement(PreviewEvent event) async =>
      (await _calendar()).suggestReplacement(event);
  @override
  Future<List<PreviewEvent>> readTrashedActivities() async =>
      (await _calendar()).trash();

  @override
  Future<void> loadEarlierConfirmations() async {
    _confirmationDays += 30;
    try {
      await load(PreviewSurface.home);
    } catch (_) {
      _confirmationDays -= 30;
      rethrow;
    }
  }

  @override
  List<Category> get categories => List.unmodifiable(_savedCategories);

  @override
  Future<void> load(PreviewSurface surface) async {
    if (surface == PreviewSurface.startup || surface == PreviewSurface.home) {
      final readZone = _readDeviceZone;
      if (readZone != null) _deviceZone = await readZone();
    }
    if (surface == PreviewSurface.startup) {
      final store = await _database();
      final record = (await store.profiles.all()).singleOrNull;
      _savedCategories = await store.categories.all();
      await super.rememberStep(record?.onboardingStep ?? 0);
      if (record != null && record.onboardingCompleted) {
        await super.saveProfile(
          PreviewProfile(
            name: record.name ?? '',
            notifications: record.notificationsEnabled ?? false,
            sundayFirst: record.weekStartsOn == DateTime.sunday,
            study: record.activityPreferences['study'] ?? '',
            workout: record.activityPreferences['workout'] ?? '',
            other: record.activityPreferences['other'] ?? '',
            defaultBuffer: record.defaultBuffer,
            quietHours: record.quietHours,
            preferences: record.preferences,
            categoryTimes: {
              for (final entry in record.activityPreferences.entries)
                if (entry.key.startsWith('category:'))
                  entry.key.substring('category:'.length): entry.value,
            },
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
    if (surface == PreviewSurface.home) {
      final calendar = await _calendar();
      final day = today;
      _homeEvents = await calendar.read(
        shiftDay(day, -_confirmationDays),
        shiftDay(day, 32),
      );
      return;
    }
    await super.load(surface);
  }

  @override
  Future<void> rememberStep(int step) async {
    RangeError.checkValueInInterval(step, 0, 2);
    final store = await _database();
    final savedStep = await store.transaction((data) async {
      final previous = (await data.profiles.all()).singleOrNull;
      if (previous?.onboardingCompleted == true) return 0;
      await data.profiles.save(
        Profile(
          previous?.metadata ?? RecordMetadata.create(),
          onboardingStep: step,
          onboardingCompleted: false,
        ),
      );
      return step;
    });
    await super.rememberStep(savedStep);
  }

  @override
  Future<void> saveProfile(PreviewProfile profile) async {
    final store = await _database();
    await store.transaction((data) async {
      final previous = (await data.profiles.all()).singleOrNull;
      await data.profiles.save(
        Profile(
          previous?.metadata ?? RecordMetadata.create(),
          name: profile.name,
          notificationsEnabled: profile.notifications,
          weekStartsOn: profile.sundayFirst ? DateTime.sunday : DateTime.monday,
          defaultBuffer: profile.defaultBuffer,
          quietHours: profile.quietHours,
          preferences: profile.preferences,
          activeHours: {
            for (final entry in profile.activeHours.entries)
              entry.key: (
                startMinute: entry.value.start,
                endMinute: entry.value.end,
              ),
          },
          activityPreferences: {
            for (final entry
                in (previous?.activityPreferences ?? const <String, String>{})
                    .entries)
              if (!entry.key.startsWith('category:')) entry.key: entry.value,
            'study': profile.study,
            'workout': profile.workout,
            'other': profile.other,
            for (final entry in profile.categoryTimes.entries)
              'category:${entry.key}': entry.value,
          },
        ),
      );
    });
    await super.rememberStep(0);
    await super.saveProfile(profile);
  }

  @override
  Future<Category> saveCategory(Category category) async {
    final store = await _database();
    final saved = await store.transaction((data) async {
      if (!isCategoryNameAvailable(
        category.name,
        await data.categories.all(),
        editingId: category.id,
      )) {
        throw const FormatException('Nama kategori tidak tersedia.');
      }
      return data.categories.save(
        Category(
          category.metadata,
          name: category.name.trim(),
          color: category.color,
          icon: category.icon,
        ),
      );
    });
    _savedCategories = [
      for (final category in _savedCategories)
        if (category.id == saved.id) saved else category,
      if (!_savedCategories.any((category) => category.id == saved.id)) saved,
    ];
    return saved;
  }

  @override
  Future<void> deleteCategory(
    Category category, {
    Category? replacement,
  }) async {
    final store = await _database();
    await store.deleteCategory(category.id, replacementId: replacement?.id);
    _savedCategories = _savedCategories
        .where((item) => item.id != category.id)
        .toList();
  }
}
