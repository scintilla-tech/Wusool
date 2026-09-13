import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

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
  }) async {
    state = state.copyWith(busy: true, errorMessage: null);
    try {
      final api = ref.read(apiClientProvider);
      final payload = <String, dynamic>{'phone': phone, 'password': password};
      // tenantCode is omitted for platform-level accounts (PLATFORM_SUPER_ADMIN).
      if (tenantCode.trim().isNotEmpty) {
        payload['tenantCode'] = tenantCode.trim();
      }
      final res = await api.dio.post<Map<String, dynamic>>('/auth/login', data: payload);
      final data = res.data?['data'] as Map<String, dynamic>?;
      final access = data?['accessToken'] as String?;
      final refresh = data?['refreshToken'] as String?;
      final user = data?['user'] as Map<String, dynamic>?;

      if (access == null || refresh == null || user == null) {
        state = state.copyWith(busy: false, errorMessage: 'استجابة غير صحيحة من الخادم');
        return false;
      }

      final tokenStore = ref.read(tokenStoreProvider);
      await tokenStore.save(access: access, refresh: refresh);

      state = AuthState(status: AuthStatus.authenticated, user: AuthUser.fromJson(user));
      return true;
    } on DioException catch (e) {
      String? message;
      final data = e.response?.data;
      if (data is Map) {
        final error = data['error'];
        if (error is Map) {
          message = error['message'] as String?;
        }
      }
      state = state.copyWith(busy: false, errorMessage: message ?? 'تعذر تسجيل الدخول');
      return false;
    } catch (_) {
      state = state.copyWith(busy: false, errorMessage: 'تعذر تسجيل الدخول');
      return false;
    }
  }

  Future<void> logout() async {
    final api = ref.read(apiClientProvider);
    final tokenStore = ref.read(tokenStoreProvider);
    try {
      final refresh = tokenStore.refreshToken;
      if (refresh != null) {
        await api.dio.post('/auth/logout', data: {'refreshToken': refresh});
      }
    } catch (_) {
      // ignore logout errors
    }
    await tokenStore.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
