import 'package:intl/intl.dart';

/// Handles monetary values in minor units (Santims for ETB).
/// 1 ETB = 100 Santims.
/// All arithmetic strictly avoids floating-point roundoff errors.
class Money {
  final int santims;
  final String currency;

  const Money(this.santims, {this.currency = 'ETB'});

  factory Money.fromMajor(num major, {String currency = 'ETB'}) {
    // Avoid double multiplication drift by parsing formatted 2-decimal string
    final fixed = major.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = int.parse(parts[0]);
    final cents = int.parse(parts[1]);
    final total = whole >= 0 ? (whole * 100 + cents) : (whole * 100 - cents);
    return Money(total, currency: currency);
  }

  /// Parses a decimal string (e.g. "1,234.50" or "500" or "-45.20") to Money.
  factory Money.parseString(String input, {String currency = 'ETB'}) {
    final sanitized = input.replaceAll(',', '').replaceAll(' ', '').trim();
    if (sanitized.isEmpty) return Money(0, currency: currency);

    final isNegative = sanitized.startsWith('-');
    final clean = isNegative ? sanitized.substring(1) : sanitized;

    if (!clean.contains('.')) {
      final whole = int.tryParse(clean) ?? 0;
      return Money(isNegative ? -whole * 100 : whole * 100, currency: currency);
    }

    final parts = clean.split('.');
    final whole = int.tryParse(parts[0]) ?? 0;
    var fractionStr = parts[1];
    if (fractionStr.length > 2) {
      fractionStr = fractionStr.substring(0, 2);
    } else if (fractionStr.length == 1) {
      fractionStr = '${fractionStr}0';
    } else if (fractionStr.isEmpty) {
      fractionStr = '00';
    }

    final fraction = int.tryParse(fractionStr) ?? 0;
    final total = whole * 100 + fraction;
    return Money(isNegative ? -total : total, currency: currency);
  }

  double get toMajorDouble => santims / 100.0;

  Money operator +(Money other) {
    assert(currency == other.currency, 'Cannot add different currencies');
    return Money(santims + other.santims, currency: currency);
  }

  Money operator -(Money other) {
    assert(currency == other.currency, 'Cannot subtract different currencies');
    return Money(santims - other.santims, currency: currency);
  }

  Money abs() => Money(santims.abs(), currency: currency);

  bool get isNegative => santims < 0;
  bool get isZero => santims == 0;
  bool get isPositive => santims > 0;

  /// Formats the amount as human-readable string with currency symbol.
  /// Example: "ETB 1,250.50" or "-ETB 45.00"
  String format({bool includeCurrency = true, bool compact = false}) {
    final absSantims = santims.abs();
    final whole = absSantims ~/ 100;
    final fraction = absSantims % 100;
    final fractionStr = fraction.toString().padLeft(2, '0');

    final wholeFormatted = NumberFormat('#,###').format(whole);
    final sign = santims < 0 ? '-' : '';

    if (includeCurrency) {
      return '$sign$currency $wholeFormatted.$fractionStr';
    }
    return '$sign$wholeFormatted.$fractionStr';
  }

  @override
  String toString() => format();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          runtimeType == other.runtimeType &&
          santims == other.santims &&
          currency == other.currency;

  @override
  int get hashCode => santims.hashCode ^ currency.hashCode;
}
