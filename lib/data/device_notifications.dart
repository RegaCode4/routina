import 'package:flutter/services.dart';
import 'package:routina/application/local_reminders.dart';

class DeviceNotifications implements NotificationPlatform {
  const DeviceNotifications();
  static const _channel = MethodChannel('routina/notifications');

  @override
  Future<NotificationPermission> permission() async =>
      switch (await _channel.invokeMethod<String>('permission')) {
        'authorized' => NotificationPermission.authorized,
        'denied' => NotificationPermission.denied,
        'notDetermined' => NotificationPermission.notDetermined,
        _ => NotificationPermission.unavailable,
      };

  @override
  Future<void> requestPermission() => _channel.invokeMethod<void>('request');

  @override
  Future<void> openSettings() => _channel.invokeMethod<void>('settings');

  @override
  Future<void> synchronize(List<LocalReminder> reminders, QuietPolicy? quiet) =>
      _channel.invokeMethod<void>('sync', {
        'reminders': [
          for (final reminder in reminders)
            {
              'id': reminder.id,
              'kind': reminder.kind.name,
              'title': reminder.title,
              'body': reminder.body,
              'at': reminder.at.millisecondsSinceEpoch,
              'expires': reminder.expires.millisecondsSinceEpoch,
              'deviceTime': reminder.deviceTime,
              'catchUp': reminder.catchUp,
            },
        ],
        'quiet': quiet == null
            ? null
            : {
                'start': quiet.hours.startMinute,
                'end': quiet.hours.endMinute,
                'exceptions': quiet.exceptions
                    .map((kind) => kind.name)
                    .toList(),
              },
      });
}
