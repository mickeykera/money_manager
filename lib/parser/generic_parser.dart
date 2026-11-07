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
    final hasCurrency =
        lower.contains('etb') ||
        lower.contains('birr') ||
        message.contains('ብር');
    final hasMoneyVerb = RegExp(
      r'\b(debited|credited|debit|credit|paid|payment|transferred|transfer|'
      r'withdrawn|withdrawal|deposit(?:ed)?|spent|charged|deducted|'
      r'purchased|bought|recharged|received)\b',
      caseSensitive: false,
    ).hasMatch(lower);
    final hasBankSignal =
        lower.contains('account') ||
        lower.contains('acct') ||
        lower.contains('bank') ||
        lower.contains('transaction') ||
        lower.contains('txn') ||
        lower.contains('balance') ||
        lower.contains('ref') ||
        message.contains('ሂሳብ') ||
        message.contains('ባንክ');

    // A plain "data balance is 7GB" message must not be mistaken for money.
    if (lower.contains('balance') && !hasCurrency && !hasMoneyVerb) {
      return false;
    }

    return hasMoneyVerb || (hasCurrency && hasBankSignal);
  }

  @override
  ParseResult parse(String message, String? sender) {
    final filterResult = checkCommonFilters(message);
    if (filterResult != null) return filterResult;

    final lower = message.toLowerCase();
    final type = detectType(message);
    final balance = extractBalance(message);

    final hasTransactionVerb = RegExp(
      r'\b(debited|credited|debit|credit|paid|payment|transferred|transfer|'
      r'withdrawn|withdrawal|deposit(?:ed)?|spent|charged|deducted|'
      r'purchased|bought|recharged|received)\b',
      caseSensitive: false,
    ).hasMatch(lower);

    // Pure balance alert: no transaction to record, but the reported balance is
    // still valuable for reconciling the account.
    if (!hasTransactionVerb) {
      if (balance != null) {
        return ParseResult(
          status: ParseStatus.rejectedNonFinancial,
          institution: sender ?? institutionName,
          balanceSantims: balance,
          failureReason: 'Pure balance notification without transaction charge',
          rawMessage: message,
        );
      }
      return ParseResult.failure(
        institution: sender ?? institutionName,
        rawMessage: message,
        reason: 'No transaction amount or balance found',
        status: ParseStatus.rejectedNonFinancial,
      );
    }

    // Search for the amount before the balance section so "Current Balance is
    // ETB 1,000" is never used as the transaction amount.
    final amountPart = _truncateAtBalance(message);
    String? amountStr = _findAmount(amountPart) ?? _findAmount(message);

    if (amountStr == null) {
      if (balance != null) {
        return ParseResult(
          status: ParseStatus.rejectedNonFinancial,
          institution: sender ?? institutionName,
          balanceSantims: balance,
          failureReason: 'Balance notification without a transaction amount',
          rawMessage: message,
        );
      }
      return ParseResult.failure(
        institution: sender ?? institutionName,
        rawMessage: message,
        reason:
            'Unrecognized message format; no clear transaction amount found',
        status: ParseStatus.rejectedNonFinancial,
      );
    }

    final amountSantims = parseAmountToSantims(amountStr);

    // Extract Merchant if available
    String merchant = 'Bank Transaction';
    final merchantMatch = RegExp(
      r"(?:to|for|at|from)\s+([A-Za-z0-9\s&'\-\.]+?)(?:\s+on|\.\s*Ref|\.\s*Bal|\.\s*Current|$)",
      caseSensitive: false,
    ).firstMatch(message);

    if (merchantMatch != null && merchantMatch.groupCount >= 1) {
      var m = merchantMatch.group(1)?.trim();
      if (m != null && m.isNotEmpty && !m.toLowerCase().startsWith('account')) {
        m = m.replaceFirst(
          RegExp(
            r'^(?:payment|purchase)\s+(?:to|at|for)\s+',
            caseSensitive: false,
          ),
          '',
        );
        merchant = m.trim();
      }
    }

    final reference = extractReference(message);

    // Generic parsers assign lower confidence (0.75) and flag for review if no reference
    final confidence = reference != null ? 0.85 : 0.70;
    final status = confidence >= 0.80
        ? ParseStatus.success
        : ParseStatus.pendingReview;

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

  String _truncateAtBalance(String message) {
    final lower = message.toLowerCase();
    var index = lower.indexOf('balance');
    if (index < 0) index = lower.indexOf('ቀሪ');
    if (index <= 0) return message;
    return message.substring(0, index);
  }

  String? _findAmount(String text) {
    final patterns = <RegExp>[
      RegExp(
        r'(?:debited|credited|paid|transferred|withdrawn|spent|charged|'
        r'deducted|deposited|received|purchased|bought|recharged|debit|credit)'
        r'\b[\s:.\-]*(?:with|by|of|for|from|to|amount|an\s+amount\s+of)?'
        r'[\s:.\-]*(?:ETB|Birr|ብር)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:ETB|Birr|ብር)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:ETB|Birr|ብር)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    }
    return null;
  }
}
