import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

/// Central service — FirebaseAuth + Firestore.
/// Admin-created accounts only; no self-registration.
/// All data scoped under: users/{uid}/{collection}/{docId}
class FirebaseService {
  FirebaseService._();
  static final instance = FirebaseService._();

  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  // ── AUTH ──────────────────────────────────────────────────────────────────
  User?  get currentUser     => _auth.currentUser;
  String? get uid            => _auth.currentUser?.uid;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();

  // ── COLLECTION REFS ───────────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection('users').doc(uid).collection(name);

  DocumentReference<Map<String, dynamic>> _doc(String col, String id) =>
      _col(col).doc(id);

  // ── HELPER: safe Map<String,dynamic> merge ────────────────────────────────
  // Spread operator in release mode can produce Map<dynamic,dynamic>.
  // Explicitly cast to avoid the minified type-cast crash.
  static Map<String, dynamic> _merge(Map<String, dynamic> data, String id) {
    final result = <String, dynamic>{'id': id};
    result.addAll(data);
    return result;
  }

  // ── SETTINGS ──────────────────────────────────────────────────────────────
  Future<List<String>> fetchCategories() async {
    final snap = await _doc('settings', 'categories').get();
    if (!snap.exists) return [];
    return List<String>.from(snap.data()!['list'] as List? ?? []);
  }

  Future<void> saveCategories(List<String> cats) =>
      _doc('settings', 'categories').set({'list': cats});

  // ── FARMS ─────────────────────────────────────────────────────────────────
  Stream<List<Farm>> farmsStream() => _col('farms')
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs
          .map((d) => Farm.fromJson(_merge(d.data(), d.id)))
          .toList());

  Future<void> addFarm(Farm farm) =>
      _doc('farms', farm.id).set(farm.toJson()..remove('id'));

  Future<void> updateFarm(Farm farm) =>
      _doc('farms', farm.id).update(farm.toJson()..remove('id'));

  Future<void> deleteFarm(String id) async {
    final batch = _db.batch();
    batch.delete(_doc('farms', id));
    final mandis = await _col('mandis').where('farmId', isEqualTo: id).get();
    for (final d in mandis.docs) batch.delete(d.reference);
    await batch.commit();
  }

  // ── MANDIS ────────────────────────────────────────────────────────────────
  Stream<List<Mandi>> mandisStream() => _col('mandis')
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs
          .map((d) => Mandi.fromJson(_merge(d.data(), d.id)))
          .toList());

  Future<void> addMandi(Mandi mandi) =>
      _doc('mandis', mandi.id).set(mandi.toJson()..remove('id'));

  Future<void> updateMandi(Mandi mandi) =>
      _doc('mandis', mandi.id).update(mandi.toJson()..remove('id'));

  Future<void> deleteMandi(String id) => _doc('mandis', id).delete();

  // ── CROPS ─────────────────────────────────────────────────────────────────
  Stream<List<Crop>> cropsStream() => _col('crops')
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs
          .map((d) => Crop.fromJson(_merge(d.data(), d.id)))
          .toList());

  Future<void> addCrop(Crop crop) =>
      _doc('crops', crop.id).set(crop.toJson()..remove('id'));

  Future<void> updateCrop(Crop crop) =>
      _doc('crops', crop.id).update(crop.toJson()..remove('id'));

  Future<void> deleteCrop(String id) => _doc('crops', id).delete();

  // ── SALES ─────────────────────────────────────────────────────────────────
  Stream<List<Sale>> salesStream() => _col('sales')
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => Sale.fromJson(_merge(d.data(), d.id)))
          .toList());

  Future<void> addSale(Sale sale) =>
      _doc('sales', sale.id).set(sale.toJson()..remove('id'));

  Future<void> updateSale(Sale sale) =>
      _doc('sales', sale.id).update(sale.toJson()..remove('id'));

  Future<void> deleteSale(String id) => _doc('sales', id).delete();

  // ── EXPENSES ──────────────────────────────────────────────────────────────
  Stream<List<Expense>> expensesStream() => _col('expenses')
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => Expense.fromJson(_merge(d.data(), d.id)))
          .toList());

  Future<void> addExpense(Expense exp) =>
      _doc('expenses', exp.id).set(exp.toJson()..remove('id'));

  Future<void> updateExpense(Expense exp) =>
      _doc('expenses', exp.id).update(exp.toJson()..remove('id'));

  Future<void> deleteExpense(String id) => _doc('expenses', id).delete();
}
