import '../../core/constants/app_constants.dart';
import '../../core/utils/money.dart';
import 'telecom_parse_result.dart';

class EthioTelecomParser {
  bool canParse(String message, String? sender) {
    final lower = message.toLowerCase();
    final hasTelecomKeyword = lower.contains('package') ||
        lower.contains('bundle') ||
        lower.contains('ፓኬጅ') ||
        lower.contains('remaining') ||
        lower.contains('ቀሪ') ||
        lower.contains('valid until') ||
        lower.contains('expire') ||
        lower.contains('gb') ||
        lower.contains('mb');

    if (sender != null) {
      final s = sender.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (s == 'ethiotelecom' || s == 'ethiotel' || s == '994') return true;
      if (s == '127' && hasTelecomKeyword) return true;
    }
    return (lower.contains('ethio telecom') || lower.contains('ኢትዮ ቴሌኮም') || lower.contains('ethiotelecom')) &&
        hasTelecomKeyword;
  }

  TelecomParseResult parse(String message, String? sender) {
    final lower = message.toLowerCase();
    final isAmharic = message.contains('ውድ ደንበኛችን') || message.contains('ፓኬጅ') || message.contains('ኢትዮ ቴሌኮም');

    // 1. Detect if it's a Purchase vs a Balance Update
    final isPurchase = lower.contains('successfully purchased') ||
        lower.contains('you have bought') ||
        message.contains('በተሳካ ሁኔታ ገዝተዋል') ||
        message.contains('ገዝተዋል');

    final isBalanceUpdate = lower.contains('remaining') ||
        lower.contains('balance is') ||
        message.contains('ቀሪ') ||
        lower.contains('expire');

    // Extract Unit & Allowance (e.g. "10GB", "500MB", "145 Minutes", "80 SMS")
    String unit = 'GB';
    double allowance = 0.0;
    String category = AppConstants.bundleCategoryData;

    if (lower.contains('night') || lower.contains('የማታ')) {
      category = AppConstants.bundleCategoryNightData;
    } else if (lower.contains('combo') || lower.contains('ኮምቦ')) {
      category = AppConstants.bundleCategoryCombo;
    } else if (lower.contains('voice') || lower.contains('ድምፅ') || lower.contains('minutes')) {
      if (!lower.contains('gb') && !lower.contains('mb') && !lower.contains('data')) {
        category = AppConstants.bundleCategoryVoice;
        unit = 'minutes';
      }
    } else if (lower.contains('sms')) {
      if (!lower.contains('gb') && !lower.contains('mb') && !lower.contains('data')) {
        category = AppConstants.bundleCategorySms;
        unit = 'SMS';
      }
    }

    // Regex for Data Allowance: e.g. "10GB", "7.20 GB", "500 MB", "500MB"
    final dataRegex = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*(GB|MB)', caseSensitive: false);
    final dataMatch = dataRegex.firstMatch(message);

    // Regex for Voice Minutes: e.g. "145 Minutes", "45 Min"
    final voiceRegex = RegExp(r'([0-9]+)\s*(?:Minutes|Mins|Min|ደቂቃ)', caseSensitive: false);
    final voiceMatch = voiceRegex.firstMatch(message);

    // Regex for SMS: e.g. "80 SMS"
    final smsRegex = RegExp(r'([0-9]+)\s*SMS', caseSensitive: false);
    final smsMatch = smsRegex.firstMatch(message);

    if (dataMatch != null && (category != AppConstants.bundleCategoryVoice && category != AppConstants.bundleCategorySms)) {
      allowance = double.tryParse(dataMatch.group(1)!) ?? 0.0;
      unit = dataMatch.group(2)!.toUpperCase();
    } else if (voiceMatch != null && category == AppConstants.bundleCategoryVoice) {
      allowance = double.tryParse(voiceMatch.group(1)!) ?? 0.0;
      unit = 'minutes';
    } else if (smsMatch != null && category == AppConstants.bundleCategorySms) {
      allowance = double.tryParse(smsMatch.group(1)!) ?? 0.0;
      unit = 'SMS';
    }

    // Extract Purchase Price (e.g. "for ETB 300.00", "በብር 300.00")
    int? purchasePrice;
    final priceMatch = RegExp(r'(?:for\s+ETB|for\s+Birr|በብር|ብር)\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false).firstMatch(message);
    if (priceMatch != null && priceMatch.groupCount >= 1) {
      purchasePrice = Money.parseString(priceMatch.group(1)!).santims;
    }

    // Extract Expiry Timestamp (e.g. "valid until 2026-11-24 18:30:00", "እስከ 2026-11-24")
    DateTime? expiry;
    final dateMatch = RegExp(r'(?:valid\s+until|expire[a-z\s]*on|እስከ)\s*([0-9]{4}-[0-9]{2}-[0-9]{2}(?:\s+[0-9]{2}:[0-9]{2}(?::[0-9]{2})?)?)', caseSensitive: false).firstMatch(message);
    if (dateMatch != null && dateMatch.groupCount >= 1) {
      expiry = DateTime.tryParse(dateMatch.group(1)!);
    }

    // Bundle Name
    String bundleName = 'Ethio telecom $allowance $unit';
    if (category == AppConstants.bundleCategoryNightData) {
      bundleName = 'Night Data $allowance $unit';
    } else if (category == AppConstants.bundleCategoryCombo) {
      bundleName = 'Combo Package ($allowance $unit)';
    } else if (category == AppConstants.bundleCategoryVoice) {
      bundleName = '${allowance.toInt()} Mins Voice Bundle';
    } else if (category == AppConstants.bundleCategorySms) {
      bundleName = '${allowance.toInt()} SMS Bundle';
    } else if (lower.contains('monthly') || message.contains('ወርሃዊ')) {
      bundleName = 'Monthly $allowance $unit Data';
    } else if (lower.contains('weekly') || message.contains('ሳምንታዊ')) {
      bundleName = 'Weekly $allowance $unit Data';
    } else if (lower.contains('daily') || message.contains('ዕለታዊ')) {
      bundleName = 'Daily $allowance $unit Data';
    }

    if (allowance <= 0.001) {
      return TelecomParseResult.unrecognized(message, reason: 'Could not extract telecom bundle allowance');
    }

    return TelecomParseResult(
      isRecognized: true,
      provider: AppConstants.providerEthioTelecom,
      bundleName: bundleName,
      category: category,
      isPurchase: isPurchase,
      isBalanceUpdate: isBalanceUpdate,
      originalAllowance: allowance,
      remainingAllowance: allowance,
      unit: unit,
      purchasePriceSantims: purchasePrice,
      expiryTime: expiry,
      activationTime: DateTime.now(),
      confidenceScore: isAmharic ? 0.94 : 0.98,
      rawMessage: message,
    );
  }
}
