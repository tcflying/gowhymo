import 'package:flutter/material.dart';

final ColorScheme lightGrayScheme = ColorScheme.light(
  primary: const Color(0xFF616161),
  onPrimary: Colors.white,
  primaryContainer: const Color(0xFFE0E0E0),
  onPrimaryContainer: const Color(0xFF1F1F1F),
  secondary: const Color(0xFF757575),
  onSecondary: Colors.white,
  secondaryContainer: const Color(0xFFEEEEEE),
  onSecondaryContainer: const Color(0xFF1F1F1F),
  surface: Colors.white,
  onSurface: const Color(0xFF1F1F1F),
  surfaceContainerHighest: const Color(0xFFF5F5F5),
  onSurfaceVariant: const Color(0xFF616161),
  error: const Color(0xFFB00020),
  onError: Colors.white,
  outline: const Color(0xFFBDBDBD),
  outlineVariant: const Color(0xFFE0E0E0),
  shadow: Colors.black.withValues(alpha: 0.15),
  scrim: Colors.black.withValues(alpha: 0.3),
  inverseSurface: const Color(0xFF1F1F1F),
  onInverseSurface: Colors.white,
  inversePrimary: const Color(0xFFBDBDBD),
);

final ColorScheme darkGrayScheme = ColorScheme.dark(
  primary: const Color(0xFFE0E0E0),
  onPrimary: const Color(0xFF1F1F1F),
  primaryContainer: const Color(0xFF424242),
  onPrimaryContainer: const Color(0xFFE0E0E0),
  secondary: const Color(0xFFBDBDBD),
  onSecondary: const Color(0xFF1F1F1F),
  secondaryContainer: const Color(0xFF616161),
  onSecondaryContainer: const Color(0xFFE0E0E0),
  surface: const Color(0xFF121212),
  onSurface: const Color(0xFFE0E0E0),
  surfaceContainerHighest: const Color(0xFF2C2C2C),
  onSurfaceVariant: const Color(0xFFBDBDBD),
  error: const Color(0xFFCF6679),
  onError: Colors.black,
  outline: const Color(0xFF5A5A5A),
  outlineVariant: const Color(0xFF3C3C3C),
  shadow: Colors.black.withValues(alpha: 0.3),
  scrim: Colors.black.withValues(alpha: 0.5),
  inverseSurface: const Color(0xFFE0E0E0),
  onInverseSurface: const Color(0xFF121212),
  inversePrimary: const Color(0xFF424242),
);

final ThemeData darkGrayThemeData = ThemeData(
  useMaterial3: true,
  colorScheme: darkGrayScheme,
  scaffoldBackgroundColor: darkGrayScheme.surface,
  appBarTheme: AppBarTheme(
    backgroundColor: darkGrayScheme.surface,
    foregroundColor: darkGrayScheme.onSurface,
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    color: darkGrayScheme.surface,
    surfaceTintColor: Colors.transparent,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: darkGrayScheme.primary,
      foregroundColor: darkGrayScheme.onPrimary,
    ),
  ),
);

final inputDecorationTheme = InputDecorationTheme(
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
);
