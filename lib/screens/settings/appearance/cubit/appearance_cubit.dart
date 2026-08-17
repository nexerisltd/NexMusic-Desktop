import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:nexmusic/services/settings_manager.dart';

part 'appearance_state.dart';

class AppearanceCubit extends Cubit<AppearanceState> {
  final SettingsManager _settings = GetIt.I<SettingsManager>();

  late final VoidCallback _listener;

  AppearanceCubit()
      : super(
          AppearanceLoaded(
            themeMode: GetIt.I<SettingsManager>().themeMode,
            accentColor: GetIt.I<SettingsManager>().accentColor,
            amoledBlack: GetIt.I<SettingsManager>().amoledBlack,
            dynamicColors: GetIt.I<SettingsManager>().dynamicColors,
            lyricsTextSize: GetIt.I<SettingsManager>().lyricsTextSize,
            lyricsLineSpacing: GetIt.I<SettingsManager>().lyricsLineSpacing,
            autoScrollLyrics: GetIt.I<SettingsManager>().autoScrollLyrics,
            thumbnailCornerRadius:
                GetIt.I<SettingsManager>().thumbnailCornerRadius,
            hidePlayerThumbnail:
                GetIt.I<SettingsManager>().hidePlayerThumbnail,
            playerBackgroundStyle:
                GetIt.I<SettingsManager>().playerBackgroundStyle,
            cropAlbumArt: GetIt.I<SettingsManager>().cropAlbumArt,
            playerButtonsStyle: GetIt.I<SettingsManager>().playerButtonsStyle,
            lyricsTextPosition: GetIt.I<SettingsManager>().lyricsTextPosition,
            defaultOpenTab: GetIt.I<SettingsManager>().defaultOpenTab,
          ),
        ) {
    _listener = () {
      if (!isClosed) {
        _emitState();
      }
    };

    _settings.addListener(_listener);
  }

  void _emitState() {
    if (isClosed) return;

    emit(
      AppearanceLoaded(
        themeMode: _settings.themeMode,
        accentColor: _settings.accentColor,
        amoledBlack: _settings.amoledBlack,
        dynamicColors: _settings.dynamicColors,
        lyricsTextSize: _settings.lyricsTextSize,
        lyricsLineSpacing: _settings.lyricsLineSpacing,
        autoScrollLyrics: _settings.autoScrollLyrics,
        thumbnailCornerRadius: _settings.thumbnailCornerRadius,
        hidePlayerThumbnail: _settings.hidePlayerThumbnail,
        playerBackgroundStyle: _settings.playerBackgroundStyle,
        cropAlbumArt: _settings.cropAlbumArt,
        playerButtonsStyle: _settings.playerButtonsStyle,
        lyricsTextPosition: _settings.lyricsTextPosition,
        defaultOpenTab: _settings.defaultOpenTab,
      ),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _settings.setThemeMode(mode);
    // listener will emit
  }

  void setAmoledBlack(bool value) {
    _settings.amoledBlack = value;
  }

  void setDynamicColors(bool value) {
    _settings.dynamicColors = value;
  }

  void setLyricsTextSize(double value) {
    _settings.lyricsTextSize = value;
  }

  void setLyricsLineSpacing(double value) {
    _settings.lyricsLineSpacing = value;
  }

  void setAutoScrollLyrics(bool value) {
    _settings.autoScrollLyrics = value;
  }

  void setThumbnailCornerRadius(double value) {
    _settings.thumbnailCornerRadius = value;
  }

  void setHidePlayerThumbnail(bool value) {
    _settings.hidePlayerThumbnail = value;
  }

  void setPlayerBackgroundStyle(int value) {
    _settings.playerBackgroundStyle = value;
  }

  void setCropAlbumArt(bool value) {
    _settings.cropAlbumArt = value;
  }

  void setPlayerButtonsStyle(int value) {
    _settings.playerButtonsStyle = value;
  }

  void setLyricsTextPosition(int value) {
    _settings.lyricsTextPosition = value;
  }

  void setDefaultOpenTab(int value) {
    _settings.defaultOpenTab = value;
  }

  @override
  Future<void> close() {
    _settings.removeListener(_listener);
    return super.close();
  }
}
