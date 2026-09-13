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

class AuthState {
  final bool busy;
  final bool authenticated;
  final bool restoring;
  final String? errorMessage;
  final AuthUser? user;

  const AuthState({
    this.busy = false,
    this.authenticated = false,
    this.restoring = true,
    this.errorMessage,
    this.user,
  });

  AuthState copyWith({
    bool? busy,
    bool? authenticated,
    bool? restoring,
    String? errorMessage,
    AuthUser? user,
  }) {
    return AuthState(
      busy: busy ?? this.busy,
      authenticated: authenticated ?? this.authenticated,
      restoring: restoring ?? this.restoring,
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
      state = state.copyWith(restoring: false);
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get<Map<String, dynamic>>('/auth/me');
      final data = res.data?['data'] as Map<String, dynamic>?;
      state = AuthState(
        authenticated: true,
        user: data != null ? AuthUser.fromJson(data) : null,
      );
    } catch (_) {
      await tokenStore.clear();
      state = const AuthState();
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

      state = AuthState(authenticated: true, user: AuthUser.fromJson(user));
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
    state = const AuthState(authenticated: false, restoring: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
