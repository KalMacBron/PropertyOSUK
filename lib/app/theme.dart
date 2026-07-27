import 'package:flutter/material.dart';

ThemeData buildPropertyOsTheme() {
  const navy = Color(0xFF14213D);
  const accent = Color(0xFF2F7D6D);

  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      primary: navy,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    useMaterial3: true,
    cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
  );
}
