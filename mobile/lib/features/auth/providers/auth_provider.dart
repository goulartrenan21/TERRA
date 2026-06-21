import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Current session — null when logged out
final authSessionProvider = StateProvider<Session?>((ref) {
  return Supabase.instance.client.auth.currentSession;
});

// Stream-based auth state changes
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final authNotifierProvider = NotifierProvider<AuthNotifier, AsyncValue<void>>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AsyncValue<void>> {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _client.auth.signInWithPassword(email: email, password: password);
    });
  }

  Future<void> signUpWithEmail(String email, String password, String displayName) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.terra://login-callback',
      );
    });
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _client.auth.signOut();
    });
  }

  String? get currentUserId => _client.auth.currentUser?.id;
  String? get currentUserEmail => _client.auth.currentUser?.email;
}
