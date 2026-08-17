import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:nexmusic/services/yt_audio_stream.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';

import '../utils/add_history.dart';
import '../ytmusic/ytmusic.dart';
import 'settings_manager.dart';
import 'equalizer_backend.dart';
import 'desktop_equalizer.dart';
import 'android_equalizer_adapter.dart';

class MediaPlayer extends ChangeNotifier {
  late final AudioPlayer _player;

  final _loudnessEnhancer = AndroidLoudnessEnhancer();
  AndroidEqualizer? _equalizer;
  AndroidEqualizerParameters? _equalizerParams;

  List<IndexedAudioSource> _songList = [];
  List<Map<String, dynamic>> _originalPlaylist = [];
  final ValueNotifier<MediaItem?> _currentSongNotifier = ValueNotifier(null);
  final ValueNotifier<int?> _currentIndex = ValueNotifier(null);
  final ValueNotifier<ButtonState> _buttonState =
      ValueNotifier(ButtonState.loading);
  Timer? _timer;
  final ValueNotifier<Duration?> _timerDuration = ValueNotifier(null);

  final ValueNotifier<LoopMode> _loopMode = ValueNotifier(LoopMode.off);

  final ValueNotifier<ProgressBarState> _progressBarState =
      ValueNotifier(ProgressBarState());

  bool _shuffleModeEnabled = false;

  bool autoFetching = false;

  MediaPlayer() {
    if (Platform.isAndroid) {
      _equalizer = AndroidEqualizer();
    }
    final AudioPipeline pipeline = AudioPipeline(
      androidAudioEffects: [
        if (Platform.isAndroid && _equalizer != null) _equalizer!,
        _loudnessEnhancer,
      ],
    );
    _player = AudioPlayer(audioPipeline: pipeline);

    GetIt.I.registerSingleton<AndroidLoudnessEnhancer>(_loudnessEnhancer);
    if (Platform.isAndroid && _equalizer != null) {
      GetIt.I.registerSingleton<AndroidEqualizer>(_equalizer!);
      GetIt.I.registerSingleton<EqualizerBackend>(AndroidEqualizerAdapter(_equalizer!));
      print(GetIt.I<AndroidEqualizer>());
    } else {
      GetIt.I.registerSingleton<EqualizerBackend>(DesktopEqualizer(_player));
    }

    _init();
  }

  AudioPlayer get player => _player;
  List<IndexedAudioSource> get songList => List.unmodifiable(_songList);
  ValueNotifier<MediaItem?> get currentSongNotifier => _currentSongNotifier;
  ValueNotifier<int?> get currentIndex => _currentIndex;
  ValueNotifier<ButtonState> get buttonState => _buttonState;
  ValueNotifier<ProgressBarState> get progressBarState => _progressBarState;
  bool get shuffleModeEnabled => _shuffleModeEnabled;
  ValueNotifier<LoopMode> get loopMode => _loopMode;
  ValueNotifier<Duration?> get timerDuration => _timerDuration;

  Stream<
      ({
        List<IndexedAudioSource>? sequence,
        int? currentIndex,
        MediaItem? currentItem
      })> get currentTrackStream => _player.sequenceStateStream.map((state) {
        MediaItem? currentItem;
        final tag = state?.currentSource?.tag;
        if (tag is MediaItem) currentItem = tag;

        return (
          sequence: state?.sequence,
          currentIndex: state?.currentIndex,
          currentItem: currentItem,
        );
      });

  Future<void> _init() async {
    await _loadLoudnessEnhancer();
    await _loadEqualizer();
    await _restoreShuffleAndRepeat();

    _listenToChangesInPlaylist();
    _listenToPlaybackState();
    _listenToCurrentPosition();
    _listenToBufferedPosition();
    _listenToTotalDuration();
    _listenToChangesInSong();
    _listenToShuffle();
    _listenToAutofetch();
    _listenToPlayerErrors();

    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (currentSongNotifier.value != null && _player.playing) {
        GetIt.I<YTMusic>()
            .addPlayingStats(currentSongNotifier.value!.id, _player.position);
      }
    });
  }

  Future<void> _restoreShuffleAndRepeat() async {
    final settings = GetIt.I<SettingsManager>();
    if (!settings.rememberShuffleAndRepeat) return;

    _shuffleModeEnabled = settings.restoredShuffle;
    _loopMode.value = LoopMode.values[settings.restoredLoopMode];
    await _player.setLoopMode(_loopMode.value);
  }

  void _persistShuffleAndRepeatIfEnabled() {
    final settings = GetIt.I<SettingsManager>();
    if (!settings.rememberShuffleAndRepeat) return;

    settings.restoredShuffle = _shuffleModeEnabled;
    settings.restoredLoopMode = _loopMode.value.index;
  }

  Future<void> _loadLoudnessEnhancer() async {
    await _loudnessEnhancer
        .setEnabled(GetIt.I<SettingsManager>().loudnessEnabled);

    await _loudnessEnhancer
        .setTargetGain(GetIt.I<SettingsManager>().loudnessTargetGain);
  }

  Future<void> _loadEqualizer() async {
    if (Platform.isAndroid && _equalizer != null) {
      await _equalizer!.setEnabled(GetIt.I<SettingsManager>().equalizerEnabled);
      _equalizer!.parameters.then((value) async {
        _equalizerParams ??= value;
        final List<AndroidEqualizerBand> bands = _equalizerParams!.bands;
        if (GetIt.I<SettingsManager>().equalizerBandsGain.isEmpty) {
          GetIt.I<SettingsManager>().equalizerBandsGain =
              List.generate(bands.length, (index) => 0.0);
        }

        List<double> equalizerBandsGain =
            GetIt.I<SettingsManager>().equalizerBandsGain;
        for (var e in bands) {
          final gain =
              equalizerBandsGain.isNotEmpty ? equalizerBandsGain[e.index] : 0.0;
          _equalizerParams!.bands[e.index].setGain(gain);
        }
      });
      return;
    }

    // Desktop: the Android branch above pushes saved state through
    // just_audio's AndroidEqualizer API, which doesn't exist here — do the
    // same job through the platform-agnostic EqualizerBackend instead, so
    // a previously-saved EQ curve is actually reapplied on next launch
    // rather than only showing correctly once the settings page is opened.
    final backend = GetIt.I<EqualizerBackend>();
    final settings = GetIt.I<SettingsManager>();
    final savedGains = settings.equalizerBandsGain;

    if (savedGains.isEmpty) {
      settings.equalizerBandsGain =
          List.generate(backend.bands.length, (index) => 0.0);
    } else {
      for (var i = 0; i < backend.bands.length && i < savedGains.length; i++) {
        await backend.setBandGain(i, savedGains[i]);
      }
    }
    // Set enabled last: DesktopEqualizer only rebuilds mpv's filter chain
    // when explicitly enabled, so this applies every restored band gain
    // in a single pass instead of one filter-chain rebuild per band.
    await backend.setEnabled(settings.equalizerEnabled);
  }

  Future<void> setLoudnessEnabled(bool value) async {
    await _loudnessEnhancer.setEnabled(value);
    GetIt.I<SettingsManager>().loudnessEnabled = value;
  }

  Future<void> setEqualizerEnabled(bool value) async {
    await GetIt.I<EqualizerBackend>().setEnabled(value);
    GetIt.I<SettingsManager>().equalizerEnabled = value;
  }

  Future<void> setLoudnessTargetGain(double value) async {
    await _loudnessEnhancer.setTargetGain(value);
    GetIt.I<SettingsManager>().loudnessTargetGain = value;
  }

  void _listenToChangesInPlaylist() {
    _player.sequenceStream.listen((playlist) {
      final List<IndexedAudioSource> newList =
          (playlist).cast<IndexedAudioSource>();

      if (listEquals(newList, _songList)) return;

      final bool shouldAdd = (_songList.isEmpty && newList.isNotEmpty);

      if (newList.isEmpty) {
        _currentSongNotifier.value = null;
        _currentIndex.value = null;
        _songList = [];
      } else {
        _songList = newList;

        _currentIndex.value ??= 0;
        _currentSongNotifier.value =
            (_songList.length > (_currentIndex.value ?? 0))
                ? _songList[_currentIndex.value ?? 0].tag
                : null;
      }

      if (shouldAdd == true && _currentSongNotifier.value != null) {
        addHistory(_currentSongNotifier.value!.extras!);
      }

      notifyListeners();
    });
  }

  void _listenToPlaybackState() {
    _player.playerStateStream.listen((event) {
      final isPlaying = event.playing;
      final processingState = event.processingState;
      if (processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering) {
        _buttonState.value = ButtonState.loading;
      } else if (processingState == ProcessingState.ready) {
        _buttonState.value =
            isPlaying ? ButtonState.playing : ButtonState.paused;
      } else if (processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
        _buttonState.value = ButtonState.paused;
      } else {
        // idle state
        _buttonState.value = ButtonState.paused;
      }
    });
  }

  void _listenToPlayerErrors() {
    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        _buttonState.value = ButtonState.paused;
        notifyListeners();
      },
    );
  }

  void _listenToCurrentPosition() {
    _player.positionStream.listen((position) {
      final oldState = _progressBarState.value;
      if (oldState.current != position) {
        _progressBarState.value = ProgressBarState(
          current: position,
          buffered: oldState.buffered,
          total: oldState.total,
        );
      }
    });
  }

  void _listenToBufferedPosition() {
    _player.bufferedPositionStream.listen((position) {
      final oldState = _progressBarState.value;
      if (oldState.buffered != position) {
        _progressBarState.value = ProgressBarState(
          current: oldState.current,
          buffered: position,
          total: oldState.total,
        );
      }
    });
  }

  void _listenToTotalDuration() {
    _player.durationStream.listen((position) {
      final oldState = _progressBarState.value;
      if (oldState.total != position) {
        _progressBarState.value = ProgressBarState(
          current: oldState.current,
          buffered: oldState.buffered,
          total: position ?? Duration.zero,
        );
      }
    });
  }

  void _listenToShuffle() {
    if (Platform.isAndroid || Platform.isIOS) {
      _player.shuffleModeEnabledStream.listen((data) {
        if (_shuffleModeEnabled != data) {
          _shuffleModeEnabled = data;
          notifyListeners();
        }
      });
    }
  }

  void _listenToChangesInSong() {
    _player.currentIndexStream.listen((index) {
      if (_songList.isNotEmpty && _currentIndex.value != index) {
        _currentIndex.value = index;
        _currentSongNotifier.value =
            index != null && _songList.isNotEmpty && index < _songList.length
                ? _songList[index].tag
                : null;
        if (_songList.isNotEmpty && _currentIndex.value != null) {
          final MediaItem item = _songList[_currentIndex.value!].tag;
          addHistory(item.extras!);
        }
        notifyListeners();
      }
    });
  }

  void changeLoopMode() {
    switch (_loopMode.value) {
      case LoopMode.off:
        _loopMode.value = LoopMode.all;
        break;
      case LoopMode.all:
        _loopMode.value = LoopMode.one;
        break;
      default:
        _loopMode.value = LoopMode.off;
        break;
    }
    _player.setLoopMode(_loopMode.value);
    _persistShuffleAndRepeatIfEnabled();
  }

  Future<void> skipSilence(bool value) async {
    await _player.setSkipSilenceEnabled(value);
    GetIt.I<SettingsManager>().skipSilence = value;
  }

  Future<void> setShuffleModeEnabled(bool value) async {
    _shuffleModeEnabled = value;
    notifyListeners();
    _persistShuffleAndRepeatIfEnabled();
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        if (value) {
          await _player.shuffle();
        }
        await _player.setShuffleModeEnabled(value);
      } else {
        if (value) {
          await _shuffleRemainingQueue();
        } else {
          await _restoreOriginalQueueOrder();
        }
      }
    } catch (e) {
      print("Error setting shuffle mode: $e");
    }
  }

  Future<AudioSource> _getAudioSource(Map<String, dynamic> song) async {
    MediaItem tag = MediaItem(
      id: song['videoId'],
      title: song['title'] ?? 'Title',
      album: song['album']?['name'],
      artUri: Uri.parse(
          song['thumbnails']?.first['url'].replaceAll('w60-h60', 'w225-h225')),
      artist: song['artists']?.map((artist) => artist['name']).join(','),
      extras: song,
    );

    final bool isDownloaded = song['status'] == 'DOWNLOADED' &&
        song['path'] != null &&
        (await File(song['path']).exists());

    if (isDownloaded) {
      return AudioSource.file(song['path'], tag: tag);
    } else {
      // Use direct URL approach for macOS for better compatibility with AVFoundation
      if (Platform.isMacOS) {
        final quality =
            GetIt.I<SettingsManager>().streamingQuality.name.toLowerCase();
        return await getDirectUrlAudioSource(song['videoId'], quality, tag);
      }
      return YouTubeAudioSource(
        videoId: song['videoId'],
        quality: GetIt.I<SettingsManager>().streamingQuality.name.toLowerCase(),
        tag: tag,
      );
    }
  }

  int _lastPlayRequestId = 0;

  Future<void> playSong(Map<String, dynamic> song) async {
    if (song['videoId'] == null) return;

    // Generate a new request ID
    final int requestId = DateTime.now().millisecondsSinceEpoch;
    _lastPlayRequestId = requestId;

    _originalPlaylist = [song];

    // OPTIMISTIC UPDATE: Show miniplayer immediately with loading state
    MediaItem tempTag = MediaItem(
      id: song['videoId'],
      title: song['title'] ?? 'Title',
      album: song['album']?['name'],
      artUri: Uri.parse(
          song['thumbnails']?.first['url'].replaceAll('w60-h60', 'w225-h225')),
      artist: song['artists']?.map((artist) => artist['name']).join(','),
      extras: song,
    );
    _currentSongNotifier.value = tempTag;
    _buttonState.value = ButtonState.loading;
    notifyListeners();

    // stop and set the tapped song as the single source so it plays immediately
    try {
      await _player.pause();
      await _player.stop();
      if (_lastPlayRequestId != requestId) return; // Stale request
      await _player.clearAudioSources();
      if (_lastPlayRequestId != requestId) return; // Stale request
    } catch (e) {
      // Ignore stop errors
    }

    try {
      final source = await _getAudioSource(song);
      if (_lastPlayRequestId != requestId)
        return; // Stale request, user clicked something else

      // Set audio source and play immediately (no need for separate load())
      await _player.setAudioSource(source);
      if (_lastPlayRequestId != requestId) return;

      // Play immediately - just_audio handles loading internally
      await _player.play();
    } catch (e) {
      if (_lastPlayRequestId == requestId) {
        print("Error playing song: $e");
        _buttonState.value = ButtonState.paused;
        notifyListeners();
      }
    }
  }

  /// If the given videoId already exists elsewhere in the queue, removes
  /// that earlier occurrence (from both the original playlist list and the
  /// live player sequence) so it isn't duplicated when re-added.
  Future<void> _removeExistingOccurrence(String videoId) async {
    final origIdx =
        _originalPlaylist.indexWhere((song) => song['videoId'] == videoId);
    if (origIdx != -1) {
      _originalPlaylist.removeAt(origIdx);
    }

    final sequence = _player.sequence;
    for (int i = 0; i < sequence.length; i++) {
      final tag = sequence[i].tag;
      if (tag is MediaItem && tag.id == videoId) {
        // Don't remove the currently playing track.
        if (i == _player.currentIndex) continue;
        await _player.removeAudioSourceAt(i);
        break;
      }
    }
  }

  Future<void> playNext(Map<String, dynamic> mediaItem) async {
    final currentSong = _currentSongNotifier.value;
    int insertIndexOrig = _originalPlaylist.length;
    if (currentSong != null) {
      final origIdx = _originalPlaylist.indexWhere((song) => song['videoId'] == currentSong.id);
      if (origIdx != -1) {
        insertIndexOrig = origIdx + 1;
      }
    }

    // Case 1: A single video/song
    if (mediaItem['videoId'] != null) {
      if (GetIt.I<SettingsManager>().preventDuplicateTracks) {
        await _removeExistingOccurrence(mediaItem['videoId']);
      }
      _originalPlaylist.insert(insertIndexOrig, mediaItem);
      final audioSource = await _getAudioSource(mediaItem);

      // Determine insertion position
      final currentIndex = _player.currentIndex ?? -1;
      final sequenceLength = _player.sequence.length;
      final insertIndex = (currentIndex + 1).clamp(0, sequenceLength);

      // If player already has something in the queue
      if (sequenceLength > 0) {
        await _player.insertAudioSource(insertIndex, audioSource);
      } else {
        // If queue is empty, just set and start playing
        await _player.setAudioSource(audioSource);
      }

      // Case 2: Custom or Downloaded Playlist
    } else if (mediaItem['songs'] != null) {
      List songs = mediaItem['songs'];
      final songMaps = songs.map((s) => Map<String, dynamic>.from(s)).toList();
      _originalPlaylist.insertAll(insertIndexOrig, songMaps);
      await _addSongListToQueue(songs, isNext: true);

      // Case 3: Online Playlist
    } else if (mediaItem['playlistId'] != null) {
      List songs = mediaItem['type'] == 'ARTIST'
          ? await GetIt.I<YTMusic>()
              .getNextSongList(playlistId: mediaItem['playlistId'])
          : await GetIt.I<YTMusic>().getPlaylistSongs(mediaItem['playlistId']);
      final songMaps = songs.map((s) => Map<String, dynamic>.from(s)).toList();
      _originalPlaylist.insertAll(insertIndexOrig, songMaps);
      await _addSongListToQueue(songs, isNext: true);
    }
  }

  Future<void> playAll(List songs, {int index = 0}) async {
    if (songs.isEmpty) return;

    autoFetching = true;
    _originalPlaylist = songs.map((s) => Map<String, dynamic>.from(s)).toList();

    if (!GetIt.I<SettingsManager>().persistentShuffle) {
      _shuffleModeEnabled = false;
    }

    _buttonState.value = ButtonState.loading;
    notifyListeners();

    try {
      await _player.stop();

      // Play just the selected song immediately - no waiting
      final selectedSong = Map<String, dynamic>.from(songs[index]);
      final firstSource = await _getAudioSource(selectedSong);

      await _player.setAudioSource(firstSource);
      // Don't wait for load - just play immediately
      _player.play(); // Don't await - let it start playing while we add more

      // Add rest of playlist completely in background (fire and forget)
      if (songs.length > 1) {
        // Use unawaited to truly run in background
        Future(() async {
        await _addRemainingToPlaylist(songs, index);
        autoFetching = false;
        });
      }
      else {
        autoFetching = false;
      }
    } catch (e) {
      autoFetching = false;
      print('Error in playAll: $e');
      _buttonState.value = ButtonState.paused;
      notifyListeners();
    }
  }

  Future<void> _addRemainingToPlaylist(List songs, int playedIndex) async {
    try {
      int added = 0;
      final remaining = <Map<String, dynamic>>[];
      for (int i = playedIndex + 1; i < songs.length; i++) {
        remaining.add(Map<String, dynamic>.from(songs[i]));
      }

      if (_shuffleModeEnabled) {
        remaining.shuffle();
      }

      for (var song in remaining) {
        try {
          final source = await _getAudioSource(song);
          await _player.addAudioSource(source);
          added++;
        } catch (e) {
          // Skip failed songs silently
        }
      }
    } catch (e) {
      print('Error adding remaining songs: $e');
    }
  }

  Future<void> addToQueue(Map<String, dynamic> mediaItem) async {
    // Case 1: A single video/song
    if (mediaItem['videoId'] != null) {
      if (GetIt.I<SettingsManager>().preventDuplicateTracks) {
        await _removeExistingOccurrence(mediaItem['videoId']);
      }
      _originalPlaylist.add(mediaItem);
      await _player.addAudioSource(await _getAudioSource(mediaItem));

      // Case 2: Custom or Downloaded Playlist
    } else if (mediaItem['songs'] != null) {
      List songs = mediaItem['songs'];
      final songMaps = songs.map((s) => Map<String, dynamic>.from(s)).toList();
      _originalPlaylist.addAll(songMaps);
      await _addSongListToQueue(songs, isNext: false);

      // Case 3: Online Playlist
    } else if (mediaItem['playlistId'] != null) {
      List songs = mediaItem['type'] == 'ARTIST'
          ? await GetIt.I<YTMusic>()
              .getNextSongList(playlistId: mediaItem['playlistId'])
          : await GetIt.I<YTMusic>().getPlaylistSongs(mediaItem['playlistId']);
      final songMaps = songs.map((s) => Map<String, dynamic>.from(s)).toList();
      _originalPlaylist.addAll(songMaps);
      await _addSongListToQueue(songs, isNext: false);
    }
  }

  Future<void> startRelated(Map<String, dynamic> song,
      {bool radio = false, bool shuffle = false, bool isArtist = false}) async {
    _originalPlaylist = [];
    await _player.clearAudioSources();
    if (!isArtist) {
      await addToQueue(song);
    }
    List songs = await GetIt.I<YTMusic>().getNextSongList(
        videoId: song['videoId'],
        playlistId: song['playlistRadioId'],
        radio: radio,
        shuffle: shuffle);
    if (songs.isNotEmpty) songs.removeAt(0);
    final songMaps = songs.map((s) => Map<String, dynamic>.from(s)).toList();
    _originalPlaylist.addAll(songMaps);
    await _addSongListToQueue(songs, isNext: false);
    await _player.play();
  }

  Future<void> startPlaylistSongs(Map endpoint) async {
    _originalPlaylist = [];
    await _player.clearAudioSources();
    List songs = await GetIt.I<YTMusic>().getNextSongList(
        playlistId: endpoint['playlistId'], params: endpoint['params']);

    if (songs.isNotEmpty && songs.first['videoId'] == null) {
      // if API returned a placeholder, convert or handle accordingly
    }

    final songMaps = songs.map((s) => Map<String, dynamic>.from(s)).toList();
    _originalPlaylist.addAll(songMaps);
    await _addSongListToQueue(songs);
    await _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
    await _player.clearAudioSources();
    await _player.seek(Duration.zero, index: 0);
    _currentIndex.value = null;
    _currentSongNotifier.value = null;
    notifyListeners();
  }

  Future<void> _addSongListToQueue(List songs, {bool isNext = false}) async {
    if (songs.isEmpty) return;

    final songMaps = songs.map((s) => Map<String, dynamic>.from(s)).toList();
    if (_shuffleModeEnabled) {
      songMaps.shuffle();
    }

    // Convert your song objects into AudioSources
    final newSources = await Future.wait(songMaps.map((song) async {
      return await _getAudioSource(song);
    }));

    // Current queue length
    final queueLength = _player.sequence.length;

    if (isNext) {
      // Insert immediately after the current index
      final currentIndex = _player.currentIndex ?? -1;
      int insertIndex = (currentIndex + 1).clamp(0, queueLength);

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // just_audio_media_kit doesn't support inserting into the middle
        // of the queue (it floods with failing "playlist-move" native
        // calls). Rebuild the queue instead, same safe approach used for
        // shuffle — no reordering/move primitive needed.
        await _rebuildQueueWithSongsInsertedAt(insertIndex, songMaps);
      } else {
        await _player.insertAudioSources(insertIndex, newSources);
      }
    } else {
      // Append to the end
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // just_audio_media_kit's bulk addAudioSources also floods with
        // failing "playlist-move" native calls on desktop — add one at a
        // time instead (same proven-safe pattern as playAll).
        for (final source in newSources) {
          await _player.addAudioSource(source);
        }
      } else {
        await _player.addAudioSources(newSources);
      }
    }
  }

  /// Rebuilds the entire queue from scratch with [newSongs] spliced in at
  /// [insertIndex], preserving current playback position. Desktop-safe
  /// alternative to `insertAudioSources` (see comment above).
  Future<void> _rebuildQueueWithSongsInsertedAt(
    int insertIndex,
    List<Map<String, dynamic>> newSongs,
  ) async {
    final currentIndex = _player.currentIndex;
    final currentPosition = _player.position;
    final wasPlaying = _player.playing;

    final allSources = List<IndexedAudioSource>.from(_player.sequence);
    if (allSources.isEmpty) {
      // Nothing playing yet — just play the new songs directly.
      final first = await _getAudioSource(newSongs.first);
      await _player.setAudioSource(first);
      for (int i = 1; i < newSongs.length; i++) {
        await _player.addAudioSource(await _getAudioSource(newSongs[i]));
      }
      return;
    }

    Map<String, dynamic> songFor(IndexedAudioSource src) {
      final id = (src.tag as MediaItem).id;
      return _originalPlaylist.firstWhere(
        (s) => s['videoId'] == id,
        orElse: () => <String, dynamic>{},
      );
    }

    final existingSongs = allSources.map(songFor).toList();
    final clampedIndex = insertIndex.clamp(0, existingSongs.length);
    final orderedSongs = [
      ...existingSongs.sublist(0, clampedIndex),
      ...newSongs,
      ...existingSongs.sublist(clampedIndex),
    ];

    // The currently playing song shifts position if songs were inserted
    // before it — recompute its new index.
    final newCurrentIndex = currentIndex == null
        ? 0
        : (currentIndex < clampedIndex ? currentIndex : currentIndex + newSongs.length);

    final firstSource = await _getAudioSource(orderedSongs.first);
    await _player.setAudioSource(firstSource);
    for (int i = 1; i < orderedSongs.length; i++) {
      await _player.addAudioSource(await _getAudioSource(orderedSongs[i]));
    }
    await _player.seek(currentPosition, index: newCurrentIndex);
    if (wasPlaying) _player.play();
  }

  void _listenToAutofetch() {
    player.currentIndexStream.listen((index) async {
      if (index == null) return;
      if (player.sequence.length - index < 5 &&
          GetIt.I<SettingsManager>().autofetchSongs &&
          autoFetching == false) {
        autoFetching = true;
        List nextSongs = await GetIt.I<YTMusic>()
            .getNextSongList(videoId: player.sequence[index].tag.id);
        if (nextSongs.isNotEmpty) nextSongs.removeAt(0);
        final songMaps = nextSongs.map((s) => Map<String, dynamic>.from(s)).toList();
        _originalPlaylist.addAll(songMaps);
        await _addSongListToQueue(nextSongs);
        autoFetching = false;
      }
    });
  }

  void setTimer(Duration duration) {
    int seconds = duration.inSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      seconds--;
      _timerDuration.value = Duration(seconds: seconds);
      if (seconds == 0) {
        cancelTimer();
        _player.pause();
      }
      notifyListeners();
    });
  }

  void cancelTimer() {
    _timerDuration.value = null;
    _timer?.cancel();
    notifyListeners();
  }

  Future<AudioSource> _cloneSource(AudioSource source, Map<String, dynamic> song) async {
    if (source is UriAudioSource) {
      return AudioSource.uri(source.uri, tag: source.tag);
    }
    return await _getAudioSource(song);
  }

  Future<void> _shuffleRemainingQueue() async {
    try {
      final currentSong = _currentSongNotifier.value;
      if (currentSong == null) return;
      final currentIndex = _player.currentIndex;
      if (currentIndex == null) return;
      final currentPosition = _player.position;
      final wasPlaying = _player.playing;

      final allSources = List<IndexedAudioSource>.from(_player.sequence ?? []);
      if (allSources.isEmpty || currentIndex + 1 >= allSources.length) return;

      final beforeSources = allSources.sublist(0, currentIndex);
      final remainingSources = allSources.sublist(currentIndex + 1);

      Map<String, dynamic> songFor(IndexedAudioSource src) {
        return _originalPlaylist.firstWhere(
          (s) => s['videoId'] == (src.tag as MediaItem).id,
          orElse: () => <String, dynamic>{},
        );
      }

      final beforeSongs = beforeSources.map(songFor).toList();
      final remainingSongs = remainingSources.map(songFor).toList()..shuffle();
      final currentSongMap = songFor(allSources[currentIndex]);

      final orderedSongs = [...beforeSongs, currentSongMap, ...remainingSongs];
      final newCurrentIndex = beforeSongs.length;

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // just_audio_media_kit does not support ConcatenatingAudioSource,
        // so rebuild the queue incrementally instead (same approach as
        // playAll uses).
        final firstSource = await _getAudioSource(orderedSongs.first);
        await _player.setAudioSource(firstSource);
        for (int i = 1; i < orderedSongs.length; i++) {
          final source = await _getAudioSource(orderedSongs[i]);
          await _player.addAudioSource(source);
        }
        await _player.seek(currentPosition, index: newCurrentIndex);
        if (wasPlaying) _player.play();
      } else {
        final newBeforeSources = <AudioSource>[];
        for (final song in beforeSongs) {
          newBeforeSources.add(await _getAudioSource(song));
        }
        final newRemainingSources = <AudioSource>[];
        for (final song in remainingSongs) {
          newRemainingSources.add(await _getAudioSource(song));
        }
        final newCurrentSource = await _getAudioSource(currentSongMap);
        final newSources = [
          ...newBeforeSources,
          newCurrentSource,
          ...newRemainingSources,
        ];

        await _player.setAudioSource(
          ConcatenatingAudioSource(children: newSources),
          initialIndex: newCurrentIndex,
          initialPosition: currentPosition,
        );
      }
    } catch (e) {
      print("Error shuffling remaining queue: $e");
    }
  }

  Future<void> _restoreOriginalQueueOrder() async {
    try {
      final currentSong = _currentSongNotifier.value;
      if (currentSong == null) return;
      final currentPosition = _player.position;
      final wasPlaying = _player.playing;

      final allSources = List<IndexedAudioSource>.from(_player.sequence ?? []);

      final sourceMap = <String, IndexedAudioSource>{};
      for (var source in allSources) {
        final tag = source.tag;
        if (tag is MediaItem) {
          sourceMap[tag.id] = source;
        }
      }

      final orderedSongs = <Map<String, dynamic>>[];
      for (var song in _originalPlaylist) {
        orderedSongs.add(song);
      }

      final origIndex = orderedSongs.indexWhere(
        (song) => song['videoId'] == currentSong.id,
      );
      if (origIndex == -1) return;

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final firstSource = await _getAudioSource(orderedSongs.first);
        await _player.setAudioSource(firstSource);
        for (int i = 1; i < orderedSongs.length; i++) {
          final source = await _getAudioSource(orderedSongs[i]);
          await _player.addAudioSource(source);
        }
        await _player.seek(currentPosition, index: origIndex);
        if (wasPlaying) _player.play();
      } else {
        final usedSources = <IndexedAudioSource>{};
        final List<AudioSource> originalSources = [];
        for (var song in orderedSongs) {
          final videoId = song['videoId'];
          final source = sourceMap[videoId];
          if (source != null && !usedSources.contains(source)) {
            originalSources.add(await _cloneSource(source, song));
            usedSources.add(source);
          } else {
            originalSources.add(await _getAudioSource(song));
          }
        }

        await _player.setAudioSource(
          ConcatenatingAudioSource(children: originalSources),
          initialIndex: origIndex,
          initialPosition: currentPosition,
        );
      }
    } catch (e) {
      print("Error restoring original queue order: $e");
    }
  }
}

enum ButtonState { loading, paused, playing }

enum LoopState { off, all, one }

class ProgressBarState {
  Duration current;
  Duration buffered;
  Duration total;
  ProgressBarState(
      {this.current = Duration.zero,
      this.buffered = Duration.zero,
      this.total = Duration.zero});
}
