import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _progressCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _progressAnim = CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut);

    _fadeCtrl.forward();
    _progressCtrl.forward();

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) context.go('/login');
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.splashStart, AppColors.greenDark, AppColors.greenMid],
            stops: [0, 0.45, 1],
          ),
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -120, right: -80,
              child: Container(
                width: 420, height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.greenMuted.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -60, left: -60,
              child: Container(
                width: 260, height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.greenMuted.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              bottom: 120, right: 60,
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.greenMuted.withOpacity(0.07),
                ),
              ),
            ),
            // Main content
            Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(_fadeAnim),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // App icon
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x40000000), blurRadius: 32, offset: Offset(0, 8))
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.eco_rounded, color: AppColors.greenMuted, size: 52),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Title
                      const Text('FarmTrack Pro',
                          style: TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      Text('Smart Farm Expense Management',
                          style: TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.65))),
                      const SizedBox(height: 56),
                      // Progress bar
                      SizedBox(
                        width: 180,
                        child: AnimatedBuilder(
                          animation: _progressAnim,
                          builder: (_, __) => ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: _progressAnim.value,
                              backgroundColor: Colors.white.withOpacity(0.15),
                              color: AppColors.greenMuted,
                              minHeight: 3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Grow smarter · Track better',
                          style: TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.4),
                              letterSpacing: 0.1,
                              fontWeight: FontWeight.w400)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
