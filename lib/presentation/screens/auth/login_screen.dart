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
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  bool _obscureLogin = true;

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
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LoginProgressDialog(),
    );

    final error = await ref
        .read(authProvider.notifier)
        .login(_emailCtrl.text.trim(), _passCtrl.text);

    if (!mounted) return;

    // Close the dialog
    Navigator.of(context, rootNavigator: true).pop();

    if (error == null) {
      context.go('/app/dashboard');
    }
    // On error: dialog is closed, authState.error will show the error box
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
                        child: Row(children: [
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Shreeji Harvest Hub',
                                  style: t.titleLarge?.copyWith(
                                      fontSize: 18, fontFamily: 'Sora')),
                              Text('Harvest Management',
                                  style: t.labelSmall?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontFamily: 'Sora')),
                            ],
                          ),
                        ]),
                      ),
                      // ── Sign In Form
                      _SignInTab(
                        emailCtrl: _emailCtrl,
                        passCtrl: _passCtrl,
                        obscure: _obscureLogin,
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

// ── PROGRESS DIALOG ──────────────────────────────────────────────────────────
class _LoginProgressDialog extends StatefulWidget {
  const _LoginProgressDialog();

  @override
  State<_LoginProgressDialog> createState() => _LoginProgressDialogState();
}

class _LoginProgressDialogState extends State<_LoginProgressDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progressAnim;

  int _msgIndex = 0;
  static const _messages = [
    'Connecting to server…',
    'Verifying credentials…',
    'Loading your data…',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8));

    _progressAnim = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 0.40)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 25),
      TweenSequenceItem(
          tween: Tween(begin: 0.40, end: 0.70)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 35),
      TweenSequenceItem(
          tween: Tween(begin: 0.70, end: 0.88)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 40),
    ]).animate(_ctrl);

    _ctrl.forward();

    // Cycle status messages
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _msgIndex = 1);
    });
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _msgIndex = 2);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.shadowLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.greenMid, AppColors.greenMuted],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.eco_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(height: 18),
            const Text(
              'Signing In',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'Sora',
              ),
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _messages[_msgIndex],
                key: ValueKey(_msgIndex),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: 'Sora',
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Progress bar track
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(3),
              ),
              child: AnimatedBuilder(
                animation: _progressAnim,
                builder: (context, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _progressAnim.value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.greenMid, AppColors.greenLight],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // Percentage text
            AnimatedBuilder(
              animation: _progressAnim,
              builder: (context, _) {
                return Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(_progressAnim.value * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                      fontFamily: 'Sora',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── SIGN IN TAB ───────────────────────────────────────────────────────────────
class _SignInTab extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscure;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  const _SignInTab({
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.error,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Welcome back 👋',
            style: t.headlineMedium?.copyWith(fontFamily: 'Sora')),
        const SizedBox(height: 3),
        Text('Sign in to Shreeji Harvest Hub',
            style: t.bodySmall
                ?.copyWith(color: AppColors.textSecondary, fontFamily: 'Sora')),
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
          decoration: _kDec('Enter password',
              suffix: IconButton(
                icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textTertiary,
                    size: 18),
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
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: onSubmit,
            child: const Text(
              'Sign In →',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: 'Sora',
              ),
            ),
          ),
        ),
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
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.05,
            fontFamily: 'Sora'),
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
        child: Center(
            child: Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.red,
                    fontFamily: 'Sora'))),
      );
}

const _kInputStyle =
    TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Sora');

InputDecoration _kDec(String hint, {Widget? suffix}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          fontSize: 13, color: AppColors.textTertiary, fontFamily: 'Sora'),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      suffixIcon: suffix,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.border2, width: 1.5)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.border2, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.greenLight, width: 1.5)),
      filled: true,
      fillColor: AppColors.surface2,
    );
