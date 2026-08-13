import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'typography.dart';

/// Fallback accent color used when the user hasn't picked one yet.
/// Matches the default seed color used on NexMusic-Android.
const Color defaultThemeColor = Color(0xFFED5564);

class AppTheme {
  static ThemeData light({Color? primary, bool amoledBlack = false}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary ?? defaultThemeColor,
      brightness: Brightness.light,
    );

    return ThemeData.light(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: appTextTheme(ThemeData.light().textTheme),
      colorScheme: colorScheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurface),
        selectedIconTheme: IconThemeData(color: colorScheme.onPrimary),
        indicatorColor: colorScheme.primary,
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle:
            TextStyle(color: colorScheme.primary, fontSize: 11),
        unselectedLabelTextStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.6),
          fontSize: 11,
        ),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: Map<TargetPlatform, PageTransitionsBuilder>.fromIterable(
          TargetPlatform.values,
          value: (_) => const FadeForwardsPageTransitionsBuilder(),
        ),
      ),
    );
  }

  static ThemeData dark({Color? primary, bool amoledBlack = false}) {
    var colorScheme = ColorScheme.fromSeed(
      seedColor: primary ?? defaultThemeColor,
      brightness: Brightness.dark,
    );

    // AMOLED Black: pin surface/background to true black for OLED panels,
    // mirroring `ColorScheme.pureBlack()` on NexMusic-Android.
    if (amoledBlack) {
      colorScheme = colorScheme.copyWith(
        surface: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF0A0A0A),
        surfaceContainer: const Color(0xFF0D0D0D),
        surfaceContainerHigh: const Color(0xFF141414),
        surfaceContainerHighest: const Color(0xFF1A1A1A),
      );
    }

    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: appTextTheme(ThemeData.dark().textTheme),
      colorScheme: colorScheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurface),
        selectedIconTheme: IconThemeData(color: colorScheme.onPrimary),
        indicatorColor: colorScheme.primary,
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: TextStyle(
          color: colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.6),
          fontSize: 11,
        ),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: Map<TargetPlatform, PageTransitionsBuilder>.fromIterable(
          TargetPlatform.values,
          value: (_) => const FadeForwardsPageTransitionsBuilder(),
        ),
      ),
    );
  }
}
