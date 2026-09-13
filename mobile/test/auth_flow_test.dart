import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wasl_mobile/app.dart';
import 'package:wasl_mobile/core/api_client.dart';
import 'package:wasl_mobile/features/auth/login_screen.dart';
import 'package:wasl_mobile/features/student/student_shell.dart';

/// Fake HTTP adapter with canned responses so the auth flow can be tested
/// without a live backend.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.loginStatus = 200, this.meStatus = 200});

  final int loginStatus;
  final int meStatus;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    if (path.contains('/auth/login')) {
      if (loginStatus != 200) {
        return ResponseBody.fromString(
          jsonEncode({
            'success': false,
            'error': {'code': 'INVALID_CREDENTIALS', 'message': 'Invalid credentials'},
          }),
          loginStatus,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      return _json({
        'success': true,
        'data': {
          'accessToken': 'access',
          'refreshToken': 'refresh',
          'user': {'id': 'u1', 'role': 'STUDENT', 'firstName': 'Nejood', 'lastName': 'Demo'},
        },
      });
    }
    if (path.contains('/auth/me')) {
      if (meStatus == 304) {
        return ResponseBody.fromString('', 304);
      }
      return _json({
        'success': true,
        'data': {'id': 'u1', 'role': 'STUDENT', 'firstName': 'Nejood', 'lastName': 'Demo'},
      });
    }
    // Any other endpoint the role shell may call.
    return _json({'success': true, 'data': null});
  }

  ResponseBody _json(Object body) => ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

Future<Widget> _app({
  int loginStatus = 200,
  int meStatus = 200,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      apiClientProvider.overrideWith((ref) {
        final tokenStore = ref.watch(tokenStoreProvider);
        final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
          ..httpClientAdapter = _FakeAdapter(loginStatus: loginStatus, meStatus: meStatus);
        return ApiClient(dio, tokenStore, 'http://test.local/api/v1');
      }),
    ],
    child: const WaslApp(),
  );
}

void main() {
  testWidgets('successful login navigates to the role shell (no infinite loading)',
      (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), '+966500000101');
    await tester.enterText(fields.at(2), 'WaslDemo@2026');
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(StudentShell), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('failed login shows an error and restores the login button', (tester) async {
    await tester.pumpWidget(await _app(loginStatus: 401));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), '+966500000101');
    await tester.enterText(fields.at(2), 'wrong-password');
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget); // button restored
    expect(find.byType(SnackBar), findsOneWidget); // visible error
  });

  testWidgets('a 304 on /auth/me does not leave the app stuck loading', (tester) async {
    await tester.pumpWidget(
      await _app(meStatus: 304, prefs: {'wasl_access_token': 'a', 'wasl_refresh_token': 'r'}),
    );
    await tester.pumpAndSettle();

    // Falls back to the login screen instead of hanging on a spinner.
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
