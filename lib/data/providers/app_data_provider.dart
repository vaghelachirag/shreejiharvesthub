import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../../core/constants/app_constants.dart';

final _uuid = Uuid();

// ── DATE FILTER STATE ─────────────────────────────────────────────────────────
enum DateRange { day, month, all }

class DateFilterState {
  final DateRange range;
  final DateTime activeDate;

  DateFilterState({
    this.range = DateRange.day,
    DateTime? activeDate,
  }) : activeDate = activeDate ?? DateTime.now();

  DateFilterState copyWith({DateRange? range, DateTime? activeDate}) =>
      DateFilterState(range: range ?? this.range, activeDate: activeDate ?? this.activeDate);
}

final dateFilterProvider = StateNotifierProvider<DateFilterNotifier, DateFilterState>((ref) {
  return DateFilterNotifier();
});

class DateFilterNotifier extends StateNotifier<DateFilterState> {
  DateFilterNotifier() : super(DateFilterState(activeDate: DateTime.now()));

  void setRange(DateRange range) => state = state.copyWith(range: range);
  void setDate(DateTime date) => state = state.copyWith(activeDate: date);
  void previousPeriod() {
    final d = state.activeDate;
    state = state.copyWith(
      activeDate: state.range == DateRange.day
          ? d.subtract(const Duration(days: 1))
          : DateTime(d.year, d.month - 1, 1),
    );
  }
  void nextPeriod() {
    final d = state.activeDate;
    state = state.copyWith(
      activeDate: state.range == DateRange.day
          ? d.add(const Duration(days: 1))
          : DateTime(d.year, d.month + 1, 1),
    );
  }
  void goToday() => state = state.copyWith(activeDate: DateTime.now());
}

// ── APP DATA STATE ────────────────────────────────────────────────────────────
class AppDataState {
  final List<Farm> farms;
  final List<Mandi> mandis;
  final List<Crop> crops;
  final List<Sale> sales;
  final List<Expense> expenses;
  final List<String> categories;

  const AppDataState({
    required this.farms, required this.mandis, required this.crops,
    required this.sales, required this.expenses, required this.categories,
  });

  AppDataState copyWith({
    List<Farm>? farms, List<Mandi>? mandis, List<Crop>? crops,
    List<Sale>? sales, List<Expense>? expenses, List<String>? categories,
  }) => AppDataState(
        farms: farms ?? this.farms, mandis: mandis ?? this.mandis,
        crops: crops ?? this.crops, sales: sales ?? this.sales,
        expenses: expenses ?? this.expenses, categories: categories ?? this.categories,
      );
}

class AppDataNotifier extends StateNotifier<AppDataState> {
  AppDataNotifier() : super(_seedData());

  // ── FARMS ──
  void addFarm(Farm farm) => state = state.copyWith(farms: [...state.farms, farm]);
  void updateFarm(Farm farm) => state = state.copyWith(
        farms: state.farms.map((f) => f.id == farm.id ? farm : f).toList());
  void deleteFarm(String id) {
    state = state.copyWith(
      farms: state.farms.where((f) => f.id != id).toList(),
      mandis: state.mandis.where((m) => m.farmId != id).toList(),
    );
  }

  // ── MANDIS ──
  void addMandi(Mandi mandi) => state = state.copyWith(mandis: [...state.mandis, mandi]);
  void updateMandi(Mandi mandi) => state = state.copyWith(
        mandis: state.mandis.map((m) => m.id == mandi.id ? mandi : m).toList());
  void deleteMandi(String id) =>
      state = state.copyWith(mandis: state.mandis.where((m) => m.id != id).toList());

  // ── CROPS ──
  void addCrop(Crop crop) => state = state.copyWith(crops: [...state.crops, crop]);
  void updateCrop(Crop crop) => state = state.copyWith(
        crops: state.crops.map((c) => c.id == crop.id ? crop : c).toList());
  void deleteCrop(String id) =>
      state = state.copyWith(crops: state.crops.where((c) => c.id != id).toList());

  // ── SALES ──
  void addSale(Sale sale) => state = state.copyWith(sales: [...state.sales, sale]);
  void updateSale(Sale sale) => state = state.copyWith(
        sales: state.sales.map((s) => s.id == sale.id ? sale : s).toList());
  void deleteSale(String id) =>
      state = state.copyWith(sales: state.sales.where((s) => s.id != id).toList());

  // ── EXPENSES ──
  void addExpense(Expense exp) => state = state.copyWith(expenses: [...state.expenses, exp]);
  void updateExpense(Expense exp) => state = state.copyWith(
        expenses: state.expenses.map((e) => e.id == exp.id ? exp : e).toList());
  void deleteExpense(String id) =>
      state = state.copyWith(expenses: state.expenses.where((e) => e.id != id).toList());

  // ── CATEGORIES ──
  void addCategory(String cat) {
    if (!state.categories.contains(cat)) {
      state = state.copyWith(categories: [...state.categories, cat]);
    }
  }
  void deleteCategory(String cat) =>
      state = state.copyWith(categories: state.categories.where((c) => c != cat).toList());

  // ── FILTER HELPER ──
  List<Sale> filteredSales(DateRange range, DateTime activeDate,
      {String farmId = '', String mandiId = '', String cropId = ''}) {
    return state.sales.where((s) {
      if (!_matchesDate(s.date, range, activeDate)) return false;
      if (farmId.isNotEmpty && s.farmId != farmId) return false;
      if (mandiId.isNotEmpty && s.mandiId != mandiId) return false;
      if (cropId.isNotEmpty && s.cropId != cropId) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Expense> filteredExpenses(DateRange range, DateTime activeDate,
      {String farmId = '', String mandiId = '', String cropId = '', String cat = ''}) {
    return state.expenses.where((e) {
      if (!_matchesDate(e.date, range, activeDate)) return false;
      if (farmId.isNotEmpty && e.farmId != farmId) return false;
      if (mandiId.isNotEmpty && e.mandiId != mandiId) return false;
      if (cropId.isNotEmpty && e.cropId != cropId) return false;
      if (cat.isNotEmpty && e.cat != cat) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static bool _matchesDate(String date, DateRange range, DateTime active) {
    if (range == DateRange.all) return true;
    try {
      final d = DateTime.parse(date);
      if (range == DateRange.day) {
        return d.year == active.year && d.month == active.month && d.day == active.day;
      } else {
        return d.year == active.year && d.month == active.month;
      }
    } catch (_) {
      return false;
    }
  }

  String newId(String prefix) => '$prefix${_uuid.v4().substring(0, 8)}';
}

final appDataProvider = StateNotifierProvider<AppDataNotifier, AppDataState>((ref) {
  return AppDataNotifier();
});

// ── SEED DATA (from HTML) ─────────────────────────────────────────────────────
AppDataState _seedData() => AppDataState(
      categories: List.from(AppConstants.defaultCategories),
      farms: const [
        Farm(id: 'f1', name: 'Jamalpur Farm', type: 'Vegetable', area: '3 acres', address: 'APMC, Jamalpur, Ahmedabad'),
        Farm(id: 'f2', name: 'Aslali Farm', type: 'Vegetable', area: '2.5 acres', address: 'Karnavati, Aslali'),
        Farm(id: 'f3', name: 'Mehsana Farm', type: 'Vegetable', area: '2 acres', address: 'Sabji Mandi, Mehsana'),
      ],
      mandis: const [
        Mandi(id: 'm1', farmId: '', name: 'APMC Jamalpur', location: 'Jamalpur, Ahmedabad'),
        Mandi(id: 'm2', farmId: '', name: 'Local Market', location: 'Jamalpur, Ahmedabad'),
        Mandi(id: 'm3', farmId: '', name: 'APMC Karnavati', location: 'Aslali, Ahmedabad'),
        Mandi(id: 'm4', farmId: '', name: 'Mehsana Mandi', location: 'Mehsana'),
      ],
      crops: const [
        Crop(id: 'c1', farmId: 'f1', name: 'Tomato', start: '2026-01-15', end: '2026-04-20'),
        Crop(id: 'c2', farmId: 'f1', name: 'Okra', start: '2026-03-01', end: '2026-06-15'),
        Crop(id: 'c3', farmId: 'f2', name: 'Cabbage', start: '2026-02-10', end: '2026-05-05'),
        Crop(id: 'c4', farmId: 'f3', name: 'Brinjal', start: '2026-02-20', end: '2026-05-30'),
      ],
      sales: const [
        Sale(id: '1', date: '2026-03-02', buyer: 'Maqbulbhai-67', qty: 800, rate: 11.5, amount: 9200, farmId: 'f1', mandiId: 'm1', cropId: 'c1', payMode: 'Cash'),
        Sale(id: '2', date: '2026-03-05', buyer: 'Maqbulbhai-67', qty: 2000, rate: 11, amount: 22000, farmId: 'f1', mandiId: 'm1', cropId: 'c1', payMode: 'Cash'),
        Sale(id: '3', date: '2026-03-06', buyer: 'Prakashbhai-91', qty: 2200, rate: 0, amount: 16440, farmId: 'f1', mandiId: 'm1', cropId: 'c1', payMode: 'Online'),
        Sale(id: '4', date: '2026-03-07', buyer: 'Arifbhai-72', qty: 2220, rate: 0, amount: 19980, farmId: 'f3', mandiId: 'm4', cropId: 'c4', payMode: 'Cash'),
        Sale(id: '5', date: '2026-03-07', buyer: 'Prakashbhai-91', qty: 200, rate: 0, amount: 18660, farmId: 'f1', mandiId: 'm1', cropId: 'c1', payMode: 'Other'),
        Sale(id: '6', date: '2026-03-09', buyer: 'Arifbhai-72', qty: 1560, rate: 8, amount: 12480, farmId: 'f3', mandiId: 'm4', cropId: 'c4', payMode: 'Online'),
        Sale(id: '7', date: '2026-03-13', buyer: 'Prakashbhai-33', qty: 2220, rate: 0, amount: 22080, farmId: 'f2', mandiId: 'm3', cropId: 'c3', payMode: 'Cash'),
        Sale(id: '8', date: '2026-03-14', buyer: 'Prakashbhai-33', qty: 1320, rate: 12, amount: 15840, farmId: 'f2', mandiId: 'm3', cropId: 'c3', payMode: 'Cash'),
        Sale(id: '9', date: '2026-03-17', buyer: 'Prakashbhai-91', qty: 1520, rate: 0, amount: 17400, farmId: 'f1', mandiId: 'm1', cropId: 'c2', payMode: 'Online'),
        Sale(id: '10', date: '2026-03-18', buyer: 'Prakashbhai-91', qty: 2300, rate: 0, amount: 23850, farmId: 'f1', mandiId: 'm2', cropId: 'c2', payMode: 'Other'),
        Sale(id: '11', date: '2026-03-19', buyer: 'Prakashbhai-33', qty: 2080, rate: 11, amount: 22880, farmId: 'f2', mandiId: 'm3', cropId: 'c3', payMode: 'Cash'),
        Sale(id: '12', date: '2026-03-23', buyer: 'Prakashbhai-91', qty: 1520, rate: 0, amount: 15700, farmId: 'f1', mandiId: 'm1', cropId: 'c2', payMode: 'Online'),
        Sale(id: '13', date: '2026-03-28', buyer: 'Prakashbhai-67', qty: 2340, rate: 0, amount: 23550, farmId: 'f1', mandiId: 'm1', cropId: 'c2', payMode: 'Cash'),
        Sale(id: '14', date: '2026-03-30', buyer: 'Prakashbhai-67', qty: 2000, rate: 0, amount: 18400, farmId: 'f1', mandiId: 'm2', cropId: 'c2', payMode: 'Cash'),
      ],
      expenses: const [
        Expense(id: 'e1', date: '2026-03-02', desc: 'Labour charges', cat: 'Labour', amount: 500, farmId: 'f1', mandiId: 'm1', cropId: 'c1', payMode: 'Cash'),
        Expense(id: 'e2', date: '2026-03-02', desc: 'Plastic bags + tea/coffee', cat: 'Supplies', amount: 1960, farmId: 'f1', mandiId: 'm1', cropId: 'c1', payMode: 'Cash'),
        Expense(id: 'e3', date: '2026-03-02', desc: 'Transport (tempo)', cat: 'Transport', amount: 2000, farmId: 'f1', mandiId: 'm1', cropId: 'c1', payMode: 'Online'),
        Expense(id: 'e4', date: '2026-03-05', desc: 'Labour charges', cat: 'Labour', amount: 1500, farmId: 'f1', mandiId: 'm2', cropId: 'c1', payMode: 'Cash'),
        Expense(id: 'e5', date: '2026-03-05', desc: 'Supplies (bags etc)', cat: 'Supplies', amount: 1060, farmId: 'f1', mandiId: 'm2', cropId: 'c1', payMode: 'Other'),
        Expense(id: 'e6', date: '2026-03-06', desc: 'Labour charges', cat: 'Labour', amount: 600, farmId: 'f1', mandiId: 'm1', cropId: 'c1', payMode: 'Online'),
        Expense(id: 'e7', date: '2026-03-07', desc: 'Labour + auto rent (Ramnagar)', cat: 'Labour', amount: 4520, farmId: 'f3', mandiId: 'm4', cropId: 'c4', payMode: 'Cash'),
        Expense(id: 'e8', date: '2026-03-07', desc: 'Transport (tempo)', cat: 'Transport', amount: 5000, farmId: 'f3', mandiId: 'm4', cropId: 'c4', payMode: 'Cash'),
        Expense(id: 'e9', date: '2026-03-08', desc: 'Labour + auto rent', cat: 'Labour', amount: 1610, farmId: 'f1', mandiId: 'm1', cropId: 'c1', payMode: 'Online'),
        Expense(id: 'e10', date: '2026-03-10', desc: 'Withdraw for Prasad', cat: 'Misc', amount: 5000, farmId: 'f1', mandiId: 'm1', cropId: 'c1', payMode: 'Other'),
        Expense(id: 'e11', date: '2026-03-13', desc: 'Labour + auto rent', cat: 'Labour', amount: 2960, farmId: 'f2', mandiId: 'm3', cropId: 'c3', payMode: 'Cash'),
        Expense(id: 'e12', date: '2026-03-14', desc: 'Supplies', cat: 'Supplies', amount: 2000, farmId: 'f2', mandiId: 'm3', cropId: 'c3', payMode: 'Online'),
        Expense(id: 'e13', date: '2026-03-16', desc: 'Payment — cement/bricks', cat: 'Misc', amount: 23000, farmId: 'f1', mandiId: 'm2', cropId: 'c2', payMode: 'Cash'),
        Expense(id: 'e14', date: '2026-03-16', desc: 'Payment — fertilizer/pesticides', cat: 'Fertilizer', amount: 24200, farmId: 'f1', mandiId: 'm2', cropId: 'c2', payMode: 'Cash'),
        Expense(id: 'e15', date: '2026-03-17', desc: 'Labour charges', cat: 'Labour', amount: 550, farmId: 'f1', mandiId: 'm1', cropId: 'c2', payMode: 'Online'),
        Expense(id: 'e16', date: '2026-03-19', desc: 'Labour charges', cat: 'Labour', amount: 1400, farmId: 'f2', mandiId: 'm3', cropId: 'c3', payMode: 'Cash'),
        Expense(id: 'e17', date: '2026-03-21', desc: 'Hose pipe and spray gun', cat: 'Supplies', amount: 3500, farmId: 'f1', mandiId: 'm1', cropId: 'c2', payMode: 'Cash'),
        Expense(id: 'e18', date: '2026-03-23', desc: 'Labour charges', cat: 'Labour', amount: 2200, farmId: 'f1', mandiId: 'm1', cropId: 'c2', payMode: 'Online'),
        Expense(id: 'e19', date: '2026-03-24', desc: 'CGTMSE collateral (greenhouse loan)', cat: 'Loan', amount: 27000, farmId: 'f1', mandiId: 'm1', cropId: 'c2', payMode: 'Cash'),
        Expense(id: 'e20', date: '2026-03-28', desc: 'Labour charges', cat: 'Labour', amount: 2200, farmId: 'f1', mandiId: 'm1', cropId: 'c2', payMode: 'Other'),
        Expense(id: 'e21', date: '2026-03-30', desc: 'Labour + supplies', cat: 'Labour', amount: 2550, farmId: 'f1', mandiId: 'm2', cropId: 'c2', payMode: 'Online'),
        Expense(id: 'e22', date: '2026-03-20', desc: 'Petrol — Tersanpara + Reliance', cat: 'Transport', amount: 710, farmId: 'f1', mandiId: 'm1', cropId: 'c2', payMode: 'Cash'),
      ],
    );
