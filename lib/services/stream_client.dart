import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'yt_client_config.dart';
import 'yt_debug_log.dart';

class AudioStreamClient {
  final http.Client _httpClient = http.Client();

  AudioStreamClient();

  /// Fallback headers used when we don't have a UA on file for the
  /// client that actually produced a given stream URL (see
  /// yt_client_config.dart's userAgentForStreamUrl). This used to be
  /// applied unconditionally to every request regardless of origin
  /// client, which could silently 403 an otherwise-valid URL — see
  /// send() below for the actual per-request UA selection.
  static const Map<String, String> _defaultHeaders = {
    'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.63 Safari/537.36',
    'cookie': 'CONSENT=YES+cb',
    'accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
    'accept-language': 'en-US,en;q=0.9',
    'sec-fetch-dest': 'document',
    'sec-fetch-mode': 'navigate',
    'sec-fetch-site': 'none',
    'sec-fetch-user': '?1',
    'sec-gpc': '1',
    'upgrade-insecure-requests': '1',
  };

  Stream<List<int>> getAudioStream(streamInfo,
          {required int start, required int end}) =>
      _getStream(streamInfo, streamClient: this, start: start, end: end);

  Stream<List<int>> _getStream(
    StreamInfo streamInfo, {
    Map<String, String> headers = const {},
    bool validate = true,
    required int start,
    required int end,
    int errorCount = 0,
    required AudioStreamClient streamClient,
  }) async* {
    var url = streamInfo.url;
    var bytesCount = start;
    while (bytesCount != end) {
      try {
        final response = await retry(this, () async {
          final from = bytesCount;
          final to = end - 1;

          late final http.Request request;
          if (url.queryParameters['c'] == 'ANDROID') {
            request = http.Request('get', url);
            request.headers['Range'] = 'bytes=$from-$to';
          } else {
            url = url.replace(queryParameters: {
              ...url.queryParameters,
              'range': '$from-$to'
            });
            request = http.Request('get', url);
          }
          return send(request);
        });
        if (validate) {
          try {
            _validateResponse(response, response.statusCode);
          } on FatalFailureException {
            continue;
          }
        }
        final stream = StreamController<List<int>>();
        response.stream.listen(
          (data) {
            bytesCount += data.length;
            stream.add(data);
          },
          onError: (_) => null,
          onDone: stream.close,
          cancelOnError: false,
        );
        errorCount = 0;
        yield* stream.stream;
      } on HttpClientClosedException {
        break;
      } on Exception {
        if (errorCount == 5) {
          rethrow;
        }
        await Future.delayed(const Duration(milliseconds: 500));
        yield* _getStream(
          streamInfo,
          streamClient: streamClient,
          headers: headers,
          validate: validate,
          start: bytesCount,
          end: end,
          errorCount: errorCount + 1,
        );
        break;
      }
    }
  }

  void _validateResponse(http.BaseResponse response, int statusCode) {
    final request = response.request!;

    if (request.url.host.endsWith('.google.com') &&
        request.url.path.startsWith('/sorry/')) {
      throw RequestLimitExceededException.httpRequest(response);
    }

    if (statusCode >= 500) {
      throw TransientFailureException.httpRequest(response);
    }

    if (statusCode == 429) {
      throw RequestLimitExceededException.httpRequest(response);
    }

    if (statusCode >= 400) {
      throw FatalFailureException.httpRequest(response);
    }
  }

  Future<T> retry<T>(
    AudioStreamClient? client,
    FutureOr<T> Function() function,
  ) async {
    var retryCount = 5;

    // ignore: literal_only_boolean_expressions
    while (true) {
      try {
        return await function();
      } on FatalFailureException catch (e) {
        // A 4xx on this exact URL/client is very likely to fail the same
        // way again — same client, same UA, same signed URL. Retrying
        // without changing anything mostly burns latency, so fail fast
        // here instead of consuming retry budget; the caller (whoever
        // resolved this stream's manifest) is responsible for falling
        // back to a different client if it wants to retry at all.
        YtDebugLog.event('download_fatal_no_retry', {
          'error': e.toString(),
        });
        rethrow;
        // ignore: avoid_catches_without_on_clauses
      } on Exception catch (e) {
        retryCount -= getExceptionCost(e);
        if (retryCount <= 0) {
          rethrow;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  int getExceptionCost(Exception e) {
    if (e is RequestLimitExceededException) {
      return 2;
    }
    if (e is FatalFailureException) {
      return 3;
    }
    return 1;
  }

  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Apply default headers if they are not already present
    _defaultHeaders.forEach((key, value) {
      if (request.headers[key] == null) {
        request.headers[key] = _defaultHeaders[key]!;
      }
    });

    // The CDN can tie a signed stream URL to the requesting client's
    // UA/context; always sending a hardcoded desktop Chrome UA regardless
    // of which client (androidVr, ios, etc.) actually produced the URL
    // can silently 403 an otherwise-valid stream. Override with a UA
    // matching whichever client the `c` query param on this URL says
    // produced it, when we have one on file (see yt_client_config.dart).
    final matchedUa = userAgentForStreamUrl(request.url);
    if (matchedUa != null) {
      request.headers['user-agent'] = matchedUa;
    }

    // print(request);
    // print(StackTrace.current);
    return _httpClient.send(request);
  }
}
