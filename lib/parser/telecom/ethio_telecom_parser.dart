import '../../core/constants/app_constants.dart';
import 'telecom_parse_result.dart';
import 'telecom_text_utils.dart';

class EthioTelecomParser {
  /// Sender IDs used by Ethio telecom package alerts. `251994` is what Android
  /// usually stores for `+251994`; `0994` is the local form.
  static const Set<String> _ethioSenderIds = {
    '994',
    '0994',
    '251994',
    '00251994',
    'ethiotelecom',
    'ethiotel',
    'ethiotelecomet',
    'ethiotelecome',
  };

  /// Senders that belong to another provider/bank even if the text mentions a
  /// bundle. Keeps a CBE or M-PESA alert from being treated as telecom.
  static const Set<String> _otherProviderSenders = {
    'cbe',
    'cbebirr',
    'boa',
    'abyssinia',
    'bankofabyssinia',
    'dashen',
    'amole',
    'mpesa',
    'safaricom',
    'safaricomet',
    '700',
    '704',
    '777',
  };

  bool canParse(String message, String? sender) {
    final lower = message.toLowerCase();
    final hasTelecomKeyword = TelecomTextUtils.hasTelecomKeyword(message);

    if (sender != null) {
      final s = TelecomTextUtils.normalizeSender(sender);

      // Any message from 994 / 251994 is an Ethio telecom message, even when it
      // is written in Amharic or only says "you have recharged".
      if (_ethioSenderIds.contains(s)) return true;

      // 127 is shared by CBE and Telebirr. Only treat it as telecom when the
      // text clearly looks like an Ethio telecom package alert.
      if (s == '127') {
        return hasTelecomKeyword &&
            (lower.contains('ethio telecom') ||
                lower.contains('ethiotelecom') ||
                message.contains('ኢትዮ ቴሌኮም') ||
                message.contains('ፓኬጅ') ||
                lower.contains('package') ||
                lower.contains('bundle') ||
                lower.contains('gb') ||
                lower.contains('mb'));
      }

      if (_otherProviderSenders.contains(s)) return false;
    }

    final hasProvider =
        lower.contains('ethio telecom') ||
        lower.contains('ethiotelecom') ||
        lower.contains('ethio-telecom') ||
        message.contains('ኢትዮ ቴሌኮም') ||
        message.contains('ኢትዮቴሌኮም');

    return hasProvider && hasTelecomKeyword;
  }

  TelecomParseResult parse(String message, String? sender) {
    final isAmharic =
        message.contains('ውድ ደንበኛችን') ||
        message.contains('ፓኬጅ') ||
        message.contains('ኢትዮ ቴሌኮም');

    final isPurchase = TelecomTextUtils.isPurchase(message);
    final isBalanceUpdate = TelecomTextUtils.isBalanceUpdate(message);

    // Unlimited plans have no numeric allowance. They are defined by their
    // activation and expiry dates instead.
    if (TelecomTextUtils.isUnlimited(message)) {
      if (TelecomTextUtils.isExpiryNotice(message) && !isPurchase) {
        return TelecomParseResult.unrecognized(
          message,
          reason: 'Unlimited plan expiry notification, not a new package',
        );
      }
      return _parseUnlimited(
        message,
        isPurchase: isPurchase,
        isBalanceUpdate: isBalanceUpdate,
        isAmharic: isAmharic,
      );
    }

    // Extract every allowance form, preferring the value labelled "remaining".
    final dataRemaining = TelecomTextUtils.dataAllowance(
      message,
      remainingOnly: true,
    );
    final dataAny = TelecomTextUtils.dataAllowance(message);
    final voiceRemaining = TelecomTextUtils.voiceAllowance(
      message,
      remainingOnly: true,
    );
    final voiceAny = TelecomTextUtils.voiceAllowance(message);
    final smsRemaining = TelecomTextUtils.smsAllowance(
      message,
      remainingOnly: true,
    );
    final smsAny = TelecomTextUtils.smsAllowance(message);

    // For a purchase, prefer the bundle size that was bought rather than a
    // "remaining" figure in the same SMS.
    final purchaseData = TelecomTextUtils.dataAllowance(
      message,
      ignoreRemaining: true,
    );
    final purchaseVoice = TelecomTextUtils.voiceAllowance(
      message,
      ignoreRemaining: true,
    );
    final purchaseSms = TelecomTextUtils.smsAllowance(
      message,
      ignoreRemaining: true,
    );

    final balanceAllowance =
        dataRemaining ??
        voiceRemaining ??
        smsRemaining ??
        dataAny ??
        voiceAny ??
        smsAny;
    final purchaseAllowance = purchaseData ?? purchaseVoice ?? purchaseSms;

    final chosen = isPurchase
        ? (purchaseAllowance ?? balanceAllowance)
        : balanceAllowance;

    if (chosen == null || chosen.value <= 0.001) {
      return TelecomParseResult.unrecognized(
        message,
        reason: 'Could not extract telecom bundle allowance',
      );
    }

    // For a purchase, the original size is the purchased amount. If the same
    // SMS also reports what is left, keep that as the remaining allowance.
    var originalAllowance = chosen.value;
    var remainingAllowance = chosen.value;
    if (isPurchase) {
      final reportedRemaining = dataRemaining ?? voiceRemaining ?? smsRemaining;
      if (reportedRemaining != null && reportedRemaining.unit == chosen.unit) {
        remainingAllowance = reportedRemaining.value;
      }
    } else {
      originalAllowance = chosen.value;
      remainingAllowance = chosen.value;
    }

    final category = _categoryFor(message, chosen.unit);
    final unit = chosen.unit;

    final purchasePrice = isPurchase
        ? TelecomTextUtils.purchasePriceSantims(message)
        : null;
    final expiry = TelecomTextUtils.expiryTime(message);

    final bundleName = _bundleName(
      category: category,
      allowance: originalAllowance,
      unit: unit,
      message: message,
    );

    return TelecomParseResult(
      isRecognized: true,
      provider: AppConstants.providerEthioTelecom,
      bundleName: bundleName,
      category: category,
      isPurchase: isPurchase,
      isBalanceUpdate: isBalanceUpdate,
      originalAllowance: originalAllowance,
      remainingAllowance: remainingAllowance,
      unit: unit,
      purchasePriceSantims: purchasePrice,
      expiryTime: expiry,
      activationTime: TelecomTextUtils.activationTime(message) ?? DateTime.now(),
      confidenceScore: isAmharic ? 0.94 : 0.98,
      rawMessage: message,
    );
  }

  TelecomParseResult _parseUnlimited(
    String message, {
    required bool isPurchase,
    required bool isBalanceUpdate,
    required bool isAmharic,
  }) {
    final category = TelecomTextUtils.unlimitedCategory(message);
    final planName = TelecomTextUtils.unlimitedPlanName(message);
    final expiry = TelecomTextUtils.expiryTime(message);
    final activation = TelecomTextUtils.activationTime(message);

    return TelecomParseResult(
      isRecognized: true,
      provider: AppConstants.providerEthioTelecom,
      bundleName: planName ?? _defaultUnlimitedName(category, message),
      category: category,
      isPurchase: isPurchase,
      isBalanceUpdate: isBalanceUpdate,
      originalAllowance: 0,
      remainingAllowance: 0,
      unit: 'Unlimited',
      purchasePriceSantims: isPurchase
          ? TelecomTextUtils.purchasePriceSantims(message)
          : null,
      expiryTime: expiry,
      activationTime: activation,
      confidenceScore: isAmharic ? 0.93 : 0.97,
      rawMessage: message,
    );
  }

  String _defaultUnlimitedName(String category, String message) {
    if (category == AppConstants.bundleCategorySms) return 'Unlimited SMS';
    if (category == AppConstants.bundleCategoryVoice) return 'Unlimited Voice';
    final lower = message.toLowerCase();
    if (lower.contains('monthly') || message.contains('ወርሃዊ')) {
      return 'Monthly Unlimited Internet';
    }
    if (lower.contains('weekly') || message.contains('ሳምንታዊ')) {
      return 'Weekly Unlimited Internet';
    }
    return 'Unlimited Internet';
  }

  String _categoryFor(String message, String unit) {
    final lower = message.toLowerCase();
    if (lower.contains('night') || message.contains('የማታ')) {
      return AppConstants.bundleCategoryNightData;
    }
    if (lower.contains('combo') ||
        lower.contains('all-in-one') ||
        message.contains('ኮምቦ')) {
      return AppConstants.bundleCategoryCombo;
    }
    if (unit == 'minutes') return AppConstants.bundleCategoryVoice;
    if (unit == 'SMS') return AppConstants.bundleCategorySms;
    return AppConstants.bundleCategoryData;
  }

  String _bundleName({
    required String category,
    required double allowance,
    required String unit,
    required String message,
  }) {
    final lower = message.toLowerCase();
    final size = TelecomTextUtils.formatAllowance(allowance);

    if (category == AppConstants.bundleCategoryNightData) {
      return 'Night Data $size $unit';
    }
    if (category == AppConstants.bundleCategoryCombo) {
      return 'Combo Package ($size $unit)';
    }
    if (category == AppConstants.bundleCategoryVoice) {
      return '$size Mins Voice Bundle';
    }
    if (category == AppConstants.bundleCategorySms) {
      return '$size SMS Bundle';
    }
    if (lower.contains('monthly') || message.contains('ወርሃዊ')) {
      return 'Monthly $size $unit Data';
    }
    if (lower.contains('weekly') || message.contains('ሳምንታዊ')) {
      return 'Weekly $size $unit Data';
    }
    if (lower.contains('daily') || message.contains('ዕለታዊ')) {
      return 'Daily $size $unit Data';
    }
    return 'Ethio telecom $size $unit';
  }
}
