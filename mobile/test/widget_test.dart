import 'package:flutter_test/flutter_test.dart';

import 'package:wasl_mobile/app.dart';
import 'package:wasl_mobile/core/api_client.dart';
import 'package:wasl_mobile/core/token_store.dart';
import 'package:wasl_mobile/core/theme.dart';
import 'package:wasl_mobile/features/auth/login_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class _MemoryTokenStorage implements TokenStorageBackend {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  testWidgets('app renders the login screen when signed out', (tester) async {
    final tokenStore = TokenStore(_MemoryTokenStorage());
    await tokenStore.initialize();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tokenStoreProvider.overrideWithValue(tokenStore)],
        child: const WaslApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsWidgets);
  });

  testWidgets('theme defines the WASL navy primary color', (tester) async {
    final theme = buildTheme();
    expect(theme.colorScheme.primary, WaslColors.navy);
  });
}
