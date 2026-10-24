import '../../core/constants/app_constants.dart';
import '../../core/utils/money.dart';

class TransactionModel {
  final String id;
  final int amountSantims; // Integer minor units (Santims for ETB)
  final String currency;
  final String type; // 'expense', 'income', 'transfer', 'refund', 'reversal'
  final String merchant;
  final DateTime timestamp;
  final int timezoneOffsetMinutes;
  final String categoryId;
  final String accountId;
  final String source; // 'sms', 'manual', 'csv'
  final String importStatus; // 'posted', 'pending_review', 'rejected'
  final String? sourceFingerprint;
  final String? originalMessage;
  final String? reference; // Bank transaction reference code
  final String? linkedTransactionId; // Links transfers or refunds
  final String? notes;
  final bool isReviewed;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionModel({
    required this.id,
    required this.amountSantims,
    this.currency = AppConstants.defaultCurrency,
    required this.type,
    required this.merchant,
    required this.timestamp,
    this.timezoneOffsetMinutes = 180, // UTC+3 for EAT
    required this.categoryId,
    required this.accountId,
    this.source = AppConstants.sourceManual,
    this.importStatus = AppConstants.statusPosted,
    this.sourceFingerprint,
    this.originalMessage,
    this.reference,
    this.linkedTransactionId,
    this.notes,
    this.isReviewed = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Money get money => Money(amountSantims, currency: currency);

  bool get isExpense => type == AppConstants.typeExpense;
  bool get isIncome => type == AppConstants.typeIncome;
  bool get isTransfer => type == AppConstants.typeTransfer;
  bool get isRefund => type == AppConstants.typeRefund;
  bool get isReversal => type == AppConstants.typeReversal;

  TransactionModel copyWith({
    String? id,
    int? amountSantims,
    String? currency,
    String? type,
    String? merchant,
    DateTime? timestamp,
    int? timezoneOffsetMinutes,
    String? categoryId,
    String? accountId,
    String? source,
    String? importStatus,
    String? sourceFingerprint,
    String? originalMessage,
    String? reference,
    String? linkedTransactionId,
    String? notes,
    bool? isReviewed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      amountSantims: amountSantims ?? this.amountSantims,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      merchant: merchant ?? this.merchant,
      timestamp: timestamp ?? this.timestamp,
      timezoneOffsetMinutes: timezoneOffsetMinutes ?? this.timezoneOffsetMinutes,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      source: source ?? this.source,
      importStatus: importStatus ?? this.importStatus,
      sourceFingerprint: sourceFingerprint ?? this.sourceFingerprint,
      originalMessage: originalMessage ?? this.originalMessage,
      reference: reference ?? this.reference,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      notes: notes ?? this.notes,
      isReviewed: isReviewed ?? this.isReviewed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount_santims': amountSantims,
      'currency': currency,
      'type': type,
      'merchant': merchant,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'timezone_offset_minutes': timezoneOffsetMinutes,
      'category_id': categoryId,
      'account_id': accountId,
      'source': source,
      'import_status': importStatus,
      'source_fingerprint': sourceFingerprint,
      'original_message': originalMessage,
      'reference': reference,
      'linked_transaction_id': linkedTransactionId,
      'notes': notes,
      'is_reviewed': isReviewed ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      amountSantims: map['amount_santims'] as int,
      currency: (map['currency'] as String?) ?? AppConstants.defaultCurrency,
      type: map['type'] as String,
      merchant: map['merchant'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      timezoneOffsetMinutes: (map['timezone_offset_minutes'] as int?) ?? 180,
      categoryId: map['category_id'] as String,
      accountId: map['account_id'] as String,
      source: (map['source'] as String?) ?? AppConstants.sourceManual,
      importStatus: (map['import_status'] as String?) ?? AppConstants.statusPosted,
      sourceFingerprint: map['source_fingerprint'] as String?,
      originalMessage: map['original_message'] as String?,
      reference: map['reference'] as String?,
      linkedTransactionId: map['linked_transaction_id'] as String?,
      notes: map['notes'] as String?,
      isReviewed: (map['is_reviewed'] as int? ?? 1) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
