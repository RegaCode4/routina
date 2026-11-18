import 'package:flutter/material.dart';

/// Approved FigCraft branding; the full transparent viewport matches Android.
abstract final class RoutinaBrand {
  static const ember = Color(0xFFEE613E);
  static const splashAsset = 'assets/branding/routina-splash.png';
  static const splashViewport = 288.0;
}

class RoutinaBrandMark extends StatelessWidget {
  const RoutinaBrandMark({super.key});

  @override
  Widget build(BuildContext context) => Image.asset(
    RoutinaBrand.splashAsset,
    width: RoutinaBrand.splashViewport,
    height: RoutinaBrand.splashViewport,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    excludeFromSemantics: true,
  );
}
