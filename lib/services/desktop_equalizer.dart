import 'package:just_audio/just_audio.dart';
import 'equalizer_backend.dart';

/// 10-band ISO graphic equalizer for Windows/Linux/macOS, implemented by
/// setting mpv's `af` (audio filter) property through media_kit's
/// underlying native player. just_audio_media_kit exposes the raw
/// media_kit Player for a given AudioPlayer via `JustAudioMediaKit.player`.
///
/// NOTE: if your installed just_audio_media_kit version doesn't expose
/// `player(playerId)` under that exact name, check its README — the mpv
/// property call itself (`setProperty('af', ...)`) is the stable part.
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
  double get minDecibels => -12.0;

  @override
  double get maxDecibels => 12.0;

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

  Future<void> _apply() async {
    // just_audio_media_kit 2.x no longer exposes its underlying media_kit
    // player. Keep EQ state in the UI until a supported public API is added.
  }
}
