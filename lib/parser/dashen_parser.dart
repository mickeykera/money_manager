import '../core/constants/app_constants.dart';
import 'base_parser.dart';
import 'models/parse_result.dart';

class DashenParser extends BaseParser {
  @override
  String get institutionName => 'Dashen Bank';

  @override
  String get defaultAccountId => 'acc_cbe'; // Falls back to bank account if no dedicated Dashen account

  @override
  bool canParse(String message, String? sender) {
    if (sender != null) {
      final s = sender.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (s == 'dashen' || s == 'dashenbank' || s == 'amole') return true;
    }
    final lower = message.toLowerCase();
    return lower.contains('dashen') ||
        lower.contains('ዳሽን') ||
        lower.contains('amole') ||
        message.contains('DSH');
  }

  @override
  ParseResult parse(String message, String? sender) {
    final filterResult = checkCommonFilters(message);
    if (filterResult != null) return filterResult;

    final type = detectType(message);

    final regex = RegExp(
      r'(?:debited|credited|transferred)\s+(?:with|by)\s+(?:ETB|Birr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    String? amountStr;
    final match = regex.firstMatch(message);
    if (match != null && match.groupCount >= 1) {
      amountStr = match.group(1);
    }

    if (amountStr == null) {
      return ParseResult.failure(
        institution: institutionName,
        rawMessage: message,
        reason: 'Could not extract transaction amount from Dashen Bank message',
        status: ParseStatus.pendingReview,
      );
    }

    final amountSantims = parseAmountToSantims(amountStr);

    String merchant = 'Dashen Bank';
    final reasonMatch = RegExp(
      r"(?:Reason|Purpose|for|at)[\s:]+([A-Za-z0-9\s&'\-\.]+?)(?:\.\s*Avail|\.\s*Txn|\.\s*Ref|$)",
      caseSensitive: false,
    ).firstMatch(message);

    if (reasonMatch != null && reasonMatch.groupCount >= 1) {
      final r = reasonMatch.group(1)?.trim();
      if (r != null && r.isNotEmpty) {
        merchant = r;
      }
    }

    final reference = extractReference(
      message,
      RegExp(r'(?:Txn\s*ID|Txn\s*Ref|Ref)[\s:]*([A-Za-z0-9\.\-_]+)', caseSensitive: false),
    );

    final balance = extractBalance(
      message,
      RegExp(r'(?:Avail\s*Bal|Balance)[\s:ETB]*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
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
      confidenceScore: 0.94,
      rawMessage: message,
    );
  }
}
