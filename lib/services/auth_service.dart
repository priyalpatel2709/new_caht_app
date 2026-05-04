import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  // Call: supabase.auth.currentUser
  // Response: User? (null means not authenticated)
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  // Call: supabase.auth.signUp(email, password, data: {username})
  // Success: AuthResponse with session and user object
  // Error: AuthException
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      // Keep the public profile table in sync with auth users.
      if (response.user != null) {
        await _supabase.from('profiles').upsert({
          'id': response.user!.id,
          'username': username,
        });
      }

      return response;
    } on AuthException {
      rethrow;
    } on PostgrestException {
      rethrow;
    }
  }

  // Call: supabase.auth.signInWithPassword(email, password)
  // Success: AuthResponse with session.accessToken and user.id
  // Error: AuthException
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on AuthException {
      rethrow;
    }
  }

  // Call: supabase.auth.signOut()
  // Success: void
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException {
      rethrow;
    }
  }
}
