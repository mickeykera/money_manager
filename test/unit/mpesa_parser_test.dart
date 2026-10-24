import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerleaf/core/constants/app_constants.dart';
import 'package:ledgerleaf/parser/models/parse_result.dart';
import 'package:ledgerleaf/parser/mpesa_parser.dart';

void main() {
  group('MpesaParser Unit Tests', () {
    late MpesaParser parser;

    setUp(() {
      parser = MpesaParser();
    });

    test('canParse identifies Safaricom M-PESA messages and senders', () {
      expect(parser.canParse('TD94RNM67E Confirmed. ETB 450.00 sent to Abebe', '700'), isTrue);
      expect(parser.canParse('M-PESA Confirmed. ETB 100.00 paid to Store', 'MPESA'), isTrue);
      expect(parser.canParse('Dear CBE customer, you spent ETB 50.00', '127'), isFalse);
    });

    test('parses money sent to another person', () {
      const sms = 'TD94RNM67E Confirmed. ETB 450.00 sent to Abebe Bikila 0712345678 on 24/10/26 at 10:30 AM. New M-PESA balance is ETB 1,820.00.';
      final result = parser.parse(sms, '700');

      expect(result.status, equals(ParseStatus.success));
      expect(result.amountSantims, equals(45000));
      expect(result.currency, equals('ETB'));
      expect(result.merchant, equals('Abebe Bikila'));
      expect(result.reference, equals('TD94RNM67E'));
      expect(result.balanceSantims, equals(182000));
      expect(result.transactionType, equals(AppConstants.typeExpense));
    });

    test('parses money received', () {
      const sms = 'TD94RNM68F Confirmed. You have received ETB 2,000.00 from Aster Aweke 0798765432 on 24/10/26 at 11:15 AM. New M-PESA balance is ETB 3,820.00.';
      final result = parser.parse(sms, 'MPESA');

      expect(result.status, equals(ParseStatus.success));
      expect(result.amountSantims, equals(200000));
      expect(result.merchant, contains('Aster Aweke'));
      expect(result.reference, equals('TD94RNM68F'));
      expect(result.balanceSantims, equals(382000));
      expect(result.transactionType, equals(AppConstants.typeIncome));
    });

    test('parses merchant till payment', () {
      const sms = 'TD94RNM69G Confirmed. ETB 180.00 paid to Safaricom Supermarket (Till 890123) on 24/10/26 at 12:00 PM. New M-PESA balance is ETB 3,640.00.';
      final result = parser.parse(sms, '700');

      expect(result.status, equals(ParseStatus.success));
      expect(result.amountSantims, equals(18000));
      expect(result.merchant, equals('Safaricom Supermarket'));
      expect(result.balanceSantims, equals(364000));
    });

    test('parses airtime purchase', () {
      const sms = 'TD94RNM70H Confirmed. You have bought ETB 50.00 of airtime on 24/10/26 at 1:00 PM. New M-PESA balance is ETB 3,590.00.';
      final result = parser.parse(sms, '700');

      expect(result.status, equals(ParseStatus.success));
      expect(result.amountSantims, equals(5000));
      expect(result.merchant, equals('Safaricom Airtime Top-up'));
      expect(result.balanceSantims, equals(359000));
    });

    test('rejects pure balance inquiry without transaction charge', () {
      const sms = 'Dear Customer, your New M-PESA balance is ETB 3,590.00.';
      final result = parser.parse(sms, '700');

      expect(result.status, equals(ParseStatus.rejectedNonFinancial));
      expect(result.balanceSantims, equals(359000));
    });
  });
}
