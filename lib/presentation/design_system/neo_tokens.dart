import 'package:flutter/material.dart';

abstract final class NeoColors {
  static const blue = Color(0xFF537BFF);
  static const yellow = Color(0xFFFFE65B);
  static const coral = Color(0xFFFF8C82);
  static const cream = Color(0xFFF5F2E9);
  static const ink = Color(0xFF171717);

  static const paper = Color(0xFFFFFDF7);
  static const muted = Color(0xFF51504B);
  static const line = Color(0xFFD1CCC0);
  static const disabled = Color(0xFFE8E4D9);
  static const blueTint = Color(0xFFE6EBFF);
  static const yellowTint = Color(0xFFFFF4AF);
  static const coralTint = Color(0xFFFFE4E0);
  static const greenTint = Color(0xFFD5ECBE);
  static const errorText = Color(0xFF852921);
  static const scrim = Color(0x82171717);

  static const hover = Color(0x18171717);
  static const pressed = Color(0x26171717);
  static const accentHover = Color(0x26FFFDF7);
  static const accentPressed = Color(0x45FFFDF7);
}

abstract final class NeoSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const page = 24.0;
  static const section = 32.0;
}

abstract final class NeoSize {
  static const touch = 48.0;
  static const button = 50.0;
  static const header = 56.0;
  static const fab = 56.0;
  static const nav = 64.0;
  static const cardSample = 78.0;
  static const cardIcon = 42.0;
  static const badgeIcon = 14.0;
  static const navIcon = 22.0;
  static const sheetHandleWidth = 40.0;
  static const progress = 8.0;
}

abstract final class NeoRadius {
  static const small = BorderRadius.all(Radius.circular(6));
  static const input = BorderRadius.all(Radius.circular(8));
  static const card = BorderRadius.all(Radius.circular(10));
  static const hero = BorderRadius.all(Radius.circular(12));
  static const sheet = BorderRadius.vertical(top: Radius.circular(20));
}

abstract final class NeoLine {
  static const thin = BorderSide(color: NeoColors.ink);
  static const subtle = BorderSide(color: NeoColors.line);
  static const outline = BorderSide(color: NeoColors.ink, width: 2);
  static const focus = BorderSide(color: NeoColors.ink, width: 3);
  static const error = BorderSide(color: NeoColors.errorText, width: 2);
  static const errorFocus = BorderSide(color: NeoColors.errorText, width: 3);
}

abstract final class NeoShadow {
  static const button = [BoxShadow(color: NeoColors.ink, offset: Offset(3, 3))];
  static const hard = [BoxShadow(color: NeoColors.ink, offset: Offset(4, 4))];
}

abstract final class NeoType {
  static const sans = 'Bricolage Grotesque';
  static const mono = 'Space Mono';
  static const navSize = 10.0;
  static const navMultilineSize = 16.0;

  static const display = TextStyle(
    fontFamily: sans,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.15,
  );
  static const title = TextStyle(
    fontFamily: sans,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
  static const section = TextStyle(
    fontFamily: sans,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );
  static const item = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );
  static const body = TextStyle(fontFamily: sans, fontSize: 14, height: 1.4);
  static const caption = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    height: 1.35,
  );
  static const badge = TextStyle(
    fontFamily: sans,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );
  static const nav = TextStyle(
    fontFamily: sans,
    fontSize: navSize,
    height: 1.25,
  );
  static const metric = TextStyle(
    fontFamily: mono,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.12,
  );
  static const numericCaption = TextStyle(
    fontFamily: mono,
    fontSize: 12,
    height: 1.35,
  );
}
