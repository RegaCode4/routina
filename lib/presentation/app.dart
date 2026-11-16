import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:routina/application/read_today.dart';
import 'package:routina/presentation/app_shell.dart';

class RoutinaApp extends StatelessWidget {
  const RoutinaApp({required this.readToday, super.key});

  final ReadToday readToday;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF171717);
    const cream = Color(0xFFF5F2E9);
    const yellow = Color(0xFFFFE65B);

    return MaterialApp(
      title: 'Routina',
      locale: const Locale('id'),
      supportedLocales: const [Locale('id')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        fontFamily: 'Bricolage Grotesque',
        scaffoldBackgroundColor: cream,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF537BFF),
          onPrimary: ink,
          secondary: yellow,
          onSecondary: ink,
          error: Color(0xFFFF8C82),
          onError: ink,
          surface: cream,
          onSurface: ink,
        ),
        appBarTheme: const AppBarTheme(backgroundColor: cream),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: ink,
            side: const BorderSide(color: ink, width: 2),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: ink),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFFFFFDF7),
          indicatorColor: yellow,
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      home: AppShell(readToday: readToday),
    );
  }
}
