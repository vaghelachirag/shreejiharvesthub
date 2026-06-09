import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';

// ── AUTH STATE ────────────────────────────────────────────────────────────────
class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final String? error;
  final String uid;
  final String userEmail;
  final String userDisplayName;

  const AuthState({
    this.isLoggedIn = false,
    this.isLoading = false,
    this.error,
    this.uid = '',
    this.userEmail = '',
    this.userDisplayName = '',
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isLoading,
    String? error,
    String? uid,
    String? userEmail,
    String? userDisplayName,
  }) =>
      AuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        uid: uid ?? this.uid,
        userEmail: userEmail ?? this.userEmail,
        userDisplayName: userDisplayName ?? this.userDisplayName,
      );

  factory AuthState.fromUser(User user) => AuthState(
        isLoggedIn: true,
        uid: user.uid,
        userEmail: user.email ?? '',
        userDisplayName: user.displayName?.isNotEmpty == true
            ? user.displayName!
            : (user.email?.split('@').first ?? 'User'),
      );
}

// ── NOTIFIER ─────────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseService _svc;

  AuthNotifier(this._svc) : super(const AuthState()) {
    _svc.authStateChanges.listen((user) {
      if (user != null) {
        state = AuthState.fromUser(user);
      } else {
        state = const AuthState();
      }
    });
  }

  Future<String?> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _svc.signInWithEmail(email.trim(), password);
      return null;
    } on FirebaseAuthException catch (e) {
      final msg = _friendlyError(e.code);
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    } catch (_) {
      const msg = 'An unexpected error occurred.';
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    }
  }

 /* Future<String?> register(String email, String password, String displayName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cred = await _svc.createAccount(email.trim(), password);
      if (displayName.trim().isNotEmpty) {
        await cred.user?.updateDisplayName(displayName.trim());
      }
      return null;
    } on FirebaseAuthException catch (e) {
      final msg = _friendlyError(e.code);
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    }
  }*/

  Future<void> logout() async {
    await _svc.signOut();
    state = const AuthState();
  }

  void clearError() => state = state.copyWith(error: null);

  static String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':        return 'No account found with this email.';
      case 'wrong-password':        return 'Incorrect password. Please try again.';
      case 'invalid-credential':    return 'Incorrect email or password.';
      case 'email-already-in-use':  return 'This email is already registered.';
      case 'weak-password':         return 'Password must be at least 6 characters.';
      case 'invalid-email':         return 'Please enter a valid email address.';
      case 'too-many-requests':     return 'Too many attempts. Please try again later.';
      case 'network-request-failed':return 'Network error. Check your connection.';
      default:                      return 'Authentication failed. Please try again.';
    }
  }
}

// ── PROVIDERS ─────────────────────────────────────────────────────────────────
final firebaseServiceProvider = Provider<FirebaseService>(
  (_) => FirebaseService.instance,
);

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(firebaseServiceProvider));
});
