import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'ytmusic_auth.dart';

/// Central place for which InnerTube clients we try (in order) when
/// resolving playable audio streams, plus a couple of small helpers used
/// everywhere we then have to fetch actual bytes from a resolved stream
/// URL.
///
/// Background (2026-08): every call site used to hardcode a single
/// `YoutubeApiClient.androidVr` with no fallback at all — a single point
/// of failure. This list is NOT a port of the Android app's 11-client
/// fallback chain (that was tuned empirically against Android's own
/// hand-rolled client definitions, most of which have no equivalent
/// here). It's a short, fork-appropriate chain built from what
/// `youtube_explode_dart`'s own `YoutubeApiClient` exposes:
///   - `androidVr`: kept first — proven reliable, historically doesn't
///     need a PO token.
///   - `androidSdkless`: this fork's own doc calls it "better
///     compatibility for streaming audio/video without 403 errors" and
///     no PO token required either.
///   - `ios`: limited streams but no signature deciphering needed.
/// `webCreator`/`webRemix`-style clients are deliberately NOT in this
/// list — this fork marks `webCreator` `@Deprecated('Youtube always
/// requires authentication for this client')`, so it's not a safe
/// unauthenticated fallback the way it apparently was on Android.
/// NOTE: not `const` — this fork declares `YoutubeApiClient.ios` as
/// `static final` (not `const`), since its construction isn't a
/// compile-time constant expression, so a `const` list containing it
/// won't compile. `androidVr`/`androidSdkless` are `const` themselves;
/// mixing them into a plain `final` list here is fine.
final List<YoutubeApiClient> kAudioFallbackClients = [
  YoutubeApiClient.androidVr,
  YoutubeApiClient.androidSdkless,
  YoutubeApiClient.ios,
];

/// googlevideo stream URLs carry a `c` query parameter identifying which
/// InnerTube client actually produced that URL (e.g. `ANDROID_VR`,
/// `ANDROID`, `IOS`). We use this afterwards to pick a User-Agent for the
/// byte-range GET that matches the client the CDN thinks issued the
/// request, instead of always sending one hardcoded desktop UA regardless
/// of which client actually resolved the stream.
String? clientNameFromStreamUrl(Uri url) => url.queryParameters['c'];

/// User-Agents lifted directly from this fork's own `YoutubeApiClient`
/// payloads (lib/src/videos/youtube_api_client.dart), keyed by clientName.
/// `ANDROID_VR` has no explicit `userAgent` field in its payload in this
/// fork (unlike ios/android/safari/tv) — rather than invent a plausible-
/// looking string for it, it's deliberately left out below, so a stream
/// produced by that client falls back to the HTTP client's own default UA
/// instead of a guessed one presented as fact.
const Map<String, String> kClientUserAgents = {
  'IOS':
      'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
  'ANDROID':
      'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
  'ANDROID_MUSIC':
      'com.google.android.youtube/19.29.1  (Linux; U; Android 11) gzip',
  'WEB':
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.5 Safari/605.1.15,gzip(gfe)',
  'TVHTML5': 'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version,gzip(gfe)',
};

/// Best-effort User-Agent for a byte-range GET against [url], matching
/// whichever client's context actually produced this particular stream
/// URL. Returns null (meaning: don't override, let the HTTP client use
/// its own default) when we don't have a UA on file for that client.
String? userAgentForStreamUrl(Uri url) {
  final client = clientNameFromStreamUrl(url);
  if (client == null) return null;
  return kClientUserAgents[client];
}

/// Returns a copy of [base] with authenticated-session headers merged in
/// (YT Music cookie + SAPISIDHASH), for use as the first entry in a
/// client fallback list when a signed-in session is available. Doesn't
/// mutate [base] — [YoutubeApiClient] fields are all final.
YoutubeApiClient withAuthHeaders(
  YoutubeApiClient base, {
  required String cookieHeader,
  required String authorizationHeader,
}) {
  return YoutubeApiClient(base.payload, base.apiUrl, headers: {
    ...base.headers,
    'Cookie': cookieHeader,
    'Authorization': authorizationHeader,
    'X-Goog-AuthUser': '0',
  });
}

/// Simple FIFO async mutex (Dart has no built-in one, and this avoids
/// pulling in the `synchronized` package for a single use). Used to
/// serialize manifest/stream-URL resolution across the whole app.
///
/// Why: on the Android app, the player prefetching the next queue item
/// while the current one was still loading caused two full client-
/// fallback cascades to fire within the same millisecond, which tripped
/// YouTube's burst/anti-abuse detection and 403'd *every* client for
/// ~20s. This app enables the desktop player's own playlist prefetch
/// (`JustAudioMediaKit.prefetchPlaylist = true` in main.dart) and also
/// allows up to 3 concurrent downloads, both of which can trigger the
/// same kind of near-simultaneous manifest resolution — so this lock is
/// shared by every call site that resolves a manifest, not just
/// playback.
class AsyncLock {
  Future<void>? _tail;

  Future<T> synchronized<T>(Future<T> Function() action) async {
    final previous = _tail;
    final completer = Completer<void>();
    _tail = completer.future;
    if (previous != null) {
      await previous;
    }
    try {
      return await action();
    } finally {
      completer.complete();
    }
  }
}

/// Single shared lock for all manifest/stream-URL resolution app-wide.
final AsyncLock manifestResolutionLock = AsyncLock();

/// Builds the client fallback list for a manifest request, shared by
/// every call site (playback and downloads alike). If a signed-in YT
/// Music session is available, an authenticated variant of the first
/// fallback client (cookie + SAPISIDHASH) is tried first, with the plain
/// unauthenticated chain still available right after it as a fallback —
/// so auth issues don't regress anything that worked unauthenticated
/// before.
List<YoutubeApiClient> resolveAudioClients() {
  final clients = List<YoutubeApiClient>.from(kAudioFallbackClients);
  try {
    final auth = GetIt.I<YTMusicAuthService>();
    final cookie = auth.cookieHeader;
    if (auth.isSignedIn && cookie != null) {
      clients.insert(
        0,
        withAuthHeaders(
          clients.first,
          cookieHeader: cookie,
          authorizationHeader: auth.buildAuthHeader(),
        ),
      );
    }
  } catch (_) {
    // YTMusicAuthService not registered (e.g. in a context where GetIt
    // hasn't been set up) — proceed unauthenticated, same as before.
  }
  return clients;
}

/// Whether [clients] (as returned by resolveAudioClients()) has an
/// authenticated variant prepended, for diagnostic logging.
bool audioClientsHaveAuth(List<YoutubeApiClient> clients) =>
    clients.length > kAudioFallbackClients.length;
