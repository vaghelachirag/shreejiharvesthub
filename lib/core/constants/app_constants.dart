class AppConstants {
  // Demo credentials
  static const List<Map<String, String>> users = [
    {'username': 'admin', 'password': 'farm123', 'name': 'Admin'},
    {'username': 'farmer', 'password': 'farm123', 'name': 'Farmer'},
  ];

  // ── Responsive breakpoints ──────────────────────────────────────────────────
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;

  static const List<String> payModes = ['Cash', 'Online', 'Bank', 'Agnadiyu'];
  static const List<String> defaultCategories = [
    'Labour', 'Transport', 'Supplies', 'Fertilizer', 'Loan', 'Misc'
  ];
  static const List<String> farmTypes = [
    'Vegetable', 'Grain', 'Fruit', 'Dairy', 'Mixed', 'Other'
  ];
}

// ── Responsive helpers ────────────────────────────────────────────────────────
extension ScreenSize on double {
  bool get isMobile  => this < AppConstants.mobileBreakpoint;
  bool get isTablet  => this >= AppConstants.mobileBreakpoint && this < AppConstants.tabletBreakpoint;
  bool get isDesktop => this >= AppConstants.tabletBreakpoint;
}
