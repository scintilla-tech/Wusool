import 'package:flutter/foundation.dart';

class AppConfig {
  final String apiBaseUrl;
  final String environment;

  const AppConfig({required this.apiBaseUrl, required this.environment});

  /// Socket.IO origin (API base without the `/api/v1` suffix).
  String get socketUrl => apiBaseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');

  factory AppConfig.fromEnvironment() {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    const environment = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );

    if (!{'development', 'demo', 'production'}.contains(environment)) {
      throw StateError('APP_ENV must be development, demo, or production.');
    }

    final fallbackUrl = kIsWeb
        ? 'http://localhost:3100/api/v1'
        : defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:3100/api/v1'
        : 'http://localhost:3100/api/v1';
    final url = (configuredUrl.isEmpty ? fallbackUrl : configuredUrl)
        .replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(url);

    if (uri == null ||
        !uri.hasScheme ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw StateError('API_BASE_URL must be a valid HTTP(S) base URL.');
    }
    if (!RegExp(r'/api/v1$').hasMatch(uri.path)) {
      throw StateError('API_BASE_URL must end with /api/v1.');
    }

    final isHostLoopback =
        uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
    if (environment != 'development' && isHostLoopback) {
      throw StateError(
        'Loopback API_BASE_URL is only valid in development. '
        'Use the host LAN address or an HTTPS URL on a phone.',
      );
    }
    if (environment == 'production' && uri.scheme != 'https') {
      throw StateError('Production API_BASE_URL must use HTTPS.');
    }

    return AppConfig(apiBaseUrl: url, environment: environment);
  }
}
