import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/auth_provider.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/dashboard/main_shell.dart';

// Notifies GoRouter to re-run `redirect` on auth changes, without ever
// rebuilding the GoRouter itself — recreating it (e.g. via ref.watch(authProvider)
// above) tears down the active Navigator/Overlay, which silently breaks any
// dialog that happens to be open at that moment (e.g. the logout confirm dialog).
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, _) => notifyListeners());
  }
}

final _authRefreshProvider = Provider<_AuthRefreshNotifier>((ref) {
  final notifier = _AuthRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_authRefreshProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final isLoggedIn = ref.read(authProvider).isLoggedIn;
      final isSplash   = state.matchedLocation == '/splash';
      final isLogin    = state.matchedLocation == '/login';

      if (isSplash) return null;
      if (!isLoggedIn && !isLogin) return '/login';
      if (isLoggedIn && isLogin)   return '/app/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login',  builder: (_, _) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/app/dashboard', builder: (_, _) => const _Stub()),
          GoRoute(path: '/app/sales',     builder: (_, _) => const _Stub()),
          GoRoute(path: '/app/expenses',  builder: (_, _) => const _Stub()),
          GoRoute(path: '/app/crops',     builder: (_, _) => const _Stub()),
          GoRoute(path: '/app/markets',   builder: (_, _) => const _Stub()),
          GoRoute(path: '/app/farms',     builder: (_, _) => const _Stub()),
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
