class AppConstants {
  static const String appName = 'LedgerLeaf';
  static const String defaultCurrency = 'ETB';
  static const String appGroupIdentifier = 'group.com.ledgerleaf.app';
  static const String databaseName = 'ledgerleaf.db';
  static const int databaseVersion = 1;

  // Transaction Types
  static const String typeExpense = 'expense';
  static const String typeIncome = 'income';
  static const String typeTransfer = 'transfer';
  static const String typeRefund = 'refund';
  static const String typeReversal = 'reversal';

  static const List<String> allTransactionTypes = [
    typeExpense,
    typeIncome,
    typeTransfer,
    typeRefund,
    typeReversal,
  ];

  // Sources
  static const String sourceSms = 'sms';
  static const String sourceManual = 'manual';
  static const String sourceCsv = 'csv';

  // Import Status
  static const String statusPosted = 'posted';
  static const String statusPendingReview = 'pending_review';
  static const String statusRejected = 'rejected';

  // Account Types
  static const String accountTypeBank = 'bank';
  static const String accountTypeMobileMoney = 'mobile_money';
  static const String accountTypeCash = 'cash';
  static const String accountTypeOther = 'other';

  // Settings Keys
  static const String keyCurrency = 'currency';
  static const String keyRetainOriginalSms = 'retain_original_sms';
  static const String keySmsRetentionDays = 'sms_retention_days';
  static const String keyPrivacyMode = 'privacy_mode';
  static const String keyOnboardingCompleted = 'onboarding_completed';
  static const String keyAutoCategorization = 'auto_categorization';
  static const String keyThemeMode = 'theme_mode'; // 'system', 'light', 'dark'
}
