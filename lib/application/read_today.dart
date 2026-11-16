import 'package:routina/domain/clock.dart';
import 'package:routina/domain/result.dart';

final class ReadToday {
  const ReadToday(this._clock);

  final Clock _clock;

  Result<DateTime> call() {
    try {
      final now = _clock.now().toLocal();
      return Success(DateTime(now.year, now.month, now.day));
    } on Exception catch (error, stackTrace) {
      return Failure(error, stackTrace);
    }
  }
}
