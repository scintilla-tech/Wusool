import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStorageBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSecureTokenStorage implements TokenStorageBackend {
  final FlutterSecureStorage _storage;

  const PlatformSecureTokenStorage(this._storage);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class TokenStore {
  static const _accessKey = 'wasl_access_token';
  static const _refreshKey = 'wasl_refresh_token';
  static const _installationIdKey = 'wasl_installation_id';
  static const _pendingLogoutRefreshKey = 'wasl_pending_logout_refresh';

  final TokenStorageBackend _storage;
  String? _accessToken;
  String? _refreshToken;
  String? _installationId;
  String? _pendingLogoutRefresh;

  TokenStore(this._storage);

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String get installationId => _installationId!;
  String? get pendingLogoutRefresh => _pendingLogoutRefresh;

  bool get hasTokens => accessToken != null && refreshToken != null;

  Future<void> initialize() async {
    _accessToken = await _storage.read(_accessKey);
    _refreshToken = await _storage.read(_refreshKey);
    if ((_accessToken == null) != (_refreshToken == null)) await clear();
    _installationId = await _storage.read(_installationIdKey);
    _pendingLogoutRefresh = await _storage.read(_pendingLogoutRefreshKey);
    if (_installationId == null) {
      final random = Random.secure();
      _installationId = List.generate(
        8,
        (_) => random.nextInt(0x7fffffff).toRadixString(16).padLeft(8, '0'),
      ).join();
      await _storage.write(_installationIdKey, _installationId!);
    }
  }

  Future<void> savePendingLogout(String refresh) async {
    await _storage.write(_pendingLogoutRefreshKey, refresh);
    _pendingLogoutRefresh = refresh;
  }

  Future<void> clearPendingLogout() async {
    _pendingLogoutRefresh = null;
    await _storage.delete(_pendingLogoutRefreshKey);
  }

  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(_accessKey, access);
    try {
      await _storage.write(_refreshKey, refresh);
      _accessToken = access;
      _refreshToken = refresh;
    } catch (_) {
      await _storage.delete(_accessKey);
      rethrow;
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    await Future.wait([
      _storage.delete(_accessKey),
      _storage.delete(_refreshKey),
    ]);
  }
}
