import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

/// Thrown for any failure while initializing the BotGuard VM or minting a
/// PO Token.
class PoTokenException implements Exception {
  final String message;
  PoTokenException(this.message);
  @override
  String toString() => 'PoTokenException: $message';
}

/// A single (identifier, token) pair. [identifier] is either a per-video id
/// (for the "player" PO Token, sent with the innertube /player request) or a
/// session-level visitor-data-like string (for the "streaming"/GVS PO Token,
/// sent with the actual media download requests).
class PoTokenResult {
  final String identifier;
  final String poToken;
  PoTokenResult(this.identifier, this.poToken);
}

/// Generates real YouTube PO Tokens by running Google's own BotGuard
/// JavaScript inside a headless WebView — the same approach NewPipe and
/// NexMusic-Android use (see assets/solver/po_token.html, ported verbatim
/// from NewPipe, GPL-3.0, same license as this project).
///
/// Flow (mirrors PoTokenWebView.kt):
///  1. Load po_token.html into a headless WebView with base URL
///     https://www.youtube.com (so the BotGuard script believes it's
///     running on a real YouTube page).
///  2. POST to jnn-pa.googleapis.com's Waa/Create endpoint *natively*
///     (not from inside the WebView — that origin would hit CORS) to get
///     the raw BotGuard challenge data.
///  3. Feed that into the WebView's `runBotGuard()`, which executes the
///     challenge and produces a `botguardResponse` string plus a
///     `webPoSignalOutput` — the latter contains actual JS closures and
///     can never leave the WebView's JS heap, so it's stashed as
///     `globalThis.webPoSignalOutput` instead of being returned to Dart.
///  4. POST `botguardResponse` to Waa/GenerateIT (again natively) to get
///     an `integrityToken`, which is likewise stashed as
///     `globalThis.integrityToken` inside the WebView.
///  5. For each identifier we need a token for, call the WebView's
///     `obtainPoToken(webPoSignalOutput, integrityToken, identifier)` and
///     get back a plain token string.
class PoTokenGenerator {
  static const _googleApiKey = 'AIzaSyDyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw';
  static const _requestKey = 'O43z0dpjhgX20SCx4KAo';
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
  static const _waaCreateUrl =
      'https://jnn-pa.googleapis.com/\$rpc/google.internal.waa.v1.Waa/Create';
  static const _waaGenerateItUrl =
      'https://jnn-pa.googleapis.com/\$rpc/google.internal.waa.v1.Waa/GenerateIT';

  HeadlessInAppWebView? _headless;
  InAppWebViewController? _controller;
  Completer<void>? _initCompleter;
  final Map<String, Completer<String>> _pending = {};
  bool _dead = false;

  Map<String, String> get _grpcHeaders => {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
        'Content-Type': 'application/json+protobuf',
        'x-goog-api-key': _googleApiKey,
        'x-user-agent': 'grpc-web-javascript/0.1',
      };

  /// Whether this generator is unusable and a fresh one should be created.
  bool get isDead => _dead;

  Future<void> _ensureReady() async {
    if (_dead) {
      throw PoTokenException('PoTokenGenerator is dead, create a new one');
    }
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    final completer = Completer<void>();
    _initCompleter = completer;
    try {
      await _init(completer);
    } catch (e) {
      _dead = true;
      if (!completer.isCompleted) completer.completeError(e);
      rethrow;
    }
  }

  /// flutter_inappwebview's JS-handler callback shape changed across 6.x
  /// versions: older releases pass a plain `List<dynamic> args`, newer ones
  /// (6.2+) wrap it in a `JavaScriptHandlerFunctionData` object with an
  /// `.args` getter. This project's pubspec pins `^6.1.5` without a
  /// committed pubspec.lock, so the exact resolved version isn't knowable
  /// ahead of time — this extracts the arg list either way instead of
  /// assuming one shape.
  List<dynamic> _extractArgs(dynamic raw) {
    if (raw is List) return raw;
    try {
      final dynamic maybeArgs = (raw as dynamic).args;
      if (maybeArgs is List) return maybeArgs;
    } catch (_) {
      // fall through
    }
    return const [];
  }

  Future<void> _init(Completer<void> readyCompleter) async {
    final html = await rootBundle.loadString('assets/solver/po_token.html');

    late HeadlessInAppWebView headless;
    headless = HeadlessInAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        userAgent: _userAgent,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;

        controller.addJavaScriptHandler(
          handlerName: 'onJsInitializationError',
          callback: (rawArgs) {
            final args = _extractArgs(rawArgs);
            final err = args.isNotEmpty ? args[0].toString() : 'unknown';
            if (!readyCompleter.isCompleted) {
              readyCompleter.completeError(PoTokenException(err));
            }
            return null;
          },
        );

        controller.addJavaScriptHandler(
          handlerName: 'onInitializationFinished',
          callback: (rawArgs) {
            if (!readyCompleter.isCompleted) readyCompleter.complete();
            return null;
          },
        );

        controller.addJavaScriptHandler(
          handlerName: 'onRunBotguardResult',
          callback: (rawArgs) async {
            final args = _extractArgs(rawArgs);
            final botguardResponse = args.isNotEmpty ? args[0].toString() : '';
            try {
              final genResp = await http.post(
                Uri.parse(_waaGenerateItUrl),
                headers: _grpcHeaders,
                body: jsonEncode([_requestKey, botguardResponse]),
              );
              if (genResp.statusCode != 200) {
                throw PoTokenException(
                    'Waa/GenerateIT failed: HTTP ${genResp.statusCode}');
              }
              await controller.evaluateJavascript(source: '''
                (async function() {
                  try {
                    globalThis.integrityToken = JSON.parse(${jsonEncode(genResp.body)});
                    window.flutter_inappwebview.callHandler('onInitializationFinished');
                  } catch (error) {
                    window.flutter_inappwebview.callHandler('onJsInitializationError', error.toString());
                  }
                })();
              ''');
            } catch (e) {
              if (!readyCompleter.isCompleted) readyCompleter.completeError(e);
            }
            return null;
          },
        );

        controller.addJavaScriptHandler(
          handlerName: 'onObtainPoTokenResult',
          callback: (rawArgs) {
            final args = _extractArgs(rawArgs);
            if (args.length < 2) return null;
            final identifier = args[0].toString();
            final token = args[1].toString();
            _pending.remove(identifier)?.complete(token);
            return null;
          },
        );

        controller.addJavaScriptHandler(
          handlerName: 'onObtainPoTokenError',
          callback: (rawArgs) {
            final args = _extractArgs(rawArgs);
            final identifier = args.isNotEmpty ? args[0].toString() : '';
            final err = args.length > 1 ? args[1].toString() : 'unknown';
            _pending.remove(identifier)?.completeError(PoTokenException(err));
            return null;
          },
        );
      },
      onLoadStop: (controller, url) async {
        try {
          await _downloadAndRunBotguard(controller);
        } catch (e) {
          if (!readyCompleter.isCompleted) readyCompleter.completeError(e);
        }
      },
    );

    await headless.run();
    _headless = headless;

    if (_controller == null) {
      throw PoTokenException(
          'HeadlessInAppWebView did not report onWebViewCreated');
    }

    await _controller!.loadData(
      data: html,
      baseUrl: WebUri('https://www.youtube.com'),
      mimeType: 'text/html',
      encoding: 'utf-8',
    );

    await readyCompleter.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () =>
          throw PoTokenException('PoToken WebView initialization timed out'),
    );
  }

  Future<void> _downloadAndRunBotguard(InAppWebViewController controller) async {
    final createResp = await http.post(
      Uri.parse(_waaCreateUrl),
      headers: _grpcHeaders,
      body: '[ "$_requestKey" ]',
    );
    if (createResp.statusCode != 200) {
      throw PoTokenException('Waa/Create failed: HTTP ${createResp.statusCode}');
    }

    await controller.evaluateJavascript(source: '''
      (async function() {
        try {
          const data = JSON.parse(${jsonEncode(createResp.body)});
          const result = await runBotGuard(data);
          globalThis.webPoSignalOutput = result.webPoSignalOutput;
          window.flutter_inappwebview.callHandler('onRunBotguardResult', result.botguardResponse);
        } catch (error) {
          window.flutter_inappwebview.callHandler('onJsInitializationError', error.toString());
        }
      })();
    ''');
  }

  /// Generates a PO Token for [identifier] (a video id for the "player"
  /// token, or a visitor-data-like string for the "streaming"/GVS token).
  /// Can be called repeatedly with different identifiers once
  /// initialization has completed.
  ///
  /// If a request for this exact [identifier] is already in flight (e.g.
  /// playlist prefetch asking for the same video from two places at once),
  /// this awaits that same in-flight request instead of kicking off a
  /// redundant second one.
  Future<PoTokenResult> generatePoToken(String identifier) async {
    await _ensureReady();

    final existing = _pending[identifier];
    if (existing != null) {
      final token = await existing.future;
      return PoTokenResult(identifier, token);
    }

    final completer = Completer<String>();
    _pending[identifier] = completer;

    await _controller!.evaluateJavascript(source: '''
      (async function() {
        const identifier = ${jsonEncode(identifier)};
        try {
          const poToken = await obtainPoToken(webPoSignalOutput, integrityToken, identifier);
          window.flutter_inappwebview.callHandler('onObtainPoTokenResult', identifier, poToken);
        } catch (error) {
          window.flutter_inappwebview.callHandler('onObtainPoTokenError', identifier, error.toString());
        }
      })();
    ''');

    String token;
    try {
      token = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          final err = PoTokenException('generatePoToken timed out for $identifier');
          // Complete the underlying completer too (not just this wrapped
          // future) so any other caller that deduped onto `existing.future`
          // above doesn't hang forever waiting on a completer nobody ever
          // resolves.
          if (!completer.isCompleted) completer.completeError(err);
          _pending.remove(identifier);
          throw err;
        },
      );
    } catch (e) {
      _pending.remove(identifier);
      rethrow;
    }
    return PoTokenResult(identifier, token);
  }

  Future<void> close() async {
    _dead = true;
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(PoTokenException('PoTokenGenerator closed'));
      }
    }
    _pending.clear();
    await _headless?.dispose();
    _headless = null;
    _controller = null;
  }
}
