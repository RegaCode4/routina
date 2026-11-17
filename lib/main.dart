import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/application/read_today.dart';
import 'package:routina/data/device_clock.dart';
import 'package:routina/data/device_notifications.dart';
import 'package:routina/data/local/sqlite_planner_store.dart';
import 'package:routina/data/memory_planner_preview.dart';
import 'package:routina/data/stored_planner_profile.dart';
import 'package:routina/domain/preview_event.dart';
import 'package:routina/domain/result.dart';
import 'package:routina/presentation/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stackTrace),
    );
    return true;
  };

  ErrorWidget.builder = (_) => const Padding(
    padding: EdgeInsets.all(16),
    child: Text(
      'Tampilan tidak dapat dimuat.',
      textDirection: TextDirection.ltr,
    ),
  );

  const scenario = String.fromEnvironment('ROUTINA_PREVIEW');
  final today = switch (const ReadToday(DeviceClock())()) {
    Success(:final value) => value,
    Failure() => DateTime(2026, 11, 15),
  };
  runApp(
    RoutinaApp(
      previewScenario: scenario,
      repository: scenario.isEmpty
          ? StoredPlannerProfile(
              today: today,
              openStore: SqlitePlannerStore.open,
              notificationPlatform: const DeviceNotifications(),
              readDeviceZone: () async {
                try {
                  const channel = MethodChannel('routina/device_time_zone');
                  return await channel.invokeMethod<String>('identifier') ??
                      'UTC';
                } on MissingPluginException {
                  return 'UTC';
                } on PlatformException {
                  return 'UTC';
                }
              },
            )
          : MemoryPlannerPreview(
              today: today,
              profile:
                  scenario == 'splash-error' || scenario == 'onboarding-resume'
                  ? null
                  : PreviewProfile(
                      name: 'Nara',
                      notifications: scenario != 'notifications-off',
                      sundayFirst: scenario == 'sunday-first',
                      activeHours: {
                        for (var day = 1; day <= 7; day++)
                          day: ActiveInterval(8 * 60, (day < 6 ? 21 : 20) * 60),
                      },
                    ),
              onboardingStep: scenario == 'onboarding-resume' ? 1 : 0,
              seedCategories: scenario != 'categories-empty',
              fixture:
                  PreviewFixture.values
                      .where((fixture) => fixture.name == scenario)
                      .firstOrNull ??
                  PreviewFixture.standard,
              failOnce: {
                if (scenario == 'splash-error') PreviewSurface.startup,
                if (scenario == 'home-error') PreviewSurface.home,
                if (scenario == 'calendar-error') PreviewSurface.calendar,
              },
              latency: scenario == 'loading'
                  ? const Duration(seconds: 2)
                  : const Duration(milliseconds: 250),
            ),
    ),
  );
}
