import '../../core/constants/app_constants.dart';
import 'telecom_parse_result.dart';
import 'telecom_text_utils.dart';

class SafaricomTelecomParser {
  /// Safaricom Ethiopia data/voice short codes. 700 is also the M-PESA sender,
  /// so those messages must contain a telecom keyword before they are treated
  /// as a bundle alert.
  static const Set<String> _safaricomSenderIds = {
    'safaricom',
    'safaricomet',
    'safaricomethiopia',
    '700',
    '0700',
    '251700',
    '704',
    '0704',
    '251704',
    '777',
    '0777',
    '251777',
  };

  static const Set<String> _otherProviderSenders = {
    'cbe',
    'cbebirr',
    'telebirr',
    'ethiotelecom',
    'ethiotel',
    '994',
    '0994',
    '251994',
    'boa',
    'abyssinia',
    'dashen',
    'amole',
  };

  bool canParse(String message, String? sender) {
    final lower = message.toLowerCase();
    final hasTelecomKeyword = TelecomTextUtils.hasTelecomKeyword(message);

    if (sender != null) {
      final s = TelecomTextUtils.normalizeSender(sender);
      if (_otherProviderSenders.contains(s)) return false;
      if (_safaricomSenderIds.contains(s)) {
        // 700 carries both M-PESA and bundle alerts. M-PESA confirmations must
        // go to the money parser, not the bundle parser.
        if (s == '700' || s == '0700' || s == '251700') {
          if (lower.contains('m-pesa') ||
              lower.contains('mpesa') ||
              lower.contains('confirmed')) {
            return false;
          }
          return hasTelecomKeyword;
        }
        return true;
      }
      if (s.contains('safaricom')) return hasTelecomKeyword;
    }

    final hasProvider =
        lower.contains('safaricom') || message.contains('ሳፋሪኮም');
    return hasProvider && hasTelecomKeyword;
  }

  TelecomParseResult parse(String message, String? sender) {
    final isPurchase = TelecomTextUtils.isPurchase(message);
    final isBalanceUpdate = TelecomTextUtils.isBalanceUpdate(message);

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
        reason: 'Could not extract Safaricom bundle allowance',
      );
    }

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
      provider: AppConstants.providerSafaricom,
      bundleName: bundleName,
      category: category,
      isPurchase: isPurchase,
      isBalanceUpdate: isBalanceUpdate,
      originalAllowance: originalAllowance,
      remainingAllowance: remainingAllowance,
      unit: unit,
      purchasePriceSantims: purchasePrice,
      expiryTime: expiry,
      activationTime: DateTime.now(),
      confidenceScore: 0.98,
      rawMessage: message,
    );
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
      return 'Safaricom Night $size $unit';
    }
    if (category == AppConstants.bundleCategoryCombo) {
      return 'Safaricom All-in-One ($size $unit)';
    }
    if (category == AppConstants.bundleCategoryVoice) {
      return 'Safaricom $size Mins Voice';
    }
    if (category == AppConstants.bundleCategorySms) {
      return 'Safaricom $size SMS Bundle';
    }
    if (lower.contains('monthly')) return 'Safaricom Monthly $size $unit';
    if (lower.contains('weekly')) return 'Safaricom Weekly $size $unit';
    if (lower.contains('daily')) return 'Safaricom Daily $size $unit';
    return 'Safaricom $size $unit';
  }
}
