import 'package:flutter/foundation.dart';

// ── FARM ─────────────────────────────────────────────────────────────────────
@immutable
class Farm {
  final String id;
  final String name;
  final String type;
  final String area;
  final String address;

  const Farm({
    required this.id,
    required this.name,
    this.type = 'Vegetable',
    this.area = '',
    this.address = '',
  });

  Farm copyWith({String? id, String? name, String? type, String? area, String? address}) =>
      Farm(id: id ?? this.id, name: name ?? this.name, type: type ?? this.type,
          area: area ?? this.area, address: address ?? this.address);

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'type': type, 'area': area, 'address': address};

  factory Farm.fromJson(Map<String, dynamic> j) => Farm(
    id: j['id'] as String, name: j['name'] as String,
    type: j['type'] as String? ?? 'Vegetable',
    area: j['area'] as String? ?? '',
    address: j['address'] as String? ?? '',
  );
}

// ── MANDI ────────────────────────────────────────────────────────────────────
@immutable
class Mandi {
  final String id;
  final String farmId;
  final String name;
  final String location;

  const Mandi({required this.id, required this.farmId, required this.name, this.location = ''});

  Mandi copyWith({String? id, String? farmId, String? name, String? location}) =>
      Mandi(id: id ?? this.id, farmId: farmId ?? this.farmId,
          name: name ?? this.name, location: location ?? this.location);

  Map<String, dynamic> toJson() =>
      {'id': id, 'farmId': farmId, 'name': name, 'location': location};

  factory Mandi.fromJson(Map<String, dynamic> j) => Mandi(
    id: j['id'] as String, farmId: j['farmId'] as String,
    name: j['name'] as String, location: j['location'] as String? ?? '',
  );
}

// ── CROP ─────────────────────────────────────────────────────────────────────
@immutable
class Crop {
  final String id;
  final String farmId;
  final String name;
  final String start;
  final String end;
  final String cleanup;

  const Crop({required this.id, required this.farmId, required this.name, this.start = '', this.end = '', this.cleanup = ''});

  Crop copyWith({String? id, String? farmId, String? name, String? start, String? end, String? cleanup}) =>
      Crop(id: id ?? this.id, farmId: farmId ?? this.farmId,
          name: name ?? this.name, start: start ?? this.start, end: end ?? this.end,
          cleanup: cleanup ?? this.cleanup);

  Map<String, dynamic> toJson() =>
      {'id': id, 'farmId': farmId, 'name': name, 'start': start, 'end': end, 'cleanup': cleanup};

  factory Crop.fromJson(Map<String, dynamic> j) => Crop(
    id: j['id'] as String, farmId: j['farmId'] as String,
    name: j['name'] as String,
    start: j['start'] as String? ?? '',
    end: j['end'] as String? ?? '',
    cleanup: j['cleanup'] as String? ?? '',
  );
}

// ── BREAKDOWN ITEM ────────────────────────────────────────────────────────────
@immutable
class BreakdownItem {
  final int qty;
  final double rate;
  final double sub;
  final String quality;
  const BreakdownItem({required this.qty, required this.rate, required this.sub, this.quality = ''});

  Map<String, dynamic> toJson() => {'qty': qty, 'rate': rate, 'sub': sub, 'quality': quality};
  factory BreakdownItem.fromJson(Map<String, dynamic> j) => BreakdownItem(
    qty: (j['qty'] as num).toInt(),
    rate: (j['rate'] as num).toDouble(),
    sub: (j['sub'] as num).toDouble(),
    quality: j['quality'] as String? ?? '',
  );
}

// ── SALE ─────────────────────────────────────────────────────────────────────
@immutable
class Sale {
  final String id;
  final String date;
  final String buyer;
  final double qty;
  final double rate;
  final double amount;
  final double deduction;
  final String deductDesc;
  final String farmId;
  final String mandiId;
  final String cropId;
  final String payMode;
  final List<BreakdownItem> breakdown;

  const Sale({
    required this.id, required this.date, required this.buyer,
    required this.qty, required this.rate, required this.amount,
    this.deduction = 0, this.deductDesc = '', required this.farmId,
    required this.mandiId, required this.cropId, this.payMode = 'Cash',
    this.breakdown = const [],
  });

  Sale copyWith({
    String? id, String? date, String? buyer, double? qty, double? rate,
    double? amount, double? deduction, String? deductDesc, String? farmId,
    String? mandiId, String? cropId, String? payMode, List<BreakdownItem>? breakdown,
  }) => Sale(
    id: id ?? this.id, date: date ?? this.date, buyer: buyer ?? this.buyer,
    qty: qty ?? this.qty, rate: rate ?? this.rate, amount: amount ?? this.amount,
    deduction: deduction ?? this.deduction, deductDesc: deductDesc ?? this.deductDesc,
    farmId: farmId ?? this.farmId, mandiId: mandiId ?? this.mandiId,
    cropId: cropId ?? this.cropId, payMode: payMode ?? this.payMode,
    breakdown: breakdown ?? this.breakdown,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date, 'buyer': buyer, 'qty': qty, 'rate': rate,
    'amount': amount, 'deduction': deduction, 'deductDesc': deductDesc,
    'farmId': farmId, 'mandiId': mandiId, 'cropId': cropId, 'payMode': payMode,
    'breakdown': breakdown.map((b) => b.toJson()).toList(),
  };

  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
    id: j['id'].toString(), date: j['date'] as String,
    buyer: j['buyer'] as String? ?? '',
    qty: (j['qty'] as num?)?.toDouble() ?? 0,
    rate: (j['rate'] as num?)?.toDouble() ?? 0,
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    deduction: (j['deduction'] as num?)?.toDouble() ?? 0,
    deductDesc: j['deductDesc'] as String? ?? '',
    farmId: j['farmId'] as String? ?? '',
    mandiId: j['mandiId'] as String? ?? '',
    cropId: j['cropId'] as String? ?? '',
    payMode: j['payMode'] as String? ?? 'Cash',
    breakdown: (j['breakdown'] as List<dynamic>? ?? [])
        .map((b) => BreakdownItem.fromJson(b as Map<String, dynamic>))
        .toList(),
  );
}

// ── EXPENSE ───────────────────────────────────────────────────────────────────
@immutable
class Expense {
  final String id;
  final String date;
  final String desc;
  final String cat;
  final double amount;
  final String farmId;
  final String mandiId;
  final String cropId;
  final String payMode;

  const Expense({
    required this.id, required this.date, required this.desc,
    required this.cat, required this.amount, required this.farmId,
    required this.mandiId, required this.cropId, this.payMode = 'Cash',
  });

  Expense copyWith({
    String? id, String? date, String? desc, String? cat, double? amount,
    String? farmId, String? mandiId, String? cropId, String? payMode,
  }) => Expense(
    id: id ?? this.id, date: date ?? this.date, desc: desc ?? this.desc,
    cat: cat ?? this.cat, amount: amount ?? this.amount,
    farmId: farmId ?? this.farmId, mandiId: mandiId ?? this.mandiId,
    cropId: cropId ?? this.cropId, payMode: payMode ?? this.payMode,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date, 'desc': desc, 'cat': cat, 'amount': amount,
    'farmId': farmId, 'mandiId': mandiId, 'cropId': cropId, 'payMode': payMode,
  };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'].toString(), date: j['date'] as String,
    desc: j['desc'] as String? ?? '',
    cat: j['cat'] as String? ?? 'Misc',
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    farmId: j['farmId'] as String? ?? '',
    mandiId: j['mandiId'] as String? ?? '',
    cropId: j['cropId'] as String? ?? '',
    payMode: j['payMode'] as String? ?? 'Cash',
  );
}