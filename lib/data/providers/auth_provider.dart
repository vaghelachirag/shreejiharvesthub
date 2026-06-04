import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';

class AuthState {
  final bool isLoggedIn;
  final String userName;
  final String userDisplayName;

  const AuthState({
    this.isLoggedIn = false,
    this.userName = '',
    this.userDisplayName = '',
  });

  AuthState copyWith({bool? isLoggedIn, String? userName, String? userDisplayName}) =>
      AuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        userName: userName ?? this.userName,
        userDisplayName: userDisplayName ?? this.userDisplayName,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  /// Returns true if login succeeded, false otherwise.
  bool login(String username, String password) {
    final user = AppConstants.users.firstWhere(
      (u) => u['username'] == username && u['password'] == password,
      orElse: () => {},
    );
    if (user.isNotEmpty) {
      state = AuthState(
        isLoggedIn: true,
        userName: user['username']!,
        userDisplayName: user['name']!,
      );
      return true;
    }
    return false;
  }

  void logout() {
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
