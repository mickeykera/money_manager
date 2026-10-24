import 'package:intl/intl.dart';

class TelecomBundleModel {
  final String id;
  final String provider; // 'Ethio telecom', 'Safaricom Ethiopia'
  final String bundleName; // e.g. "Monthly 10GB Data", "Weekly 5GB Combo"
  final String category; // 'data', 'voice', 'sms', 'combo', 'night_data', 'social', 'unlimited'
  final double originalAllowance; // e.g. 10.0 (in standard unit)
  final double remainingAllowance; // e.g. 7.20
  final String unit; // 'GB', 'MB', 'minutes', 'SMS'
  final DateTime? activationTime;
  final DateTime? expiryTime;
  final int? purchasePriceSantims; // in minor units
  final String? linkedTransactionId; // Links to transactions ledger if purchased
  final String? sourceMessage;
  final String? sourceFingerprint;
  final DateTime lastConfirmedTime;
  final double confidenceScore;
  final String status; // 'active', 'expired', 'exhausted', 'uncertain'

  const TelecomBundleModel({
    required this.id,
    required this.provider,
    required this.bundleName,
    required this.category,
    required this.originalAllowance,
    required this.remainingAllowance,
    required this.unit,
    this.activationTime,
    this.expiryTime,
    this.purchasePriceSantims,
    this.linkedTransactionId,
    this.sourceMessage,
    this.sourceFingerprint,
    required this.lastConfirmedTime,
    this.confidenceScore = 1.0,
    this.status = 'active',
  });

  bool get isExpired {
    if (status == 'expired' || status == 'exhausted') return true;
    if (expiryTime != null && DateTime.now().isAfter(expiryTime!)) return true;
    if (remainingAllowance <= 0.001) return true;
    return false;
  }

  bool get isExhausted => status == 'exhausted' || remainingAllowance <= 0.001;

  double get percentageRemaining {
    if (originalAllowance <= 0) return 0.0;
    return (remainingAllowance / originalAllowance).clamp(0.0, 1.0);
  }

  double get consumedAllowance {
    if (originalAllowance <= 0) return 0.0;
    return (originalAllowance - remainingAllowance).clamp(0.0, originalAllowance);
  }

  String get formattedRemaining {
    if (unit == 'GB' || unit == 'MB') {
      return '${remainingAllowance.toStringAsFixed(remainingAllowance.truncateToDouble() == remainingAllowance ? 0 : 2)} $unit';
    } else if (unit == 'minutes') {
      return '${remainingAllowance.toInt()} mins';
    } else {
      return '${remainingAllowance.toInt()} SMS';
    }
  }

  String get formattedAllowance {
    if (unit == 'GB' || unit == 'MB') {
      return '${originalAllowance.toStringAsFixed(originalAllowance.truncateToDouble() == originalAllowance ? 0 : 2)} $unit';
    } else if (unit == 'minutes') {
      return '${originalAllowance.toInt()} mins';
    } else {
      return '${originalAllowance.toInt()} SMS';
    }
  }

  String get expiryFormatted {
    if (expiryTime == null) return 'No expiry date';
    final now = DateTime.now();
    final diff = expiryTime!.difference(now);
    if (diff.isNegative) return 'Expired';

    if (diff.inDays > 1) {
      return 'Expires in ${diff.inDays} days (${DateFormat('MMM d').format(expiryTime!)})';
    } else if (diff.inHours > 0) {
      return 'Expires in ${diff.inHours} hrs';
    } else {
      return 'Expires in ${diff.inMinutes} mins';
    }
  }

  TelecomBundleModel copyWith({
    String? id,
    String? provider,
    String? bundleName,
    String? category,
    double? originalAllowance,
    double? remainingAllowance,
    String? unit,
    DateTime? activationTime,
    DateTime? expiryTime,
    int? purchasePriceSantims,
    String? linkedTransactionId,
    String? sourceMessage,
    String? sourceFingerprint,
    DateTime? lastConfirmedTime,
    double? confidenceScore,
    String? status,
  }) {
    return TelecomBundleModel(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      bundleName: bundleName ?? this.bundleName,
      category: category ?? this.category,
      originalAllowance: originalAllowance ?? this.originalAllowance,
      remainingAllowance: remainingAllowance ?? this.remainingAllowance,
      unit: unit ?? this.unit,
      activationTime: activationTime ?? this.activationTime,
      expiryTime: expiryTime ?? this.expiryTime,
      purchasePriceSantims: purchasePriceSantims ?? this.purchasePriceSantims,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      sourceMessage: sourceMessage ?? this.sourceMessage,
      sourceFingerprint: sourceFingerprint ?? this.sourceFingerprint,
      lastConfirmedTime: lastConfirmedTime ?? this.lastConfirmedTime,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'provider': provider,
      'bundle_name': bundleName,
      'category': category,
      'original_allowance': originalAllowance,
      'remaining_allowance': remainingAllowance,
      'unit': unit,
      'activation_time': activationTime?.millisecondsSinceEpoch,
      'expiry_time': expiryTime?.millisecondsSinceEpoch,
      'purchase_price_santims': purchasePriceSantims,
      'linked_transaction_id': linkedTransactionId,
      'source_message': sourceMessage,
      'source_fingerprint': sourceFingerprint,
      'last_confirmed_time': lastConfirmedTime.millisecondsSinceEpoch,
      'confidence_score': confidenceScore,
      'status': status,
    };
  }

  factory TelecomBundleModel.fromMap(Map<String, dynamic> map) {
    return TelecomBundleModel(
      id: map['id'] as String,
      provider: map['provider'] as String,
      bundleName: map['bundle_name'] as String,
      category: map['category'] as String,
      originalAllowance: (map['original_allowance'] as num).toDouble(),
      remainingAllowance: (map['remaining_allowance'] as num).toDouble(),
      unit: map['unit'] as String,
      activationTime: map['activation_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['activation_time'] as int)
          : null,
      expiryTime: map['expiry_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expiry_time'] as int)
          : null,
      purchasePriceSantims: map['purchase_price_santims'] as int?,
      linkedTransactionId: map['linked_transaction_id'] as String?,
      sourceMessage: map['source_message'] as String?,
      sourceFingerprint: map['source_fingerprint'] as String?,
      lastConfirmedTime: DateTime.fromMillisecondsSinceEpoch(map['last_confirmed_time'] as int),
      confidenceScore: (map['confidence_score'] as num?)?.toDouble() ?? 1.0,
      status: map['status'] as String? ?? 'active',
    );
  }
}

class BundleObservationModel {
  final String id;
  final String bundleId;
  final DateTime timestamp;
  final double remainingAllowance;
  final String unit;
  final double? estimatedUsageSincePrevious;
  final String sourceMessage;

  const BundleObservationModel({
    required this.id,
    required this.bundleId,
    required this.timestamp,
    required this.remainingAllowance,
    required this.unit,
    this.estimatedUsageSincePrevious,
    required this.sourceMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bundle_id': bundleId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'remaining_allowance': remainingAllowance,
      'unit': unit,
      'estimated_usage': estimatedUsageSincePrevious,
      'source_message': sourceMessage,
    };
  }

  factory BundleObservationModel.fromMap(Map<String, dynamic> map) {
    return BundleObservationModel(
      id: map['id'] as String,
      bundleId: map['bundle_id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      remainingAllowance: (map['remaining_allowance'] as num).toDouble(),
      unit: map['unit'] as String,
      estimatedUsageSincePrevious: (map['estimated_usage'] as num?)?.toDouble(),
      sourceMessage: map['source_message'] as String,
    );
  }
}

class TelecomSummary {
  final double ethioDataRemainingGb;
  final double safaricomDataRemainingGb;
  final int totalVoiceMinutesRemaining;
  final int totalSmsRemaining;
  final DateTime? nextKnownExpiry;
  final List<TelecomBundleModel> activeBundles;

  const TelecomSummary({
    this.ethioDataRemainingGb = 0.0,
    this.safaricomDataRemainingGb = 0.0,
    this.totalVoiceMinutesRemaining = 0,
    this.totalSmsRemaining = 0,
    this.nextKnownExpiry,
    this.activeBundles = const [],
  });

  double get totalDataRemainingGb => ethioDataRemainingGb + safaricomDataRemainingGb;
  bool get hasActiveBundles => activeBundles.isNotEmpty;

  static const empty = TelecomSummary(
    ethioDataRemainingGb: 0.0,
    safaricomDataRemainingGb: 0.0,
    totalVoiceMinutesRemaining: 0,
    totalSmsRemaining: 0,
    activeBundles: [],
  );
}
