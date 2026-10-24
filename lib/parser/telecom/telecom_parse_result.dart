class TelecomParseResult {
  final bool isRecognized;
  final String provider; // 'Ethio telecom', 'Safaricom Ethiopia'
  final String bundleName;
  final String category; // 'data', 'voice', 'sms', 'combo', 'night_data', 'social', 'unlimited'
  final bool isPurchase; // True if message reports a new package purchase with price
  final bool isBalanceUpdate; // True if message reports remaining allowance
  final double originalAllowance;
  final double remainingAllowance;
  final String unit; // 'GB', 'MB', 'minutes', 'SMS'
  final int? purchasePriceSantims;
  final DateTime? expiryTime;
  final DateTime? activationTime;
  final double confidenceScore;
  final String? failureReason;
  final String rawMessage;

  const TelecomParseResult({
    required this.isRecognized,
    required this.provider,
    required this.bundleName,
    required this.category,
    this.isPurchase = false,
    this.isBalanceUpdate = false,
    this.originalAllowance = 0.0,
    this.remainingAllowance = 0.0,
    this.unit = 'GB',
    this.purchasePriceSantims,
    this.expiryTime,
    this.activationTime,
    this.confidenceScore = 1.0,
    this.failureReason,
    required this.rawMessage,
  });

  static TelecomParseResult unrecognized(String message, {String? reason}) {
    return TelecomParseResult(
      isRecognized: false,
      provider: 'Unknown',
      bundleName: '',
      category: 'data',
      failureReason: reason ?? 'Not a recognized telecom bundle message',
      rawMessage: message,
    );
  }
}
