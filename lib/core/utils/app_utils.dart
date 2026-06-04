import 'package:intl/intl.dart';

class AppUtils {
  static final _inrFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final _numFormatter = NumberFormat('#,##,###', 'en_IN');
  static final _dateFormatter = DateFormat('dd MMM yyyy');
  static final _monthFormatter = DateFormat('MMMM yyyy');

  static String formatCurrency(num amount) => _inrFormatter.format(amount);
  static String formatNumber(num n) => _numFormatter.format(n);

  static String formatDate(String isoDate) {
    if (isoDate.isEmpty) return '—';
    try {
      return _dateFormatter.format(DateTime.parse(isoDate));
    } catch (_) {
      return isoDate;
    }
  }

  static String formatMonth(DateTime dt) => _monthFormatter.format(dt);

  static String cropStatusLabel(String start, String end) {
    if (start.isEmpty) return 'upcoming';
    final now = DateTime.now();
    final s = DateTime.tryParse(start);
    final e = end.isNotEmpty ? DateTime.tryParse(end) : null;
    if (s == null) return 'upcoming';
    if (now.isBefore(s)) return 'upcoming';
    if (e != null && now.isAfter(e)) return 'done';
    return 'active';
  }
}
