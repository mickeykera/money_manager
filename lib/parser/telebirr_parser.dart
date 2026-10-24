import '../core/constants/app_constants.dart';
import 'base_parser.dart';
import 'models/parse_result.dart';

class TelebirrParser extends BaseParser {
  @override
  String get institutionName => 'Telebirr';

  @override
  String get defaultAccountId => 'acc_telebirr';

  @override
  bool canParse(String message, String? sender) {
    if (sender != null) {
      final s = sender.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (s == 'telebirr' || s == '127' || s == 'ethiotel' || s == 'ethiotelecom') return true;
    }
    final lower = message.toLowerCase();
    return lower.contains('telebirr') ||
        lower.contains('ቴሌብር') ||
        message.contains('TB2') ||
        (lower.contains('you have paid etb') && lower.contains('transaction number'));
  }

  @override
  ParseResult parse(String message, String? sender) {
    final filterResult = checkCommonFilters(message);
    if (filterResult != null) return filterResult;

    final type = detectType(message);

    // Amount extraction:
    // "You have paid ETB 250.00" / "transferred ETB 500.00" / "received ETB 1,200.00" / "withdrawn ETB 1,000.00" / "bought ETB 50.00"
    final enRegex = RegExp(
      r'(?:paid|transferred|received|withdrawn|bought|recharged)\s+(?:ETB|Birr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    // Amharic: "ብር 250.00 ከፍለዋል" or "ብር 250.00 ተቀብለዋል" or "ለ ... ብር 250.00"
    final amRegex = RegExp(
      r'ብር\s*([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:ከፍለዋል|ተቀብለዋል|አስተላልፈዋል|አውጥተዋል)',
      caseSensitive: false,
    );

    String? amountStr;
    var match = enRegex.firstMatch(message) ?? amRegex.firstMatch(message);

    if (match != null && match.groupCount >= 1) {
      amountStr = match.group(1);
    } else {
      // Fallback: look for ETB followed by decimal number
      final fallback = RegExp(r'ETB\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false).firstMatch(message);
      if (fallback != null) {
        amountStr = fallback.group(1);
      }
    }

    if (amountStr == null) {
      return ParseResult.failure(
        institution: institutionName,
        rawMessage: message,
        reason: 'Could not extract transaction amount from Telebirr message',
        status: ParseStatus.pendingReview,
      );
    }

    final amountSantims = parseAmountToSantims(amountStr);

    // Merchant / Beneficiary extraction
    String merchant = 'Telebirr';
    if (message.toLowerCase().contains('airtime')) {
      merchant = 'Ethio Telecom Airtime';
    } else {
      final merchantMatch = RegExp(
        r"(?:to|from|for)\s+([A-Za-z0-9\s&'\-\.]+?)(?:\s*\([0-9\*\+a-zA-Z]+\)|\s+on\s+[0-9]{4}|\.\s*Transaction|\.\s*Trans|$)",
        caseSensitive: false,
      ).firstMatch(message);

      if (merchantMatch != null && merchantMatch.groupCount >= 1) {
        final m = merchantMatch.group(1)?.trim();
        if (m != null && m.isNotEmpty) {
          merchant = m;
        }
      } else if (message.toLowerCase().contains('withdrawn')) {
        merchant = 'Telebirr Cash Out';
      }
    }

    final reference = extractReference(
      message,
      RegExp(r'(?:Transaction\s*(?:number|No\.?)|Trans\s*No\.?|የግብይት\s*ቁጥር)[\s:is]*([A-Za-z0-9\.\-_]+)', caseSensitive: false),
    );

    final balance = extractBalance(message);

    return ParseResult(
      status: ParseStatus.success,
      institution: institutionName,
      transactionType: type,
      amountSantims: amountSantims,
      currency: AppConstants.defaultCurrency,
      merchant: merchant,
      reference: reference,
      balanceSantims: balance,
      confidenceScore: 0.98,
      rawMessage: message,
    );
  }
}
