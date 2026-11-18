import 'package:flutter_test/flutter_test.dart';

/// A static splash has no animation for pumpAndSettle to wait on.
Future<void> waitForPlannerStartup(WidgetTester tester) async {
  final loading = find.bySemanticsLabel('Memuat Routina');
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (loading.evaluate().isNotEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  expect(loading, findsNothing, reason: 'Native startup storage must finish.');
  await tester.pumpAndSettle();
}
