import 'package:intl/intl.dart';

class Formatter {
  static String formatAmount(int amount) {
    final formatter = NumberFormat('#,##0');
    return formatter.format(amount);
  }
}
