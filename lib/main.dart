import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:routina/application/read_today.dart';
import 'package:routina/data/device_clock.dart';
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

  runApp(const RoutinaApp(readToday: ReadToday(DeviceClock())));
}
