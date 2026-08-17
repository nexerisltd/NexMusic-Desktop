/// Platform-agnostic equalizer band, used by both the Android backend
/// (just_audio's AndroidEqualizer) and the Desktop backend (mpv/media_kit
/// audio filters), so the UI never has to branch on platform.
class EqBandInfo {
  final int index;
  final double centerFrequency;
  double gain;

  EqBandInfo({
    required this.index,
    required this.centerFrequency,
    required this.gain,
  });
}

/// Common interface both platform equalizer backends implement.
abstract class EqualizerBackend {
  double get minDecibels;
  double get maxDecibels;
  List<EqBandInfo> get bands;

  Future<void> setEnabled(bool enabled);
  Future<void> setBandGain(int index, double gain);

  /// Sets every band's gain at once (e.g. applying a preset), rebuilding
  /// the underlying audio effect only once instead of once per band.
  /// [gains] must be the same length as [bands]; extra values are
  /// ignored, missing ones leave that band unchanged.
  Future<void> setAllBands(List<double> gains);
}
