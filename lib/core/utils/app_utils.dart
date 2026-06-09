import 'package:intl/intl.dart';
import '../../data/models/models.dart';

class AppUtils {
  static final _inrFormatter  = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _numFormatter  = NumberFormat('#,##,###', 'en_IN');
  static final _dateFormatter = DateFormat('dd MMM yyyy');
  static final _monthFormatter = DateFormat('MMMM yyyy');

  static String formatCurrency(num amount) => _inrFormatter.format(amount);
  static String formatNumber(num n)        => _numFormatter.format(n);

  static String formatDate(String isoDate) {
    if (isoDate.isEmpty) return '—';
    try { return _dateFormatter.format(DateTime.parse(isoDate)); }
    catch (_) { return isoDate; }
  }

  static String formatMonth(DateTime dt) => _monthFormatter.format(dt);

  static String cropStatusLabel(String start, String end) {
    if (start.isEmpty) return 'upcoming';
    final now = DateTime.now();
    final s   = DateTime.tryParse(start);
    final e   = end.isNotEmpty ? DateTime.tryParse(end) : null;
    if (s == null)             return 'upcoming';
    if (now.isBefore(s))       return 'upcoming';
    if (e != null && now.isAfter(e)) return 'done';
    return 'active';
  }

  // ── Release-safe lookup helpers ───────────────────────────────────────────
  // firstWhere+orElse with model constructors causes type-cast crashes in
  // dart2js release builds (generic type minification). Plain for-loops safe.

  static String farmName(List<Farm> farms, String id) {
    if (id.isEmpty) return '—';
    for (final f in farms) { if (f.id == id) return f.name; }
    return '—';
  }

  static String mandiName(List<Mandi> mandis, String id) {
    if (id.isEmpty) return '—';
    for (final m in mandis) { if (m.id == id) return m.name; }
    return '—';
  }

  static String cropName(List<Crop> crops, String id) {
    if (id.isEmpty) return '—';
    for (final c in crops) { if (c.id == id) return c.name; }
    return '—';
  }
}
