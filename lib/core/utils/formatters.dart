import 'package:intl/intl.dart';

class Fmt {
  // Devise CDF avec séparateurs
  static String currency(num amount, {String symbol = 'CDF', int decimals = 0}) {
    final fmt = NumberFormat.currency(
      locale: 'fr_CD',
      symbol: '$symbol ',
      decimalDigits: decimals,
    );
    return fmt.format(amount);
  }

  // Montant compact (ex: 1.2M, 500K)
  static String compact(num amount) {
    if (amount.abs() >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount.abs() >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  // Date courte
  static String date(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('dd/MM/yyyy', 'fr').format(date);
  }

  // Date + heure
  static String datetime(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('dd/MM/yyyy HH:mm', 'fr').format(date);
  }

  // Pourcentage avec signe
  static String percent(num value, {int decimals = 1}) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(decimals)}%';
  }

  // Variation (flèche + couleur via bool)
  static String variation(num current, num previous) {
    if (previous == 0) return '—';
    final pct = ((current - previous) / previous.abs()) * 100;
    return percent(pct);
  }

  // Mois en français
  static String monthYear(DateTime date) =>
      DateFormat('MMMM yyyy', 'fr').format(date);
}
