import 'package:flutter/material.dart';

abstract final class PropertyOsColours {
  static const navy = Color(0xFF0B2A3C);
  static const deepNavy = Color(0xFF071F2F);
  static const selectedNavy = Color(0xFF194A64);
  static const amber = Color(0xFFF2B426);
  static const amberText = Color(0xFFA76A08);
  static const workspace = Color(0xFFF3F6F7);
  static const border = Color(0xFFD7E0E5);
  static const ink = Color(0xFF102B3D);
  static const muted = Color(0xFF718697);
  static const success = Color(0xFF238A68);
  static const warning = Color(0xFFD99A16);
  static const critical = Color(0xFFD65353);
}

ThemeData buildPropertyOsTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PropertyOsColours.navy,
    primary: PropertyOsColours.navy,
    secondary: PropertyOsColours.amber,
    surface: Colors.white,
    error: PropertyOsColours.critical,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _NoTransitionsBuilder(),
        TargetPlatform.iOS: _NoTransitionsBuilder(),
        TargetPlatform.linux: _NoTransitionsBuilder(),
        TargetPlatform.macOS: _NoTransitionsBuilder(),
        TargetPlatform.windows: _NoTransitionsBuilder(),
      },
    ),
    colorScheme: scheme,
    scaffoldBackgroundColor: PropertyOsColours.workspace,
    fontFamily: 'Arial',
    textTheme: const TextTheme(
      displayLarge:
          TextStyle(fontFamily: 'Georgia', color: PropertyOsColours.ink),
      displayMedium:
          TextStyle(fontFamily: 'Georgia', color: PropertyOsColours.ink),
      headlineLarge:
          TextStyle(fontFamily: 'Georgia', color: PropertyOsColours.ink),
      headlineMedium:
          TextStyle(fontFamily: 'Georgia', color: PropertyOsColours.ink),
      titleLarge:
          TextStyle(fontFamily: 'Georgia', color: PropertyOsColours.ink),
      bodyLarge: TextStyle(color: PropertyOsColours.ink, height: 1.45),
      bodyMedium: TextStyle(color: PropertyOsColours.ink, height: 1.4),
    ),
    dividerColor: PropertyOsColours.border,
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: PropertyOsColours.border),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.zero),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: PropertyOsColours.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}
