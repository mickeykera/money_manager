import '../core/constants/app_constants.dart';
import '../core/utils/money.dart';
import 'models/parse_result.dart';
import 'otp_filter.dart';

abstract class BaseParser {
  String get institutionName;
  String get defaultAccountId;

  /// Checks if this parser can handle the message given sender and content
  bool canParse(String message, String? sender);

  /// Executes parsing on the message
  ParseResult parse(String message, String? sender);

  /// Helper to check common security filters
  ParseResult? checkCommonFilters(String message) {
    if (OtpFilter.isOtp(message)) {
      return ParseResult.failure(
        institution: institutionName,
        rawMessage: message,
        reason: 'Message contains OTP or security verification passcode',
        status: ParseStatus.rejectedOtp,
      );
    }

    if (OtpFilter.isFailedTransaction(message)) {
      return ParseResult.failure(
        institution: institutionName,
        rawMessage: message,
        reason: 'Transaction was declined, failed, or had insufficient funds',
        status: ParseStatus.rejectedFailedTxn,
      );
    }

    return null;
  }

  /// Extracts numeric amount from string match safely into minor units
  int parseAmountToSantims(String amountStr) {
    return Money.parseString(amountStr).santims.abs();
  }

  /// Extracts standard reference code (e.g. "FT24...", "TB26...", "Ref: ...")
  String? extractReference(String message, [RegExp? customRegex]) {
    final regex =
        customRegex ??
        RegExp(
          r'(?:Ref|Txn\s*Ref|Txn\s*ID|Transaction\s*(?:number|No\.?)|የግብይት\s*ቁጥር)[\s:]*([A-Za-z0-9\.\-_]+)',
          caseSensitive: false,
        );
    final match = regex.firstMatch(message);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)?.replaceAll(RegExp(r'[\.\s]+$'), '');
    }
    return null;
  }

  /// Extracts available balance if mentioned
  int? extractBalance(String message, [RegExp? customRegex]) {
    final regex =
        customRegex ??
        RegExp(
          r'(?:current\s+balance|available\s+bal(?:ance)?|remaining\s+bal(?:ance)?|'
          r'new\s+m-?pesa\s+balance|bal(?:ance)?|ቀሪ\s*ሂሳብ(?:ዎ)?)'
          r'[\s:.\-]*(?:is|was|of|ብር|etb|birr)?[\s:.\-]*'
          r'(?:etb|birr|ብር)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
          caseSensitive: false,
        );
    final match = regex.firstMatch(message);
    if (match != null && match.groupCount >= 1) {
      final balStr = match.group(1);
      if (balStr != null) {
        return Money.parseString(balStr).santims;
      }
    }

    // Some banks put the account number between the label and the amount, e.g.
    // "Current Balance for Account 1000****4821 is ETB 14,250.75". Fall back to
    // the first currency-marked amount after the label.
    final broad = RegExp(
      r'(?:current\s+balance|available\s+bal(?:ance)?|remaining\s+bal(?:ance)?|'
      r'new\s+m-?pesa\s+balance|bal(?:ance)?|ቀሪ\s*ሂሳብ(?:ዎ)?)'
      r'.{0,80}?(?:etb|birr|ብር)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );
    final broadMatch = broad.firstMatch(message);
    if (broadMatch != null && broadMatch.groupCount >= 1) {
      final balStr = broadMatch.group(1);
      if (balStr != null) {
        return Money.parseString(balStr).santims;
      }
    }
    return null;
  }

  /// Determines transaction type (expense vs income vs reversal)
  String detectType(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('reversed') ||
        lower.contains('reversal') ||
        lower.contains('ተመላሽ')) {
      return AppConstants.typeReversal;
    }
    if (lower.contains('refund') || lower.contains('refunded')) {
      return AppConstants.typeRefund;
    }
    if (lower.contains('credited') ||
        lower.contains('received') ||
        lower.contains('ተቀብለዋል') ||
        lower.contains('ገቢ')) {
      return AppConstants.typeIncome;
    }
    if (lower.contains('transferred') ||
        lower.contains('transfer to') ||
        lower.contains('አስተላልፈዋል')) {
      return AppConstants.typeTransfer;
    }
    return AppConstants.typeExpense;
  }
}
