import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:routina/application/planner_preview.dart';
import 'package:routina/presentation/app_shell.dart';
import 'package:routina/presentation/design_system/neo_theme.dart';
import 'package:routina/presentation/planner/setup_screens.dart';

class RoutinaApp extends StatelessWidget {
  const RoutinaApp({required this.repository, super.key});
  final PlannerPreviewRepository repository;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Routina',
    locale: const Locale('id'),
    supportedLocales: const [Locale('id')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    debugShowCheckedModeBanner: false,
    theme: buildNeoTheme(),
    home: PlannerStartup(
      repository: repository,
      shell: AppShell(repository: repository),
    ),
  );
}
