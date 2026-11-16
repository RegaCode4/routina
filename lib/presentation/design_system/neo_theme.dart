import 'package:flutter/material.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';

ThemeData buildNeoTheme() {
  const scheme = ColorScheme.light(
    primary: NeoColors.blue,
    onPrimary: NeoColors.ink,
    secondary: NeoColors.yellow,
    onSecondary: NeoColors.ink,
    error: NeoColors.errorText,
    onError: NeoColors.paper,
    surface: NeoColors.cream,
    onSurface: NeoColors.ink,
  );

  return ThemeData(
    colorScheme: scheme,
    fontFamily: NeoType.sans,
    scaffoldBackgroundColor: NeoColors.cream,
    textTheme: const TextTheme(
      headlineLarge: NeoType.display,
      headlineSmall: NeoType.section,
      titleLarge: NeoType.title,
      titleMedium: NeoType.item,
      bodyLarge: NeoType.body,
      bodyMedium: NeoType.body,
      bodySmall: NeoType.caption,
      labelLarge: NeoType.item,
      labelSmall: NeoType.badge,
    ).apply(bodyColor: NeoColors.ink, displayColor: NeoColors.ink),
    iconTheme: const IconThemeData(color: NeoColors.ink),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: NeoColors.ink),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: NeoColors.ink,
      selectionColor: NeoColors.blueTint,
      selectionHandleColor: NeoColors.ink,
    ),
    inputDecorationTheme: const InputDecorationThemeData(
      filled: true,
      fillColor: NeoColors.paper,
      constraints: BoxConstraints(minHeight: NeoSize.touch),
      contentPadding: EdgeInsets.all(NeoSpace.sm),
      labelStyle: NeoType.body,
      floatingLabelStyle: NeoType.item,
      hintStyle: TextStyle(color: NeoColors.muted),
      helperStyle: TextStyle(color: NeoColors.muted),
      errorStyle: TextStyle(color: NeoColors.errorText),
      helperMaxLines: 4,
      errorMaxLines: 5,
      prefixIconColor: NeoColors.ink,
      suffixIconColor: NeoColors.ink,
      border: OutlineInputBorder(
        borderRadius: NeoRadius.input,
        borderSide: NeoLine.outline,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: NeoRadius.input,
        borderSide: NeoLine.outline,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: NeoRadius.input,
        borderSide: NeoLine.focus,
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: NeoRadius.input,
        borderSide: NeoLine.subtle,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: NeoRadius.input,
        borderSide: NeoLine.error,
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: NeoRadius.input,
        borderSide: NeoLine.errorFocus,
      ),
    ),
  );
}
