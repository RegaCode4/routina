import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/read_today.dart';
import 'package:routina/domain/clock.dart';
import 'package:routina/domain/result.dart';

final class _TestClock implements Clock {
  const _TestClock(this.read);

  final DateTime Function() read;

  @override
  DateTime now() => read();
}

void main() {
  test('reads the local calendar day without a time component', () {
    final readToday = ReadToday(_TestClock(() => DateTime(2026, 11, 16, 23)));

    expect((readToday() as Success<DateTime>).value, DateTime(2026, 11, 16));
  });

  test('preserves the exception and stack for a recoverable failure', () {
    final exception = Exception('clock unavailable');
    final readToday = ReadToday(_TestClock(() => throw exception));

    final result = readToday() as Failure<DateTime>;

    expect(result.exception, same(exception));
    expect(result.stackTrace.toString(), isNotEmpty);
  });

  test('lets programming errors propagate', () {
    final readToday = ReadToday(_TestClock(() => throw StateError('test')));

    expect(readToday.call, throwsStateError);
  });
}
