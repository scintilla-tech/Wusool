import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wasl_mobile/app.dart';
import 'package:wasl_mobile/core/api_client.dart';
import 'package:wasl_mobile/core/theme.dart';
import 'package:wasl_mobile/features/auth/login_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('app renders the login screen when signed out', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
