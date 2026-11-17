import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/calendar_zones.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/data/stored_planner_profile.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/app.dart';
import 'package:routina/presentation/design_system/neo_overlays.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets(
    'Profile trash reviews conflicts and confirms permanent deletion',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.utc(2026, 11, 17, 8);
      final utc = CalendarZones(deviceZoneId: 'UTC');
      final (repository, store, eventId, taskId, blockerId) = (await tester
          .runAsync(() async {
            final store = await SqlitePlannerStore.open(
              factory: databaseFactoryFfi,
              path: inMemoryDatabasePath,
              now: () => now,
            );
            addTearDown(store.close);
            final repository = StoredPlannerProfile(
              today: now,
              now: () => now,
              openStore: () async => store,
              readDeviceZone: () async => 'UTC',
            );
            await repository.saveProfile(PreviewProfile(name: 'Nara'));
            Future<EventOccurrence> event(String title, int hour, int end) =>
                store.events.save(
                  EventOccurrence(
                    RecordMetadata.create(),
                    title: title,
                    schedule: utc.interval(
                      DateTime.utc(2026, 11, 17, hour),
                      DateTime.utc(2026, 11, 17, end),
                      'UTC',
                      TimeMode.originalZone,
                    ),
                  ),
                );
            final source = await event('Rapat lama', 10, 11);
            await store.softDelete((
              kind: RecordKind.eventOccurrence,
              id: source.id,
            ));
            final blocker = await event('Rapat yang aktif', 10, 12);
            final task = await store.tasks.save(
              Task(RecordMetadata.create(), title: 'Tugas arsip'),
            );
            await store.softDelete((kind: RecordKind.task, id: task.id));
            return (repository, store, source.id, task.id, blocker.id);
          }))!;

      await tester.pumpWidget(RoutinaApp(repository: repository));
      final profile = find.bySemanticsLabel(RegExp(r'^Profil, Tab'));
      await waitFor(tester, profile);
      await tap(tester, profile);
      final trash = find.text('Tempat Sampah');
      await tester.scrollUntilVisible(
        trash,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tap(tester, trash);
      await waitFor(tester, find.text('Rapat lama'));
      expect(find.text('Tugas arsip'), findsOneWidget);
      await tap(tester, find.text('Rapat lama'));
      expect(find.text('Item terhapus'), findsOneWidget);
      expect(find.text('Sisa retensi 30 hari'), findsOneWidget);
      await tap(tester, find.text('Pulihkan kegiatan'));
      await waitFor(tester, find.text('Pemulihan memicu bentrok'));
      expect(find.textContaining('Rapat yang aktif'), findsOneWidget);
      expect(find.text('Pilih tanggal lain'), findsOneWidget);
      await tap(tester, find.text('Batal'));
      expect(await tester.runAsync(() => store.events.find(eventId)), isNull);

      await tap(tester, find.text('Pulihkan kegiatan'));
      await waitFor(tester, find.text('Pulihkan dengan bentrok'));
      await tap(tester, find.text('Pulihkan dengan bentrok'));
      await waitFor(tester, find.text('Tugas arsip'));
      expect(find.text('Item dipulihkan.'), findsOneWidget);
      expect(
        await tester.runAsync(() => store.events.find(eventId)),
        isNotNull,
      );
      expect(
        (await tester.runAsync(
          () => store.events.find(blockerId),
        ))!.schedule.end.instant,
        DateTime.utc(2026, 11, 17, 12),
      );

      await tap(tester, find.text('Tugas arsip'));
      await tap(tester, find.text('Hapus permanen'));
      expect(find.text('Hapus item secara permanen?'), findsOneWidget);
      await tap(tester, find.text('Batal'));
      expect(
        await tester.runAsync(
          () => store.tasks.find(taskId, includeDeleted: true),
        ),
        isNotNull,
      );
      await tap(tester, find.text('Hapus permanen'));
      await tap(
        tester,
        find.descendant(
          of: find.byType(NeoDialog),
          matching: find.text('Hapus Permanen'),
        ),
      );
      await waitFor(tester, find.text('Tempat Sampah kosong'));
      expect(find.text('Item dihapus permanen.'), findsOneWidget);
      expect(
        await tester.runAsync(
          () => store.tasks.find(taskId, includeDeleted: true),
        ),
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      // Refreshing the shell also reloads offstage tabs. Let their queued
      // SQLite reads release the transaction lock before test teardown.
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
      }
    },
  );
}
