import 'package:routina/application/local_reminders.dart';

class FakeNotifications implements NotificationPlatform {
  NotificationPermission access = NotificationPermission.authorized;
  NotificationPermission answer = NotificationPermission.denied;
  List<LocalReminder> queued = [];
  QuietPolicy? quiet;
  int requests = 0;
  int settingsOpens = 0;
  int synchronizations = 0;
  bool failOnce = false;

  @override
  Future<NotificationPermission> permission() async => access;

  @override
  Future<void> requestPermission() async {
    requests++;
    access = answer;
  }

  @override
  Future<void> openSettings() async => settingsOpens++;

  @override
  Future<void> synchronize(
    List<LocalReminder> reminders,
    QuietPolicy? quiet,
  ) async {
    synchronizations++;
    if (failOnce) {
      failOnce = false;
      throw StateError('Test platform failure');
    }
    this.quiet = quiet;
    queued = List.of(reminders);
  }
}
