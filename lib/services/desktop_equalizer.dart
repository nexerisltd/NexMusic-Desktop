import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import 'equalizer_backend.dart';

/// 10-band ISO graphic equalizer for Windows/Linux/macOS, implemented by
/// setting mpv's `af` (audio filter) property through media_kit's
/// underlying native player.
///
/// Reaching that underlying player requires two small local additions to
/// the vendored `packages/just_audio_media_kit` copy — see that package's
/// CHANGELOG.md for exactly what was added and why (upstream keeps its
/// player registry entirely private, which is what kept this equalizer
/// from ever applying a real audio effect before).
class DesktopEqualizer implements EqualizerBackend {
  final AudioPlayer audioPlayer;
  bool _enabled = false;

  static const _frequencies = [31.0, 62.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0];

  final List<EqBandInfo> _bands = List.generate(
    _frequencies.length,
    (i) => EqBandInfo(index: i, centerFrequency: _frequencies[i], gain: 0.0),
  );

  DesktopEqualizer(this.audioPlayer);

  @override
  double get minDecibels => -30.0;

  @override
  double get maxDecibels => 50.0;

  @override
  List<EqBandInfo> get bands => _bands;

  @override
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    await _apply();
  }

  @override
  Future<void> setBandGain(int index, double gain) async {
    _bands[index].gain = gain.clamp(minDecibels, maxDecibels);
    if (_enabled) await _apply();
  }

  @override
  Future<void> setAllBands(List<double> gains) async {
    for (var i = 0; i < _bands.length && i < gains.length; i++) {
      _bands[i].gain = gains[i].clamp(minDecibels, maxDecibels);
    }
    if (_enabled) await _apply();
  }

  /// Builds an ffmpeg/mpv `equalizer` filter chain from the current band
  /// gains. Bands left at 0dB are skipped entirely rather than included
  /// as a no-op peaking filter, keeping the chain short when only a few
  /// bands are adjusted.
  String _buildFilterChain() {
    if (_bands.every((b) => b.gain == 0)) return '';

    // Some presets boost several bands by +30/+40dB, which would clip
    // hard. Rather than depend on a limiter filter (mpv builds vary in
    // which optional ffmpeg filters are compiled in — `alimiter` isn't
    // present here and an unknown filter makes mpv reject the *entire*
    // af string, briefly killing audio output entirely), scale every
    // band down by the same amount whenever the loudest band would
    // exceed a safe peak, preserving the preset's relative shape.
    const safePeakDb = 12.0;
    final maxGain = _bands.map((b) => b.gain).reduce((a, b) => a > b ? a : b);
    final headroom = maxGain > safePeakDb ? maxGain - safePeakDb : 0.0;

    final segments = <String>[
      for (final band in _bands)
        if (band.gain != 0)
          'equalizer=f=${band.centerFrequency.round()}'
          ':width_type=o:width=1'
          ':g=${(band.gain - headroom).toStringAsFixed(2)}',
    ];
    return segments.join(',');
  }

  Future<void> _apply() async {
    final platform = JustAudioPlatform.instance;
    if (platform is! JustAudioMediaKit) return;

    final player = platform.currentPlayer;
    if (player == null) return;

    final chain = _enabled ? _buildFilterChain() : '';
    await player.setMpvProperty('af', chain);
  }
}
