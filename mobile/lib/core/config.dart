class AppConfig {
  final String apiBaseUrl;

  const AppConfig({required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:3100/api/v1',
    );
    return AppConfig(apiBaseUrl: url);
  }
}
