import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Handles real "Sign in with Google" using the OAuth 2.0 loopback
/// redirect flow (the standard flow for installed/desktop apps — see
/// https://developers.google.com/identity/protocols/oauth2/native-app).
///
/// This is deliberately separate from [YTMusicAuthService]: official
/// Google OAuth scopes (openid/email/profile) can't access YT Music's
/// internal, undocumented API — that still needs the cookie-based
/// WebView session. This service exists purely to show a real "who's
/// signed in" identity (name, email, profile photo) and give a proper
/// sign-out, the way a native app normally would.
class GoogleAuthService extends ChangeNotifier {
  // "Desktop app" type OAuth client. Per Google's own docs, installed-app
  // client secrets aren't treated as confidential the way a server-side
  // secret is — see the link above. They're still kept out of source
  // control here (passed via --dart-define at build time) so GitHub's
  // push protection doesn't block commits and the values aren't sitting
  // in plain text in the repo history.
  static const String _clientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );
  static const String _clientSecret = String.fromEnvironment(
    'GOOGLE_CLIENT_SECRET',
    defaultValue: '',
  );

  static const String _authEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const String _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const String _userinfoEndpoint =
      'https://www.googleapis.com/oauth2/v3/userinfo';
  static const String _revokeEndpoint = 'https://oauth2.googleapis.com/revoke';

  late final Box _box;

  bool _isSignedIn = false;
  bool get isSignedIn => _isSignedIn;

  String? _displayName;
  String? get displayName => _displayName;

  String? _email;
  String? get email => _email;

  String? _photoUrl;
  String? get photoUrl => _photoUrl;

  String? _accessToken;
  String? _refreshToken;
  DateTime? _accessTokenExpiry;

  bool _isSigningIn = false;
  bool get isSigningIn => _isSigningIn;

  Future<void> init() async {
    _box = await Hive.openBox('GOOGLE_AUTH');
    _displayName = _box.get('name');
    _email = _box.get('email');
    _photoUrl = _box.get('photo_url');
    _accessToken = _box.get('access_token');
    _refreshToken = _box.get('refresh_token');
    final expiryMs = _box.get('access_token_expiry');
    _accessTokenExpiry =
        expiryMs != null ? DateTime.fromMillisecondsSinceEpoch(expiryMs) : null;
    _isSignedIn = _refreshToken != null && _email != null;
    notifyListeners();
  }

  String _randomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)])
        .join();
  }

  /// Opens the system browser for Google's consent screen, listens on a
  /// local loopback server for the redirect, exchanges the resulting code
  /// for tokens, then fetches and stores the user's profile.
  ///
  /// Returns an error message on failure, or null on success.
  Future<String?> signIn() async {
    if (_clientId.isEmpty || _clientSecret.isEmpty) {
      return 'Google sign-in isn\'t configured for this build — missing '
          '--dart-define=GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET.';
    }
    if (_isSigningIn) return 'A sign-in is already in progress.';
    _isSigningIn = true;
    notifyListeners();

    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final redirectUri = 'http://127.0.0.1:${server.port}';
      final state = _randomString(24);

      final authUri = Uri.parse(_authEndpoint).replace(queryParameters: {
        'client_id': _clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'access_type': 'offline',
        'prompt': 'select_account',
        'state': state,
      });

      if (!await launchUrl(authUri)) {
        return 'Could not open the browser for sign-in.';
      }

      final request = await server.first.timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw TimeoutException('Sign-in timed out'),
      );

      final params = request.uri.queryParameters;
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write('''
          <html><body style="font-family:sans-serif;text-align:center;padding-top:80px">
          <h2>NexMusic</h2>
          <p>Signed in — you can close this tab and return to the app.</p>
          </body></html>
        ''');
      await request.response.close();

      if (params['state'] != state) {
        return 'Sign-in failed (state mismatch). Please try again.';
      }
      final code = params['code'];
      if (code == null) {
        return params['error'] ?? 'Sign-in was cancelled.';
      }

      final tokenResponse = await http.post(
        Uri.parse(_tokenEndpoint),
        body: {
          'code': code,
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
        },
      );
      if (tokenResponse.statusCode != 200) {
        return 'Could not complete sign-in (token exchange failed).';
      }
      final tokens = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      _accessToken = tokens['access_token'];
      _refreshToken = tokens['refresh_token'] ?? _refreshToken;
      final expiresIn = tokens['expires_in'] as int? ?? 3600;
      _accessTokenExpiry =
          DateTime.now().add(Duration(seconds: expiresIn));

      final userResponse = await http.get(
        Uri.parse(_userinfoEndpoint),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      if (userResponse.statusCode != 200) {
        return 'Signed in, but could not load your profile.';
      }
      final profile = jsonDecode(userResponse.body) as Map<String, dynamic>;
      _displayName = profile['name'];
      _email = profile['email'];
      _photoUrl = profile['picture'];

      await _box.putAll({
        'name': _displayName,
        'email': _email,
        'photo_url': _photoUrl,
        'access_token': _accessToken,
        if (_refreshToken != null) 'refresh_token': _refreshToken,
        'access_token_expiry': _accessTokenExpiry!.millisecondsSinceEpoch,
      });

      _isSignedIn = true;
      return null;
    } catch (e) {
      return 'Sign-in failed: $e';
    } finally {
      await server?.close(force: true);
      _isSigningIn = false;
      notifyListeners();
    }
  }

  /// Refreshes the access token using the stored refresh token. Returns
  /// true on success. Safe to call proactively (e.g. before it's known to
  /// be expired) — Google's token endpoint just issues a fresh one.
  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'refresh_token': _refreshToken!,
          'grant_type': 'refresh_token',
        },
      );
      if (response.statusCode != 200) return false;
      final tokens = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = tokens['access_token'];
      final expiresIn = tokens['expires_in'] as int? ?? 3600;
      _accessTokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
      await _box.putAll({
        'access_token': _accessToken,
        'access_token_expiry': _accessTokenExpiry!.millisecondsSinceEpoch,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns a currently-valid access token, refreshing it first if it's
  /// expired (or close to it). Null if not signed in or refresh fails.
  Future<String?> getValidAccessToken() async {
    if (!_isSignedIn) return null;
    final expiry = _accessTokenExpiry;
    final needsRefresh = expiry == null ||
        DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 2)));
    if (needsRefresh) {
      final ok = await _refreshAccessToken();
      if (!ok) return null;
    }
    return _accessToken;
  }

  Future<void> signOut() async {
    final token = _accessToken ?? _refreshToken;
    if (token != null) {
      try {
        await http.post(
          Uri.parse(_revokeEndpoint),
          body: {'token': token},
        );
      } catch (_) {
        // Best-effort — still clear local state even if revoke fails
        // (e.g. offline).
      }
    }

    await _box.clear();
    _isSignedIn = false;
    _displayName = null;
    _email = null;
    _photoUrl = null;
    _accessToken = null;
    _refreshToken = null;
    _accessTokenExpiry = null;
    notifyListeners();
  }
}
