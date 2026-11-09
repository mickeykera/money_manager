import '../../core/constants/app_constants.dart';

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

  /// Parses `2026-11-24 18:30:00`, `24/11/2026`, `24-11-2026`,
  /// `Nov 15, 2026 6:09:08 PM` and `2026-10-16 at 17:00:12`.
  static DateTime? parseDate(String raw) {
    var cleaned = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+at\s+', caseSensitive: false), ' ');

    final iso = DateTime.tryParse(cleaned);
    if (iso != null) return iso;

    // Month-name dates: "Nov 15, 2026 6:09:08 PM".
    final monthName = RegExp(
      r'^([A-Za-z]{3,9})\s+([0-9]{1,2}),?\s+([0-9]{4})'
      r'(?:\s+([0-9]{1,2}):([0-9]{2})(?::([0-9]{2}))?\s*(AM|PM)?)?$',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (monthName != null) {
      final month = _monthNumber(monthName.group(1)!);
      if (month != null) {
        var hour = int.tryParse(monthName.group(4) ?? '0') ?? 0;
        final minute = int.tryParse(monthName.group(5) ?? '0') ?? 0;
        final second = int.tryParse(monthName.group(6) ?? '0') ?? 0;
        final suffix = monthName.group(7)?.toUpperCase();
        if (suffix == 'PM' && hour < 12) hour += 12;
        if (suffix == 'AM' && hour == 12) hour = 0;
        return DateTime(
          int.parse(monthName.group(3)!),
          month,
          int.parse(monthName.group(2)!),
          hour,
          minute,
          second,
        );
      }
    }

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

  static int? _monthNumber(String raw) {
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final key = raw.toLowerCase();
    if (key.length < 3) return null;
    return months[key.substring(0, 3)];
  }

  static final RegExp dataPattern = RegExp(
    r'([0-9][0-9,]*(?:\.[0-9]+)?)\s*'
    r'(GB|MB|G|M|GIGA(?:BYTES?)?|MEGA(?:BYTES?)?|ጊ\.ባ|ሜ\.ባ)\b',
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

  /// Only completed actions count as a purchase. Imperative marketing text
  /// ("Activate your 3GB bundle", "To purchase a new bundle dial *777#") must
  /// not be mistaken for a real purchase, otherwise promos create ledger rows.
  static final RegExp purchasePattern = RegExp(
    r'\b(purchased|bought|recharged|subscribed|renewed|activated|'
    r'topped\s*up)\b',
    caseSensitive: false,
  );

  static bool isPurchase(String message) {
    final lower = message.toLowerCase();
    return purchasePattern.hasMatch(lower) ||
        lower.contains('new service offer') ||
        lower.contains('is added to your service') ||
        lower.contains('has been added') ||
        message.contains('ገዝተዋል') ||
        message.contains('ተሞልቷል') ||
        message.contains('አስገብተዋል') ||
        message.contains('ተመዝግቧል') ||
        message.contains('ተጨምሯል');
  }

  /// Marketing/bundle-advertisement messages that are not purchases. These
  /// often contain a bundle size and a price, so without this guard they look
  /// like a purchase to the parser and create phantom bundles and expenses.
  static bool isPromotionalOffer(String message) {
    final lower = message.toLowerCase();

    // Wording that only appears in advertising, never in a receipt.
    final strongMarkers = <String>[
      'your squad is waiting',
      'pubg gaming bundle',
      'don’t miss out',
      "don't miss out",
      'exciting news',
      'customer service week',
      'one bundle-',
      'one bundle –',
      'call anyone',
      'package doubled',
      'doubled for new year',
      'select besh',
      'up to 2x data',
      'more value',
      'free 50mb',
    ];
    if (strongMarkers.any(lower.contains)) return true;

    // Amharic advertising language ("for free", "only", "will be returned").
    if (message.contains('በነጻ') ||
        message.contains('ብቻ') ||
        message.contains('ተመላሽ ይሆናል') ||
        message.contains('ያገኟቸዋል')) {
      return true;
    }

    final hasCallToAction = RegExp(
      r'\b(?:dial|dail)\s*\*|\b(?:dial|dail)\s+[0-9*]|\bto buy\b|\bbuy now\b',
      caseSensitive: false,
    ).hasMatch(lower);
    if (!hasCallToAction) return false;

    return lower.contains('for only') ||
        lower.contains('for just') ||
        lower.contains('at only') ||
        lower.contains('only ') ||
        lower.contains('just ') ||
        lower.contains('valid for') ||
        lower.contains('enjoy ');
  }

  /// Service/support notices that mention packages but do not activate one,
  /// such as fair-use-policy explanations and SIM self-service menus.
  static bool isInformationalNotice(String message) {
    final lower = message.toLowerCase();
    return lower.contains('fair user policy') ||
        lower.contains('no fup') ||
        lower.contains('have no fup') ||
        lower.contains('self-service') ||
        lower.contains('for language change') ||
        lower.contains('to get support') ||
        lower.contains('support regarding telebirr') ||
        lower.contains('thank you for contacting us') ||
        lower.contains('welcome to ethio telecom') ||
        lower.contains('sim lost') ||
        lower.contains('puk request') ||
        lower.contains('is suspended') ||
        lower.contains('is resumed');
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
  /// "በብር 35.00", "ETB 100", "100 Birr" or "for Br.60".
  static int? purchasePriceSantims(String message) {
    const currency = r'(?:ETB|Birr|Br\.?|ብር)';
    final explicit = RegExp(
      r'(?:for|at|with)\s+' + currency + r'\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    final leading = RegExp(
      currency + r'\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(message);
    final trailing = RegExp(
      r'([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*' + currency,
      caseSensitive: false,
    ).firstMatch(message);

    final match = explicit ?? leading ?? trailing;
    if (match == null) return null;
    final amount = parseNumber(match.group(1)!);
    if (amount <= 0) return null;
    return (amount * 100).round();
  }

  /// A single date token used by the expiry/activation patterns. Supports
  /// `2026-11-24`, `24/11/2026`, `Nov 15, 2026` and an optional time suffix
  /// (`18:30:00`, `6:09:08 PM`, `at 17:00:12`).
  static const String _dateToken =
      r'(?:'
      r'[0-9]{4}[-/][0-9]{1,2}[-/][0-9]{1,2}'
      r'|[0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{4}'
      r'|[A-Za-z]{3,9}\s+[0-9]{1,2},?\s+[0-9]{4}'
      r')'
      r'(?:\s+(?:at\s+)?[0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?\s*(?:AM|PM)?)?';

  static final RegExp expiryPattern = RegExp(
    r'(?:valid\s*(?:until|till|up\s*to)|expir(?:es|e|ed|y(?:\s*date)?)|'
    r'እስከ|ድረስ)'
    r'.{0,80}?'
    '($_dateToken)',
    caseSensitive: false,
  );

  static DateTime? expiryTime(String message) {
    final match = expiryPattern.firstMatch(message);
    if (match == null) return null;
    return parseDate(match.group(1)!);
  }

  static final RegExp activationPattern = RegExp(
    r'(?:effective\s+as\s+of|activated\s+(?:on|at)|activation\s*(?:date|time)?\s*:?|'
    r'valid\s+from)\s*'
    '($_dateToken)',
    caseSensitive: false,
  );

  static DateTime? activationTime(String message) {
    final match = activationPattern.firstMatch(message);
    if (match == null) return null;
    return parseDate(match.group(1)!);
  }

  /// Unlimited packages have no numeric allowance; they are valid until the
  /// expiry date instead.
  static bool isUnlimited(String message) {
    final lower = message.toLowerCase();
    return RegExp(r'\bunlimited\b|\binfinity\b', caseSensitive: false)
            .hasMatch(lower) ||
        message.contains('ያልተገደበ') ||
        message.contains('ያልተገደበው');
  }

  /// Category for an unlimited plan: SMS, voice, or general internet/data.
  ///
  /// The plan name wins over footer text. Ethio telecom activation SMS end with
  /// "please send an SMS to 8994", which used to make an unlimited *internet*
  /// plan look like an SMS plan.
  static String unlimitedCategory(String message) {
    final planName = unlimitedPlanName(message);
    if (planName != null) {
      final name = planName.toLowerCase();
      if (name.contains('sms') || name.contains('text')) {
        return AppConstants.bundleCategorySms;
      }
      if (name.contains('voice') ||
          name.contains('minute') ||
          name.contains('call')) {
        return AppConstants.bundleCategoryVoice;
      }
      if (name.contains('internet') ||
          name.contains('data') ||
          name.contains('wullo')) {
        return AppConstants.bundleCategoryUnlimited;
      }
    }

    final body = stripSupportFooter(message);
    final lower = body.toLowerCase();
    final mentionsSms = RegExp(r'\bsms\b|texts?\b', caseSensitive: false)
            .hasMatch(lower) ||
        body.contains('ኤስኤምኤስ') ||
        body.contains('ጽሑፍ');
    if (mentionsSms) return AppConstants.bundleCategorySms;

    final mentionsVoice = RegExp(
      r'\b(voice|minutes?|mins?|calls?)\b',
      caseSensitive: false,
    ).hasMatch(lower) ||
        body.contains('ደቂቃ') ||
        body.contains('ጥሪ');
    if (mentionsVoice) return AppConstants.bundleCategoryVoice;

    return AppConstants.bundleCategoryUnlimited;
  }

  static const List<String> _supportFooterMarkers = <String>[
    'send an sms to',
    'for more information',
    'for any additional information',
    'kindly share your experience',
    'thank you for using our service',
    'thank you, ethio telecom',
    'thank you! ethio telecom',
    'thank you ethio telecom',
    'have a nice time',
    'have a wonderful time',
    'we are always delighted',
    'happy new year',
    'happy holiday',
  ];

  /// Drops the support/marketing footer that telecom operators append to
  /// activation SMS. The footer mentions "SMS" and support numbers, which must
  /// not influence how the package itself is categorized.
  static String stripSupportFooter(String message) {
    final lower = message.toLowerCase();
    var cut = message.length;
    for (final marker in _supportFooterMarkers) {
      final index = lower.indexOf(marker);
      if (index >= 0 && index < cut) cut = index;
    }
    return message.substring(0, cut).trim();
  }

  /// Pulls a readable plan name out of activation/reminder messages such as
  /// "the new service offer Monthly Unlimited Premium Internet plan" or
  /// "successfully purchased Wullo Unlimited Internet for Br.60".
  static String? unlimitedPlanName(String message) {
    final patterns = <RegExp>[
      RegExp(
        r'(?:offer|plan)\s+([A-Za-z][A-Za-z0-9 ]*?Unlimited[A-Za-z0-9 ]*?)\s+plan\b',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:your\s+)?([A-Za-z][A-Za-z0-9 ]*?Unlimited[A-Za-z0-9 ]*?)\s+plan\b',
        caseSensitive: false,
      ),
      RegExp(
        r'purchased\s+([A-Za-z][A-Za-z0-9 ]*?Unlimited[A-Za-z0-9 ]*?)\s+for\b',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      final name = _cleanPlanName(match?.group(1) ?? '');
      if (name.isNotEmpty) return name;
    }
    return null;
  }

  static String _cleanPlanName(String raw) {
    var name = raw.trim();
    name = name.replaceFirst(
      RegExp(r'^(?:a|an|the)\s+', caseSensitive: false),
      '',
    );
    name = name.replaceFirst(
      RegExp(r'\s+(?:monthly|weekly|daily|plan)$', caseSensitive: false),
      '',
    );
    return name.trim();
  }

  /// Messages such as "Your Wullo Unlimited Internet has expired" are
  /// notifications, not new package activations.
  static bool isExpiryNotice(String message) {
    final lower = message.toLowerCase();
    return RegExp(
      r'\b(?:has|have|is|was)\s+(?:now\s+)?expired\b',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  /// Ethio telecom's service short code (994) also sends prepaid SIM notices:
  /// airtime recharges, bonus funds, free-airtime redemptions and subscriber
  /// airtime transfers. Their "balance" is the prepaid airtime balance, not the
  /// Telebirr wallet, so they must never create ledger entries or reconcile the
  /// mobile-money account.
  static const Set<String> ethioServiceSenderIds = {
    '994',
    '0994',
    '251994',
    '00251994',
  };

  static bool isPrepaidAirtimeNotice(String message, String? sender) {
    final lower = message.toLowerCase();

    // Airtime received from another subscriber is prepaid SIM credit, not
    // mobile-money. Telebirr sends these from the shared 127 short code, so the
    // sender alone cannot distinguish them from wallet movements.
    final isAirtimeReceipt =
        (lower.contains('received') && lower.contains('airtime')) ||
        lower.contains('airtime from') ||
        lower.contains('airtime transfer');
    if (isAirtimeReceipt) return true;

    if (sender == null) return false;
    final normalized = normalizeSender(sender);
    if (!ethioServiceSenderIds.contains(normalized)) return false;

    // A genuine Telebirr wallet movement is still financial even when it is
    // delivered from the service short code.
    final looksLikeTelebirrWallet =
        lower.contains('telebirr account') ||
        lower.contains('from your telebirr') ||
        lower.contains('your telebirr transaction') ||
        (lower.contains('transaction number') && lower.contains('telebirr'));
    if (looksLikeTelebirrWallet) return false;

    return lower.contains('prepaid') ||
        lower.contains('airtime') ||
        lower.contains('bonus fund') ||
        lower.contains('subscriber transferred') ||
        lower.contains('day deal') ||
        lower.contains('recharged balance') ||
        lower.contains('remaining amount from bonus');
  }
}
