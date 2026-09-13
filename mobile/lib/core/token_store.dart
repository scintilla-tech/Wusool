import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  static const _accessKey = 'wasl_access_token';
  static const _refreshKey = 'wasl_refresh_token';

  final SharedPreferences _prefs;

  TokenStore(this._prefs);

  String? get accessToken => _prefs.getString(_accessKey);
  String? get refreshToken => _prefs.getString(_refreshKey);

  bool get hasTokens => accessToken != null && refreshToken != null;

  Future<void> save({required String access, required String refresh}) async {
    await _prefs.setString(_accessKey, access);
    await _prefs.setString(_refreshKey, refresh);
  }

  Future<void> clear() async {
    await _prefs.remove(_accessKey);
    await _prefs.remove(_refreshKey);
  }
}
