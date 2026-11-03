import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/token_store.dart';

class AuthUser {
  final String id;
  final String role;
  final String firstName;
  final String lastName;

  const AuthUser({
    required this.id,
    required this.role,
    required this.firstName,
    required this.lastName,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      role: json['role'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
    );
  }
}

/// Explicit auth lifecycle. The app never has an ambiguous "loading" state:
/// it is either initializing (only at true startup), unauthenticated, or
/// authenticated.
enum AuthStatus { initializing, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final bool busy;
  final String? errorMessage;
  final AuthUser? user;

  const AuthState({
    this.status = AuthStatus.initializing,
    this.busy = false,
    this.errorMessage,
    this.user,
  });

  AuthState copyWith({
    AuthStatus? status,
    bool? busy,
    String? errorMessage,
    AuthUser? user,
  }) {
    return AuthState(
      status: status ?? this.status,
      busy: busy ?? this.busy,
      errorMessage: errorMessage,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  bool _restored = false;

  @override
  AuthState build() {
    Future.microtask(restore);
    return const AuthState();
  }

  Future<void> restore() async {
    if (_restored) return;
    _restored = true;

    final tokenStore = ref.read(tokenStoreProvider);
    await _retryPendingLogout(tokenStore);
    if (!tokenStore.hasTokens) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get<Map<String, dynamic>>('/auth/me');
      final data = res.data?['data'];
      if (data is Map) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: AuthUser.fromJson(data.cast<String, dynamic>()),
        );
        return;
      }
      // No usable body (e.g. an unexpected 304): treat as signed out, never hang.
      await tokenStore.clear();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (_) {
      await tokenStore.clear();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login({
    required String tenantCode,
    required String phone,
    required String password,
  }) {
    final payload = <String, dynamic>{'phone': phone, 'password': password};
    // tenantCode is omitted for platform-level accounts (PLATFORM_SUPER_ADMIN).
    if (tenantCode.trim().isNotEmpty) {
      payload['tenantCode'] = tenantCode.trim();
    }
    return _signIn('/auth/login', payload, fallback: 'تعذر تسجيل الدخول');
  }

  /// Sends a one-time code to the phone of an account that has no password
  /// yet. The server answers the same for any phone, so this cannot tell
  /// whether an account exists. Returns the code only in development.
  Future<String?> requestActivationCode({
    required String tenantCode,
    required String phone,
  }) async {
    final api = ref.read(apiClientProvider);
    final res = await api.dio.post<Map<String, dynamic>>(
      '/auth/activation/request',
      data: {'tenantCode': tenantCode.trim(), 'phone': phone.trim()},
    );
    return res.data?['data']?['devOtp'] as String?;
  }

  /// First sign-in: proves the phone with [code], sets [password], signs in.
  Future<bool> activate({
    required String tenantCode,
    required String phone,
    required String code,
    required String password,
  }) {
    return _signIn('/auth/activation/complete', {
      'tenantCode': tenantCode.trim(),
      'phone': phone.trim(),
      'code': code.trim(),
      'password': password,
    }, fallback: 'تعذر تفعيل الحساب');
  }

  Future<bool> _signIn(
    String path,
    Map<String, dynamic> payload, {
    required String fallback,
  }) async {
    await _retryPendingLogout(ref.read(tokenStoreProvider));
    state = state.copyWith(busy: true, errorMessage: null);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.post<Map<String, dynamic>>(path, data: payload);
      final data = res.data?['data'] as Map<String, dynamic>?;
      final access = data?['accessToken'] as String?;
      final refresh = data?['refreshToken'] as String?;
      final user = data?['user'] as Map<String, dynamic>?;

      if (access == null || refresh == null || user == null) {
        state = state.copyWith(
          busy: false,
          errorMessage: 'استجابة غير صحيحة من الخادم',
        );
        return false;
      }

      final tokenStore = ref.read(tokenStoreProvider);
      await tokenStore.save(access: access, refresh: refresh);

      state = AuthState(
        status: AuthStatus.authenticated,
        user: AuthUser.fromJson(user),
      );
      return true;
    } on DioException catch (e) {
      final data = e.response?.data;
      final error = data is Map ? data['error'] : null;
      final code = error is Map ? error['code'] as String? : null;
      state = state.copyWith(
        busy: false,
        errorMessage: switch (code) {
          'INVALID_CREDENTIALS' =>
            'رقم الجوال أو كلمة المرور غير صحيحة. في أول دخول يلزم '
                'تفعيل الحساب أولاً.',
          'INVALID_CODE' => 'الرمز غير صحيح أو انتهت صلاحيته',
          'RATE_LIMITED' => 'محاولات كثيرة، حاول بعد قليل',
          _ when e.response == null => 'تعذّر الاتصال بالخادم',
          _ => fallback,
        },
      );
      return false;
    } catch (_) {
      state = state.copyWith(busy: false, errorMessage: fallback);
      return false;
    }
  }

  Future<void> logout() async {
    final api = ref.read(apiClientProvider);
    final tokenStore = ref.read(tokenStoreProvider);
    try {
      final refresh = tokenStore.refreshToken;
      if (refresh != null) {
        // Session revocation and this installation's push-token deactivation
        // are committed together by the backend.
        await api.dio.post(
          '/auth/logout',
          data: {
            'refreshToken': refresh,
            'deviceId': tokenStore.installationId,
          },
        );
        await tokenStore.clearPendingLogout();
      } else {
        await api.dio.delete(
          '/devices',
          data: {'deviceId': tokenStore.installationId},
        );
      }
    } catch (_) {
      final refresh = tokenStore.refreshToken;
      if (refresh != null) await tokenStore.savePendingLogout(refresh);
    }
    await tokenStore.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _retryPendingLogout(TokenStore tokenStore) async {
    final pending = tokenStore.pendingLogoutRefresh;
    if (pending == null) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.post(
        '/auth/logout',
        data: {'refreshToken': pending, 'deviceId': tokenStore.installationId},
      );
      await tokenStore.clearPendingLogout();
    } catch (_) {
      // Keep the encrypted marker for the next startup/login retry.
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
