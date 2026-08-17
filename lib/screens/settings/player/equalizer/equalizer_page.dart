import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:nexmusic/screens/settings/player/equalizer/cubit/equalizer_cubit.dart';
import 'package:nexmusic/screens/settings/player/equalizer/cubit/equalizer_state.dart';
import 'package:nexmusic/screens/settings/player/equalizer/cubit/loudness_cubit.dart';
import 'package:nexmusic/screens/settings/player/equalizer/cubit/loudness_state.dart';
import 'package:nexmusic/generated/l10n.dart';
import 'package:nexmusic/screens/settings/widgets/setting_item.dart';
import 'package:nexmusic/services/media_player.dart';
import 'package:nexmusic/services/settings_manager.dart';
import 'package:nexmusic/themes/text_styles.dart';
import 'package:nexmusic/utils/adaptive_widgets/slider.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../services/equalizer_backend.dart';
import 'eq_presets.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

class EqualizerPage extends StatelessWidget {
  const EqualizerPage({super.key});

  Future<Widget> _build(BuildContext context) async {
    final settings = GetIt.I<SettingsManager>();
    final eqBackend = GetIt.I<EqualizerBackend>();

    final eqCubit = EqualizerCubit(
      enabled: settings.equalizerEnabled,
      minDb: eqBackend.minDecibels,
      maxDb: eqBackend.maxDecibels,
      bands: eqBackend.bands
          .map(
            (b) => EqBand(
              index: b.index,
              centerFrequency: b.centerFrequency,
              gain: b.gain,
            ),
          )
          .toList(),
    );

    final loudnessCubit = LoudnessCubit(
      enabled: settings.loudnessEnabled,
      targetGain: settings.loudnessTargetGain,
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: eqCubit),
        BlocProvider.value(value: loudnessCubit),
      ],
      child: const _EqualizerView(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _build(context),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: ExpressiveLoadingIndicator()),
          );
        }
        return snapshot.data!;
      },
    );
  }
}

class _EqualizerView extends StatelessWidget {
  const _EqualizerView();

  Future<void> _applyPreset(BuildContext context, List<double> gains) async {
    final settings = GetIt.I<SettingsManager>();
    context.read<EqualizerCubit>().setAllBands(gains);
    settings.equalizerBandsGain = List<double>.from(gains);
    await GetIt.I<EqualizerBackend>().setAllBands(gains);
  }

  bool _matchesPreset(List<EqBand> bands, List<double> presetGains) {
    if (bands.length != presetGains.length) return false;
    for (var i = 0; i < bands.length; i++) {
      if ((bands[i].gain - presetGains[i]).abs() > 0.01) return false;
    }
    return true;
  }

  Widget _presetSection(
    BuildContext context,
    String title,
    List<EqPreset> presets,
    List<EqBand> currentBands,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in presets)
                FilterChip(
                  label: Text(preset.name),
                  selected: _matchesPreset(currentBands, preset.gains),
                  showCheckmark: false,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(
                    color: _matchesPreset(currentBands, preset.gains)
                        ? Theme.of(context).colorScheme.onPrimary
                        : null,
                    fontWeight: _matchesPreset(currentBands, preset.gains)
                        ? FontWeight.bold
                        : null,
                  ),
                  onSelected: (_) => _applyPreset(context, preset.gains),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaPlayer = GetIt.I<MediaPlayer>();
    final settings = GetIt.I<SettingsManager>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          S.of(context).Loudness_And_Equalizer,
          style: mediumTextStyle(context, bold: false),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          /// LOUDNESS
          GroupTitle(title: "Loudness"),
          BlocBuilder<LoudnessCubit, LoudnessState>(
            builder: (context, state) {
              return SettingSwitchTile(
                leading: const Icon(Icons.volume_up),
                title: S.of(context).Loudness_Enhancer,
                isFirst: true,
                value: state.enabled,
                onChanged: (val) async {
                  context.read<LoudnessCubit>().toggle(val);
                  await mediaPlayer.setLoudnessEnabled(val);
                },
              );
            },
          ),
          SettingEmptyTile(
            isLast: true,
            child: BlocBuilder<LoudnessCubit, LoudnessState>(
              builder: (context, state) {
                return Slider(
                  min: -1,
                  max: 1,
                  value: state.targetGain,
                  onChanged: state.enabled
                      ? (val) async {
                          context.read<LoudnessCubit>().setTargetGain(val);
                          await mediaPlayer.setLoudnessTargetGain(val);
                        }
                      : null,
                );
              },
            ),
          ),

          /// EQUALIZER
          GroupTitle(title: "Equalizer"),
          BlocBuilder<EqualizerCubit, EqualizerState>(
            builder: (context, state) {
              return SettingSwitchTile(
                leading: const Icon(Icons.equalizer),
                title: S.of(context).Enable_Equalizer,
                isFirst: true,
                value: state.enabled,
                onChanged: (val) async {
                  context.read<EqualizerCubit>().toggle(val);
                  await mediaPlayer.setEqualizerEnabled(val);
                },
              );
            },
          ),
          SettingEmptyTile(
            isLast: true,
            child: BlocBuilder<EqualizerCubit, EqualizerState>(
              builder: (context, state) {
                if (!state.enabled) return const SizedBox();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _presetSection(context, 'Nex Signature', EqPresets.nexSignature, state.bands),
                    _presetSection(context, 'Dolby Atmos', EqPresets.dolbyAtmos, state.bands),
                    _presetSection(context, 'Dirac Audio', EqPresets.diracAudio, state.bands),
                    const SizedBox(height: 8),
                    SizedBox(
                  height: 250,
                  child: Row(
                    children: [
                      for (final band in state.bands)
                        Expanded(
                          child: Column(
                            children: [
                              Text(band.gain.toStringAsFixed(1)),
                              Expanded(
                                child: AdaptiveSlider(
                                  vertical: true,
                                  min: state.minDb,
                                  max: state.maxDb,
                                  value: band.gain,
                                  onChanged: (val) async {
                                    context
                                        .read<EqualizerCubit>()
                                        .setBandGain(band.index, val);

                                    await settings.setEqualizerBandsGain(
                                        band.index, val);

                                    await GetIt.I<EqualizerBackend>()
                                        .setBandGain(band.index, val);
                                  },
                                ),
                              ),
                              Text('${band.centerFrequency.round()} Hz'),
                            ],
                          ),
                        ),
                    ],
                  ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
