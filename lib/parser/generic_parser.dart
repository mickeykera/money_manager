import '../core/constants/app_constants.dart';
import 'base_parser.dart';
import 'models/parse_result.dart';

class GenericBankParser extends BaseParser {
  @override
  String get institutionName => 'Generic Bank';

  @override
  String get defaultAccountId => 'acc_cbe';

  @override
  bool canParse(String message, String? sender) {
    final lower = message.toLowerCase();
    // Look for common banking keywords
    return lower.contains('debited') ||
        lower.contains('credited') ||
        lower.contains('paid') ||
        lower.contains('transferred') ||
        lower.contains('withdrawn') ||
        (lower.contains('account') && (lower.contains('balance') || lower.contains('etb')));
  }

  @override
  ParseResult parse(String message, String? sender) {
    final filterResult = checkCommonFilters(message);
    if (filterResult != null) return filterResult;

    final type = detectType(message);

    // Look for amount pattern
    final regex = RegExp(
      r'(?:debited|credited|paid|transferred|withdrawn|amount\s*of)\s*(?:with|by|of)?\s*(?:ETB|Birr|\$)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    final altRegex = RegExp(
      r'(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    String? amountStr;
    final match = regex.firstMatch(message) ?? altRegex.firstMatch(message);
    if (match != null && match.groupCount >= 1) {
      amountStr = match.group(1);
    }

    if (amountStr == null) {
      return ParseResult.failure(
        institution: institutionName,
        rawMessage: message,
        reason: 'Unrecognized message format; no clear transaction amount found',
        status: ParseStatus.rejectedNonFinancial,
      );
    }

    final amountSantims = parseAmountToSantims(amountStr);

    // Extract Merchant if available
    String merchant = 'Bank Transaction';
    final merchantMatch = RegExp(
      r"(?:to|for|at|from)\s+([A-Za-z0-9\s&'\-\.]+?)(?:\s+on|\.\s*Ref|\.\s*Bal|$)",
      caseSensitive: false,
    ).firstMatch(message);

    if (merchantMatch != null && merchantMatch.groupCount >= 1) {
      var m = merchantMatch.group(1)?.trim();
      if (m != null && m.isNotEmpty && !m.toLowerCase().startsWith('account')) {
        m = m.replaceFirst(RegExp(r'^(?:payment|purchase)\s+(?:to|at|for)\s+', caseSensitive: false), '');
        merchant = m.trim();
      }
    }

    final reference = extractReference(message);
    final balance = extractBalance(message);

    // Generic parsers assign lower confidence (0.75) and flag for review if no reference
    final confidence = reference != null ? 0.85 : 0.70;
    final status = confidence >= 0.80 ? ParseStatus.success : ParseStatus.pendingReview;

    return ParseResult(
      status: status,
      institution: sender ?? institutionName,
      transactionType: type,
      amountSantims: amountSantims,
      currency: AppConstants.defaultCurrency,
      merchant: merchant,
      reference: reference,
      balanceSantims: balance,
      confidenceScore: confidence,
      warnings: status == ParseStatus.pendingReview
          ? ['Generic transaction template matched; please review and confirm.']
          : [],
      rawMessage: message,
    );
  }
}
