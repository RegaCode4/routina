import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routina/application/read_today.dart';
import 'package:routina/domain/clock.dart';
import 'package:routina/presentation/app.dart';

final class _TestClock implements Clock {
  DateTime date = DateTime(2026, 11, 16);
  bool unavailable = false;

  @override
  DateTime now() {
    if (unavailable) throw Exception('internal clock error');
    return date;
  }
}

void main() {
  testWidgets('opens all five tabs and returns from Home Statistik', (
    tester,
  ) async {
    await tester.pumpWidget(RoutinaApp(readToday: ReadToday(_TestClock())));
    await tester.pumpAndSettle();

    final navigation = find.byType(NavigationBar);
    for (final label in [
      'Kalender',
      'To-Do List',
      'Rutinitas',
      'Profil',
      'Home',
    ]) {
      await tester.tap(
        find.descendant(of: navigation, matching: find.text(label)),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(label)),
        findsOneWidget,
      );
    }

    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();
    expect(navigation, findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Statistik'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(navigation, findsOneWidget);
    expect(tester.widget<NavigationBar>(navigation).selectedIndex, 0);
  });

  testWidgets('shows a safe failure message and retries the date', (
    tester,
  ) async {
    final clock = _TestClock()..unavailable = true;
    await tester.pumpWidget(RoutinaApp(readToday: ReadToday(clock)));
    await tester.pumpAndSettle();

    expect(
      find.text('Tanggal perangkat belum dapat ditampilkan.'),
      findsOneWidget,
    );
    expect(find.textContaining('internal clock error'), findsNothing);
    clock.unavailable = false;

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('16 November 2026'), findsOneWidget);
  });

  testWidgets('refreshes the date on resume and keeps the selected tab', (
    tester,
  ) async {
    final clock = _TestClock();
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(RoutinaApp(readToday: ReadToday(clock)));
    await tester.pumpAndSettle();
    expect(find.textContaining('16 November 2026'), findsOneWidget);

    final navigation = find.byType(NavigationBar);
    await tester.tap(find.text('Kalender'));
    await tester.pumpAndSettle();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    clock.date = DateTime(2026, 11, 17);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(tester.widget<NavigationBar>(navigation).selectedIndex, 1);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.textContaining('17 November 2026'), findsOneWidget);
  });

  testWidgets('keeps the shell usable with large text on a narrow device', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(RoutinaApp(readToday: ReadToday(_TestClock())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('To-Do List'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Fitur halaman ini belum tersedia.'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
  });
}
