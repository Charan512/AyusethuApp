import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? token;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.token,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? token,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      token: token ?? this.token,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService = AuthService();

  AuthNotifier() : super(const AuthState());

  /// Check if user has existing token on app launch
  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);
    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn) {
      state = state.copyWith(status: AuthStatus.authenticated);
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// Login
  Future<void> login({String? phone, String? email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final result = await _authService.login(
        phone: phone,
        email: email,
        password: password,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: result['user'] as UserModel,
        token: result['token'] as String,
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? 'Login failed. Please try again.';
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: msg,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'An unexpected error occurred',
      );
    }
  }

  /// Register
  Future<void> register({
    required String name,
    required String phone,
    String? email,
    required String password,
    String? farmSize,
    String? irrigationType,
    String? location,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final result = await _authService.register(
        name: name,
        phone: phone,
        email: email,
        password: password,
        farmSize: farmSize,
        irrigationType: irrigationType,
        location: location,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: result['user'] as UserModel,
        token: result['token'] as String,
      );
    } on DioException catch (e) {
      final msg =
          e.response?.data?['error'] ?? 'Registration failed. Please try again.';
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: msg,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'An unexpected error occurred',
      );
    }
  }

  /// Update user after profile save
  void updateUser(UserModel user) {
    state = state.copyWith(user: user);
  }

  /// Logout
  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
