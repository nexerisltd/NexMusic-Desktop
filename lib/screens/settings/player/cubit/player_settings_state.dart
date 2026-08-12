part of 'player_settings_cubit.dart';

@immutable
sealed class PlayerSettingsState {
  const PlayerSettingsState();
}

class PlayerSettingsLoaded extends PlayerSettingsState {
  final bool skipSilence;
  final bool closeToTray;
  final bool minimizeToTray;
  final bool persistentShuffle;
  final bool rememberShuffleAndRepeat;
  final bool preventDuplicateTracks;

  const PlayerSettingsLoaded({
    required this.skipSilence,
    required this.closeToTray,
    required this.minimizeToTray,
    required this.persistentShuffle,
    required this.rememberShuffleAndRepeat,
    required this.preventDuplicateTracks,
  });
}
