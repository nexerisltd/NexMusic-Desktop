part of 'appearance_cubit.dart';

@immutable
sealed class AppearanceState {
  const AppearanceState();
}

class AppearanceLoaded extends AppearanceState {
  final ThemeMode themeMode;
  final Color? accentColor;
  final bool amoledBlack;
  final bool dynamicColors;
  final double lyricsTextSize;
  final double lyricsLineSpacing;
  final bool autoScrollLyrics;
  final double thumbnailCornerRadius;
  final bool hidePlayerThumbnail;
  final int playerBackgroundStyle;

  const AppearanceLoaded({
    required this.themeMode,
    required this.accentColor,
    required this.amoledBlack,
    required this.dynamicColors,
    required this.lyricsTextSize,
    required this.lyricsLineSpacing,
    required this.autoScrollLyrics,
    required this.thumbnailCornerRadius,
    required this.hidePlayerThumbnail,
    required this.playerBackgroundStyle,
  });
}
