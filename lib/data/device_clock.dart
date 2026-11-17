import 'dart:io';

import 'package:flutter/services.dart';
import 'package:routina/domain/clock.dart';
import 'package:routina/domain/planner_records.dart';

final class DeviceClock implements Clock {
  const DeviceClock();

  @override
  DateTime now() => DateTime.now();

  Future<TimerClockSample?> timerSample() async {
    if (!Platform.isAndroid) return null;
    try {
      final sample = await const MethodChannel(
        'routina/device_clock',
      ).invokeMapMethod<String, int>('timerSample');
      final bootCount = sample?['bootCount'];
      final uptimeUs = sample?['uptimeUs'];
      return bootCount == null || uptimeUs == null
          ? null
          : (bootCount: bootCount, uptimeUs: uptimeUs);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
