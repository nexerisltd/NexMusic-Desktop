import 'package:bloc/bloc.dart';
import 'equalizer_state.dart';

class EqualizerCubit extends Cubit<EqualizerState> {
  EqualizerCubit({
    required bool enabled,
    required double minDb,
    required double maxDb,
    required List<EqBand> bands,
  }) : super(
          EqualizerState(
            enabled: enabled,
            minDb: minDb,
            maxDb: maxDb,
            bands: bands,
          ),
        );

  void toggle(bool enabled) {
    emit(state.copyWith(enabled: enabled));
  }

  void setBandGain(int index, double gain) {
    final updated = state.bands
        .map(
          (b) => b.index == index ? b.copyWith(gain: gain) : b,
        )
        .toList();

    emit(state.copyWith(bands: updated));
  }

  /// Applies a full preset: sets every band's gain in one state update
  /// instead of one emit per band. [gains] must be ordered to match
  /// [EqualizerState.bands]' index order.
  void setAllBands(List<double> gains) {
    final updated = [
      for (final b in state.bands)
        if (b.index < gains.length) b.copyWith(gain: gains[b.index]) else b,
    ];

    emit(state.copyWith(bands: updated));
  }
}
