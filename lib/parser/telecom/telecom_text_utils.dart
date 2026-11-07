/// Shared helpers for Ethio telecom and Safaricom bundle messages.
///
/// Telecom SMS use many spellings for the same thing ("10GB", "10 GB",
/// "1,024MB", "145 Minutes", "valid until 24/11/2026"). Keeping the patterns in
/// one place means both providers behave consistently.
class TelecomAllowance {
  final double value;
  final String unit;

  const TelecomAllowance(this.value, this.unit);
}

class TelecomTextUtils {
  TelecomTextUtils._();

  /// Lower-cases a sender and strips spaces, dashes, `+` and brackets so
  /// `+251 994`, `251-994` and `251994` all become `251994`.
  static String normalizeSender(String sender) {
    return sender.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static double parseNumber(String raw) {
    return double.tryParse(raw.replaceAll(',', '')) ?? 0.0;
  }

  static String normalizeDataUnit(String raw) {
    final upper = raw.toUpperCase();
    if (upper.startsWith('G') || upper.contains('GIGA')) return 'GB';
    if (upper.startsWith('M') || upper.contains('MEGA')) return 'MB';
    return upper;
  }

  static String formatAllowance(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  /// Parses `2026-11-24 18:30:00`, `24/11/2026`, `24-11-2026` and similar.
  static DateTime? parseDate(String raw) {
    final cleaned = raw.trim();
    final iso = DateTime.tryParse(cleaned);
    if (iso != null) return iso;

    final datePart = cleaned.split(RegExp(r'[ T]')).first;
    final parts = datePart.split(RegExp(r'[-/]'));
    if (parts.length != 3) return null;

    final first = int.tryParse(parts[0]);
    final second = int.tryParse(parts[1]);
    final third = int.tryParse(parts[2]);
    if (first == null || second == null || third == null) return null;

    // yyyy-mm-dd vs dd/mm/yyyy.
    if (first > 31) return DateTime(first, second, third);
    return DateTime(third, second, first);
  }

  static final RegExp dataPattern = RegExp(
    r'([0-9][0-9,]*(?:\.[0-9]+)?)\s*'
    r'(GB|MB|G|M|GIGA(?:BYTES?)?|MEGA(?:BYTES?)?)\b',
    caseSensitive: false,
  );

  static final RegExp voicePattern = RegExp(
    r'([0-9][0-9,]*)\s*(?:Minutes?|Mins?|Min|ደቂቃ)',
    caseSensitive: false,
  );

  static final RegExp smsPattern = RegExp(
    r'([0-9][0-9,]*)\s*(?:SMS|Texts?|ጽሑፍ)',
    caseSensitive: false,
  );

  // The number closest to a "remaining/available/left" label is the balance,
  // not the original bundle size (e.g. "Total 10GB, remaining 7.2GB").
  static final RegExp remainingDataPattern = RegExp(
    r'(?:remaining|available|left|ቀሪ|የቀረ)[^0-9]{0,48}?'
    r'([0-9][0-9,]*(?:\.[0-9]+)?)\s*'
    r'(GB|MB|G|M|GIGA(?:BYTES?)?|MEGA(?:BYTES?)?)\b',
    caseSensitive: false,
  );

  static final RegExp remainingVoicePattern = RegExp(
    r'(?:remaining|available|left|ቀሪ|የቀረ)[^0-9]{0,48}?'
    r'([0-9][0-9,]*)\s*(?:Minutes?|Mins?|Min|ደቂቃ)',
    caseSensitive: false,
  );

  static final RegExp remainingSmsPattern = RegExp(
    r'(?:remaining|available|left|ቀሪ|የቀረ)[^0-9]{0,48}?'
    r'([0-9][0-9,]*)\s*(?:SMS|Texts?|ጽሑፍ)',
    caseSensitive: false,
  );

  static TelecomAllowance? dataAllowance(
    String message, {
    bool remainingOnly = false,
    bool ignoreRemaining = false,
  }) {
    final remaining = ignoreRemaining
        ? null
        : remainingDataPattern.firstMatch(message);
    final match =
        remaining ?? (remainingOnly ? null : dataPattern.firstMatch(message));
    if (match == null) return null;
    return TelecomAllowance(
      parseNumber(match.group(1)!),
      normalizeDataUnit(match.group(2)!),
    );
  }

  static TelecomAllowance? voiceAllowance(
    String message, {
    bool remainingOnly = false,
    bool ignoreRemaining = false,
  }) {
    final remaining = ignoreRemaining
        ? null
        : remainingVoicePattern.firstMatch(message);
    final match =
        remaining ?? (remainingOnly ? null : voicePattern.firstMatch(message));
    if (match == null) return null;
    return TelecomAllowance(parseNumber(match.group(1)!), 'minutes');
  }

  static TelecomAllowance? smsAllowance(
    String message, {
    bool remainingOnly = false,
    bool ignoreRemaining = false,
  }) {
    final remaining = ignoreRemaining
        ? null
        : remainingSmsPattern.firstMatch(message);
    final match =
        remaining ?? (remainingOnly ? null : smsPattern.firstMatch(message));
    if (match == null) return null;
    return TelecomAllowance(parseNumber(match.group(1)!), 'SMS');
  }

  static final RegExp purchasePattern = RegExp(
    r'\b(purchased|purchase|buy|bought|recharged|recharge|subscribed|'
    r'subscribe|renewed|renew|activated|activate|topped?\s*up|top\s*up)\b',
    caseSensitive: false,
  );

  static bool isPurchase(String message) {
    final lower = message.toLowerCase();
    return purchasePattern.hasMatch(lower) ||
        message.contains('ገዝተዋል') ||
        message.contains('ተሞልቷል') ||
        message.contains('አስገብተዋል') ||
        message.contains('ተመዝግቧል') ||
        message.contains('ተጨምሯል');
  }

  static bool isBalanceUpdate(String message) {
    final lower = message.toLowerCase();
    return lower.contains('remaining') ||
        lower.contains('balance') ||
        lower.contains('available') ||
        lower.contains('left') ||
        lower.contains('usage') ||
        lower.contains('used') ||
        lower.contains('valid until') ||
        lower.contains('valid till') ||
        lower.contains('expire') ||
        message.contains('ቀሪ') ||
        message.contains('የቀረ') ||
        message.contains('ጥቅም ላይ');
  }

  static bool hasTelecomKeyword(String message) {
    final lower = message.toLowerCase();
    return lower.contains('package') ||
        lower.contains('bundle') ||
        lower.contains('remaining') ||
        lower.contains('valid until') ||
        lower.contains('valid till') ||
        lower.contains('expire') ||
        lower.contains('data') ||
        lower.contains('internet') ||
        lower.contains('gb') ||
        lower.contains('mb') ||
        lower.contains('minutes') ||
        lower.contains('mins') ||
        lower.contains('sms') ||
        lower.contains('voice') ||
        lower.contains('airtime') ||
        lower.contains('purchased') ||
        lower.contains('purchase') ||
        lower.contains('recharged') ||
        lower.contains('recharge') ||
        lower.contains('subscribed') ||
        lower.contains('renewed') ||
        lower.contains('top up') ||
        lower.contains('topup') ||
        lower.contains('activated') ||
        message.contains('ፓኬጅ') ||
        message.contains('ቀሪ') ||
        message.contains('ገዝተዋል') ||
        message.contains('ተሞልቷል');
  }

  /// Extracts the purchase price from phrases such as "for ETB 300.00",
  /// "በብር 35.00", "ETB 100" or "100 Birr".
  static int? purchasePriceSantims(String message) {
    final explicit = RegExp(
      r'(?:for|at|with)\s+(?:ETB|Birr|ብር)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    final leading = RegExp(
      r'(?:ETB|Birr|ብር)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    final trailing = RegExp(
      r'([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(?:ETB|Birr|ብር)',
      caseSensitive: false,
    ).firstMatch(message);

    final match = explicit ?? leading ?? trailing;
    if (match == null) return null;
    final amount = parseNumber(match.group(1)!);
    if (amount <= 0) return null;
    return (amount * 100).round();
  }

  static final RegExp expiryPattern = RegExp(
    r'(?:valid\s*(?:until|till|up\s*to|for)|expires?\s*(?:on|at)?|እስከ|ድረስ)\s*'
    r'('
    r'[0-9]{4}[-/][0-9]{1,2}[-/][0-9]{1,2}'
    r'(?:[ T][0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?)?'
    r'|'
    r'[0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{4}'
    r'(?:[ T][0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?)?'
    r')',
    caseSensitive: false,
  );

  static DateTime? expiryTime(String message) {
    final match = expiryPattern.firstMatch(message);
    if (match == null) return null;
    return parseDate(match.group(1)!);
  }
}
