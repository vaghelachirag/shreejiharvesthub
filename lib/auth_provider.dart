import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'auth_provider.dart';
import 'data/models/models.dart';
import 'data/providers/auth_provider.dart';
import 'data/services/firebase_service.dart';

const _uuid = Uuid();

// ── DATE FILTER ───────────────────────────────────────────────────────────────
enum DateRange { day, month, all }

class DateFilterState {
  final DateRange range;
  final DateTime activeDate;
  DateFilterState({this.range = DateRange.day, DateTime? activeDate})
      : activeDate = activeDate ?? DateTime.now();
  DateFilterState copyWith({DateRange? range, DateTime? activeDate}) =>
      DateFilterState(range: range ?? this.range, activeDate: activeDate ?? this.activeDate);
}

class DateFilterNotifier extends StateNotifier<DateFilterState> {
  DateFilterNotifier() : super(DateFilterState(activeDate: DateTime.now()));
  void setRange(DateRange r) => state = state.copyWith(range: r);
  void setDate(DateTime d)   => state = state.copyWith(activeDate: d);
  void previousPeriod() {
    final d = state.activeDate;
    state = state.copyWith(
        activeDate: state.range == DateRange.day
            ? d.subtract(const Duration(days: 1))
            : DateTime(d.year, d.month - 1, 1));
  }
  void nextPeriod() {
    final d = state.activeDate;
    state = state.copyWith(
        activeDate: state.range == DateRange.day
            ? d.add(const Duration(days: 1))
            : DateTime(d.year, d.month + 1, 1));
  }
  void goToday() => state = state.copyWith(activeDate: DateTime.now());
}

final dateFilterProvider =
StateNotifierProvider<DateFilterNotifier, DateFilterState>(
        (_) => DateFilterNotifier());

// ── FIRESTORE STREAM PROVIDERS ────────────────────────────────────────────────
final _svcProvider = Provider<FirebaseService>((_) => FirebaseService.instance);

final farmsStreamProvider = StreamProvider<List<Farm>>((ref) {
  if (!ref.watch(authProvider).isLoggedIn) return Stream.value(<Farm>[]);
  return ref.read(_svcProvider).farmsStream();
});

final mandisStreamProvider = StreamProvider<List<Mandi>>((ref) {
  if (!ref.watch(authProvider).isLoggedIn) return Stream.value(<Mandi>[]);
  return ref.read(_svcProvider).mandisStream();
});

final cropsStreamProvider = StreamProvider<List<Crop>>((ref) {
  if (!ref.watch(authProvider).isLoggedIn) return Stream.value(<Crop>[]);
  return ref.read(_svcProvider).cropsStream();
});

final salesStreamProvider = StreamProvider<List<Sale>>((ref) {
  if (!ref.watch(authProvider).isLoggedIn) return Stream.value(<Sale>[]);
  return ref.read(_svcProvider).salesStream();
});

final expensesStreamProvider = StreamProvider<List<Expense>>((ref) {
  if (!ref.watch(authProvider).isLoggedIn) return Stream.value(<Expense>[]);
  return ref.read(_svcProvider).expensesStream();
});

// ── CATEGORIES ────────────────────────────────────────────────────────────────
final categoriesProvider =
StateNotifierProvider<CategoriesNotifier, List<String>>((ref) {
  final auth = ref.watch(authProvider);
  return CategoriesNotifier(ref.read(_svcProvider), auth.isLoggedIn);
});

class CategoriesNotifier extends StateNotifier<List<String>> {
  final FirebaseService _svc;
  CategoriesNotifier(this._svc, bool loggedIn)
      : super(['Labour', 'Transport', 'Supplies', 'Fertilizer', 'Loan', 'Misc']) {
    if (loggedIn) _load();
  }
  Future<void> _load() async {
    final cats = await _svc.fetchCategories();
    if (cats.isNotEmpty) state = cats;
  }
  Future<void> add(String cat) async {
    if (state.contains(cat)) return;
    final updated = List<String>.from(state)..add(cat);
    state = updated;
    await _svc.saveCategories(updated);
  }
  Future<void> remove(String cat) async {
    final updated = state.where((c) => c != cat).toList();
    state = updated;
    await _svc.saveCategories(updated);
  }
}

// ── ACTIONS ───────────────────────────────────────────────────────────────────
final firebaseActionsProvider =
Provider<FirebaseDataActions>((ref) => FirebaseDataActions(ref.read(_svcProvider)));

class FirebaseDataActions {
  final FirebaseService _svc;
  FirebaseDataActions(this._svc);

  String newId(String prefix) => '$prefix${_uuid.v4().substring(0, 8)}';

  Future<void> addFarm(Farm f)          => _svc.addFarm(f);
  Future<void> updateFarm(Farm f)       => _svc.updateFarm(f);
  Future<void> deleteFarm(String id)    => _svc.deleteFarm(id);
  Future<void> addMandi(Mandi m)        => _svc.addMandi(m);
  Future<void> updateMandi(Mandi m)     => _svc.updateMandi(m);
  Future<void> deleteMandi(String id)   => _svc.deleteMandi(id);
  Future<void> addCrop(Crop c)          => _svc.addCrop(c);
  Future<void> updateCrop(Crop c)       => _svc.updateCrop(c);
  Future<void> deleteCrop(String id)    => _svc.deleteCrop(id);
  Future<void> addSale(Sale s)          => _svc.addSale(s);
  Future<void> updateSale(Sale s)       => _svc.updateSale(s);
  Future<void> deleteSale(String id)    => _svc.deleteSale(id);
  Future<void> addExpense(Expense e)    => _svc.addExpense(e);
  Future<void> updateExpense(Expense e) => _svc.updateExpense(e);
  Future<void> deleteExpense(String id) => _svc.deleteExpense(id);

  List<Sale> filteredSales(List<Sale> all, DateRange range, DateTime date,
      {String farmId = '', String mandiId = '', String cropId = ''}) {
    return all.where((s) {
      if (!_matchDate(s.date, range, date)) return false;
      if (farmId.isNotEmpty  && s.farmId  != farmId)  return false;
      if (mandiId.isNotEmpty && s.mandiId != mandiId) return false;
      if (cropId.isNotEmpty  && s.cropId  != cropId)  return false;
      return true;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Expense> filteredExpenses(List<Expense> all, DateRange range, DateTime date,
      {String farmId = '', String mandiId = '', String cropId = '', String cat = ''}) {
    return all.where((e) {
      if (!_matchDate(e.date, range, date)) return false;
      if (farmId.isNotEmpty  && e.farmId  != farmId)  return false;
      if (mandiId.isNotEmpty && e.mandiId != mandiId) return false;
      if (cropId.isNotEmpty  && e.cropId  != cropId)  return false;
      if (cat.isNotEmpty     && e.cat     != cat)     return false;
      return true;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  static bool _matchDate(String date, DateRange range, DateTime active) {
    if (range == DateRange.all) return true;
    try {
      final d = DateTime.parse(date);
      if (range == DateRange.day) {
        return d.year == active.year && d.month == active.month && d.day == active.day;
      }
      return d.year == active.year && d.month == active.month;
    } catch (_) { return false; }
  }
}

// ── RELEASE-SAFE TYPED EXTRACTORS ─────────────────────────────────────────────
// .valueOrNull on AsyncValue<List<Farm>> erases to List<dynamic> in dart2js.
// .when() with explicit typed empty lists preserves the concrete generic type.
// These MUST be top-level functions, not nested lambdas.

List<Farm> _xFarms(AsyncValue<List<Farm>> v) =>
    v.when(data: (d) => d, loading: () => <Farm>[], error: (_, __) => <Farm>[]);

List<Mandi> _xMandis(AsyncValue<List<Mandi>> v) =>
    v.when(data: (d) => d, loading: () => <Mandi>[], error: (_, __) => <Mandi>[]);

List<Crop> _xCrops(AsyncValue<List<Crop>> v) =>
    v.when(data: (d) => d, loading: () => <Crop>[], error: (_, __) => <Crop>[]);

List<Sale> _xSales(AsyncValue<List<Sale>> v) =>
    v.when(data: (d) => d, loading: () => <Sale>[], error: (_, __) => <Sale>[]);

List<Expense> _xExpenses(AsyncValue<List<Expense>> v) =>
    v.when(data: (d) => d, loading: () => <Expense>[], error: (_, __) => <Expense>[]);

// ── COMPAT SHIM ───────────────────────────────────────────────────────────────
// Public class name (no underscore) so screens can reference it without a cast.

final appDataProvider = Provider<AppDataCompat>((ref) {
  return AppDataCompat(
    _xFarms(ref.watch(farmsStreamProvider)),
    _xMandis(ref.watch(mandisStreamProvider)),
    _xCrops(ref.watch(cropsStreamProvider)),
    _xSales(ref.watch(salesStreamProvider)),
    _xExpenses(ref.watch(expensesStreamProvider)),
    ref.watch(categoriesProvider),
    ref.watch(firebaseActionsProvider),
  );
});

class AppDataCompat {
  final List<Farm>    farms;
  final List<Mandi>   mandis;
  final List<Crop>    crops;
  final List<Sale>    sales;
  final List<Expense> expenses;
  final List<String>  categories;
  final FirebaseDataActions _a;

  AppDataCompat(this.farms, this.mandis, this.crops,
      this.sales, this.expenses, this.categories, this._a);

  String newId(String p) => _a.newId(p);

  Future<void> addFarm(Farm f)          => _a.addFarm(f);
  Future<void> updateFarm(Farm f)       => _a.updateFarm(f);
  Future<void> deleteFarm(String id)    => _a.deleteFarm(id);
  Future<void> addMandi(Mandi m)        => _a.addMandi(m);
  Future<void> updateMandi(Mandi m)     => _a.updateMandi(m);
  Future<void> deleteMandi(String id)   => _a.deleteMandi(id);
  Future<void> addCrop(Crop c)          => _a.addCrop(c);
  Future<void> updateCrop(Crop c)       => _a.updateCrop(c);
  Future<void> deleteCrop(String id)    => _a.deleteCrop(id);
  Future<void> addSale(Sale s)          => _a.addSale(s);
  Future<void> updateSale(Sale s)       => _a.updateSale(s);
  Future<void> deleteSale(String id)    => _a.deleteSale(id);
  Future<void> addExpense(Expense e)    => _a.addExpense(e);
  Future<void> updateExpense(Expense e) => _a.updateExpense(e);
  Future<void> deleteExpense(String id) => _a.deleteExpense(id);

  List<Sale> filteredSales(DateRange range, DateTime date,
      {String farmId = '', String mandiId = '', String cropId = ''}) =>
      _a.filteredSales(sales, range, date,
          farmId: farmId, mandiId: mandiId, cropId: cropId);

  List<Expense> filteredExpenses(DateRange range, DateTime date,
      {String farmId = '', String mandiId = '', String cropId = '', String cat = ''}) =>
      _a.filteredExpenses(expenses, range, date,
          farmId: farmId, mandiId: mandiId, cropId: cropId, cat: cat);
}