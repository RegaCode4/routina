import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:routina/data/device_clock.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/data/stored_planner_profile.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/presentation/app.dart';

import 'support/startup_wait.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const clock = DeviceClock();

  testWidgets(
    'Android clock and SQLite preserve a timer across lifecycle',
    (tester) async {
      final directory = await Directory.systemTemp.createTemp(
        'routina-device-',
      );
      final path = '${directory.path}/planner.db';
      var now = DateTime.utc(2026, 11, 17, 8);
      var zone = 'UTC';
      var store = await SqlitePlannerStore.open(path: path);
      addTearDown(() async {
        await store.close();
        await directory.delete(recursive: true);
      });

      StoredPlannerProfile repository() => StoredPlannerProfile(
        today: now,
        now: () => now,
        openStore: () async => store,
        readDeviceZone: () async => zone,
        readTimerClock: clock.timerSample,
      );
      final first = repository();
      await first.saveProfile(PreviewProfile(name: 'Uji perangkat'));
      final work = first.routineWorkspace;
      final routine = await work.save(
        Routine(
          RecordMetadata.create(),
          title: 'Latihan perangkat',
          frequencyRule: 'FREQ=DAILY',
          targetType: RoutineTargetType.duration,
          targetDuration: const Duration(minutes: 30),
        ),
      );
      final day = work.today;
      await work.start(routine.id, day);
      final original = (await store.routineTimers()).single;
      expect(original.startedOnDevice, isNotNull);

      await tester.pumpWidget(RoutinaApp(repository: first));
      await waitForPlannerStartup(tester);
      await tester.pumpAndSettle();
      expect(find.text('Halo, Uji perangkat.'), findsOneWidget);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        binding.handleAppLifecycleStateChanged(state);
      }
      now = now.add(const Duration(days: 1));
      zone = 'Asia/Jakarta';
      await Future<void>.delayed(const Duration(milliseconds: 200));
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      await work.reconcileGoals();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await store.close();
      store = await SqlitePlannerStore.open(path: path);

      final recovered = repository().routineWorkspace;
      final view = (await recovered.read(routine.id, day))!;
      final elapsed = view.actualAt(now);
      expect(elapsed, greaterThan(Duration.zero));
      expect(elapsed, lessThan(const Duration(minutes: 30)));
      expect(view.timer!.id, original.id);
      expect(view.timer!.startedOnDevice, original.startedOnDevice);
      expect(
        view.timer!.runningSince!.difference(now).abs(),
        lessThan(const Duration(minutes: 30)),
      );
      expect(view.goalReachedAt(now), isFalse);
      await recovered.pause(view.timer!);
      final paused = (await store.routineTimers()).single;
      expect(paused.accumulated, greaterThanOrEqualTo(elapsed));
      await recovered.start(routine.id, day, resumeId: paused.id);
      now = now.subtract(const Duration(days: 2));
      await Future.wait([recovered.stop(paused), recovered.stop(paused)]);
      final log = (await store.timeLogs.all()).single;
      expect(log.id, original.id);
      expect(log.actualDuration, greaterThanOrEqualTo(paused.accumulated));
      expect(log.actualDuration, lessThan(const Duration(minutes: 30)));
      expect(await store.routineTimers(), isEmpty);
      expect(
        (await store.routineOccurrences.all()).single.status,
        ActivityStatus.planned,
      );
    },
    skip: !Platform.isAndroid,
  );
}
