import 'abyssinia_parser.dart';
import 'base_parser.dart';
import 'cbe_parser.dart';
import 'dashen_parser.dart';
import 'generic_parser.dart';
import 'models/parse_result.dart';
import 'otp_filter.dart';
import 'telebirr_parser.dart';

class ParserEngine {
  final List<BaseParser> _parsers;

  ParserEngine({List<BaseParser>? parsers})
      : _parsers = parsers ??
            [
              CbeParser(),
              TelebirrParser(),
              AbyssiniaParser(),
              DashenParser(),
              GenericBankParser(),
            ];

  /// Parses an incoming SMS message with optional sender identifier
  ParseResult parse(String message, {String? sender}) {
    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) {
      return ParseResult.failure(
        institution: 'Unknown',
        rawMessage: message,
        reason: 'Empty message text',
        status: ParseStatus.rejectedNonFinancial,
      );
    }

    // 1. First line of defense: OTP / 2FA rejection
    if (OtpFilter.isOtp(cleanMessage)) {
      return ParseResult.failure(
        institution: sender ?? 'Security Alert',
        rawMessage: cleanMessage,
        reason: 'Security passcode or OTP detected; discarded for privacy',
        status: ParseStatus.rejectedOtp,
      );
    }

    // 2. Failed transaction rejection
    if (OtpFilter.isFailedTransaction(cleanMessage)) {
      return ParseResult.failure(
        institution: sender ?? 'Bank',
        rawMessage: cleanMessage,
        reason: 'Declined or failed transaction alert',
        status: ParseStatus.rejectedFailedTxn,
      );
    }

    // 3. Find matching parser
    for (final parser in _parsers) {
      if (parser.canParse(cleanMessage, sender)) {
        final result = parser.parse(cleanMessage, sender);
        // If specific parser successfully parsed or has specific failure, return
        if (result.isSuccess || result.isPendingReview || result.isRejected) {
          return result;
        }
      }
    }

    // 4. Fallback to Generic parser
    final generic = GenericBankParser();
    if (generic.canParse(cleanMessage, sender)) {
      return generic.parse(cleanMessage, sender);
    }

    // 5. Completely unrecognized message
    return ParseResult.failure(
      institution: sender ?? 'Unknown',
      rawMessage: cleanMessage,
      reason: 'No financial transaction format matched this message',
      status: ParseStatus.rejectedNonFinancial,
    );
  }
}
