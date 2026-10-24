import '../../core/constants/app_constants.dart';
import '../../core/utils/money.dart';
import 'telecom_parse_result.dart';

class SafaricomTelecomParser {
  bool canParse(String message, String? sender) {
    if (sender != null) {
      final s = sender.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (s == 'safaricom' || s == 'safaricomet' || s == '700' || s == '704' || s == '777') return true;
    }
    final lower = message.toLowerCase();
    return (lower.contains('safaricom') || lower.contains('ሳፋሪኮም')) &&
        (lower.contains('bundle') ||
            lower.contains('package') ||
            lower.contains('balance') ||
            lower.contains('data') ||
            lower.contains('voice') ||
            lower.contains('remaining') ||
            lower.contains('valid until') ||
            lower.contains('expire'));
  }

  TelecomParseResult parse(String message, String? sender) {
    final lower = message.toLowerCase();

    // 1. Detect Purchase vs Balance Update
    final isPurchase = lower.contains('successfully purchased') ||
        lower.contains('you have bought') ||
        lower.contains('purchased') ||
        message.contains('በተሳካ ሁኔታ ገዝተዋል') ||
        message.contains('ገዝተዋል');

    final isBalanceUpdate = lower.contains('balance') ||
        lower.contains('remaining') ||
        message.contains('ቀሪ') ||
        lower.contains('expire');

    // 2. Identify Category & Unit
    String unit = 'GB';
    double allowance = 0.0;
    String category = AppConstants.bundleCategoryData;

    if (lower.contains('night') || lower.contains('የማታ')) {
      category = AppConstants.bundleCategoryNightData;
    } else if (lower.contains('combo') || lower.contains('all-in-one') || lower.contains('ኮምቦ')) {
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

    // 3. Extract Allowance
    // Regex for Data: e.g. "5GB", "3.85 GB", "1000MB", "450 MB"
    final dataRegex = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*(GB|MB)', caseSensitive: false);
    final dataMatch = dataRegex.firstMatch(message);

    // Regex for Voice: e.g. "300 Minutes", "42 Minutes", "20 Min"
    final voiceRegex = RegExp(r'([0-9]+)\s*(?:Minutes|Mins|Min|ደቂቃ)', caseSensitive: false);
    final voiceMatch = voiceRegex.firstMatch(message);

    // Regex for SMS: e.g. "200 SMS", "15 SMS"
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

    // 4. Extract Purchase Price (e.g. "for ETB 150.00", "ETB 750.00", "for Birr 35.00")
    int? purchasePrice;
    final priceMatch = RegExp(r'(?:for\s+ETB|for\s+Birr|ETB|Birr|በብር|ብር)\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false).firstMatch(message);
    if (priceMatch != null && priceMatch.groupCount >= 1 && isPurchase) {
      purchasePrice = Money.parseString(priceMatch.group(1)!).santims;
    }

    // 5. Extract Expiry Timestamp (e.g. "valid until 2026-11-01 23:59:59")
    DateTime? expiry;
    final dateMatch = RegExp(
      r'(?:valid\s+until|expire[a-z\s]*on|እስከ)\s*([0-9]{4}-[0-9]{2}-[0-9]{2}(?:\s+[0-9]{2}:[0-9]{2}(?::[0-9]{2})?)?)',
      caseSensitive: false,
    ).firstMatch(message);
    if (dateMatch != null && dateMatch.groupCount >= 1) {
      expiry = DateTime.tryParse(dateMatch.group(1)!);
    }

    // 6. Name resolution
    String bundleName = 'Safaricom $allowance $unit';
    if (category == AppConstants.bundleCategoryNightData) {
      bundleName = 'Safaricom Night $allowance $unit';
    } else if (category == AppConstants.bundleCategoryCombo) {
      bundleName = 'Safaricom All-in-One ($allowance $unit)';
    } else if (category == AppConstants.bundleCategoryVoice) {
      bundleName = 'Safaricom ${allowance.toInt()} Mins Voice';
    } else if (category == AppConstants.bundleCategorySms) {
      bundleName = 'Safaricom ${allowance.toInt()} SMS Bundle';
    } else if (lower.contains('monthly')) {
      bundleName = 'Safaricom Monthly $allowance $unit';
    } else if (lower.contains('weekly')) {
      bundleName = 'Safaricom Weekly $allowance $unit';
    } else if (lower.contains('daily')) {
      bundleName = 'Safaricom Daily $allowance $unit';
    }

    if (allowance <= 0.001) {
      return TelecomParseResult.unrecognized(message, reason: 'Could not extract Safaricom bundle allowance');
    }

    return TelecomParseResult(
      isRecognized: true,
      provider: AppConstants.providerSafaricom,
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
      confidenceScore: 0.98,
      rawMessage: message,
    );
  }
}
