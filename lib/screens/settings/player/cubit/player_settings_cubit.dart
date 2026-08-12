import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../../../../../services/media_player.dart';
import '../../../../../../services/settings_manager.dart';

part 'player_settings_state.dart';

class PlayerSettingsCubit extends Cubit<PlayerSettingsState> {
  final SettingsManager _settings = GetIt.I<SettingsManager>();
  final MediaPlayer _player = GetIt.I<MediaPlayer>();

  late final VoidCallback _listener;

  PlayerSettingsCubit()
      : super(
          PlayerSettingsLoaded(
            skipSilence: GetIt.I<SettingsManager>().skipSilence,
            closeToTray: GetIt.I<SettingsManager>().closeToTray,
            minimizeToTray: GetIt.I<SettingsManager>().minimizeToTray,
            persistentShuffle: GetIt.I<SettingsManager>().persistentShuffle,
            rememberShuffleAndRepeat:
                GetIt.I<SettingsManager>().rememberShuffleAndRepeat,
            preventDuplicateTracks:
                GetIt.I<SettingsManager>().preventDuplicateTracks,
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
      PlayerSettingsLoaded(
        skipSilence: _settings.skipSilence,
        closeToTray: _settings.closeToTray,
        minimizeToTray: _settings.minimizeToTray,
        persistentShuffle: _settings.persistentShuffle,
        rememberShuffleAndRepeat: _settings.rememberShuffleAndRepeat,
        preventDuplicateTracks: _settings.preventDuplicateTracks,
      ),
    );
  }

  Future<void> setSkipSilence(bool value) async {
    await _player.skipSilence(value);
    _settings.skipSilence = value;
    // listener will re-emit
  }

  Future<void> setCloseToTray(bool value) async {
    _settings.closeToTray = value;
    // listener will re-emit
  }

  Future<void> setMinimizeToTray(bool value) async {
    _settings.minimizeToTray = value;
    // listener will re-emit
  }

  Future<void> setPersistentShuffle(bool value) async {
    _settings.persistentShuffle = value;
    // listener will re-emit
  }

  Future<void> setRememberShuffleAndRepeat(bool value) async {
    _settings.rememberShuffleAndRepeat = value;
    // listener will re-emit
  }

  Future<void> setPreventDuplicateTracks(bool value) async {
    _settings.preventDuplicateTracks = value;
    // listener will re-emit
  }

  @override
  Future<void> close() {
    _settings.removeListener(_listener);
    return super.close();
  }
}
