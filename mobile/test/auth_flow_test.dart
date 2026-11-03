import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wasl_mobile/app.dart';
import 'package:wasl_mobile/core/api_client.dart';
import 'package:wasl_mobile/core/token_store.dart';
import 'package:wasl_mobile/features/auth/activation_screen.dart';
import 'package:wasl_mobile/features/auth/login_screen.dart';
import 'package:wasl_mobile/features/student/student_shell.dart';

/// Fake HTTP adapter with canned responses so the auth flow can be tested
/// without a live backend.
final activationBodies = <Map<String, dynamic>>[];

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
    if (path.contains('/auth/activation/request')) {
      return _json({
        'success': true,
        'data': {'sent': true, 'devOtp': '123456'},
      });
    }
    if (path.contains('/auth/activation/complete')) {
      activationBodies.add(options.data as Map<String, dynamic>);
    }
    if (path.contains('/auth/login') ||
        path.contains('/auth/activation/complete')) {
      if (loginStatus != 200) {
        return ResponseBody.fromString(
          jsonEncode({
            'success': false,
            'error': {
              'code': 'INVALID_CREDENTIALS',
              'message': 'Invalid credentials',
            },
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
          'user': {
            'id': 'u1',
            'role': 'STUDENT',
            'firstName': 'Nejood',
            'lastName': 'Demo',
          },
        },
      });
    }
    if (path.contains('/auth/me')) {
      if (meStatus == 304) {
        return ResponseBody.fromString('', 304);
      }
      return _json({
        'success': true,
        'data': {
          'id': 'u1',
          'role': 'STUDENT',
          'firstName': 'Nejood',
          'lastName': 'Demo',
        },
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

class _MemoryTokenStorage implements TokenStorageBackend {
  final Map<String, String> values;

  _MemoryTokenStorage([Map<String, String>? initial]) : values = {...?initial};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

Future<Widget> _app({
  int loginStatus = 200,
  int meStatus = 200,
  Map<String, Object> prefs = const {},
}) async {
  final tokenStore = TokenStore(
    _MemoryTokenStorage(
      prefs.map((key, value) => MapEntry(key, value.toString())),
    ),
  );
  await tokenStore.initialize();
  return ProviderScope(
    overrides: [
      tokenStoreProvider.overrideWithValue(tokenStore),
      apiClientProvider.overrideWith((ref) {
        final tokenStore = ref.watch(tokenStoreProvider);
        final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
          ..httpClientAdapter = _FakeAdapter(
            loginStatus: loginStatus,
            meStatus: meStatus,
          );
        return ApiClient(dio, tokenStore, 'http://test.local/api/v1');
      }),
    ],
    child: const WaslApp(),
  );
}

void main() {
  testWidgets(
    'successful login navigates to the role shell (no infinite loading)',
    (tester) async {
      await tester.pumpWidget(await _app());
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), '+966500000101');
      await tester.enterText(fields.at(2), 'test-password');
      await tester.ensureVisible(find.text('تسجيل الدخول'));
      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(StudentShell), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('failed login shows an error and restores the login button', (
    tester,
  ) async {
    await tester.pumpWidget(await _app(loginStatus: 401));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), '+966500000101');
    await tester.enterText(fields.at(2), 'wrong-password');
    await tester.ensureVisible(find.text('تسجيل الدخول'));
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget); // button restored
    expect(find.byType(SnackBar), findsOneWidget); // visible error
  });

  testWidgets('a 304 on /auth/me does not leave the app stuck loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _app(
        meStatus: 304,
        prefs: {'wasl_access_token': 'a', 'wasl_refresh_token': 'r'},
      ),
    );
    await tester.pumpAndSettle();

    // Falls back to the login screen instead of hanging on a spinner.
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a first sign-in sets the password with a texted code', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    activationBodies.clear();
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), '0500000101');
    await tester.tap(find.text('أول دخول؟ تفعيل الحساب برمز تحقق'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivationScreen), findsOneWidget);

    await tester.tap(find.text('إرسال رمز التحقق'));
    await tester.pumpAndSettle();
    expect(find.textContaining('123456'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(2), '١٢٣٤٥٦');
    await tester.enterText(fields.at(3), 'new-pass-123');
    await tester.enterText(fields.at(4), 'new-pass-123');
    await tester.tap(find.text('تفعيل الحساب والدخول'));
    await tester.pumpAndSettle();

    expect(activationBodies.single, {
      'tenantCode': 'KKU',
      'phone': '0500000101',
      'code': '123456',
      'password': 'new-pass-123',
    });
    expect(find.byType(ActivationScreen), findsNothing);
    expect(find.byType(StudentShell), findsOneWidget);
  });
}
