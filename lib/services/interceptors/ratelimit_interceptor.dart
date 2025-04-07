import 'dart:developer';
import 'package:dio/dio.dart';
import 'dart:async';

// vibe coded
class RateLimitInterceptor extends Interceptor {
  final Dio _dio;
  final Map<String, DateTime> _rateLimits = {};
  DateTime? _globalRateLimitReset;
  final List<Completer<void>> _globalQueue = [];
  int _globalRequestCount = 0;
  final int _globalRequestLimit = 50;
  DateTime _lastRequestTime = DateTime.now();
  final Duration _timeWindow = Duration(seconds: 60);

  RateLimitInterceptor(this._dio);

  // Helper method to parse rate limit headers
  DateTime? _getRateLimitResetTime(Headers headers, String bucket) {
    final resetAfterStr = headers['X-RateLimit-Reset-After']?.first;
    if (resetAfterStr != null) {
      final resetAfterSeconds = double.tryParse(resetAfterStr);
      if (resetAfterSeconds != null) {
        return DateTime.now().add(
          Duration(milliseconds: (resetAfterSeconds * 1000).round()),
        );
      }
    }

    final resetStr = headers['X-RateLimit-Reset']?.first;
    if (resetStr != null) {
      final resetEpoch = double.tryParse(resetStr);
      if (resetEpoch != null) {
        return DateTime.fromMillisecondsSinceEpoch((resetEpoch * 1000).toInt());
      }
    }

    return null;
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Check global rate limit
    if (_globalRateLimitReset != null &&
        DateTime.now().isBefore(_globalRateLimitReset!)) {
      final completer = Completer<void>();
      _globalQueue.add(completer);
      await completer.future; // Wait until the global rate limit resets
    }

    // Global request count enforcement using time window
    final now = DateTime.now();
    if (_lastRequestTime.add(_timeWindow).isBefore(now)) {
      // Reset the global request count when the time window is over
      _globalRequestCount = 0;
      _lastRequestTime = now;
    }

    if (_globalRequestCount >= _globalRequestLimit) {
      final nextSecond = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
        now.second + 1,
      );
      final delay = nextSecond.difference(now);
      await Future.delayed(delay);
      _globalRequestCount = 0; // Reset count after waiting
    }

    _globalRequestCount++;

    // Identify the bucket for this request
    final bucket =
        options.extra['rateLimitBucket'] as String? ?? options.uri.path;

    // Wait for bucket-specific rate limit reset if necessary
    if (_rateLimits.containsKey(bucket) &&
        DateTime.now().isBefore(_rateLimits[bucket]!)) {
      final remaining = _rateLimits[bucket]!.difference(DateTime.now());
      await Future.delayed(remaining);
    }

    handler.next(options);
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

    // Update rate limit reset times based on headers
    final resetTime = _getRateLimitResetTime(headers, bucket);
    if (resetTime != null) {
      _rateLimits[bucket] = resetTime;
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Handle rate limit exceeded error (HTTP 429)
    if (err.response?.statusCode == 429) {
      final headers = err.response?.headers;
      final retryAfterStr = headers?.value('Retry-After');
      final isGlobal = headers?.value('X-RateLimit-Global') == 'true';

      log("A ${isGlobal ? "global" : "route"} rate-limit was hit");

      if (retryAfterStr != null) {
        final double? retryAfterSeconds = double.tryParse(retryAfterStr);
        if (retryAfterSeconds != null) {
          final waitTime = Duration(
            milliseconds: (retryAfterSeconds * 1000).round(),
          );

          log("Retrying after $waitTime");

          if (isGlobal) {
            // Handle global rate limit reset
            _globalRateLimitReset = DateTime.now().add(waitTime);
            await Future.delayed(waitTime);

            // Release all queued requests
            for (final completer in _globalQueue) {
              completer.complete();
            }
            _globalQueue.clear();
          } else {
            // Handle bucket-specific rate limit reset
            final bucket =
                err.requestOptions.extra['rateLimitBucket'] as String? ??
                err.requestOptions.uri.path;
            _rateLimits[bucket] = DateTime.now().add(waitTime);
            await Future.delayed(waitTime);
          }

          // Retry the request after waiting
          try {
            final response = await _dio.fetch(err.requestOptions);
            return handler.resolve(response);
          } catch (e) {
            return handler.reject(
              e is DioException
                  ? e
                  : DioException(
                    requestOptions: err.requestOptions,
                    error: e,
                    type: DioExceptionType.unknown,
                  ),
            );
          }
        }
      }
    }

    handler.next(err); // Proceed with error handling
  }
}
