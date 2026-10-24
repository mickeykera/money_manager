import '../core/constants/app_constants.dart';
import 'base_parser.dart';
import 'models/parse_result.dart';

class CbeParser extends BaseParser {
  @override
  String get institutionName => 'Commercial Bank of Ethiopia';

  @override
  String get defaultAccountId => 'acc_cbe';

  @override
  bool canParse(String message, String? sender) {
    if (sender != null) {
      final s = sender.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (s == 'cbe' || s == '127' || s == 'cbebirr') return true;
      if (s == 'dashen' || s == 'boa' || s == 'abyssinia' || s == 'telebirr' || s == 'mpesa' || s == 'safaricom' || s == '700') {
        return false;
      }
    }
    final lower = message.toLowerCase();
    return lower.contains('cbe') ||
        lower.contains('commercial bank of ethiopia') ||
        lower.contains('የኢትዮጵያ ንግድ ባንክ');
  }

  @override
  ParseResult parse(String message, String? sender) {
    final filterResult = checkCommonFilters(message);
    if (filterResult != null) return filterResult;

    final lower = message.toLowerCase();

    // Pure balance alert without transaction
    if ((lower.contains('balance is') || lower.contains('current balance') || lower.contains('ቀሪ ሂሳብ')) &&
        !lower.contains('debited') &&
        !lower.contains('credited') &&
        !lower.contains('ወጪ') &&
        !lower.contains('ገቢ') &&
        !lower.contains('transferred') &&
        !lower.contains('withdrawn')) {
      final bal = extractBalance(message);
      return ParseResult(
        status: ParseStatus.rejectedNonFinancial,
        institution: institutionName,
        balanceSantims: bal,
        failureReason: 'Pure balance notification without transaction charge',
        rawMessage: message,
      );
    }

    final type = detectType(message);
    final isCredit = type == AppConstants.typeIncome;

    // Pattern 1: English "debited/credited with ETB 1,234.56"
    // e.g. "debited with ETB 350.00 on 24/10/2026 for Purchase at Fresh Corner."
    final enRegex = RegExp(
      r'(?:debited|credited|transferred)\s+with\s+(?:ETB|Birr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    // Pattern 2: Amharic "በብር 450.00 ወጪ ተደርጓል" or "በብር 450.00 ገቢ ሆኗል"
    final amRegex = RegExp(
      r'(?:በብር|ብር)\s*([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:ወጪ|ገቢ|ተቀማጭ)',
      caseSensitive: false,
    );

    // Pattern 3: "transfer of ETB 500.00"
    final transferRegex = RegExp(
      r'transfer\s+of\s+(?:ETB|Birr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    String? amountStr;
    var match = enRegex.firstMatch(message) ??
        transferRegex.firstMatch(message) ??
        amRegex.firstMatch(message);

    if (match != null && match.groupCount >= 1) {
      amountStr = match.group(1);
    }

    if (amountStr == null) {
      return ParseResult.failure(
        institution: institutionName,
        rawMessage: message,
        reason: 'Could not extract transaction amount from CBE message',
        status: ParseStatus.pendingReview,
      );
    }

    final amountSantims = parseAmountToSantims(amountStr);
    if (amountSantims <= 0) {
      return ParseResult.failure(
        institution: institutionName,
        rawMessage: message,
        reason: 'Extracted zero or invalid amount',
        status: ParseStatus.error,
      );
    }

    // Extract Merchant / Beneficiary / Purpose
    String merchant = 'Commercial Bank of Ethiopia';
    if (message.contains('ATM Cash Withdrawal')) {
      merchant = 'ATM Cash Withdrawal';
    } else {
      final merchantMatch = RegExp(
        r"(?:for|to|from|at)\s+([A-Za-z0-9\s&'\-\.]+?)(?:\s+on|\.\s*Current|\.\s*Balance|\.\s*Ref|$)",
        caseSensitive: false,
      ).firstMatch(message);

      if (merchantMatch != null && merchantMatch.groupCount >= 1) {
        var m = merchantMatch.group(1)?.trim();
        if (m != null && m.isNotEmpty && !m.toLowerCase().startsWith('account')) {
          // Strip noise prefixes
          m = m.replaceFirst(RegExp(r'^(?:Purchase|Payment)\s+(?:at|to|for)\s+', caseSensitive: false), '');
          merchant = m.trim();
        }
      } else if (isCredit) {
        merchant = 'CBE Credit / Deposit';
      }
    }

    final reference = extractReference(message);
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
      confidenceScore: 0.95,
      rawMessage: message,
    );
  }
}
