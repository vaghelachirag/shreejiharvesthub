import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/auth_provider.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/dashboard/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = authState.isLoggedIn;
      final isSplash   = state.matchedLocation == '/splash';
      final isLogin    = state.matchedLocation == '/login';

      if (isSplash) return null;
      if (!isLoggedIn && !isLogin) return '/login';
      if (isLoggedIn && isLogin)   return '/app/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login',  builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/app/dashboard', builder: (_, __) => const _Stub()),
          GoRoute(path: '/app/sales',     builder: (_, __) => const _Stub()),
          GoRoute(path: '/app/expenses',  builder: (_, __) => const _Stub()),
          GoRoute(path: '/app/crops',     builder: (_, __) => const _Stub()),
          GoRoute(path: '/app/markets',   builder: (_, __) => const _Stub()),
          GoRoute(path: '/app/farms',     builder: (_, __) => const _Stub()),
        ],
      ),
    ],
  );
});

class _Stub extends StatelessWidget {
  const _Stub();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
