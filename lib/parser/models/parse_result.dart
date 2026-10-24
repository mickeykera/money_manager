import '../../core/constants/app_constants.dart';
import '../../core/utils/money.dart';

enum ParseStatus {
  success,
  pendingReview,
  rejectedOtp,
  rejectedNonFinancial,
  rejectedFailedTxn,
  error,
}

class ParseResult {
  final ParseStatus status;
  final String institution;
  final String transactionType; // 'expense', 'income', 'transfer', 'refund', 'reversal'
  final int amountSantims;
  final String currency;
  final String merchant;
  final DateTime? transactionDate;
  final String? reference;
  final int? balanceSantims;
  final double confidenceScore; // 0.0 to 1.0
  final List<String> warnings;
  final String? failureReason;
  final String rawMessage;

  const ParseResult({
    required this.status,
    required this.institution,
    this.transactionType = AppConstants.typeExpense,
    this.amountSantims = 0,
    this.currency = AppConstants.defaultCurrency,
    this.merchant = '',
    this.transactionDate,
    this.reference,
    this.balanceSantims,
    this.confidenceScore = 0.0,
    this.warnings = const [],
    this.failureReason,
    required this.rawMessage,
  });

  Money get amount => Money(amountSantims, currency: currency);
  Money? get balance => balanceSantims != null ? Money(balanceSantims!, currency: currency) : null;

  bool get isSuccess => status == ParseStatus.success;
  bool get isPendingReview => status == ParseStatus.pendingReview;
  bool get isRejected =>
      status == ParseStatus.rejectedOtp ||
      status == ParseStatus.rejectedNonFinancial ||
      status == ParseStatus.rejectedFailedTxn ||
      status == ParseStatus.error;

  static ParseResult failure({
    required String institution,
    required String rawMessage,
    required String reason,
    ParseStatus status = ParseStatus.error,
  }) {
    return ParseResult(
      status: status,
      institution: institution,
      confidenceScore: 0.0,
      failureReason: reason,
      rawMessage: rawMessage,
    );
  }
}
