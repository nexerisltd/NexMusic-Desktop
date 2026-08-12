import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// NexMusic's type system pairs Space Grotesk (a geometric, slightly
/// technical display face) for anything headline-weight or larger with
/// Inter for body/label text, which stays highly readable at small
/// sizes. This replaces the previous system-default font across the
/// whole app.
TextTheme appTextTheme(TextTheme? textTheme) {
  textTheme ??= ThemeData.light().textTheme;

  final display = GoogleFonts.spaceGroteskTextTheme();
  final body = GoogleFonts.interTextTheme();

  return TextTheme(
    displayLarge: display.displayLarge?.copyWith(
      color: textTheme.displayLarge?.color,
      fontWeight: FontWeight.w600,
      fontSize: 57,
      height: 64 / 57,
      letterSpacing: -0.5,
    ),
    displayMedium: display.displayMedium?.copyWith(
      color: textTheme.displayMedium?.color,
      fontWeight: FontWeight.w600,
      fontSize: 45,
      height: 52 / 45,
      letterSpacing: -0.25,
    ),
    displaySmall: display.displaySmall?.copyWith(
      color: textTheme.displaySmall?.color,
      fontWeight: FontWeight.w600,
      fontSize: 36,
      height: 44 / 36,
      letterSpacing: -0.15,
    ),
    headlineLarge: display.headlineLarge?.copyWith(
      color: textTheme.headlineLarge?.color,
      fontWeight: FontWeight.w600,
      fontSize: 32,
      height: 40 / 32,
      letterSpacing: -0.1,
    ),
    headlineMedium: display.headlineMedium?.copyWith(
      color: textTheme.headlineMedium?.color,
      fontWeight: FontWeight.w600,
      fontSize: 28,
      height: 36 / 28,
      letterSpacing: -0.1,
    ),
    headlineSmall: display.headlineSmall?.copyWith(
      color: textTheme.headlineSmall?.color,
      fontWeight: FontWeight.w600,
      fontSize: 24,
      height: 32 / 24,
      letterSpacing: 0,
    ),
    titleLarge: display.titleLarge?.copyWith(
      color: textTheme.titleLarge?.color,
      fontWeight: FontWeight.w600,
      fontSize: 22,
      height: 28 / 22,
      letterSpacing: 0,
    ),
    titleMedium: display.titleMedium?.copyWith(
      color: textTheme.titleMedium?.color,
      fontWeight: FontWeight.w600,
      fontSize: 16,
      height: 24 / 16,
      letterSpacing: 0.1,
    ),
    titleSmall: display.titleSmall?.copyWith(
      color: textTheme.titleSmall?.color,
      fontWeight: FontWeight.w600,
      fontSize: 14,
      height: 20 / 14,
      letterSpacing: 0.05,
    ),
    bodyLarge: body.bodyLarge?.copyWith(
      color: textTheme.bodyLarge?.color,
      fontWeight: FontWeight.normal,
      fontSize: 16,
      height: 24 / 16,
      letterSpacing: 0.15,
    ),
    bodyMedium: body.bodyMedium?.copyWith(
      color: textTheme.bodyMedium?.color,
      fontWeight: FontWeight.normal,
      fontSize: 14,
      height: 20 / 14,
      letterSpacing: 0.1,
    ),
    bodySmall: body.bodySmall?.copyWith(
      color: textTheme.bodySmall?.color,
      fontWeight: FontWeight.normal,
      fontSize: 12,
      height: 16 / 12,
      letterSpacing: 0.15,
    ),
    labelLarge: body.labelLarge?.copyWith(
      color: textTheme.labelLarge?.color?.withAlpha(220),
      fontWeight: FontWeight.w600,
      fontSize: 14,
      height: 20 / 14,
      letterSpacing: 0.1,
    ),
    labelMedium: body.labelMedium?.copyWith(
      color: textTheme.labelMedium?.color?.withAlpha(220),
      fontWeight: FontWeight.w600,
      fontSize: 12,
      height: 16 / 12,
      letterSpacing: 0.2,
    ),
    labelSmall: body.labelSmall?.copyWith(
      color: textTheme.labelSmall?.color?.withAlpha(220),
      fontWeight: FontWeight.w600,
      fontSize: 11,
      height: 16 / 11,
      letterSpacing: 0.2,
    ),
  );
}
