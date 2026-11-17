import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/calendar_zones.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/data/stored_planner_profile.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/design_system/neo_navigation.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';

final searchNow = DateTime.utc(2026, 11, 17, 15);

Future<StoredPlannerProfile> seedSearchScenario(
  SqlitePlannerStore store,
) async {
  final repository = StoredPlannerProfile(
    today: searchNow,
    now: () => searchNow,
    openStore: () async => store,
    readDeviceZone: () async => 'UTC',
  );
  await repository.saveProfile(PreviewProfile(name: 'Rana'));
  final category = await store.categories.save(
    Category(RecordMetadata.create(), name: 'Proyek', color: 0xff506fff),
  );
  final zones = CalendarZones(deviceZoneId: 'UTC');
  ScheduledInterval interval(int day, int hour) => zones.interval(
    DateTime.utc(2026, 11, day, hour),
    DateTime.utc(2026, 11, day, hour + 1),
    'UTC',
    TimeMode.originalZone,
  );
  Future<EventOccurrence> event(
    String title,
    int day,
    int hour, {
    bool uncategorized = false,
    ActivityStatus status = ActivityStatus.completed,
  }) => store.events.save(
    EventOccurrence(
      RecordMetadata.create(),
      title: title,
      schedule: interval(day, hour),
      categoryId: uncategorized ? null : category.id,
      status: status,
    ),
  );
  await event('Rapat Pagi', 17, 7);
  await event('Rapat Sore', 17, 12);
  await event('Rapat Tim Lain', 17, 10, uncategorized: true);
  await event('Rapat Belum Selesai', 17, 11, status: ActivityStatus.planned);
  await event('Rapat Besok', 18, 7);
  final removed = await event('Rapat Arsip', 17, 10);
  await store.softDelete((kind: RecordKind.eventOccurrence, id: removed.id));

  Future<void> routine(
    String title, {
    int? hour,
    String rule = 'FREQ=DAILY',
  }) async {
    final routine = await store.routines.save(
      Routine(
        RecordMetadata.create(),
        title: title,
        targetType: RoutineTargetType.count,
        targetAmount: 2,
        categoryId: category.id,
        frequencyRule: rule,
      ),
    );
    if (hour != null) {
      await store.routineOccurrences.save(
        RoutineOccurrence(
          RecordMetadata.create(),
          routineId: routine.id,
          day: LocalDate.parse('2026-11-17'),
          schedule: interval(17, hour),
          recordedCount: 2,
          status: ActivityStatus.completed,
        ),
      );
    }
  }

  await routine('Latihan Mobilitas', hour: 7);
  await routine('Latihan Kardio', hour: 10);
  await routine('Latihan Tanpa Jam');
  await routine('Latihan Akhir Pekan', rule: 'FREQ=DAILY;BYDAY=SA,SU');
  return repository;
}

class SearchScenario {
  const SearchScenario(this.tester, this.settle);
  final WidgetTester tester;
  final Future<void> Function() settle;

  Future<void> tap(Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await settle();
  }

  Future<void> text(String label) {
    final target = find.text(label);
    final sheetOption = find.descendant(
      of: find.byType(NeoBottomSheet),
      matching: target,
    );
    return tap(sheetOption.evaluate().isEmpty ? target : sheetOption);
  }

  Future<void> action(String label) => tap(find.byTooltip(label));

  Future<void> tab(String label) => tap(
    find.descendant(
      of: find.byType(RoutinaBottomNavigation),
      matching: find.text(label),
    ),
  );

  Future<void> enter(String search) async {
    final field = find.byType(TextFormField);
    await tap(field);
    await tester.enterText(field, search);
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          )
          .controller
          .text,
      search,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle();
  }

  Future<void> reveal(String label) async {
    final scrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.text(label),
      140,
      scrollable: scrollable.first,
    );
    await settle();
  }

  Future<void> filterCurrentDate() async {
    await text('Tanggal');
    await text('Pilih tanggal');
    await tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.widgetWithText(TextButton, 'Pilih tanggal'),
      ),
    );
  }

  void expectOrder(String first, String second) {
    final before = find.text(first);
    final after = find.text(second);
    expect(before, findsOneWidget);
    expect(after, findsOneWidget);
    expect(tester.getTopLeft(before).dy, lessThan(tester.getTopLeft(after).dy));
  }
}
