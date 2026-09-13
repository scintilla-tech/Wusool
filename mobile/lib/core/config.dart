class AppConfig {
  final String apiBaseUrl;

  const AppConfig({required this.apiBaseUrl});

  /// Socket.IO origin (API base without the `/api/v1` suffix).
  String get socketUrl => apiBaseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');

  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:3100/api/v1',
    );
    return AppConfig(apiBaseUrl: url);
  }
}
