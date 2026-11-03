import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'token_store.dart';

final configProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

class ApiClient {
  final Dio dio;
  final TokenStore tokenStore;
  Future<bool>? _refreshInFlight;

  ApiClient(this.dio, this.tokenStore, String baseUrl) {
    dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = tokenStore.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final isAuth401 = error.response?.statusCode == 401;
          final alreadyRetried = error.requestOptions.extra['retried'] == true;
          final isAuthPath = error.requestOptions.path.startsWith('/auth/');

          if (isAuth401 && !alreadyRetried && !isAuthPath) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              try {
                final opts = error.requestOptions;
                opts.extra['retried'] = true;
                opts.headers['Authorization'] =
                    'Bearer ${tokenStore.accessToken}';
                final res = await dio.fetch(opts);
                handler.resolve(res);
                return;
              } on DioException catch (e) {
                handler.next(e);
                return;
              } catch (_) {
                handler.next(error);
                return;
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<bool> _tryRefresh() async {
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final attempt = _performRefresh();
    _refreshInFlight = attempt;
    try {
      return await attempt;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<bool> _performRefresh() async {
    final refresh = tokenStore.refreshToken;
    if (refresh == null) return false;
    try {
      final res = await dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refresh},
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      final access = data?['accessToken'] as String?;
      final newRefresh = data?['refreshToken'] as String?;
      if (access != null && newRefresh != null) {
        await tokenStore.save(access: access, refresh: newRefresh);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

/// The API's error code (e.g. `NO_ACTIVE_ROUTE`) carried by a failed request.
String? apiErrorCode(Object error) {
  if (error is! DioException) return null;
  final data = error.response?.data;
  final body = data is Map ? data['error'] : null;
  return body is Map ? body['code'] as String? : null;
}

/// Riverpod retries failed providers by default. A 4xx answer will not
/// change on its own, so retrying only keeps the screen spinning.
Duration? retryUnlessClientError(int retryCount, Object error) {
  final status = error is DioException ? error.response?.statusCode : null;
  if (status != null && status >= 400 && status < 500) return null;
  return ProviderContainer.defaultRetry(retryCount, error);
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(configProvider);
  final tokenStore = ref.watch(tokenStoreProvider);
  return ApiClient(Dio(), tokenStore, config.apiBaseUrl);
});
