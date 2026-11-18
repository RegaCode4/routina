import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:routina/application/local_reminders.dart';
import 'package:routina/data/device_clock.dart';
import 'package:routina/data/device_notifications.dart';
import 'package:routina/domain/planner_records.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'final Android identity keeps platform bridges and receiver alive',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      final databaseDirectory = await getDatabasesPath();
      expect(databaseDirectory, contains('/com.regacode.routina/'));
      expect(await const DeviceClock().timerSample(), isNotNull);
      final zone = await const MethodChannel(
        'routina/device_time_zone',
      ).invokeMethod<String>('identifier');
      expect(zone, isNotEmpty);

      const notifications = DeviceNotifications();
      var permission = await notifications.permission();
      expect(permission, isNot(NotificationPermission.unavailable));
      // Enable this probe only on a synthetic emulator with permission granted.
      if (!const bool.fromEnvironment('ROUTINA_NATIVE_REMINDER_PROBE')) return;
      final permissionDeadline = DateTime.now().add(
        const Duration(seconds: 30),
      );
      while (permission != NotificationPermission.authorized &&
          DateTime.now().isBefore(permissionDeadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        permission = await notifications.permission();
      }
      expect(permission, NotificationPermission.authorized);
      await notifications.requestPermission();
      addTearDown(() => notifications.synchronize([], null));
      final now = DateTime.now();
      await notifications.synchronize([
        LocalReminder(
          id: 'f20a-native-identity',
          kind: ReminderKind.deadline,
          title: 'Routina F20A',
          body: 'Uji receiver pada identitas final.',
          at: now.add(const Duration(seconds: 2)),
          expires: now.add(const Duration(minutes: 2)),
        ),
      ], null);
      final root = Directory(databaseDirectory).parent.path;
      final preferences = File(
        '$root/shared_prefs/routina_notification_queue.xml',
      );
      final deadline = now.add(const Duration(seconds: 30));
      var posted = false;
      while (DateTime.now().isBefore(deadline)) {
        final xml = await preferences.readAsString();
        final match = RegExp(
          r'<string name="plan">(.*?)</string>',
        ).firstMatch(xml);
        final text = match
            ?.group(1)
            ?.replaceAll('&quot;', '"')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>');
        if (text != null) {
          final plan = jsonDecode(text) as Map<String, dynamic>;
          final job =
              (plan['jobs'] as Map<String, dynamic>?)?['f20a-native-identity'];
          posted = job is Map && job['posted'] == true;
        }
        if (posted) break;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(
        posted,
        isTrue,
        reason: 'The explicit native receiver must deliver.',
      );
      // Give the device operator time to inspect the actual OS notification.
      debugPrint('F20A_NATIVE_NOTIFICATION_POSTED');
      await Future<void>.delayed(const Duration(seconds: 20));
    },
    skip: !Platform.isAndroid,
  );
}
