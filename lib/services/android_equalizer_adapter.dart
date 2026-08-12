import 'package:just_audio/just_audio.dart';
import 'equalizer_backend.dart';

/// Wraps just_audio's AndroidEqualizer so it satisfies the same
/// [EqualizerBackend] interface the desktop mpv-based implementation does,
/// letting the settings UI stay platform-agnostic.
class AndroidEqualizerAdapter implements EqualizerBackend {
  final AndroidEqualizer androidEqualizer;
  List<EqBandInfo>? _cachedBands;

  AndroidEqualizerAdapter(this.androidEqualizer);

  @override
  double get minDecibels => androidEqualizer.parameters == null
      ? -12.0
      : androidEqualizer.parameters!.minDecibels;

  @override
  double get maxDecibels => androidEqualizer.parameters == null
      ? 12.0
      : androidEqualizer.parameters!.maxDecibels;

  @override
  List<EqBandInfo> get bands {
    final params = androidEqualizer.parameters;
    if (params == null) return _cachedBands ?? [];
    _cachedBands = params.bands
        .map((b) => EqBandInfo(
              index: b.index,
              centerFrequency: b.centerFrequency,
              gain: b.gain,
            ))
        .toList();
    return _cachedBands!;
  }

  @override
  Future<void> setEnabled(bool enabled) => androidEqualizer.setEnabled(enabled);

  @override
  Future<void> setBandGain(int index, double gain) async {
    final params = androidEqualizer.parameters;
    if (params == null) return;
    await params.bands[index].setGain(gain);
  }
}
