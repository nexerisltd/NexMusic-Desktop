import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// WebView2 defaults to storing its data folder next to the .exe, which
/// fails with "We couldn't create the data directory" when installed
/// under Program Files (a protected, non-writable location for a normal
/// user). This creates a shared environment pointing WebView2's data
/// folder at a writable per-user AppData location instead.
Future<WebViewEnvironment?> createWritableWebViewEnvironment() async {
  if (!Platform.isWindows) return null;
  try {
    final appSupportDir = await getApplicationSupportDirectory();
    final userDataFolder = '${appSupportDir.path}\\WebView2';
    return await WebViewEnvironment.create(
      settings: WebViewEnvironmentSettings(userDataFolder: userDataFolder),
    );
  } catch (e) {
    log('Failed to create writable WebViewEnvironment: $e',
        name: 'YTMusicAuth');
    return null;
  }
}

/// Handles a real, personalized YouTube Music session using the same
/// mechanism the music.youtube.com website itself uses (cookie-based
/// session + SAPISIDHASH authorization), NOT the official YouTube Data
/// API v3 OAuth (that's [GoogleAuthService] — a different, unrelated
/// mechanism that can't access YT Music's personal home/library feeds).
///
/// This is inherently more fragile than official OAuth: Google can change
/// cookie names, the internal API, or the API key at any time without
/// notice, since this isn't a publicly documented/supported API.
class YTMusicAuthService extends ChangeNotifier {
  static const String _origin = 'https://music.youtube.com';
  static const String _browseEndpoint =
      'https://music.youtube.com/youtubei/v1/browse';

  // Public, well-known InnerTube API key embedded in music.youtube.com's
  // own web client — not a secret, every YT Music web client uses it.
  static const String _innertubeApiKey =
      'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';

  late Box _box;

  bool _isSignedIn = false;
  bool get isSignedIn => _isSignedIn;

  String? _cookieHeader;
  String? _sapisid;

  Timer? _periodicRefreshTimer;

  Future<void> init() async {
    _box = await Hive.openBox('YTMUSIC_AUTH');
    _cookieHeader = _box.get('cookie_header');
    _sapisid = _box.get('sapisid');
    _isSignedIn = _cookieHeader != null && _sapisid != null;
    notifyListeners();

    // Balanced middle ground: refresh the session exactly ONCE per app
    // launch (not periodically, not on every request) if signed in. This
    // briefly touches WebView2 a single time at startup, then fully
    // disposes it — avoiding the "relogin every few launches" problem
    // without keeping WebView2 resident throughout the session.
    if (_isSignedIn) {
      unawaited(silentlyRefreshSession());
    }
  }

  Future<void> _refreshCookiesFromDisk() async {
    try {
      final environment = await createWritableWebViewEnvironment();
      final cookieManager = CookieManager.instance(webViewEnvironment: environment);
      final musicCookies =
          await cookieManager.getCookies(url: WebUri(_origin));
      if (musicCookies.isEmpty) return; // nothing persisted, keep old data

      final googleCookies = await cookieManager
          .getCookies(url: WebUri('https://www.google.com'));
      final youtubeCookies = await cookieManager
          .getCookies(url: WebUri('https://www.youtube.com'));

      final Map<String, String> merged = {};
      for (final c in googleCookies) merged[c.name] = c.value;
      for (final c in youtubeCookies) merged[c.name] = c.value;
      for (final c in musicCookies) merged[c.name] = c.value;

      const sapisidPriority = [
        '__Secure-3PAPISID',
        '__Secure-1PAPISID',
        'SAPISID',
      ];
      String? sapisid;
      for (final name in sapisidPriority) {
        if (merged.containsKey(name)) {
          sapisid = merged[name];
          break;
        }
      }
      if (sapisid == null) return;

      _cookieHeader = merged.entries.map((e) => '${e.key}=${e.value}').join('; ');
      _sapisid = sapisid;
      await _box.put('cookie_header', _cookieHeader);
      await _box.put('sapisid', _sapisid);
      notifyListeners();
      debugPrint('[YTAuth] Refreshed cookies from disk (no page load)');
    } catch (e) {
      log('Disk cookie refresh failed (keeping existing session): $e',
          name: 'YTMusicAuth');
    }
  }

  void _startPeriodicRefresh() {
    // Intentionally disabled — see note in init() above.
  }

  /// Cancels any pending background timers/work. Call this before the app
  /// fully exits so nothing keeps the process alive after the window
  /// closes.
  void cancelBackgroundWork() {
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = null;
  }

  /// Loads music.youtube.com in an invisible, headless webview and
  /// re-captures cookies from it — refreshing our stored session using
  /// whatever the OS-level WebView2 profile already has persisted,
  /// completely invisibly to the user. Safe to call anytime; if it fails
  /// (e.g. the underlying session has actually been fully logged out),
  /// we just silently keep using whatever cookies we already have.
  Future<void> silentlyRefreshSession() async {
    try {
      final completer = Completer<void>();
      HeadlessInAppWebView? headlessWebView;

      final environment = await createWritableWebViewEnvironment();

      headlessWebView = HeadlessInAppWebView(
        webViewEnvironment: environment,
        initialUrlRequest: URLRequest(url: WebUri(_origin)),
        onLoadStop: (controller, url) async {
          // Give the page a moment to finish setting/refreshing cookies.
          await Future.delayed(const Duration(seconds: 2));
          await captureSessionFromWebview();
          if (!completer.isCompleted) completer.complete();
        },
      );

      await headlessWebView.run();

      await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {},
      );

      await headlessWebView.dispose();
    } catch (e) {
      log('Silent session refresh failed (keeping existing session): $e',
          name: 'YTMusicAuth');
    }
  }

  /// Call this after the user has finished logging in inside the embedded
  /// webview pointed at music.youtube.com. Reads cookies from the native
  /// cookie store (which, unlike JavaScript's document.cookie, can see
  /// HttpOnly cookies too — required, since Google marks the session
  /// cookies we need as HttpOnly).
  Future<bool> captureSessionFromWebview() async {
    final environment = await createWritableWebViewEnvironment();
    final cookieManager = CookieManager.instance(webViewEnvironment: environment);

    final musicCookies = await cookieManager.getCookies(url: WebUri(_origin));
    final googleCookies =
        await cookieManager.getCookies(url: WebUri('https://www.google.com'));
    final youtubeCookies =
        await cookieManager.getCookies(url: WebUri('https://www.youtube.com'));

    // Merge, preferring music.youtube.com's own values when a cookie name
    // appears in more than one domain (later entries overwrite earlier).
    final Map<String, String> merged = {};
    for (final c in googleCookies) {
      merged[c.name] = c.value;
    }
    for (final c in youtubeCookies) {
      merged[c.name] = c.value;
    }
    for (final c in musicCookies) {
      merged[c.name] = c.value;
    }

    if (merged.isEmpty) return false;

    // Prefer the modern, correctly-scoped SAPISID variants first — plain
    // SAPISID is often missing/stale since Google moved auth cookies to
    // these prefixed, domain-partitioned versions.
    const sapisidPriority = [
      '__Secure-3PAPISID',
      '__Secure-1PAPISID',
      'SAPISID',
    ];

    String? sapisid;
    String? sapisidSource;
    for (final name in sapisidPriority) {
      if (merged.containsKey(name)) {
        sapisid = merged[name];
        sapisidSource = name;
        break;
      }
    }

    debugPrint('[YTAuth] Found ${merged.length} total cookies '
        '(music=${musicCookies.length}, google=${googleCookies.length}, '
        'youtube=${youtubeCookies.length}). SAPISID source: $sapisidSource');

    if (sapisid == null) return false;

    final cookieHeader =
        merged.entries.map((e) => '${e.key}=${e.value}').join('; ');

    _cookieHeader = cookieHeader;
    _sapisid = sapisid;
    await _box.put('cookie_header', cookieHeader);
    await _box.put('sapisid', sapisid);

    _isSignedIn = true;
    notifyListeners();
    _startPeriodicRefresh();
    return true;
  }

  String? get cookieHeader => _cookieHeader;

  /// For diagnostics only (see YtDebugLog) — whether we currently hold a
  /// SAPISID value, without exposing the value itself in logs.
  bool get hasSapisid => _sapisid != null;

  String buildAuthHeader() {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final raw = '$timestamp $_sapisid $_origin';
    final hash = sha1.convert(utf8.encode(raw)).toString();
    return 'SAPISIDHASH ${timestamp}_$hash';
  }

  Map<String, String> _authHeaders() {
    return {
      'Cookie': _cookieHeader ?? '',
      'Authorization': buildAuthHeader(),
      'X-Goog-AuthUser': '0',
      'Origin': _origin,
      'Content-Type': 'application/json',
    };
  }

  /// Fetches a raw InnerTube "browse" response — the same call
  /// music.youtube.com's own web client makes. `browseId` selects which
  /// page: `FEmusic_home` (personalized home), `FEmusic_liked_playlists`
  /// (library), `FEmusic_liked_videos` (liked songs), etc.
  Future<Map<String, dynamic>?> browse(String browseId) async {
    if (!_isSignedIn) return null;

    try {
      final response = await http.post(
        Uri.parse('$_browseEndpoint?key=$_innertubeApiKey'),
        headers: _authHeaders(),
        body: jsonEncode({
          'context': {
            'client': {
              'clientName': 'WEB_REMIX',
              'clientVersion': '1.20260101.01.00',
            },
          },
          'browseId': browseId,
        }),
      );

      if (response.statusCode != 200) {
        log('YT Music browse($browseId) failed: ${response.statusCode} '
            '${response.body}', name: 'YTMusicAuth');
        return null;
      }

      return jsonDecode(response.body);
    } catch (e) {
      log('YT Music browse($browseId) error: $e', name: 'YTMusicAuth');
      return null;
    }
  }

  Future<void> signOut() async {
    cancelBackgroundWork();
    await _box.clear();
    final environment = await createWritableWebViewEnvironment();
    await CookieManager.instance(webViewEnvironment: environment)
        .deleteCookies(url: WebUri(_origin));
    _cookieHeader = null;
    _sapisid = null;
    _isSignedIn = false;
    notifyListeners();
  }
}
