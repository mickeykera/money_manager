import '../core/constants/app_constants.dart';
import 'base_parser.dart';
import 'models/parse_result.dart';

class MpesaParser extends BaseParser {
  @override
  String get institutionName => 'Safaricom M-PESA';

  @override
  String get defaultAccountId => 'acc_mpesa';

  @override
  bool canParse(String message, String? sender) {
    if (sender != null) {
      final s = sender.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (s == 'mpesa' || s == 'safaricom' || s == '700') return true;
    }
    final lower = message.toLowerCase();
    return (lower.contains('m-pesa') || lower.contains('mpesa') || lower.contains('safaricom')) &&
        (lower.contains('confirmed') || lower.contains('sent to') || lower.contains('received etb') || lower.contains('paid to'));
  }

  @override
  ParseResult parse(String message, String? sender) {
    final filterResult = checkCommonFilters(message);
    if (filterResult != null) return filterResult;

    final lower = message.toLowerCase();

    // Check if it's purely a balance inquiry without transaction (should not create expense!)
    if (lower.contains('balance is') && !lower.contains('sent to') && !lower.contains('paid to') && !lower.contains('bought') && !lower.contains('received')) {
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

    // Extract reference code at start: e.g. "TD94RNM67E Confirmed."
    String? reference;
    final refMatch = RegExp(r'^([A-Z0-9]{8,12})\s+Confirmed', caseSensitive: false).firstMatch(message);
    if (refMatch != null && refMatch.groupCount >= 1) {
      reference = refMatch.group(1);
    } else {
      reference = extractReference(message);
    }

    // Extract Amount: e.g. "ETB 450.00 sent to", "ETB 180.00 paid to", "received ETB 2,000.00", "bought ETB 50.00"
    final regex = RegExp(
      r'(?:ETB|Birr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:sent\s+to|paid\s+to|withdrawn|bought\s+(?:ETB|Birr)?)',
      caseSensitive: false,
    );
    final altRegex = RegExp(
      r'(?:received|transferred|bought|paid)\s+(?:ETB|Birr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );
    final fallbackRegex = RegExp(
      r'(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    String? amountStr;
    final match = regex.firstMatch(message) ?? altRegex.firstMatch(message) ?? fallbackRegex.firstMatch(message);
    if (match != null && match.groupCount >= 1) {
      amountStr = match.group(1);
    }

    if (amountStr == null) {
      return ParseResult.failure(
        institution: institutionName,
        rawMessage: message,
        reason: 'Could not extract transaction amount from Safaricom M-PESA message',
        status: ParseStatus.pendingReview,
      );
    }

    final amountSantims = parseAmountToSantims(amountStr);

    // Extract Merchant / Recipient
    String merchant = 'Safaricom M-PESA';
    if (lower.contains('airtime')) {
      merchant = 'Safaricom Airtime Top-up';
    } else {
      final merchantMatch = RegExp(
        r"(?:sent\s+to|paid\s+to|from)\s+([A-Za-z0-9\s&'\-\.]+?)(?:\s+07[0-9\*]+|\s+\(Till|\s+on\s+[0-9]|\.\s*Fee|$)",
        caseSensitive: false,
      ).firstMatch(message);

      if (merchantMatch != null && merchantMatch.groupCount >= 1) {
        final m = merchantMatch.group(1)?.trim();
        if (m != null && m.isNotEmpty) {
          merchant = m;
        }
      } else if (type == AppConstants.typeIncome) {
        merchant = 'M-PESA Received Funds';
      }
    }

    final balance = extractBalance(
      message,
      RegExp(r'(?:New\s*M-PESA\s*balance|balance)[\s:isETBBirr]*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
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
      confidenceScore: 0.96,
      rawMessage: message,
    );
  }
}
