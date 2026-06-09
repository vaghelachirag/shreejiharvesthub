import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/app_data_provider.dart';
import '../../widgets/common/common_widgets.dart';
import 'dashboard_screen.dart';
import '../sales/sales_screen.dart';
import '../expenses/expenses_screen.dart';
import '../crops/crops_screen.dart';
import '../farms/farms_screen.dart';
import '../markets/markets_screen.dart';

// ── NAVIGATION PROVIDER ───────────────────────────────────────────────────────
enum AppPage { dashboard, sales, expenses, crops, markets, farms }

final currentPageProvider = StateProvider<AppPage>((ref) => AppPage.dashboard);

// ── DASHBOARD FILTER PROVIDER ─────────────────────────────────────────────────
class DashboardFilter {
  final String farmId;
  final String mandiId;
  final String cropId;
  const DashboardFilter({this.farmId = '', this.mandiId = '', this.cropId = ''});
  DashboardFilter copyWith({String? farmId, String? mandiId, String? cropId}) =>
      DashboardFilter(
        farmId: farmId ?? this.farmId,
        mandiId: mandiId ?? this.mandiId,
        cropId: cropId ?? this.cropId,
      );
}

final dashboardFilterProvider =
    StateProvider<DashboardFilter>((ref) => const DashboardFilter());

// ── MAIN SHELL ────────────────────────────────────────────────────────────────
class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(currentPageProvider);

    Widget pageContent;
    switch (page) {
      case AppPage.dashboard:  pageContent = const DashboardScreen();  break;
      case AppPage.sales:      pageContent = const SalesScreen();       break;
      case AppPage.expenses:   pageContent = const ExpensesScreen();    break;
      case AppPage.crops:      pageContent = const CropsScreen();       break;
      case AppPage.markets:    pageContent = const MarketsScreen();     break;
      case AppPage.farms:      pageContent = const FarmsScreen();       break;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const _AppHeader(),
            const SizedBox(height: 12),
            const _DateBar(),
            const SizedBox(height: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.015),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(page),
                  child: pageContent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── HEADER ────────────────────────────────────────────────────────────────────
class _AppHeader extends ConsumerWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final page = ref.watch(currentPageProvider);

    const navItems = [
      (AppPage.dashboard, 'Dashboard'),
      (AppPage.sales,     'Sales'),
      (AppPage.expenses,  'Expenses'),
      (AppPage.crops,     'Crops'),
      (AppPage.markets,   'Markets'),
      (AppPage.farms,     'Farms'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.shadow,
      ),
      child: Row(
        children: [
          // ── Logo
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
            child: const Center(
              child: Icon(Icons.eco_rounded, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Shreeji Harvest Hub',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary, letterSpacing: -0.3)),
              Text(
                auth.isLoggedIn
                    ? 'Welcome, ${auth.userDisplayName}'
                    : 'Harvest expense management',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          // ── Nav buttons
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...navItems.map((item) => _NavButton(
                    label: item.$2,
                    isActive: page == item.$1,
                    onTap: () =>
                        ref.read(currentPageProvider.notifier).state = item.$1,
                  )),
              const SizedBox(width: 4),
              _LogoutButton(onTap: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Log out',
                  message: 'Log out of Shreeji Harvest Hub?',
                  confirmLabel: 'Log out',
                  isDangerous: false,
                );
                if (ok) {
                  ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                }
              }),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _NavButton(
      {required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.greenMid : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isActive ? AppColors.greenMid : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppColors.textSecondary,
                fontFamily: 'Sora')),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('⎋ Logout',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                fontFamily: 'Sora')),
      ),
    );
  }
}

// ── DATE BAR ──────────────────────────────────────────────────────────────────
class _DateBar extends ConsumerWidget {
  const _DateBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dateFilterProvider);
    final isAll = filter.range == DateRange.all;

    String dateLabel = '';
    if (filter.range == DateRange.day) {
      dateLabel = DateFormat('EEE, d MMM yyyy').format(filter.activeDate);
    } else if (filter.range == DateRange.month) {
      dateLabel = DateFormat('MMMM yyyy').format(filter.activeDate);
    } else {
      dateLabel = 'All Records';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.shadow,
      ),
      child: Row(
        children: [
          // Range buttons
          _RangeBtn(
              label: 'Day',
              active: filter.range == DateRange.day,
              onTap: () => ref
                  .read(dateFilterProvider.notifier)
                  .setRange(DateRange.day)),
          const SizedBox(width: 4),
          _RangeBtn(
              label: 'Month',
              active: filter.range == DateRange.month,
              onTap: () => ref
                  .read(dateFilterProvider.notifier)
                  .setRange(DateRange.month)),
          const SizedBox(width: 4),
          _RangeBtn(
              label: 'All',
              active: filter.range == DateRange.all,
              onTap: () => ref
                  .read(dateFilterProvider.notifier)
                  .setRange(DateRange.all)),
          const SizedBox(width: 10),
          // Divider
          Container(width: 1, height: 24, color: AppColors.border2),
          const SizedBox(width: 10),
          // Prev arrow
          _ArrowBtn(
            icon: Icons.chevron_left,
            enabled: !isAll,
            onTap: () =>
                ref.read(dateFilterProvider.notifier).previousPeriod(),
          ),
          const SizedBox(width: 6),
          // Date picker
          if (!isAll)
            _DatePickerButton(
              date: filter.activeDate,
              onPicked: (d) =>
                  ref.read(dateFilterProvider.notifier).setDate(d),
            ),
          const SizedBox(width: 6),
          // Next arrow
          _ArrowBtn(
            icon: Icons.chevron_right,
            enabled: !isAll,
            onTap: () => ref.read(dateFilterProvider.notifier).nextPeriod(),
          ),
          const SizedBox(width: 10),
          // Today button
          if (!isAll) ...[
            _TodayBtn(
                onTap: () =>
                    ref.read(dateFilterProvider.notifier).goToday()),
            const SizedBox(width: 10),
          ],
          // Date label
          Text(dateLabel,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onPicked;
  const _DatePickerButton({required this.date, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: AppColors.greenMid,
                    onPrimary: Colors.white,
                  ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border2, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_today_outlined,
              size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(DateFormat('MM/dd/yyyy').format(date),
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontFamily: 'Sora')),
        ]),
      ),
    );
  }
}

class _RangeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _RangeBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.greenMid : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: active ? AppColors.greenMid : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : AppColors.textSecondary,
                fontFamily: 'Sora')),
      ),
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _ArrowBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border2),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled
                ? AppColors.textSecondary
                : AppColors.textTertiary.withOpacity(0.4)),
      ),
    );
  }
}

class _TodayBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _TodayBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Today',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontFamily: 'Sora')),
      ),
    );
  }
}
