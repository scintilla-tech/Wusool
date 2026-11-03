import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const legacyAccessKey = 'wasl_access_token';
  const legacyRefreshKey = 'wasl_refresh_token';
  final tokenStore = TokenStore(
    const PlatformSecureTokenStorage(FlutterSecureStorage()),
  );
  await tokenStore.initialize();

  // One-time migration removes credentials written by older releases from
  // SharedPreferences after copying a complete pair into secure storage.
  final prefs = await SharedPreferences.getInstance();
  final legacyAccess = prefs.getString(legacyAccessKey);
  final legacyRefresh = prefs.getString(legacyRefreshKey);
  if (!tokenStore.hasTokens && legacyAccess != null && legacyRefresh != null) {
    await tokenStore.save(access: legacyAccess, refresh: legacyRefresh);
  }
  await prefs.remove(legacyAccessKey);
  await prefs.remove(legacyRefreshKey);

  runApp(
    ProviderScope(
      retry: retryUnlessClientError,
      overrides: [tokenStoreProvider.overrideWithValue(tokenStore)],
      child: const WaslApp(),
    ),
  );
}
