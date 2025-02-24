import 'dart:developer';

import 'package:dio/dio.dart';
import 'dart:async';

class RateLimitInterceptor extends Interceptor {
  final Dio _dio;
  final Map<String, DateTime> _rateLimits = {}; // route-specific rate limits keyed by bucket
  DateTime? _globalRateLimitReset;
  final List<Completer<void>> _globalQueue = [];
  int _globalRequestCount = 0;
  final int _globalRequestLimit = 50; // heuristic: max 50 requests per second

  RateLimitInterceptor(this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Check for global rate limit
    if (_globalRateLimitReset != null && DateTime.now().isBefore(_globalRateLimitReset!)) {
      final completer = Completer<void>();
      _globalQueue.add(completer);
      await completer.future; // Wait until the global rate limit resets
    }

    // Heuristic global request count enforcement
    final now = DateTime.now();
    if (_globalRequestCount >= _globalRequestLimit) {
      final nextSecond = DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second + 1);
      final delay = nextSecond.difference(now);
      await Future.delayed(delay);
      _globalRequestCount = 0;
    }
    _globalRequestCount++;

    // Identify the bucket for this request
    final bucket = options.extra['rateLimitBucket'] as String? ?? options.uri.path;

    // If the rate limit for this bucket is exceeded, wait for the reset time
    if (_rateLimits.containsKey(bucket) && DateTime.now().isBefore(_rateLimits[bucket]!)) {
      final remaining = _rateLimits[bucket]!.difference(DateTime.now());
      await Future.delayed(remaining); // Wait for the rate limit to reset
    }

    handler.next(options); // Proceed with the request
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final headers = response.headers;

    // Retrieve and store the bucket identifier from the response headers
    final bucket =
        headers.value('X-RateLimit-Bucket') ??
        response.requestOptions.extra['rateLimitBucket'] ??
        response.requestOptions.uri.path;
    response.requestOptions.extra['rateLimitBucket'] = bucket;

    // Update route-specific rate limits using the X-RateLimit-Reset or X-RateLimit-Reset-After headers
    final resetAfterStr = headers.value('X-RateLimit-Reset-After');
    if (resetAfterStr != null) {
      final resetAfterSeconds = double.tryParse(resetAfterStr);
      if (resetAfterSeconds != null) {
        final resetTime = DateTime.now().add(Duration(milliseconds: (resetAfterSeconds * 1000).round()));
        _rateLimits[bucket] = resetTime;
      }
    } else if (headers.value('X-RateLimit-Remaining') == '0') {
      final resetStr = headers.value('X-RateLimit-Reset');
      if (resetStr != null) {
        final resetEpoch = double.tryParse(resetStr);
        if (resetEpoch != null) {
          final resetTime = DateTime.fromMillisecondsSinceEpoch((resetEpoch * 1000).toInt());
          _rateLimits[bucket] = resetTime;
        }
      }
    }

    handler.next(response); // Proceed with the response
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Handle rate limit exceeded error (HTTP 429)
    if (err.response?.statusCode == 429) {
      final headers = err.response?.headers;
      final retryAfterStr = headers?.value('Retry-After');
      final isGlobal = headers?.value('X-RateLimit-Global') == 'true';

      log("A rate-limit was hit");

      if (retryAfterStr != null) {
        final retryAfterDouble = double.tryParse(retryAfterStr);
        if (retryAfterDouble != null) {
          final waitTime = Duration(milliseconds: (retryAfterDouble * 1000).round());

          log("Retrying after $waitTime");

          if (isGlobal) {
            // Handle global rate limit reset
            _globalRateLimitReset = DateTime.now().add(waitTime);
            // Wait for the global rate limit to expire.
            await Future.delayed(waitTime);
            // Release all queued requests
            for (final completer in _globalQueue) {
              completer.complete();
            }
            _globalQueue.clear();
          } else {
            // Handle bucket-specific rate limit reset
            final bucket = err.requestOptions.extra['rateLimitBucket'] as String? ?? err.requestOptions.uri.path;
            _rateLimits[bucket] = DateTime.now().add(waitTime);
            // Wait for the rate limit to reset
            await Future.delayed(waitTime);
          }

          // Retry the request after waiting
          try {
            final response = await _dio.fetch(err.requestOptions);
            return handler.resolve(response); // Resolve the response
          } catch (e) {
            return handler.reject(
              e is DioException
                  ? e
                  : DioException(requestOptions: err.requestOptions, error: e, type: DioExceptionType.unknown),
            );
          }
        }
      }
    }

    handler.next(err); // Proceed with error handling
  }
}
