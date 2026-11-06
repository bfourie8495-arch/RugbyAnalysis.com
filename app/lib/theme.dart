import 'package:flutter/material.dart';

/// The RugbyAnalysis.com colours, the same as the website and the prototype:
/// deep navy pages, slightly lighter cards, gold for what matters most.
/// Gold is for highlights and numbers; body text is [ink] or [muted].
class RaColors {
  static const page = Color(0xFF0E1B30); // page background
  static const bar = Color(0xFF0B1628); // bottom navigation
  static const card = Color(0xFF14243D);
  static const cardHi = Color(0xFF1A2C48); // a highlighted row (your team)
  static const line = Color(0xFF1F3355); // card borders and dividers
  static const line2 = Color(0xFF2A4066); // chips and input borders
  static const track = Color(0xFF22365A); // empty part of a bar
  static const gold = Color(0xFFC9A24B);
  static const goldSoft = Color(0xFFE2C47C);
  static const ink = Color(0xFFF4EFE4); // main text
  static const muted = Color(0xFFA8B3C7); // secondary text
  static const faint = Color(0xFF97A3BA); // small labels
  static const away = Color(0xFF6E8FE6); // the other side of a pick bar
  static const onGold = Color(0xFF10213A); // text on gold
}

/// Bundled fonts (assets/fonts, declared in pubspec.yaml).
const display = 'Poppins'; // titles, scores, big numbers
const body = 'Figtree'; // everything else

const pill = StadiumBorder();

/// Cards: navy, a 1px line, radius 18 (as in the prototype).
BoxDecoration cardDecoration({Color color = RaColors.card, Color border = RaColors.line, double radius = 18}) =>
    BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius), border: Border.all(color: border));

TextStyle displayStyle(double size, {Color color = RaColors.ink, FontWeight weight = FontWeight.w700}) =>
    TextStyle(fontFamily: display, fontSize: size, fontWeight: weight, color: color, height: 1.15, letterSpacing: -0.2);

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: RaColors.gold,
    onPrimary: RaColors.onGold,
    secondary: RaColors.goldSoft,
    surface: RaColors.page,
    onSurface: RaColors.ink,
    outline: RaColors.line2,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: RaColors.page,
    fontFamily: body,
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontFamily: display, fontWeight: FontWeight.w700, fontSize: 22, color: RaColors.ink),
      titleMedium: TextStyle(fontFamily: display, fontWeight: FontWeight.w700, fontSize: 18, color: RaColors.ink),
      bodyLarge: TextStyle(fontSize: 16, color: RaColors.ink),
      bodyMedium: TextStyle(fontSize: 14, color: RaColors.ink),
      bodySmall: TextStyle(fontSize: 12, color: RaColors.faint),
      labelLarge: TextStyle(fontWeight: FontWeight.w700),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: RaColors.page,
      foregroundColor: RaColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontFamily: display, fontWeight: FontWeight.w700, fontSize: 20, color: RaColors.ink),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: RaColors.bar,
      indicatorColor: RaColors.cardHi,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected) ? RaColors.gold : RaColors.faint,
          )),
      iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? RaColors.gold : RaColors.faint)),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: RaColors.page,
      selectedColor: RaColors.gold,
      side: BorderSide(color: RaColors.line2),
      labelStyle: TextStyle(fontFamily: body, fontWeight: FontWeight.w600, fontSize: 13),
      shape: pill,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? RaColors.onGold : RaColors.ink),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? RaColors.gold : RaColors.line2),
    ),
    dividerColor: RaColors.line,
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: RaColors.ink,
      contentTextStyle: TextStyle(color: RaColors.onGold, fontWeight: FontWeight.w700),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
