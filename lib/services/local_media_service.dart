import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Scans folders on disk for local audio files and exposes them as
/// song-maps shaped exactly like a "downloaded" YouTube Music song
/// (`status: 'DOWNLOADED'`, `path: <file>`), so every existing screen and
/// the playback engine can handle them without any special-casing —
/// `MediaPlayer._getAudioSource` already plays anything with
/// `status == 'DOWNLOADED'` straight from `path`.
///
/// This is the desktop counterpart to NexMusic-Android's
/// `localmedia/LocalSongScanner`. Unlike the Android version, this does not
/// read embedded ID3/FLAC/MP4 tags — the app's own thumbnail widget already
/// has embedded-tag reading disabled on desktop ("AudioTags support removed
/// for desktop build temporarily"), so adding a tag-parsing dependency here
/// would be inconsistent with that existing decision. Instead, titles and
/// artists are parsed from the filename (`Artist - Title.ext`), which is a
/// common enough convention to be useful without extra dependencies.
class LocalMediaService extends ChangeNotifier {
  static const Set<String> supportedExtensions = {
    'aac', 'amr', 'flac', 'm4a', 'm4b', 'm4p', 'mka', 'mp3', 'mp4',
    'oga', 'ogg', 'opus', 'wav', 'weba', 'webm', '3ga', '3gp', //
  };

  late final Box _box;

  bool _isScanning = false;
  String? _scanError;

  LocalMediaService() {
    _box = Hive.box('LOCAL_MEDIA');
  }

  bool get isScanning => _isScanning;
  String? get scanError => _scanError;

  List<String> get folders =>
      List<String>.from(_box.get('folders', defaultValue: <String>[]) as List);

  List<Map<String, dynamic>> get songs {
    final raw = _box.get('songs', defaultValue: const []) as List;
    return raw.map((e) => _deepCastMap(e)).toList();
  }

  /// Hive stores nested Map/List structures without preserving their
  /// generic type parameters (they come back as `Map<dynamic,dynamic>` /
  /// `List<dynamic>`), which can cause subtle failures wherever the rest
  /// of the app expects `Map<String, dynamic>`. This recursively rebuilds
  /// every nested map/list with proper types.
  Map<String, dynamic> _deepCastMap(dynamic value) {
    final map = Map<String, dynamic>.from(value as Map);
    return map.map((key, val) => MapEntry(key, _deepCastValue(val)));
  }

  dynamic _deepCastValue(dynamic value) {
    if (value is Map) return _deepCastMap(value);
    if (value is List) return value.map(_deepCastValue).toList();
    return value;
  }

  Future<void> addFolder(String path) async {
    final current = folders;
    if (current.contains(path)) return;
    current.add(path);
    await _box.put('folders', current);
    notifyListeners();
    await rescan();
  }

  Future<void> removeFolder(String path) async {
    final current = folders..remove(path);
    await _box.put('folders', current);

    final remaining = songs
        .where((s) => !((s['path'] as String?) ?? '').startsWith(path))
        .toList();
    await _box.put('songs', remaining);
    notifyListeners();
  }

  String _makeVideoId(String path) {
    final digest = sha1.convert(utf8.encode(path)).toString();
    return 'local_$digest';
  }

  /// Splits a filename like "Artist - Title.mp3" into (artist, title).
  /// Falls back to using the whole filename as the title if the pattern
  /// isn't present.
  List<String> _parseFilename(String filename) {
    final dot = filename.lastIndexOf('.');
    final base = dot > 0 ? filename.substring(0, dot) : filename;
    final parts = base.split(' - ');
    if (parts.length >= 2) {
      return [parts.first.trim(), parts.sublist(1).join(' - ').trim()];
    }
    return ['Unknown Artist', base.trim()];
  }

  Map<String, dynamic> _songMapFor(File file) {
    final filename = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : file.path;
    final parsed = _parseFilename(filename);
    final folderName = file.parent.path.split(Platform.pathSeparator).last;

    return {
      'videoId': _makeVideoId(file.path),
      'title': parsed[1],
      'artists': [
        {'name': parsed[0]},
      ],
      'album': {'name': folderName},
      // Empty thumbnail URL: SongThumbnail already falls back gracefully
      // for downloaded/local songs with no embedded art (see note above).
      'thumbnails': [
        {'url': ''},
      ],
      'status': 'DOWNLOADED',
      'path': file.path,
      'isLocal': true,
    };
  }

  /// Re-scans every watched folder from disk and replaces the stored song
  /// list. Safe to call repeatedly; a scan already in progress is skipped.
  Future<void> rescan() async {
    if (_isScanning) return;
    _isScanning = true;
    _scanError = null;
    notifyListeners();

    final List<Map> found = [];
    try {
      for (final folderPath in folders) {
        try {
          final dir = Directory(folderPath);
          if (!await dir.exists()) continue;

          await for (final entity in dir.list(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is! File) continue;
            final path = entity.path;
            final dot = path.lastIndexOf('.');
            final ext = dot >= 0 ? path.substring(dot + 1).toLowerCase() : '';
            if (!supportedExtensions.contains(ext)) continue;

            found.add(_songMapFor(entity));
          }
        } catch (e) {
          // One folder failing (permission denied on a subfolder, a
          // broken symlink, etc.) shouldn't wipe out everything already
          // found in the other watched folders — skip it and keep going.
          continue;
        }
      }
      await _box.put('songs', found);
    } catch (e) {
      _scanError = e.toString();
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }
}
