import 'ethio_telecom_parser.dart';
import 'safaricom_telecom_parser.dart';
import 'telecom_parse_result.dart';

class TelecomParserEngine {
  final EthioTelecomParser _ethioParser;
  final SafaricomTelecomParser _safaricomParser;

  TelecomParserEngine({
    EthioTelecomParser? ethioParser,
    SafaricomTelecomParser? safaricomParser,
  })  : _ethioParser = ethioParser ?? EthioTelecomParser(),
        _safaricomParser = safaricomParser ?? SafaricomTelecomParser();

  bool canParse(String message, String? sender) {
    return _ethioParser.canParse(message, sender) || _safaricomParser.canParse(message, sender);
  }

  TelecomParseResult parse(String message, String? sender) {
    if (_ethioParser.canParse(message, sender)) {
      return _ethioParser.parse(message, sender);
    }
    if (_safaricomParser.canParse(message, sender)) {
      return _safaricomParser.parse(message, sender);
    }
    return TelecomParseResult.unrecognized(message);
  }
}
