import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:routina/application/read_today.dart';
import 'package:routina/presentation/app_shell.dart';
import 'package:routina/presentation/design_system/neo_theme.dart';

class RoutinaApp extends StatelessWidget {
  const RoutinaApp({required this.readToday, super.key});

  final ReadToday readToday;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Routina',
      locale: const Locale('id'),
      supportedLocales: const [Locale('id')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: buildNeoTheme(),
      home: AppShell(readToday: readToday),
    );
  }
}
