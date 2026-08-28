import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:nexmusic/services/media_player.dart';
import 'package:nexmusic/services/settings_manager.dart';
import 'package:nexmusic/utils/extensions.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

class PlayPauseButton extends StatefulWidget {
  const PlayPauseButton({
    super.key,
    this.size = 30,
  });

  final double size;

  @override
  State<PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<PlayPauseButton>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  bool playing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        GetIt.I<MediaPlayer>().togglePlayPause();
      },
      child: ValueListenableBuilder(
        valueListenable: GetIt.I<MediaPlayer>().buttonState,
        builder: (context, buttonState, child) {
          if (GetIt.I<MediaPlayer>().player.playing != playing) {
            playing = GetIt.I<MediaPlayer>().player.playing;
            playing
                ? _animationController.forward()
                : _animationController.reverse();
          }
          final style = GetIt.I<SettingsManager>().playerButtonsStyle;
          final Color buttonColor = switch (style) {
            1 => Theme.of(context).colorScheme.primary,
            2 => Theme.of(context).colorScheme.tertiary,
            _ => context.isDarkMode ? Colors.white : Colors.black,
          };
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 60,
            width: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: buttonColor.withAlpha(50),
              borderRadius: BorderRadius.circular(
                  buttonState == ButtonState.playing ? 15 : 40),
            ),
            child: (buttonState == ButtonState.loading)
                ? const ExpressiveLoadingIndicator()
                : AnimatedIcon(
                    icon: AnimatedIcons.play_pause,
                    progress: _animationController,
                    size: 40,
                  ),
          );
        },
      ),
    );
  }
}
