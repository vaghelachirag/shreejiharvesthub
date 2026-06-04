class AppConstants {
  // Demo credentials
  static const List<Map<String, String>> users = [
    {'username': 'admin', 'password': 'farm123', 'name': 'Admin'},
    {'username': 'farmer', 'password': 'farm123', 'name': 'Farmer'},
  ];

  static const List<String> payModes = ['Cash', 'Online', 'Other'];
  static const List<String> defaultCategories = [
    'Labour', 'Transport', 'Supplies', 'Fertilizer', 'Loan', 'Misc'
  ];
  static const List<String> farmTypes = [
    'Vegetable', 'Grain', 'Fruit', 'Dairy', 'Mixed', 'Other'
  ];
}
