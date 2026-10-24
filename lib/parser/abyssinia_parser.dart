import '../core/constants/app_constants.dart';
import 'base_parser.dart';
import 'models/parse_result.dart';

class AbyssiniaParser extends BaseParser {
  @override
  String get institutionName => 'Bank of Abyssinia';

  @override
  String get defaultAccountId => 'acc_boa';

  @override
  bool canParse(String message, String? sender) {
    if (sender != null) {
      final s = sender.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (s == 'abyssinia' || s == 'boa' || s == 'bankofabyssinia') return true;
    }
    final lower = message.toLowerCase();
    return lower.contains('abyssinia') ||
        lower.contains('አቢሲኒያ') ||
        lower.contains('boa') ||
        (lower.contains('debited by etb') && lower.contains('available bal'));
  }

  @override
  ParseResult parse(String message, String? sender) {
    final filterResult = checkCommonFilters(message);
    if (filterResult != null) return filterResult;

    final type = detectType(message);

    // Amount extraction:
    // "debited by ETB 820.50" / "credited by ETB 12,000.00" / "transfer of ETB 2,000.00" / "reversal of ETB 820.50"
    final regex = RegExp(
      r'(?:debited|credited)\s+by\s+(?:ETB|Birr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );
    final altRegex = RegExp(
      r'(?:transfer|reversal|refund)\s+of\s+(?:ETB|Birr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    String? amountStr;
    var match = regex.firstMatch(message) ?? altRegex.firstMatch(message);
    if (match != null && match.groupCount >= 1) {
      amountStr = match.group(1);
    }

    if (amountStr == null) {
      return ParseResult.failure(
        institution: institutionName,
        rawMessage: message,
        reason: 'Could not extract transaction amount from Bank of Abyssinia message',
        status: ParseStatus.pendingReview,
      );
    }

    final amountSantims = parseAmountToSantims(amountStr);

    // Extract Merchant / Beneficiary
    String merchant = 'Bank of Abyssinia';
    final merchantMatch = RegExp(
      r"(?:to|for|at)\s+([A-Za-z0-9\s&'\-\.]+?)(?:\s+successful|\s+on|\.\s*Txn|\.\s*Ref|$)",
      caseSensitive: false,
    ).firstMatch(message);

    if (merchantMatch != null && merchantMatch.groupCount >= 1) {
      final m = merchantMatch.group(1)?.trim();
      if (m != null && m.isNotEmpty && !m.toLowerCase().startsWith('account')) {
        merchant = m;
      }
    } else if (type == AppConstants.typeIncome) {
      merchant = 'BOA Credit / Deposit';
    }

    final reference = extractReference(
      message,
      RegExp(r'(?:Txn\s*Ref|Ref|Transaction\s*Ref)[\s:]*([A-Za-z0-9\.\-_]+)', caseSensitive: false),
    );

    final balance = extractBalance(
      message,
      RegExp(r'(?:Available\s*Bal(?:ance)?|Bal(?:ance)?)[\s:ETB]*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    );

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
