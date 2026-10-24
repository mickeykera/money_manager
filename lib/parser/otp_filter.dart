class OtpFilter {
  static final List<RegExp> _otpPatterns = [
    RegExp(r'\b(?:otp|one-time\s+password|passcode)\b', caseSensitive: false),
    RegExp(r'\b(?:verification|verification\s+code|security\s+code)\b', caseSensitive: false),
    RegExp(r'\b(?:do\s+not\s+share|never\s+share\s+this)\b', caseSensitive: false),
    RegExp(r'\b(?:password\s+reset|confirm\s+your\s+login)\b', caseSensitive: false),
    RegExp(r'ሚስጥራዊ\s*ቁጥር', caseSensitive: false), // Amharic secret number / PIN
    RegExp(r'ይህንን\s*ቁጥር\s*ለማንም\s*አያጋሩ', caseSensitive: false), // Amharic: Do not share with anyone
  ];

  static final List<RegExp> _failedTxnPatterns = [
    RegExp(r'\b(?:transaction\s+failed|payment\s+declined|insufficient\s+funds|declined\s+due\s+to)\b', caseSensitive: false),
    RegExp(r'አልተሳካም', caseSensitive: false), // Amharic: Failed
    RegExp(r'በቂ\s*ቀሪ\s*ገንዘብ\s*የለም', caseSensitive: false), // Amharic: Insufficient balance
  ];

  /// Returns true if the message is an OTP / Security verification message
  static bool isOtp(String message) {
    for (final pattern in _otpPatterns) {
      if (pattern.hasMatch(message)) {
        return true;
      }
    }
    return false;
  }

  /// Returns true if message describes a failed or declined transaction
  static bool isFailedTransaction(String message) {
    for (final pattern in _failedTxnPatterns) {
      if (pattern.hasMatch(message)) {
        return true;
      }
    }
    return false;
  }
}
