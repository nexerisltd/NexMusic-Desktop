import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Minimal structured, exportable logging for YouTube stream-resolution
/// diagnostics. This app had no structured logging before this — only
/// scattered `print()`/`debugPrint()` calls, which aren't enough to
/// actually diagnose a "some songs still fail" report after the fact
/// (which client was tried, was auth sent, how long did it take, what
/// was the exact failure). This is intentionally small: one rolling log
/// file, one JSON line per event, nothing fancier.
class YtDebugLog {
  static File? _file;
  static bool _initFailed = false;
  static const int _maxBytes = 2 * 1024 * 1024; // 2MB rolling cap

  static Future<File?> _getFile() async {
    if (_file != null) return _file;
    if (_initFailed) return null;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/nexmusic_stream_diagnostics.log');
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      _file = file;
      return file;
    } catch (_) {
      _initFailed = true;
      return null;
    }
  }

  /// Logs one structured event. [fields] should be simple JSON-safe
  /// values (String, num, bool, null) — e.g. videoId, client, elapsedMs,
  /// statusCode, authAttached, error.
  static void event(String name, Map<String, Object?> fields) {
    final entry = {
      'ts': DateTime.now().toIso8601String(),
      'event': name,
      ...fields,
    };
    final line = jsonEncode(entry);
    // Always mirror to the console too, so it still shows up in a live
    // debug session without needing to go read the file.
    // ignore: avoid_print
    print('[YtDebugLog] $line');
    unawaited(_appendToFile(line));
  }

  static Future<void> _appendToFile(String line) async {
    try {
      final file = await _getFile();
      if (file == null) return;
      final stat = await file.stat();
      if (stat.size > _maxBytes) {
        // Roll over by keeping only the second half of the file, so it
        // never grows without bound without needing a separate archive.
        final content = await file.readAsString();
        final half = content.substring(content.length ~/ 2);
        final cut = half.indexOf('\n');
        await file.writeAsString(cut == -1 ? '' : half.substring(cut + 1));
      }
      await file.writeAsString(
        '$line\n',
        mode: FileMode.append,
        flush: false,
      );
    } catch (_) {
      // Best-effort only — never let logging itself break playback.
    }
  }

  /// Path to the on-disk log file, for a future "export diagnostics"
  /// button in settings, if that ends up useful.
  static Future<String?> filePath() async => (await _getFile())?.path;
}
