import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'token_store.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

final configProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(ref.watch(sharedPreferencesProvider)),
);

class ApiClient {
  final Dio dio;
  final TokenStore tokenStore;

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
                opts.headers['Authorization'] = 'Bearer ${tokenStore.accessToken}';
                final res = await dio.fetch(opts);
                handler.resolve(res);
                return;
              } catch (e) {
                handler.next(e as DioException);
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

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(configProvider);
  final tokenStore = ref.watch(tokenStoreProvider);
  return ApiClient(Dio(), tokenStore, config.apiBaseUrl);
});
