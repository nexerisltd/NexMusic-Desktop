import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:nexmusic/services/ytmusic_auth.dart';
import 'package:nexmusic/ytmusic/ytmusic.dart';
import 'package:meta/meta.dart';

part 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final YTMusic _ytMusic;
  late final VoidCallback _ytAuthListener;

  HomeCubit(this._ytMusic) : super(HomeLoading()) {
    if (GetIt.I.isRegistered<YTMusicAuthService>()) {
      final auth = GetIt.I<YTMusicAuthService>();
      _ytAuthListener = () {
        if (auth.isSignedIn) fetch();
      };
      auth.addListener(_ytAuthListener);
    }
  }

  @override
  Future<void> close() {
    if (GetIt.I.isRegistered<YTMusicAuthService>()) {
      GetIt.I<YTMusicAuthService>().removeListener(_ytAuthListener);
    }
    return super.close();
  }

  Future<void> fetch() async {
    emit(const HomeLoading());
    try {
      final auth = GetIt.I<YTMusicAuthService>();
      debugPrint(
          '[YTAuth] isSignedIn=${auth.isSignedIn} cookieLen=${auth.cookieHeader?.length}');

      final feed = await _ytMusic.browse();

      List sections = feed['sections'];
      debugPrint('[YTAuth] Received ${sections.length} sections: '
          '${sections.map((s) => s['title']).join(', ')}');

      emit(HomeSuccess(
        chips: feed['chips'] ?? [],
        sections: sections,
        continuation: feed['continuation'],
        loadingMore: false,
      ));
    } catch (e, st) {
      emit(HomeError(e.toString(), st.toString()));
    }
  }

  Future<void> refresh() async {
    try {
      final feed = await _ytMusic.browse();

      List sections = feed['sections'];

      emit(HomeSuccess(
        chips: feed['chips'] ?? [],
        sections: sections,
        continuation: feed['continuation'],
        loadingMore: false,
      ));
    } catch (e, st) {
      emit(HomeError(e.toString(), st.toString()));
    }
  }

  Future<void> fetchNext() async {
    final current = state;
    if (current is! HomeSuccess) return;
    if (current.loadingMore || current.continuation == null) return;
    emit(current.copyWith(loadingMore: true));
    try {
      final feed = await _ytMusic.browseContinuation(
          additionalParams: current.continuation!);
      emit(
        HomeSuccess(
          chips: current.chips,
          sections: [...current.sections, ...feed['sections']],
          continuation: feed['continuation'],
          loadingMore: false,
        ),
      );
    } catch (e, st) {
      emit(HomeError(e.toString(), st.toString()));
    }
  }
}
