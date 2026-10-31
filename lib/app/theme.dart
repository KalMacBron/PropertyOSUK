import 'package:flutter/material.dart';

/// Brand colour primitives.
///
/// Every text colour here meets WCAG AA (4.5:1) on white and on [workspace].
/// [warning] and [amber] are for fills, borders and icons only, never text.
abstract final class PropertyOsColours {
  static const navy = Color(0xFF0B2A3C);
  static const deepNavy = Color(0xFF071F2F);
  static const selectedNavy = Color(0xFF194A64);
  static const amber = Color(0xFFF2B426);
  static const amberText = Color(0xFF8A5806);
  static const amberTint = Color(0xFFFFF4D8);
  static const workspace = Color(0xFFF3F6F7);
  static const border = Color(0xFFD7E0E5);
  static const ink = Color(0xFF102B3D);
  static const muted = Color(0xFF5B6E7D);
  static const success = Color(0xFF1E7A5C);
  static const warning = Color(0xFFD99A16);
  static const critical = Color(0xFFB83A3A);

  /// Small labels on the navy sidebar (5.44:1 on the organisation card).
  static const sidebarLabel = Color(0xFF8DA5B5);
}

/// Colours for compliance and task statuses, read from the theme with
/// `Theme.of(context).extension<StatusColours>()!` or [StatusColours.of].
@immutable
class StatusColours extends ThemeExtension<StatusColours> {
  const StatusColours({
    required this.overdue,
    required this.dueSoon,
    required this.current,
    required this.notRecorded,
  });

  /// Text-safe colour for overdue items.
  final Color overdue;

  /// Text-safe colour for items inside the warning window.
  final Color dueSoon;

  /// Text-safe colour for items with a current record.
  final Color current;

  /// Text-safe colour for items with no record.
  final Color notRecorded;

  static const standard = StatusColours(
    overdue: PropertyOsColours.critical,
    dueSoon: PropertyOsColours.amberText,
    current: PropertyOsColours.success,
    notRecorded: PropertyOsColours.amberText,
  );

  static StatusColours of(BuildContext context) =>
      Theme.of(context).extension<StatusColours>() ?? standard;

  @override
  StatusColours copyWith({
    Color? overdue,
    Color? dueSoon,
    Color? current,
    Color? notRecorded,
  }) =>
      StatusColours(
        overdue: overdue ?? this.overdue,
        dueSoon: dueSoon ?? this.dueSoon,
        current: current ?? this.current,
        notRecorded: notRecorded ?? this.notRecorded,
      );

  @override
  StatusColours lerp(StatusColours? other, double t) {
    if (other == null) return this;
    return StatusColours(
      overdue: Color.lerp(overdue, other.overdue, t)!,
      dueSoon: Color.lerp(dueSoon, other.dueSoon, t)!,
      current: Color.lerp(current, other.current, t)!,
      notRecorded: Color.lerp(notRecorded, other.notRecorded, t)!,
    );
  }
}

/// Shared text styles that sit outside the Material type scale.
abstract final class PropertyOsText {
  /// Figures that line up in columns, for counts and money.
  static const tabularFigures = [FontFeature.tabularFigures()];

  /// Uppercase eyebrow and tile labels. Store the words in natural case and
  /// call `.toUpperCase()` where they are shown.
  static const eyebrow = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    height: 1.4,
  );
}

const _square = RoundedRectangleBorder(borderRadius: BorderRadius.zero);

/// A 2px navy outline shown while a button has keyboard focus.
WidgetStateProperty<BorderSide?> _focusSide({BorderSide? otherwise}) =>
    WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? const BorderSide(color: PropertyOsColours.navy, width: 2)
          : otherwise,
    );

ThemeData buildPropertyOsTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PropertyOsColours.navy,
    primary: PropertyOsColours.navy,
    secondary: PropertyOsColours.amber,
    surface: Colors.white,
    onSurface: PropertyOsColours.ink,
    onSurfaceVariant: PropertyOsColours.muted,
    outline: PropertyOsColours.border,
    error: PropertyOsColours.critical,
    brightness: Brightness.light,
  );
  // Headings and body text use the platform default family. No custom font
  // is bundled; CanvasKit cannot load operating-system fonts by name.
  const ink = PropertyOsColours.ink;
  const textTheme = TextTheme(
    displayLarge: TextStyle(color: ink, fontSize: 52, height: 1.08),
    displayMedium: TextStyle(color: ink, fontSize: 40, height: 1.15),
    displaySmall: TextStyle(
      color: ink,
      fontSize: 34,
      height: 1.2,
      fontFeatures: PropertyOsText.tabularFigures,
    ),
    headlineLarge: TextStyle(color: ink, fontSize: 32, height: 1.25),
    headlineMedium: TextStyle(color: ink, fontSize: 28, height: 1.25),
    headlineSmall: TextStyle(color: ink, fontSize: 24, height: 1.3),
    titleLarge: TextStyle(color: ink, fontSize: 22, height: 1.3),
    titleMedium: TextStyle(
        color: ink, fontSize: 16, fontWeight: FontWeight.w600, height: 1.5),
    titleSmall: TextStyle(
        color: ink, fontSize: 14, fontWeight: FontWeight.w600, height: 1.45),
    bodyLarge: TextStyle(color: ink, fontSize: 16, height: 1.5),
    bodyMedium: TextStyle(color: ink, fontSize: 14, height: 1.5),
    bodySmall:
        TextStyle(color: PropertyOsColours.muted, fontSize: 12, height: 1.4),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      height: 1.4,
    ),
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
    extensions: const [StatusColours.standard],
    scaffoldBackgroundColor: PropertyOsColours.workspace,
    textTheme: textTheme,
    dividerColor: PropertyOsColours.border,
    // Visible focus on light surfaces: navy at 16% instead of black at 12%.
    focusColor: PropertyOsColours.navy.withValues(alpha: 0.16),
    hoverColor: PropertyOsColours.navy.withValues(alpha: 0.06),
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
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: PropertyOsColours.navy, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: _square,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ).copyWith(
        // A navy outline would vanish against the navy fill, so the filled
        // button uses an amber outline while focused.
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? const BorderSide(color: PropertyOsColours.amber, width: 3)
              : null,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: _square).copyWith(
        side: _focusSide(
          otherwise: const BorderSide(color: PropertyOsColours.border),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: _square).copyWith(
        side: _focusSide(),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(shape: _square).copyWith(
        side: _focusSide(),
      ),
    ),
    listTileTheme: const ListTileThemeData(shape: _square),
    dialogTheme: const DialogThemeData(shape: _square),
    chipTheme: const ChipThemeData(shape: _square),
    drawerTheme: const DrawerThemeData(shape: _square),
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
