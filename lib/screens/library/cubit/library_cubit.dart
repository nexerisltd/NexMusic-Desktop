import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nexmusic/services/ytmusic_auth.dart';
import 'package:nexmusic/ytmusic/ytmusic.dart';

import '../../../../services/library.dart';

part 'library_state.dart';

class LibraryCubit extends Cubit<LibraryState> {
  final LibraryService libraryService;

  late final Box _libraryBox;
  late final Box _favouritesBox;
  late final Box _downloadsBox;
  late final Box _historyBox;
  late final Box _localMediaBox;

  late final VoidCallback _listener;
  late final VoidCallback _ytAuthListener;

  List<Map<String, dynamic>> _ytMusicPlaylists = [];

  LibraryCubit(this.libraryService) : super(const LibraryLoading()) {
    _libraryBox = Hive.box('LIBRARY');
    _favouritesBox = Hive.box('FAVOURITES');
    _downloadsBox = Hive.box('DOWNLOADS');
    _historyBox = Hive.box('SONG_HISTORY');
    _localMediaBox = Hive.box('LOCAL_MEDIA');

    _listener = _emitCurrentState;

    _libraryBox.listenable().addListener(_listener);
    _favouritesBox.listenable().addListener(_listener);
    _downloadsBox.listenable().addListener(_listener);
    _historyBox.listenable().addListener(_listener);
    _localMediaBox.listenable().addListener(_listener);

    // Re-fetch YT Music playlists whenever sign-in state changes.
    _ytAuthListener = () {
      _fetchYTMusicPlaylists();
    };
    if (GetIt.I.isRegistered<YTMusicAuthService>()) {
      GetIt.I<YTMusicAuthService>().addListener(_ytAuthListener);
    }
  }

  void loadLibrary() {
    _emitCurrentState();
    _fetchYTMusicPlaylists();
  }

  Future<void> _fetchYTMusicPlaylists() async {
    if (!GetIt.I.isRegistered<YTMusicAuthService>()) return;
    final auth = GetIt.I<YTMusicAuthService>();
    if (!auth.isSignedIn) {
      _ytMusicPlaylists = [];
      _emitCurrentState();
      return;
    }

    try {
      final ytMusic = GetIt.I<YTMusic>();
      final List<Map<String, dynamic>> allPlaylists = [];

      var result = await ytMusic.getLibraryPlaylists();
      var contents = result['contents'] as List?;
      if (contents != null) {
        allPlaylists.addAll(contents.map((e) => Map<String, dynamic>.from(e)));
      }

      // Keep following the continuation token until there are no more
      // pages, so every playlist in the account shows up — not just the
      // first ~25.
      String? continuation = result['continuation'];
      int safetyLimit = 20; // avoid an infinite loop if the API misbehaves
      while (continuation != null && safetyLimit > 0) {
        safetyLimit--;
        result = await ytMusic.getLibraryPlaylists(
          continuationParams: continuation,
        );
        contents = result['contents'] as List?;
        if (contents != null) {
          allPlaylists
              .addAll(contents.map((e) => Map<String, dynamic>.from(e)));
        }
        continuation = result['continuation'];
      }

      _ytMusicPlaylists = allPlaylists;
      debugPrint(
          '[Library] Fetched ${allPlaylists.length} YT Music playlists');
    } catch (e) {
      debugPrint('[Library] Error fetching YT Music playlists: $e');
      _ytMusicPlaylists = [];
    }
    _emitCurrentState();
  }

  void _emitCurrentState() {
    try {
      final downloadedCount =
          _downloadsBox.values.where((e) => e['status'] == 'DOWNLOADED').length;
      final localFilesCount =
          (_localMediaBox.get('songs', defaultValue: const []) as List).length;

      emit(
        LibraryLoaded(
          playlists: libraryService.playlists,
          favouritesCount: _favouritesBox.length,
          downloadsCount: downloadedCount,
          historyCount: _historyBox.length,
          localFilesCount: localFilesCount,
          ytMusicPlaylists: _ytMusicPlaylists,
        ),
      );
    } catch (e) {
      emit(LibraryError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _libraryBox.listenable().removeListener(_listener);
    _favouritesBox.listenable().removeListener(_listener);
    _downloadsBox.listenable().removeListener(_listener);
    _historyBox.listenable().removeListener(_listener);
    _localMediaBox.listenable().removeListener(_listener);
    if (GetIt.I.isRegistered<YTMusicAuthService>()) {
      GetIt.I<YTMusicAuthService>().removeListener(_ytAuthListener);
    }
    return super.close();
  }
}
