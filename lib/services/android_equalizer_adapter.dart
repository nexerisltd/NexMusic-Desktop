import 'package:just_audio/just_audio.dart';
import 'equalizer_backend.dart';

/// Wraps just_audio's AndroidEqualizer so it satisfies the same
/// [EqualizerBackend] interface the desktop mpv-based implementation does,
/// letting the settings UI stay platform-agnostic.
class AndroidEqualizerAdapter implements EqualizerBackend {
  final AndroidEqualizer androidEqualizer;
  List<EqBandInfo>? _cachedBands;
  AndroidEqualizerParameters? _parameters;

  AndroidEqualizerAdapter(this.androidEqualizer) {
    _loadParameters();
  }

  Future<void> _loadParameters() async {
    final parameters = await androidEqualizer.parameters;
    _parameters = parameters;
    _cachedBands = parameters.bands
        .map((b) => EqBandInfo(
              index: b.index,
              centerFrequency: b.centerFrequency,
              gain: b.gain,
            ))
        .toList();
  }

  @override
  double get minDecibels => _parameters?.minDecibels ?? -12.0;

  @override
  double get maxDecibels => _parameters?.maxDecibels ?? 12.0;

  @override
  List<EqBandInfo> get bands {
    return _cachedBands ?? [];
  }

  @override
  Future<void> setEnabled(bool enabled) => androidEqualizer.setEnabled(enabled);

  @override
  Future<void> setBandGain(int index, double gain) async {
    final params = _parameters ?? await androidEqualizer.parameters;
    _parameters = params;
    await params.bands[index].setGain(gain);
  }

  @override
  Future<void> setAllBands(List<double> gains) async {
    final params = _parameters ?? await androidEqualizer.parameters;
    _parameters = params;
    for (var i = 0; i < params.bands.length && i < gains.length; i++) {
      await params.bands[i].setGain(gains[i]);
    }
  }
}
