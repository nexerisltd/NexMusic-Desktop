/// 10-band EQ preset curves, ordered to match the app's band frequencies
/// (31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000 Hz).
///
/// Values verified directly against NexMusic-Android's live Equalizer
/// screen (screenshots of each preset's slider values), not just its
/// source code — the source's raw numbers needed a x10 scale correction
/// to match what the app actually applies.
class EqPreset {
  final String name;
  final List<double> gains;

  const EqPreset(this.name, this.gains);
}

class EqPresets {
  static const List<EqPreset> nexSignature = [
    EqPreset('Flat', [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
    EqPreset('Signature', [15, 10, 5, 0, -2, 0, 8, 15, 20, 15]),
    EqPreset('Acoustic', [15, 15, 5, 7.5, 10, 7.5, 12.5, 17.5, 15, 7.5]),
    EqPreset('Bass Boost', [50, 40, 25, 10, 0, -5, 0, 10, 20, 30]),
    EqPreset('Pure Clarity', [-10, -5, 0, 5, 15, 25, 30, 25, 15, 10]),
    EqPreset('Soft Bass', [20, 18, 14, 8, 3, 2, 6, 9, 11, 13]),
    EqPreset('Electronic', [35, 28, 12, -5, -15, 5, 18, 30, 40, 50]),
    EqPreset('Rock', [30, 22, 15, 5, -10, 12, 20, 25, 32, 38]),
    EqPreset('Pop', [-15, 0, 10, 18, 25, 22, 15, 8, -5, -12]),
    EqPreset('Jazz', [15, 10, 6, 14, 20, 18, 12, 18, 22, 20]),
    EqPreset('Voice', [-25, -15, 0, 20, 40, 38, 20, 12, 0, -12]),
  ];

  static const List<EqPreset> dolbyAtmos = [
    EqPreset('Dolby Open', [15, 18, 22, 18, 16, 21, 25, 28, 18, 8]),
    EqPreset('Dolby Rich', [10, 16, 20, 22, 28, 26, 24, 20, 15, 5]),
    EqPreset('Dolby Focused', [-30, -5, 13, 18, 22, 12, 14, 10, -5, -30]),
  ];

  static const List<EqPreset> diracAudio = [
    EqPreset('Dirac Music', [20, 14, 8, 0, 3, 8, 14, 20, 28, 35]),
    EqPreset('Dirac Movie', [30, 25, 15, 0, 7, 12, 18, 25, 32, 40]),
    EqPreset('Dirac Game', [15, 25, 20, 0, 8, 15, 30, 45, 40, 28]),
  ];
}
