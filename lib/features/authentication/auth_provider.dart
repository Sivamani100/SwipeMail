import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

enum AuthStatus {
  unauthenticated,
  authenticating,
  authenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final String? email;
  final String? errorMessage;
  final bool isOnboardingCompleted;

  AuthState({
    required this.status,
    this.email,
    this.errorMessage,
    required this.isOnboardingCompleted,
  });

  factory AuthState.initial(bool isOnboardingCompleted) {
    return AuthState(
      status: AuthStatus.unauthenticated,
      isOnboardingCompleted: isOnboardingCompleted,
    );
  }

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? errorMessage,
    bool? isOnboardingCompleted,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      errorMessage: errorMessage ?? this.errorMessage,
      isOnboardingCompleted: isOnboardingCompleted ?? this.isOnboardingCompleted,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final storage = ref.watch(storageServiceProvider);
    Future.microtask(() => init());
    return AuthState.initial(storage.isOnboardingCompleted());
  }

  Future<void> init() async {
    final authService = ref.read(authServiceProvider);
    final gmailService = ref.read(gmailServiceProvider);

    final hasSession = await authService.tryRestoreSession();
    if (hasSession) {
      state = state.copyWith(status: AuthStatus.authenticating);
      try {
        final profile = await gmailService.getProfile();
        state = state.copyWith(
          status: AuthStatus.authenticated,
          email: profile['email'] as String,
        );
      } catch (e) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Failed to restore Gmail session: $e',
        );
      }
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> completeOnboarding() async {
    final storage = ref.read(storageServiceProvider);
    await storage.setOnboardingCompleted(true);
    state = state.copyWith(isOnboardingCompleted: true);
  }

  Future<void> login() async {
    final authService = ref.read(authServiceProvider);
    final gmailService = ref.read(gmailServiceProvider);

    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);
    try {
      await authService.signInWithGmail();
      final profile = await gmailService.getProfile();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        email: profile['email'] as String,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> logout() async {
    final authService = ref.read(authServiceProvider);
    final storage = ref.read(storageServiceProvider);

    await authService.logout();
    await storage.clearAllData();
    state = AuthState(
      status: AuthStatus.unauthenticated,
      isOnboardingCompleted: false, // Reset onboarding as well
      email: null,
      errorMessage: null,
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
