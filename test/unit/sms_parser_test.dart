import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerleaf/core/constants/app_constants.dart';
import 'package:ledgerleaf/parser/abyssinia_parser.dart';
import 'package:ledgerleaf/parser/cbe_parser.dart';
import 'package:ledgerleaf/parser/dashen_parser.dart';
import 'package:ledgerleaf/parser/generic_parser.dart';
import 'package:ledgerleaf/parser/models/parse_result.dart';
import 'package:ledgerleaf/parser/otp_filter.dart';
import 'package:ledgerleaf/parser/parser_engine.dart';
import 'package:ledgerleaf/parser/telebirr_parser.dart';

void main() {
  group('OTP and Security Guardrail Tests', () {
    test('Detects and flags OTP / 2FA messages', () {
      // SYNTHETIC TEST FIXTURES
      const otpMsg1 = 'Your CBE Birr OTP is 849201. Do not share this secret verification code with anyone.';
      const otpMsg2 = 'EthioTelecom: Your verification code is 432190. Never share this code.';
      const otpMsg3 = 'ይህንን ሚስጥራዊ ቁጥር ለማንም አያጋሩ: 981245';

      expect(OtpFilter.isOtp(otpMsg1), isTrue);
      expect(OtpFilter.isOtp(otpMsg2), isTrue);
      expect(OtpFilter.isOtp(otpMsg3), isTrue);
    });

    test('Does NOT produce false positives on normal words containing sub-strings', () {
      const normalMsg1 = 'Payment at Hotpot Restaurant for ETB 350.00 debited.';
      const normalMsg2 = 'Ride fare to Bole airport ETB 120.00 paid.';
      expect(OtpFilter.isOtp(normalMsg1), isFalse);
      expect(OtpFilter.isOtp(normalMsg2), isFalse);
    });

    test('Detects failed or declined transactions', () {
      const failedMsg1 = 'Dear Customer, your transaction failed due to insufficient funds.';
      const failedMsg2 = 'Payment declined due to incorrect PIN.';
      const failedAmharic = 'ይቅርታ በቂ ቀሪ ገንዘብ የለም ግብይቱ አልተሳካም';

      expect(OtpFilter.isFailedTransaction(failedMsg1), isTrue);
      expect(OtpFilter.isFailedTransaction(failedMsg2), isTrue);
      expect(OtpFilter.isFailedTransaction(failedAmharic), isTrue);
    });
  });

  group('Commercial Bank of Ethiopia (CBE) Parser Tests', () {
    final parser = CbeParser();

    test('Positive: English debit message', () {
      // SYNTHETIC TEST FIXTURE
      const msg =
          'Dear Customer, your Account 1000****1234 has been debited with ETB 350.00 on 24/10/2026 for Purchase at Fresh Corner. Current Balance is ETB 14,250.75. Ref: FT242981234.';

      expect(parser.canParse(msg, 'CBE'), isTrue);
      final result = parser.parse(msg, 'CBE');

      expect(result.status, ParseStatus.success);
      expect(result.amountSantims, 35000); // 350.00 ETB
      expect(result.transactionType, AppConstants.typeExpense);
      expect(result.merchant, 'Fresh Corner');
      expect(result.reference, 'FT242981234');
      expect(result.balanceSantims, 1425075); // 14,250.75 ETB
      expect(result.confidenceScore, greaterThanOrEqualTo(0.90));
    });

    test('Positive: English credit / deposit message', () {
      // SYNTHETIC TEST FIXTURE
      const msg =
          'Dear Customer, your Account 1000****1234 has been credited with ETB 5,000.00 from Abebe Bikila on 24/10/2026. Current Balance is ETB 19,250.75. Ref: FT242989876.';

      final result = parser.parse(msg, '127');
      expect(result.status, ParseStatus.success);
      expect(result.amountSantims, 500000); // 5,000.00 ETB
      expect(result.transactionType, AppConstants.typeIncome);
      expect(result.reference, 'FT242989876');
    });

    test('Positive: Amharic debit message', () {
      // SYNTHETIC TEST FIXTURE
      const msg =
          'ውድ ደንበኛችን ሂሳብዎ 1000****1234 በ 24/10/2026 በብር 450.00 ወጪ ተደርጓል። ቀሪ ሂሳብ ብር 13,800.75 ነው። Ref: FT243001111.';

      final result = parser.parse(msg, 'CBE');
      expect(result.status, ParseStatus.success);
      expect(result.amountSantims, 45000); // 450.00 ETB
      expect(result.reference, 'FT243001111');
      expect(result.balanceSantims, 1380075);
    });

    test('Positive: ATM Cash Withdrawal', () {
      // SYNTHETIC TEST FIXTURE
      const msg =
          'Dear Customer, your Account 1000****1234 has been debited with ETB 1,000.00 for ATM Cash Withdrawal at Bole Branch ATM. Balance: ETB 12,800.75. Ref: FT243002222.';

      final result = parser.parse(msg, 'CBE');
      expect(result.status, ParseStatus.success);
      expect(result.amountSantims, 100000);
      expect(result.merchant, 'ATM Cash Withdrawal');
      expect(result.reference, 'FT243002222');
    });

    test('Negative: Missing transaction amount fails safely to pendingReview', () {
      const msg = 'Dear Customer, your Account 1000****1234 has been debited with on 24/10/2026. Ref: FT243009999.';
      final result = parser.parse(msg, 'CBE');
      expect(result.isSuccess, isFalse);
      expect(result.status, ParseStatus.pendingReview);
    });
  });

  group('Telebirr Parser Tests', () {
    final parser = TelebirrParser();

    test('Positive: Merchant payment', () {
      // SYNTHETIC TEST FIXTURE
      const msg =
          'You have paid ETB 250.00 to Kaldi\'s Coffee (0911****00) on 2026-10-24 14:30:15. Transaction number is TB261024.1430.A12345. Your current balance is ETB 1,840.50.';

      expect(parser.canParse(msg, 'telebirr'), isTrue);
      final result = parser.parse(msg, 'telebirr');

      expect(result.status, ParseStatus.success);
      expect(result.amountSantims, 25000); // 250.00 ETB
      expect(result.transactionType, AppConstants.typeExpense);
      expect(result.merchant, 'Kaldi\'s Coffee');
      expect(result.reference, 'TB261024.1430.A12345');
      expect(result.balanceSantims, 184050);
    });

    test('Positive: Received money (Credit)', () {
      // SYNTHETIC TEST FIXTURE
      const msg =
          'You have received ETB 1,200.00 from Dawit Tsige (0933****22) on 2026-10-24 16:45:00. Transaction number: TB261024.1645.C11223. Your current balance is ETB 2,540.50.';

      final result = parser.parse(msg, 'telebirr');
      expect(result.status, ParseStatus.success);
      expect(result.amountSantims, 120000); // 1,200.00 ETB
      expect(result.transactionType, AppConstants.typeIncome);
      expect(result.merchant, 'Dawit Tsige');
      expect(result.reference, 'TB261024.1645.C11223');
    });

    test('Positive: Airtime purchase', () {
      // SYNTHETIC TEST FIXTURE
      const msg =
          'You have bought ETB 50.00 airtime for 0911223344 on 2026-10-24 09:00:00. Trans No: TB261024.0900.E11111.';

      final result = parser.parse(msg, 'telebirr');
      expect(result.status, ParseStatus.success);
      expect(result.amountSantims, 5000);
      expect(result.merchant, 'Ethio Telecom Airtime');
      expect(result.reference, 'TB261024.0900.E11111');
    });

    test('Positive: Cash out / withdrawal', () {
      // SYNTHETIC TEST FIXTURE
      const msg =
          'You have withdrawn ETB 1,000.00 from Telebirr Agent XYZ on 2026-10-24 12:00:00. Trans No: TB261024.1200.D44556. Current balance: ETB 1,530.50.';

      final result = parser.parse(msg, 'telebirr');
      expect(result.status, ParseStatus.success);
      expect(result.amountSantims, 100000);
      expect(result.merchant, 'Telebirr Agent XYZ');
    });
  });

  group('Bank of Abyssinia Parser Tests', () {
    final parser = AbyssiniaParser();

    test('Positive: Debit alert', () {
      // SYNTHETIC TEST FIXTURE
      const msg =
          'Dear Customer, your account BOA****5678 has been debited by ETB 820.50 on 24-Oct-2026 11:20:00. Txn Ref: BOA261024987. Available Bal: ETB 8,450.00. Thank you for banking with Bank of Abyssinia.';

      expect(parser.canParse(msg, 'BOA'), isTrue);
      final result = parser.parse(msg, 'BOA');

      expect(result.status, ParseStatus.success);
      expect(result.amountSantims, 82050);
      expect(result.reference, 'BOA261024987');
      expect(result.balanceSantims, 845000);
    });

    test('Positive: Credit alert', () {
      // SYNTHETIC TEST FIXTURE
      const msg =
          'Dear Customer, your account BOA****5678 has been credited by ETB 12,000.00 on 24-Oct-2026. Txn Ref: BOA261024111. Available Bal: ETB 20,450.00.';

      final result = parser.parse(msg, 'BOA');
      expect(result.status, ParseStatus.success);
      expect(result.amountSantims, 1200000);
      expect(result.transactionType, AppConstants.typeIncome);
      expect(result.reference, 'BOA261024111');
    });

    test('Positive: Reversal transaction', () {
      // SYNTHETIC TEST FIXTURE
      const msg =
          'Dear Customer, reversal of ETB 820.50 on account BOA****5678 completed. Txn Ref: BOA261024REV.';

      final result = parser.parse(msg, 'BOA');
      expect(result.status, ParseStatus.success);
      expect(result.amountSantims, 82050);
      expect(result.transactionType, AppConstants.typeReversal);
    });
  });

  group('Dashen Bank Parser Tests', () {
    final parser = DashenParser();

    test('Positive: POS purchase', () {
      // SYNTHETIC TEST FIXTURE
      const msg =
          'Dear Customer, Account 5100****4321 debited with ETB 1,450.00 on 24/10/2026. Reason: POS Purchase at Shoa Supermarket. Avail Bal: ETB 6,200.00. Txn ID: DSH261024001.';

      expect(parser.canParse(msg, 'Dashen'), isTrue);
      final result = parser.parse(msg, 'Dashen');

      expect(result.status, ParseStatus.success);
      expect(result.amountSantims, 145000);
      expect(result.merchant, 'POS Purchase at Shoa Supermarket');
      expect(result.reference, 'DSH261024001');
      expect(result.balanceSantims, 620000);
    });
  });

  group('Generic Bank Parser Tests', () {
    final parser = GenericBankParser();

    test('Positive: Standard generic bank debit pattern', () {
      // SYNTHETIC TEST FIXTURE
      const msg = 'Your account has been debited with ETB 750.00 for payment to Enat Bakery. Ref: GEN998877.';

      expect(parser.canParse(msg, null), isTrue);
      final result = parser.parse(msg, null);

      expect(result.status, ParseStatus.success);
      expect(result.amountSantims, 75000);
      expect(result.merchant, 'Enat Bakery');
      expect(result.reference, 'GEN998877');
    });

    test('Without reference code, flags for pending review with lower confidence', () {
      // SYNTHETIC TEST FIXTURE
      const msg = 'Your account has been debited with ETB 200.00 for payment to Local Shop.';

      final result = parser.parse(msg, null);
      expect(result.status, ParseStatus.pendingReview);
      expect(result.confidenceScore, lessThan(0.80));
    });
  });

  group('Parser Engine End-to-End Orchestration Tests', () {
    final engine = ParserEngine();

    test('Dispatches CBE message accurately', () {
      const msg =
          'Dear Customer, your Account 1000****1234 has been debited with ETB 350.00 on 24/10/2026 for Purchase at Fresh Corner. Current Balance is ETB 14,250.75. Ref: FT242981234.';
      final result = engine.parse(msg, sender: 'CBE');
      expect(result.isSuccess, isTrue);
      expect(result.institution, 'Commercial Bank of Ethiopia');
    });

    test('Rejects OTP message safely before any parser runs', () {
      const msg = 'Your one-time passcode for CBE mobile banking is 439012. Do not share.';
      final result = engine.parse(msg, sender: 'CBE');
      expect(result.isSuccess, isFalse);
      expect(result.status, ParseStatus.rejectedOtp);
    });

    test('Rejects failed transaction message', () {
      const msg = 'Dear Customer, your transaction of ETB 500.00 failed due to insufficient funds.';
      final result = engine.parse(msg, sender: 'CBE');
      expect(result.isSuccess, isFalse);
      expect(result.status, ParseStatus.rejectedFailedTxn);
    });

    test('Fails safely on completely unknown / casual SMS message', () {
      const msg = 'Hey, are we still meeting for lunch at 1 PM today?';
      final result = engine.parse(msg, sender: 'Mom');
      expect(result.isSuccess, isFalse);
      expect(result.status, ParseStatus.rejectedNonFinancial);
    });

    test('Handles empty and whitespace-only message safely', () {
      final result = engine.parse('   ', sender: null);
      expect(result.isSuccess, isFalse);
      expect(result.status, ParseStatus.rejectedNonFinancial);
    });
  });
}
