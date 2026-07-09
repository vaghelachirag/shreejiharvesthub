import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
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

final dashboardSearchProvider = StateProvider<String>((ref) => '');

// ── MAIN SHELL ────────────────────────────────────────────────────────────────
class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final FocusNode _scrollFocus = FocusNode(debugLabel: 'PageScrollFocus');
  late final List<ScrollController> _scrollCtrls =
      List.generate(AppPage.values.length, (_) => ScrollController());

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _scrollFocus.dispose();
    for (final c in _scrollCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // Arrow keys can move focus to/from text fields, dropdowns, etc. and never
  // bubble to a Focus/Shortcuts ancestor, so scroll the active page directly
  // off the raw hardware key stream — this works no matter what has focus.
  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final ctrl = _scrollCtrls[AppPage.values.indexOf(ref.read(currentPageProvider))];
    if (!ctrl.hasClients) return false;
    final pos = ctrl.position;
    double delta;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        delta = 60;
        break;
      case LogicalKeyboardKey.arrowUp:
        delta = -60;
        break;
      case LogicalKeyboardKey.pageDown:
        delta = pos.viewportDimension * 0.9;
        break;
      case LogicalKeyboardKey.pageUp:
        delta = -pos.viewportDimension * 0.9;
        break;
      default:
        return false;
    }
    final target = (pos.pixels + delta).clamp(pos.minScrollExtent, pos.maxScrollExtent);
    ctrl.animateTo(target, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final page  = ref.watch(currentPageProvider);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width.isMobile;

    // All pages stay mounted — no layout measurement issues during switching
    final pages = [
      DashboardScreen(scrollController: _scrollCtrls[0]),
      SalesScreen(scrollController: _scrollCtrls[1]),
      ExpensesScreen(scrollController: _scrollCtrls[2]),
      CropsScreen(scrollController: _scrollCtrls[3]),
      MarketsScreen(scrollController: _scrollCtrls[4]),
      FarmsScreen(scrollController: _scrollCtrls[5]),
    ];
    final pageIndex = AppPage.values.indexOf(page);

    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: isMobile ? _NavDrawer() : null,
      body: SafeArea(
        child: Focus(
          focusNode: _scrollFocus,
          autofocus: true,
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            child: Column(
              children: [
                _AppHeader(isMobile: isMobile),
                const SizedBox(height: 8),
                if (page == AppPage.dashboard) ...[
                  const _DashboardSearchBar(),
                  const SizedBox(height: 8),
                ],
                const _DateBar(),
                const SizedBox(height: 8),
                Expanded(
                  child: IndexedStack(
                    index: pageIndex,
                    children: pages,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── NAV DRAWER (mobile) ───────────────────────────────────────────────────────
class _NavDrawer extends ConsumerWidget {
  const _NavDrawer();

  static const _navItems = [
    (AppPage.dashboard, 'Dashboard',  Icons.dashboard_outlined),
    (AppPage.sales,     'Sales',       Icons.sell_outlined),
    (AppPage.expenses,  'Expenses',    Icons.trending_down_outlined),
    (AppPage.crops,     'Crops',       Icons.grass_outlined),
    (AppPage.markets,   'Markets',     Icons.storefront_outlined),
    (AppPage.farms,     'Farms',       Icons.agriculture_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(currentPageProvider);
    final auth = ref.watch(authProvider);

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.greenMid, AppColors.greenMuted],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.eco_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Shreeji Harvest Hub',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text(auth.isLoggedIn ? auth.userDisplayName : '',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ])),
            ]),
          ),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          // Nav items
          ...(_navItems.map((item) {
            final isActive = page == item.$1;
            return InkWell(
              onTap: () {
                ref.read(currentPageProvider.notifier).state = item.$1;
                Navigator.of(context).pop();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.greenPale : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isActive ? Border.all(color: AppColors.greenMuted.withOpacity(0.3)) : null,
                ),
                child: Row(children: [
                  Icon(item.$3, size: 18,
                      color: isActive ? AppColors.greenMid : AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Text(item.$2,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                          color: isActive ? AppColors.greenMid : AppColors.textSecondary,
                          fontFamily: 'Sora')),
                ]),
              ),
            );
          })),
          const Spacer(),
          const Divider(height: 1, color: AppColors.border),
          // Logout
          InkWell(
            onTap: () async {
              Navigator.of(context).pop();
              final ok = await showConfirmDialog(context,
                  title: 'Log out',
                  message: 'Log out of Shreeji Harvest Hub?',
                  confirmLabel: 'Log out',
                  isDangerous: false);
              if (ok) {
                ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: const Row(children: [
                Icon(Icons.logout_outlined, size: 18, color: AppColors.textSecondary),
                SizedBox(width: 12),
                Text('Logout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary, fontFamily: 'Sora')),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── HEADER ────────────────────────────────────────────────────────────────────
class _AppHeader extends ConsumerWidget {
  final bool isMobile;
  const _AppHeader({required this.isMobile});

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
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 20,
          vertical: isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.shadow,
      ),
      child: Row(children: [
        // ── Hamburger on mobile
        if (isMobile) ...[
          Builder(builder: (ctx) => InkWell(
            onTap: () => Scaffold.of(ctx).openDrawer(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.menu_rounded, size: 22, color: AppColors.textPrimary),
            ),
          )),
          const SizedBox(width: 10),
        ],
        // ── Logo
        Container(
          width: isMobile ? 34 : 44, height: isMobile ? 34 : 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.greenMid, AppColors.greenMuted],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(isMobile ? 9 : 12),
          ),
          child: Center(child: Icon(Icons.eco_rounded, color: Colors.white,
              size: isMobile ? 18 : 24)),
        ),
        const SizedBox(width: 10),
        // ── Title
        if (!isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Shreeji Harvest Hub',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary, letterSpacing: -0.3)),
              Text(
                auth.isLoggedIn ? 'Welcome, ${auth.userDisplayName}' : 'Harvest management',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          )
        else
          Expanded(child: Text('Shreeji Harvest Hub',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis)),
        if (!isMobile) const Spacer(),
        // ── Nav buttons (desktop/tablet only)
        if (!isMobile) ...[
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
                final ok = await showConfirmDialog(context,
                    title: 'Log out',
                    message: 'Log out of Shreeji Harvest Hub?',
                    confirmLabel: 'Log out',
                    isDangerous: false);
                if (ok) {
                  ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                }
              }),
            ],
          ),
        ] else ...[
          // Mobile: show current page name
          Text(_pageName(page),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.greenMid, fontFamily: 'Sora')),
        ],
      ]),
    );
  }

  String _pageName(AppPage p) {
    switch (p) {
      case AppPage.dashboard: return 'Dashboard';
      case AppPage.sales:     return 'Sales';
      case AppPage.expenses:  return 'Expenses';
      case AppPage.crops:     return 'Crops';
      case AppPage.markets:   return 'Markets';
      case AppPage.farms:     return 'Farms';
    }
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _NavButton({required this.label, required this.isActive, required this.onTap});

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
          border: Border.all(color: isActive ? AppColors.greenMid : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
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
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                color: AppColors.textSecondary, fontFamily: 'Sora')),
      ),
    );
  }
}

// ── DASHBOARD SEARCH BAR ───────────────────────────────────────────────────────
class _DashboardSearchBar extends ConsumerWidget {
  const _DashboardSearchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerRight,
      child: SearchField(
        hint: 'Search activity...',
        onChanged: (v) => ref.read(dashboardSearchProvider.notifier).state = v,
      ),
    );
  }
}

// ── DATE BAR ──────────────────────────────────────────────────────────────────
class _DateBar extends ConsumerWidget {
  const _DateBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter   = ref.watch(dateFilterProvider);
    final isAll    = filter.range == DateRange.all;
    final isMobile = MediaQuery.of(context).size.width.isMobile;

    String dateLabel = '';
    if (filter.range == DateRange.day) {
      dateLabel = isMobile
          ? DateFormat('d MMM yy').format(filter.activeDate)
          : DateFormat('EEE, d MMM yyyy').format(filter.activeDate);
    } else if (filter.range == DateRange.month) {
      dateLabel = isMobile
          ? DateFormat('MMM yyyy').format(filter.activeDate)
          : DateFormat('MMMM yyyy').format(filter.activeDate);
    } else {
      dateLabel = 'All Records';
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 16,
          vertical: isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.shadow,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _RangeBtn(label: 'Day', active: filter.range == DateRange.day,
              onTap: () => ref.read(dateFilterProvider.notifier).setRange(DateRange.day)),
          const SizedBox(width: 4),
          _RangeBtn(label: 'Month', active: filter.range == DateRange.month,
              onTap: () => ref.read(dateFilterProvider.notifier).setRange(DateRange.month)),
          const SizedBox(width: 4),
          _RangeBtn(label: 'All', active: filter.range == DateRange.all,
              onTap: () => ref.read(dateFilterProvider.notifier).setRange(DateRange.all)),
          const SizedBox(width: 10),
          Container(width: 1, height: 24, color: AppColors.border2),
          const SizedBox(width: 10),
          _ArrowBtn(icon: Icons.chevron_left, enabled: !isAll,
              onTap: () => ref.read(dateFilterProvider.notifier).previousPeriod()),
          const SizedBox(width: 6),
          if (!isAll)
            _DatePickerButton(date: filter.activeDate,
                onPicked: (d) => ref.read(dateFilterProvider.notifier).setDate(d)),
          const SizedBox(width: 6),
          _ArrowBtn(icon: Icons.chevron_right, enabled: !isAll,
              onTap: () => ref.read(dateFilterProvider.notifier).nextPeriod()),
          const SizedBox(width: 10),
          if (!isAll) ...[
            _TodayBtn(onTap: () => ref.read(dateFilterProvider.notifier).goToday()),
            const SizedBox(width: 10),
          ],
          Text(dateLabel,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ]),
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
          context: context, initialDate: date,
          firstDate: DateTime(2020), lastDate: DateTime(2030),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: AppColors.greenMid, onPrimary: Colors.white)),
            child: child!,
          ),
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface2, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border2, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(DateFormat('dd/MM/yyyy').format(date),
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontFamily: 'Sora')),
        ]),
      ),
    );
  }
}

class _RangeBtn extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const _RangeBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(8),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.greenMid : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? AppColors.greenMid : AppColors.border),
      ),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
          color: active ? Colors.white : AppColors.textSecondary, fontFamily: 'Sora')),
    ),
  );
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon; final bool enabled; final VoidCallback onTap;
  const _ArrowBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onTap : null, borderRadius: BorderRadius.circular(8),
    child: Container(
      width: 30, height: 30,
      decoration: BoxDecoration(color: AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border2)),
      child: Icon(icon, size: 18,
          color: enabled ? AppColors.textSecondary : AppColors.textTertiary.withOpacity(0.4)),
    ),
  );
}

class _TodayBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _TodayBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
      child: const Text('Today',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: AppColors.textSecondary, fontFamily: 'Sora')),
    ),
  );
}