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
  // Sign In
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();

  bool _obscureLogin = true;
  bool _isLoading    = false;

  late AnimationController _popCtrl;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _popCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _scaleAnim = CurvedAnimation(
        parent: _popCtrl, curve: const ElasticOutCurve(0.9));
    _popCtrl.forward();
  }

  @override
  void dispose() {
    _popCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final error = await ref
        .read(authProvider.notifier)
        .login(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (error == null) {
      context.go('/app/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Background blobs
          Positioned(top: -100, left: -100,
            child: Container(width: 400, height: 400,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.greenMid.withOpacity(0.07),
                  Colors.transparent,
                ])))),
          Positioned(bottom: -60, right: -60,
            child: Container(width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.greenMid.withOpacity(0.07),
                  Colors.transparent,
                ])))),
          // Card
          Center(
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(_scaleAnim),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0, end: 1).animate(_popCtrl),
                child: Container(
                  width: 400,
                  constraints: const BoxConstraints(maxWidth: 400),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.shadowLg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Logo
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                        child: Column(children: [
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
                              child: const Icon(Icons.eco_rounded,
                                  color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Shreeji Harvest Hub',
                                  style: t.titleLarge?.copyWith(fontSize: 18, fontFamily: 'Sora')),
                              Text('Harvest Management',
                                  style: t.labelSmall?.copyWith(
                                      color: AppColors.textSecondary, fontSize: 11, fontFamily: 'Sora')),
                            ]),
                          ]),
                        ]),
                      ),
                      // ── Sign In Form
                      _SignInTab(
                        emailCtrl: _emailCtrl,
                        passCtrl: _passCtrl,
                        obscure: _obscureLogin,
                        isLoading: _isLoading,
                        error: authState.error,
                        onToggleObscure: () =>
                            setState(() => _obscureLogin = !_obscureLogin),
                        onSubmit: _doLogin,
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

// ── SIGN IN TAB ───────────────────────────────────────────────────────────────
class _SignInTab extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscure;
  final bool isLoading;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  const _SignInTab({
    required this.emailCtrl, required this.passCtrl,
    required this.obscure, required this.isLoading,
    required this.error, required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Welcome back 👋', style: t.headlineMedium?.copyWith(fontFamily: 'Sora')),
        const SizedBox(height: 3),
        Text('Sign in to Shreeji Harvest Hub',
            style: t.bodySmall?.copyWith(color: AppColors.textSecondary, fontFamily: 'Sora')),
        const SizedBox(height: 24),
        _Label('Email'),
        const SizedBox(height: 6),
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: _kInputStyle,
          decoration: _kDec('you@example.com'),
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: 16),
        _Label('Password'),
        const SizedBox(height: 6),
        TextField(
          controller: passCtrl,
          obscureText: obscure,
          style: _kInputStyle,
          decoration: _kDec('Enter password', suffix: IconButton(
            icon: Icon(obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
                color: AppColors.textTertiary, size: 18),
            onPressed: onToggleObscure,
          )),
          onSubmitted: (_) => onSubmit(),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          _ErrorBox(error!),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.greenMid,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: isLoading ? null : onSubmit,
            child: isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Text(
              'Sign In →',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: 'Sora',
              ),
            ),
          ),
        )
      ]),
    );
  }
}

// ── SHARED HELPERS ────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
        color: AppColors.textSecondary, letterSpacing: 0.05, fontFamily: 'Sora'),
  );
}

class _ErrorBox extends StatelessWidget {
  final String msg;
  const _ErrorBox(this.msg);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: AppColors.redPale,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.red.withOpacity(0.2)),
    ),
    child: Center(child: Text(msg,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
            color: AppColors.red, fontFamily: 'Sora'))),
  );
}

const _kInputStyle =
    TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Sora');

InputDecoration _kDec(String hint, {Widget? suffix}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary, fontFamily: 'Sora'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.greenLight, width: 1.5)),
      filled: true, fillColor: AppColors.surface2,
    );
