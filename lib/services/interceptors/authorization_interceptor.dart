import 'package:dio/dio.dart';

class AuthorizationInterceptor extends Interceptor {
  final String _token;

  AuthorizationInterceptor(this._token);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Authorization'] = _token;
    super.onRequest(options, handler);
  }
}
