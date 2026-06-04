import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _showError = false;
  late AnimationController _popCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _popCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _scaleAnim = CurvedAnimation(
        parent: _popCtrl,
        curve: const ElasticOutCurve(0.9));
    _popCtrl.forward();
  }

  @override
  void dispose() {
    _popCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _doLogin() {
    final success = ref.read(authProvider.notifier).login(
          _usernameCtrl.text.trim(),
          _passwordCtrl.text,
        );
    if (success) {
      context.go('/app/dashboard');
    } else {
      setState(() => _showError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Background blobs
          Positioned(
            top: -100, left: -100,
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.greenMid.withOpacity(0.07),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -60, right: -60,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.greenMid.withOpacity(0.07),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          // Card
          Center(
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(_scaleAnim),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0, end: 1).animate(_popCtrl),
                child: Container(
                  width: 380,
                  constraints: const BoxConstraints(maxWidth: 380),
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.shadowLg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo
                      Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.greenMid, AppColors.greenMuted],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.eco_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FarmTrack Pro',
                                style: t.titleLarge?.copyWith(fontSize: 20)),
                            Text('Farm Expense Management',
                                style: t.labelSmall?.copyWith(
                                    color: AppColors.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 26),
                      Text('Welcome back 👋', style: t.displayMedium),
                      const SizedBox(height: 4),
                      Text('Sign in to manage your farms and mandis',
                          style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 24),
                      // Username
                      _FieldLabel('Username'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _usernameCtrl,
                        autofillHints: const [AutofillHints.username],
                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Enter username',
                        ),
                        onSubmitted: (_) => _doLogin(),
                      ),
                      const SizedBox(height: 14),
                      // Password
                      _FieldLabel('Password'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Enter password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: AppColors.textTertiary, size: 18,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        onSubmitted: (_) => _doLogin(),
                      ),
                      // Error
                      if (_showError) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppColors.redPale,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.red.withOpacity(0.2)),
                          ),
                          child: const Center(
                            child: Text(
                              'Incorrect username or password. Please try again.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.red),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Login button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppColors.greenMid,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _doLogin,
                          child: const Text('Sign In →',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                                fontFamily: 'Sora'),
                            children: const [
                              TextSpan(text: 'Demo: username '),
                              TextSpan(
                                  text: 'admin',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600)),
                              TextSpan(text: ' · password '),
                              TextSpan(
                                  text: 'farm123',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.05),
    );
  }
}
