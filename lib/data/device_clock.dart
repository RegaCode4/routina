import 'package:routina/domain/clock.dart';

final class DeviceClock implements Clock {
  const DeviceClock();

  @override
  DateTime now() => DateTime.now();
}
