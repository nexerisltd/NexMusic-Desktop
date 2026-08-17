import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../generated/l10n.dart';
import '../widgets/setting_item.dart';
import 'cubit/player_settings_cubit.dart';

class PlayerSettingsPage extends StatelessWidget {
  const PlayerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PlayerSettingsCubit(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Player"),
        ),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: BlocBuilder<PlayerSettingsCubit, PlayerSettingsState>(
              builder: (context, state) {
                final s = state as PlayerSettingsLoaded;

                return ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    /// Close/minimize to tray (desktop only)
                    if (Platform.isWindows || Platform.isLinux)
                      SettingSwitchTile(
                        title: "Close to tray",
                        subtitle:
                            "Keep NexMusic running in the background when you close the window",
                        leading: const Icon(
                          Icons.push_pin_outlined,
                        ),
                        value: s.closeToTray,
                        onChanged: (value) {
                          context
                              .read<PlayerSettingsCubit>()
                              .setCloseToTray(value);
                        },
                        isFirst: true,
                        isLast: false,
                      ),

                    if (Platform.isWindows || Platform.isLinux)
                      SettingSwitchTile(
                        title: "Minimize to tray",
                        subtitle:
                            "Hide NexMusic to the system tray when you minimize the window",
                        leading: const Icon(
                          Icons.minimize,
                        ),
                        value: s.minimizeToTray,
                        onChanged: (value) {
                          context
                              .read<PlayerSettingsCubit>()
                              .setMinimizeToTray(value);
                        },
                        isFirst: false,
                        isLast: Platform.isWindows,
                      ),

                    /// Skip silence
                    if (!Platform.isWindows)
                      SettingSwitchTile(
                        title: S.of(context).Skip_Silence,
                        leading: const Icon(
                          Icons.fast_forward,
                        ),
                        value: s.skipSilence,
                        onChanged: (value) {
                          context
                              .read<PlayerSettingsCubit>()
                              .setSkipSilence(value);
                        },
                        isFirst: !Platform.isAndroid,
                        isLast: true,
                      ),

                    const Padding(
                      padding: EdgeInsets.only(top: 24, bottom: 8, left: 4),
                      child: Text(
                        "Audio",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    SettingTile(
                      title: "Loudness & Equalizer",
                      subtitle:
                          "Adjust playback loudness and the 10-band graphic equalizer",
                      leading: const Icon(Icons.equalizer),
                      isFirst: true,
                      isLast: true,
                      onTap: () => context.go('/settings/player/equalizer'),
                    ),

                    const Padding(
                      padding: EdgeInsets.only(top: 24, bottom: 8, left: 4),
                      child: Text(
                        "Queue",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    SettingSwitchTile(
                      title: "Persistent shuffle",
                      subtitle:
                          "Keep shuffle enabled when starting new songs or playlists",
                      leading: const Icon(Icons.shuffle),
                      value: s.persistentShuffle,
                      onChanged: (value) {
                        context
                            .read<PlayerSettingsCubit>()
                            .setPersistentShuffle(value);
                      },
                      isFirst: true,
                      isLast: false,
                    ),

                    SettingSwitchTile(
                      title: "Remember shuffle and repeat",
                      subtitle:
                          "Remember shuffle and repeat mode when restarting the app",
                      leading: const Icon(Icons.repeat),
                      value: s.rememberShuffleAndRepeat,
                      onChanged: (value) {
                        context
                            .read<PlayerSettingsCubit>()
                            .setRememberShuffleAndRepeat(value);
                      },
                      isFirst: false,
                      isLast: false,
                    ),

                    SettingSwitchTile(
                      title: "Prevent duplicate tracks in queue",
                      subtitle:
                          "When adding a track to queue, remove it from its previous position if already present",
                      leading: const Icon(Icons.playlist_add_check),
                      value: s.preventDuplicateTracks,
                      onChanged: (value) {
                        context
                            .read<PlayerSettingsCubit>()
                            .setPreventDuplicateTracks(value);
                      },
                      isFirst: false,
                      isLast: true,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
