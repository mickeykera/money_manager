import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerleaf/core/constants/app_constants.dart';
import 'package:ledgerleaf/data/database/database_helper.dart';
import 'package:ledgerleaf/data/repositories/account_repository.dart';
import 'package:ledgerleaf/data/repositories/bundle_repository.dart';
import 'package:ledgerleaf/data/repositories/settings_repository.dart';
import 'package:ledgerleaf/data/repositories/transaction_repository.dart';
import 'package:ledgerleaf/domain/models/bundle_model.dart';
import 'package:ledgerleaf/domain/models/filter_criteria.dart';
import 'package:ledgerleaf/parser/telecom/ethio_telecom_parser.dart';
import 'package:ledgerleaf/parser/telecom/safaricom_telecom_parser.dart';
import 'package:ledgerleaf/parser/telecom/telecom_text_utils.dart';
import 'package:ledgerleaf/services/ingestion_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('EthioTelecomParser Tests', () {
    late EthioTelecomParser parser;

    setUp(() {
      parser = EthioTelecomParser();
    });

    test('flags prepaid airtime notices so they never hit the wallet', () {
      const subscriberTransfer =
          'Dear customer,0936650202 subscriber transferred 240.00 Birr for '
          'you.Your balance is 1590.00 Birr now.ethio telecom';
      const prepaidRecharge =
          'Dear Customer, Your prepaid account has been recharged '
          'successfully. Your Recharged balance is 50.00 Birr. Your balance '
          'is 1746.57 Birr. Ethio telecom';
      const bonusFund =
          'Dear Customer, your remaining amount from Bonus Fund is 262.50 '
          'Birr and validity until 01/01/2037, From Win-back and Tele-birr.';

      expect(
        TelecomTextUtils.isPrepaidAirtimeNotice(subscriberTransfer, '251994'),
        isTrue,
      );
      expect(
        TelecomTextUtils.isPrepaidAirtimeNotice(prepaidRecharge, '994'),
        isTrue,
      );
      expect(
        TelecomTextUtils.isPrepaidAirtimeNotice(bonusFund, '251994'),
        isTrue,
      );

      // Genuine Telebirr wallet movement from the shared 127 sender.
      expect(
        TelecomTextUtils.isPrepaidAirtimeNotice(
          'You have transferred ETB 3,500.00. Your current balance is '
          'ETB 2,087.47.',
          '127',
        ),
        isFalse,
      );

      // Airtime received from another subscriber is prepaid credit, not wallet
      // money, even though Telebirr sends it from 127.
      expect(
        TelecomTextUtils.isPrepaidAirtimeNotice(
          'Dear Customer\nYou have received ETB 250.00 airtime from '
          '251936650202 on 16/10/2026 18:02:41. Your transaction number is '
          'DJG0VEEI8K.\nThank you for using telebirr\nethio telecom',
          '127',
        ),
        isTrue,
      );

      // Genuine Telebirr airtime purchase paid from the wallet.
      expect(
        TelecomTextUtils.isPrepaidAirtimeNotice(
          'You have recharged ETB 100.00 airtime for 986402248. Your current '
          'balance is ETB 0.00. Thank you for using telebirr.',
          '127',
        ),
        isFalse,
      );
    });

    test('canParse recognizes Ethio telecom senders and text', () {
      expect(
        parser.canParse('You have purchased 10GB monthly package', '994'),
        isTrue,
      );
      expect(
        parser.canParse(
          'Dear Customer, your remaining balance is 7.2GB Data',
          'ethiotelecom',
        ),
        isTrue,
      );
      expect(
        parser.canParse('ኢትዮ ቴሌኮም፡ የ 10GB ፓኬጅ በተሳካ ሁኔታ ገዝተዋል', '127'),
        isTrue,
      );
      expect(parser.canParse('CBE: You spent ETB 50.00', '127'), isFalse);
    });

    test('parses 10GB monthly purchase with price and expiry', () {
      const sms =
          'Dear customer, you have successfully purchased 10GB Monthly Data bundle for ETB 300.00. Valid until 2026-11-24 18:30:00.';
      final result = parser.parse(sms, '994');

      expect(result.isRecognized, isTrue);
      expect(result.provider, equals(AppConstants.providerEthioTelecom));
      expect(result.isPurchase, isTrue);
      expect(result.originalAllowance, equals(10.0));
      expect(result.unit, equals('GB'));
      expect(result.purchasePriceSantims, equals(30000));
      expect(result.expiryTime, isNotNull);
      expect(result.expiryTime!.year, equals(2026));
      expect(result.expiryTime!.month, equals(11));
      expect(result.expiryTime!.day, equals(24));
    });

    test('parses *804# remaining balance inquiry without purchase price', () {
      const sms =
          'Dear Customer, your remaining package balance is 7.20 GB Data valid until 2026-11-24.';
      final result = parser.parse(sms, 'Ethio telecom');

      expect(result.isRecognized, isTrue);
      expect(result.isBalanceUpdate, isTrue);
      expect(result.isPurchase, isFalse);
      expect(result.purchasePriceSantims, isNull);
      expect(result.remainingAllowance, equals(7.20));
      expect(result.unit, equals('GB'));
    });

    test('parses Amharic package purchase', () {
      const sms =
          'ውድ ደንበኛችን፡ የ 500 MB ዕለታዊ የኢንተርኔት ፓኬጅ በብር 35.00 በተሳካ ሁኔታ ገዝተዋል እስከ 2026-10-25 ድረስ የሚያገለግል።';
      final result = parser.parse(sms, 'Ethio telecom');

      expect(result.isRecognized, isTrue);
      expect(result.isPurchase, isTrue);
      expect(result.originalAllowance, equals(500.0));
      expect(result.unit, equals('MB'));
      expect(result.purchasePriceSantims, equals(3500));
    });

    test('canParse recognizes the international 251994 sender', () {
      // Android often stores +251994 as 251994. Both must be accepted.
      expect(parser.canParse('You have recharged 2GB Data.', '251994'), isTrue);
      expect(
        parser.canParse('You have recharged 2GB Data.', '+251 994'),
        isTrue,
      );
      expect(parser.canParse('You have recharged 2GB Data.', '0994'), isTrue);
    });

    test('parses a recharged internet bundle', () {
      const sms =
          'Dear customer, you have recharged 2GB internet bundle for ETB 100.00. '
          'Valid until 2026-11-30.';
      final result = parser.parse(sms, '251994');

      expect(result.isRecognized, isTrue);
      expect(result.provider, equals(AppConstants.providerEthioTelecom));
      expect(result.isPurchase, isTrue);
      expect(result.originalAllowance, equals(2.0));
      expect(result.unit, equals('GB'));
      expect(result.purchasePriceSantims, equals(10000));
      expect(result.category, equals(AppConstants.bundleCategoryData));
    });

    test('parses a subscribed package with internet keyword', () {
      const sms =
          'You have subscribed to a 1.5 GB internet package valid until '
          '24/11/2026.';
      final result = parser.parse(sms, '994');

      expect(result.isRecognized, isTrue);
      expect(result.isPurchase, isTrue);
      expect(result.originalAllowance, equals(1.5));
      expect(result.unit, equals('GB'));
    });

    test(
      'reports remaining allowance when a purchase also says what is left',
      () {
        const sms =
            'You have purchased 10GB monthly data bundle for ETB 300.00. '
            'Your remaining data balance is 7.5 GB.';
        final result = parser.parse(sms, '994');

        expect(result.isRecognized, isTrue);
        expect(result.isPurchase, isTrue);
        expect(result.originalAllowance, equals(10.0));
        expect(result.remainingAllowance, equals(7.5));
        expect(result.unit, equals('GB'));
      },
    );

    test('parses the Monthly Unlimited Premium Internet activation', () {
      const sms =
          'Dear customer, you have successfully activated the new service '
          'offer Monthly Unlimited Premium Internet plan effective as of '
          'Oct 16, 2026 6:09:08 PM and will be expired on '
          'Nov 15, 2026 6:09:08 PM.';
      final result = parser.parse(sms, '994');

      expect(result.isRecognized, isTrue);
      expect(result.provider, equals(AppConstants.providerEthioTelecom));
      expect(result.isPurchase, isTrue);
      expect(result.unit, equals('Unlimited'));
      expect(result.originalAllowance, equals(0));
      expect(result.remainingAllowance, equals(0));
      expect(result.category, equals(AppConstants.bundleCategoryUnlimited));
      expect(result.bundleName, equals('Monthly Unlimited Premium Internet'));

      expect(result.activationTime, isNotNull);
      expect(result.activationTime!.year, 2026);
      expect(result.activationTime!.month, 10);
      expect(result.activationTime!.day, 16);
      expect(result.activationTime!.hour, 18);
      expect(result.activationTime!.minute, 9);
      expect(result.activationTime!.second, 8);

      expect(result.expiryTime, isNotNull);
      expect(result.expiryTime!.year, 2026);
      expect(result.expiryTime!.month, 11);
      expect(result.expiryTime!.day, 15);
      expect(result.expiryTime!.hour, 18);
      expect(result.expiryTime!.minute, 9);
      expect(result.expiryTime!.second, 8);
    });

    test('unlimited reminder is an update, not a new package', () {
      const sms =
          'Dear customer, Your Monthly Unlimited Premium Internet plan to be '
          'expired after 30 days will expire after 1 day on 2026-10-16 at '
          '17:00:12.';
      final result = parser.parse(sms, '994');

      expect(result.isRecognized, isTrue);
      expect(result.isPurchase, isFalse);
      expect(result.unit, equals('Unlimited'));
      expect(result.expiryTime, isNotNull);
      expect(result.expiryTime!.year, 2026);
      expect(result.expiryTime!.month, 10);
      expect(result.expiryTime!.day, 16);
    });

    test('unlimited SMS plans use the sms category', () {
      const sms =
          'Dear customer, you have activated an Unlimited SMS monthly plan '
          'valid until 2026-11-15.';
      final result = parser.parse(sms, '994');

      expect(result.isRecognized, isTrue);
      expect(result.unit, equals('Unlimited'));
      expect(result.category, equals(AppConstants.bundleCategorySms));
    });

    test('expiry notification is not treated as a new activation', () {
      const sms =
          'Dear customer, your Unlimited Internet package has expired.';
      final result = parser.parse(sms, '994');

      expect(result.isRecognized, isFalse);
    });

    test('purchase detection only matches completed actions', () {
      expect(
        TelecomTextUtils.isPurchase('You have successfully purchased 1GB'),
        isTrue,
      );
      expect(
        TelecomTextUtils.isPurchase('You have activated a monthly plan'),
        isTrue,
      );
      expect(
        TelecomTextUtils.isPurchase('Activate your 3GB bundle now'),
        isFalse,
      );
      expect(
        TelecomTextUtils.isPurchase('To purchase a new bundle dial *777#'),
        isFalse,
      );
      expect(TelecomTextUtils.isPurchase('Subscribe now'), isFalse);
      expect(TelecomTextUtils.isPurchase('Renew today'), isFalse);
    });

    test('rejects the fair-user-policy informational notice', () {
      const sms =
          'Dear customer, monthly unlimited have no FUP, for any additional '
          'information about fair user policy, please refer to our website. '
          'Thank you, have a nice time.';
      final result = parser.parse(sms, '251994');

      expect(result.isRecognized, isFalse);
    });

    test('rejects service offer suspended/resumed notices', () {
      const suspended =
          'Dear ANDUALEM TESHOME GASHAW Your 0936650202 service offer Monthly '
          'Recurring 140 Min and 35 SMS rollover pack is suspended as of '
          '12-12-2024. Send SMS to 8994 for support. Ethio telecom';
      const resumed =
          'Dear Mr. michael Your 0905498267 service offer 300MB Bonus For '
          'Three Months, Monthly SIM Starter_115Min Voice Package Plus 1GB '
          'data Bonus is resumed as of 09-05-2026. Thank you Ethio telecom';

      expect(parser.parse(suspended, '994').isRecognized, isFalse);
      expect(parser.parse(resumed, '994').isRecognized, isFalse);
    });

    test('real activation with support footer is unlimited internet', () {
      const sms = 'Dear Customer \n'
          'As per your request, the new service offer Monthly Unlimited '
          'Premium Internet plan to be expired after 30 days is added to your '
          'service number 0986402248. The offer is effective as of Oct 16, '
          '2026 6:09:08 PM and will be expired on Nov 15, 2026 6:09:08 PM.\n'
          'Thank you for using our service! Kindly share your experience with '
          'us by clicking the link: https://forms.office.com/r/QjPuVbGN9t \n'
          'For more information or assistance, please send an SMS to 8994 or '
          'visit: https://telehub.ethiotelecom.et \n'
          'Happy New Year!\n'
          'Ethio telecom';
      final result = parser.parse(sms, '994');

      expect(result.isRecognized, isTrue);
      expect(result.category, equals(AppConstants.bundleCategoryUnlimited));
      expect(
        result.bundleName,
        equals('Monthly Unlimited Premium Internet'),
      );
      expect(result.expiryTime, isNotNull);
      expect(result.expiryTime!.month, equals(11));
      expect(result.expiryTime!.day, equals(15));
    });

    test('rejects Amharic annual-package advertisement', () {
      const sms = 'የአንድ ዓመት ጥቅል ገዝተው ስልክ በነጻ ይውሰዱ!\n\n'
          'ዘኔክሰስ L131፡ በየወሩ 50 ብር ብቻ የአየር ሰዓት በመሙላት ቅድሚያ የከፈሉት ብር '
          'ለ1 ዓመት በየወሩ በ4GB +80Min+50SMS መልኩ ተመላሽ ይሆናል።\n\n'
          'በአገልግሎት ማዕከሎቻችን ያገኟቸዋል!\n\nኢትዮ ቴሌኮም';

      expect(parser.parse(sms, 'ethio tel').isRecognized, isFalse);
    });
  });

  group('SafaricomTelecomParser Tests', () {
    late SafaricomTelecomParser parser;

    setUp(() {
      parser = SafaricomTelecomParser();
    });

    test('canParse recognizes Safaricom telecom senders and text', () {
      expect(
        parser.canParse(
          'You have successfully purchased 5GB Weekly Data bundle for ETB 150.00',
          '700',
        ),
        isTrue,
      );
      expect(
        parser.canParse(
          'Your Safaricom balance: Data: 3.85 GB valid until 2026-11-01',
          '704',
        ),
        isTrue,
      );
    });

    test('parses 5GB weekly purchase with price and expiry', () {
      const sms =
          'Dear customer, you have successfully purchased 5GB Weekly Data bundle for ETB 150.00. Valid until 2026-11-01 23:59:59.';
      final result = parser.parse(sms, 'Safaricom');

      expect(result.isRecognized, isTrue);
      expect(result.provider, equals(AppConstants.providerSafaricom));
      expect(result.isPurchase, isTrue);
      expect(result.originalAllowance, equals(5.0));
      expect(result.unit, equals('GB'));
      expect(result.purchasePriceSantims, equals(15000));
      expect(result.expiryTime, isNotNull);
    });

    test('parses *704# balance check without purchase price', () {
      const sms =
          'Your Safaricom balance: Data: 3.85 GB valid until 2026-11-01 23:59:59. Voice: 42 Minutes. SMS: 15.';
      final result = parser.parse(sms, '704');

      expect(result.isRecognized, isTrue);
      expect(result.isBalanceUpdate, isTrue);
      expect(result.isPurchase, isFalse);
      expect(result.remainingAllowance, equals(3.85));
      expect(result.unit, equals('GB'));
      expect(result.purchasePriceSantims, isNull);
    });

    test('canParse recognizes international Safaricom senders', () {
      expect(
        parser.canParse('You have purchased 5GB weekly data bundle', '251700'),
        isTrue,
      );
      expect(
        parser.canParse(
          'You have purchased 5GB weekly data bundle',
          '+251 704',
        ),
        isTrue,
      );
      expect(
        parser.canParse('You have purchased 5GB weekly data bundle', '777'),
        isTrue,
      );
    });

    test('does not steal M-PESA confirmations sent from 700', () {
      const mpesa =
          'TD94RNM67E Confirmed. ETB 450.00 paid to Safaricom Supermarket. '
          'New M-PESA balance is ETB 1,820.00.';
      expect(parser.canParse(mpesa, '700'), isFalse);
    });

    test('parses a recharged Safaricom internet bundle', () {
      const sms =
          'Dear customer, you have recharged 3GB internet bundle for ETB 120.00. '
          'Valid until 2026-12-01.';
      final result = parser.parse(sms, '251700');

      expect(result.isRecognized, isTrue);
      expect(result.provider, equals(AppConstants.providerSafaricom));
      expect(result.isPurchase, isTrue);
      expect(result.originalAllowance, equals(3.0));
      expect(result.unit, equals('GB'));
      expect(result.purchasePriceSantims, equals(12000));
    });

    test('parses the Wullo Unlimited Internet purchase', () {
      const sms =
          'You have successfully purchased Wullo Unlimited Internet for '
          'Br.60 valid from 6AM to 6PM during the day. '
          'Expiry date: 16-10-2026 18:00:00';
      final result = parser.parse(sms, '700');

      expect(result.isRecognized, isTrue);
      expect(result.provider, equals(AppConstants.providerSafaricom));
      expect(result.isPurchase, isTrue);
      expect(result.unit, equals('Unlimited'));
      expect(result.category, equals(AppConstants.bundleCategoryUnlimited));
      expect(result.bundleName, equals('Wullo Unlimited Internet'));
      expect(result.purchasePriceSantims, equals(6000));
      expect(result.expiryTime, isNotNull);
      expect(result.expiryTime!.year, 2026);
      expect(result.expiryTime!.month, 10);
      expect(result.expiryTime!.day, 16);
    });

    test('airtime recharge receipt is not a bundle purchase', () {
      const sms =
          'Recharge of Br. 10.00 was successful. Balance: Br. 69.00. '
          'To get 200GB and 500GB MEGA internet packages dial *704#.';
      final result = parser.parse(sms, '700');

      expect(result.isRecognized, isFalse);
    });

    test('rejects promotional bundle advertisements', () {
      const promos = <String>[
        'Your squad is waiting! Activate your 3GB PUBG Gaming Bundle valid '
            'for 24hrs at only 50 ETB. Dial *777*3*1# now!',
        'Don’t miss out!  Enjoy daily 24 minutes ( 12 tele minutes + 12 '
            'Safaricom minutes) for just 5 Birr and talk more with your loved '
            'ones.  To buy the package Dial *777*1*1*1# Today!',
        'Call anyone, anytime and anywhere! Enjoy 120 weekly minutes for only '
            '30 birr. Dial *777*1# today!',
        '30 Birr for 120 Tele minutes, 7 days! Call anyone on the Tele network '
            'with Tele Bundles. Dial *777*1# to buy now.',
        'Exciting news! Call Safaricom & Tele numbers with one bundle. '
            'Dial *777# and select Tele Minutes.',
        'Happy Customer Service Week! Thank you for being part of our 15 '
            'million subscriber family. Get unlimited weekly '
            'Safaricom-to-Safaricom calls for only 20 Br.',
        '30 birr = 120 Mins + 120 Mins, ALL weekly & monthly package doubled '
            'for New year',
        'One Bundle- Call anyone. Now with tele bundles you can call both '
            'Safaricom and Tele. Dial *777#, select Tele Minutes.',
        'Unlimited weekly minutes for just 20 Birr! Dail *777# and select '
            'Besh.',
        'Unlimited minutes for just 5 Birr! Dail *777# and select Besh.',
        'More Value, Up to 2X Data! Dial *777#, select BESH.',
        'FREE 50MB + 10  minutes! For you, Dial *777# and select BESH to get '
            'amazing offers!',
        'More for you, every day. Dial *777# and select besh to discover '
            "today's personalized offer.",
      ];

      for (final sms in promos) {
        final result = parser.parse(sms, 'Safaricom');
        expect(result.isRecognized, isFalse, reason: sms);
      }
    });

    test('Wullo expiry notice is not a purchase', () {
      const sms =
          'Dear Customer. Your Wullo Unlimited Internet has expired. To '
          'purchase a new bundle, please dial *777# Thank you.';
      final result = parser.parse(sms, 'Safaricom');

      expect(result.isRecognized, isFalse);
    });
  });

  group('BundleRepository & Usage Tracking Tests', () {
    late Database db;
    late DatabaseHelper dbHelper;
    late BundleRepository bundleRepo;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (database, version) async {
            await database.execute('''
              CREATE TABLE telecom_bundles (
                id TEXT PRIMARY KEY,
                provider TEXT NOT NULL,
                bundle_name TEXT NOT NULL,
                category TEXT NOT NULL,
                original_allowance REAL NOT NULL,
                remaining_allowance REAL NOT NULL,
                unit TEXT NOT NULL,
                activation_time INTEGER,
                expiry_time INTEGER,
                purchase_price_santims INTEGER,
                linked_transaction_id TEXT,
                source_message TEXT,
                source_fingerprint TEXT,
                last_confirmed_time INTEGER NOT NULL,
                confidence_score REAL NOT NULL,
                status TEXT NOT NULL
              );
            ''');
            await database.execute('''
              CREATE TABLE telecom_observations (
                id TEXT PRIMARY KEY,
                bundle_id TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                remaining_allowance REAL NOT NULL,
                unit TEXT NOT NULL,
                estimated_usage REAL,
                source_message TEXT NOT NULL
              );
            ''');
          },
        ),
      );
      dbHelper = DatabaseHelper();
      dbHelper.setDatabaseForTesting(db);
      bundleRepo = BundleRepository(dbHelper: dbHelper);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'saves bundle and tracks multiple observations with usage calculation',
      () async {
        final now = DateTime.now();
        final bundle = TelecomBundleModel(
          id: 'bundle_test_1',
          provider: AppConstants.providerEthioTelecom,
          bundleName: 'Monthly 10GB Data',
          category: AppConstants.bundleCategoryData,
          originalAllowance: 10.0,
          remainingAllowance: 10.0,
          unit: 'GB',
          lastConfirmedTime: now,
        );

        await bundleRepo.saveBundle(bundle);

        // Observation 1: initial 10GB
        final obs1 = await bundleRepo.recordObservation(
          bundleId: bundle.id,
          remainingAllowance: 10.0,
          unit: 'GB',
          sourceMessage: 'Purchased 10GB',
          timestamp: now,
        );
        expect(obs1.estimatedUsageSincePrevious, isNull);

        // Observation 2: 7.2 GB remaining (consumed 2.8 GB!)
        final obs2 = await bundleRepo.recordObservation(
          bundleId: bundle.id,
          remainingAllowance: 7.20,
          unit: 'GB',
          sourceMessage: 'Remaining 7.20 GB',
          timestamp: now.add(const Duration(days: 2)),
        );
        expect(obs2.estimatedUsageSincePrevious, equals(2.80));

        // Observation 3: 5.5 GB remaining (consumed 1.7 GB!)
        final obs3 = await bundleRepo.recordObservation(
          bundleId: bundle.id,
          remainingAllowance: 5.50,
          unit: 'GB',
          sourceMessage: 'Remaining 5.50 GB',
          timestamp: now.add(const Duration(days: 4)),
        );
        expect(obs3.estimatedUsageSincePrevious, equals(1.70));

        // Observation 4: Bonus / top-up increases remaining allowance to 8.0 GB (should NOT be negative!)
        final obs4 = await bundleRepo.recordObservation(
          bundleId: bundle.id,
          remainingAllowance: 8.0,
          unit: 'GB',
          sourceMessage: 'Bonus data added: 8.0 GB',
          timestamp: now.add(const Duration(days: 5)),
        );
        expect(obs4.estimatedUsageSincePrevious, equals(0.0));

        // Verify parent bundle was updated
        final updatedBundle = await bundleRepo.getBundleById(bundle.id);
        expect(updatedBundle, isNotNull);
        expect(updatedBundle!.remainingAllowance, equals(8.0));
        expect(updatedBundle.status, equals('active'));
      },
    );

    test('getTelecomSummary aggregates active bundles correctly', () async {
      final now = DateTime.now();
      await bundleRepo.saveBundle(
        TelecomBundleModel(
          id: 'ethio_1',
          provider: AppConstants.providerEthioTelecom,
          bundleName: 'Ethio 10GB',
          category: AppConstants.bundleCategoryData,
          originalAllowance: 10.0,
          remainingAllowance: 7.20,
          unit: 'GB',
          expiryTime: now.add(const Duration(days: 10)),
          lastConfirmedTime: now,
        ),
      );

      await bundleRepo.saveBundle(
        TelecomBundleModel(
          id: 'safari_1',
          provider: AppConstants.providerSafaricom,
          bundleName: 'Safaricom 5GB',
          category: AppConstants.bundleCategoryData,
          originalAllowance: 5.0,
          remainingAllowance: 3.85,
          unit: 'GB',
          expiryTime: now.add(const Duration(days: 5)),
          lastConfirmedTime: now,
        ),
      );

      final summary = await bundleRepo.getTelecomSummary();
      expect(summary.ethioDataRemainingGb, equals(7.20));
      expect(summary.safaricomDataRemainingGb, equals(3.85));
      expect(summary.totalDataRemainingGb, equals(11.05));
      expect(summary.activeBundles.length, equals(2));
      expect(summary.nextKnownExpiry, isNotNull);
      expect(
        summary.nextKnownExpiry!.day,
        equals(now.add(const Duration(days: 5)).day),
      );
    });

    test('unlimited bundles stay active with zero allowance until expiry', () {
      final now = DateTime.now();
      final bundle = TelecomBundleModel(
        id: 'ethio_unlimited',
        provider: AppConstants.providerEthioTelecom,
        bundleName: 'Monthly Unlimited Premium Internet',
        category: AppConstants.bundleCategoryUnlimited,
        originalAllowance: 0,
        remainingAllowance: 0,
        unit: 'Unlimited',
        activationTime: now.subtract(const Duration(days: 2)),
        expiryTime: now.add(const Duration(days: 20)),
        lastConfirmedTime: now,
      );

      expect(bundle.isUnlimited, isTrue);
      expect(bundle.isExpired, isFalse);
      expect(bundle.isExhausted, isFalse);
      expect(bundle.percentageRemaining, equals(1.0));
      expect(bundle.formattedRemaining, equals('Unlimited'));
      expect(bundle.formattedAllowance, equals('Unlimited'));
      expect(bundle.expiryFormatted, contains('Expires'));
    });

    test('unlimited bundles expire once the expiry date passes', () {
      final now = DateTime.now();
      final bundle = TelecomBundleModel(
        id: 'ethio_expired',
        provider: AppConstants.providerEthioTelecom,
        bundleName: 'Monthly Unlimited Premium Internet',
        category: AppConstants.bundleCategoryUnlimited,
        originalAllowance: 0,
        remainingAllowance: 0,
        unit: 'Unlimited',
        expiryTime: now.subtract(const Duration(minutes: 1)),
        lastConfirmedTime: now,
      );

      expect(bundle.isExpired, isTrue);
      expect(bundle.expiryFormatted, contains('Expired'));
    });

    test('getTelecomSummary flags unlimited data and SMS plans', () async {
      final now = DateTime.now();
      await bundleRepo.saveBundle(
        TelecomBundleModel(
          id: 'ethio_unlimited_data',
          provider: AppConstants.providerEthioTelecom,
          bundleName: 'Monthly Unlimited Premium Internet',
          category: AppConstants.bundleCategoryUnlimited,
          originalAllowance: 0,
          remainingAllowance: 0,
          unit: 'Unlimited',
          expiryTime: now.add(const Duration(days: 20)),
          lastConfirmedTime: now,
        ),
      );
      await bundleRepo.saveBundle(
        TelecomBundleModel(
          id: 'ethio_unlimited_sms',
          provider: AppConstants.providerEthioTelecom,
          bundleName: 'Unlimited SMS',
          category: AppConstants.bundleCategorySms,
          originalAllowance: 0,
          remainingAllowance: 0,
          unit: 'Unlimited',
          expiryTime: now.add(const Duration(days: 20)),
          lastConfirmedTime: now,
        ),
      );

      final summary = await bundleRepo.getTelecomSummary();
      expect(summary.activeBundles.length, equals(2));
      expect(summary.hasUnlimitedData, isTrue);
      expect(summary.hasUnlimitedSms, isTrue);
      expect(summary.ethioHasUnlimitedData, isTrue);
      expect(summary.safaricomHasUnlimitedData, isFalse);
      // Unlimited plans must not be summed as numeric GB/SMS allowances.
      expect(summary.totalDataRemainingGb, equals(0.0));
      expect(summary.totalSmsRemaining, equals(0));
    });
  });

  group('IngestionService Telecom Integration Tests', () {
    late Database db;
    late DatabaseHelper dbHelper;
    late IngestionService ingestionService;
    late BundleRepository bundleRepo;
    late TransactionRepository txRepo;
    late AccountRepository accountRepo;
    late SettingsRepository settingsRepo;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (database, version) async {
            await database.execute('''
              CREATE TABLE accounts (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                type TEXT NOT NULL,
                balance_santims INTEGER NOT NULL DEFAULT 0,
                currency TEXT NOT NULL DEFAULT 'ETB',
                account_number_masked TEXT,
                is_sms_linked INTEGER NOT NULL DEFAULT 1,
                balance_source TEXT NOT NULL DEFAULT 'Latest imported SMS',
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              );
            ''');
            await database.execute('''
              CREATE TABLE categories (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                icon_code_point INTEGER NOT NULL,
                color_value INTEGER NOT NULL,
                monthly_budget_santims INTEGER NOT NULL DEFAULT 0,
                is_income INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL
              );
            ''');
            await database.execute('''
              CREATE TABLE transactions (
                id TEXT PRIMARY KEY,
                amount_santims INTEGER NOT NULL,
                currency TEXT NOT NULL DEFAULT 'ETB',
                type TEXT NOT NULL,
                merchant TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                timezone_offset_minutes INTEGER NOT NULL DEFAULT 180,
                category_id TEXT NOT NULL,
                account_id TEXT NOT NULL,
                source TEXT NOT NULL,
                import_status TEXT NOT NULL,
                source_fingerprint TEXT,
                original_message TEXT,
                reference TEXT,
                linked_transaction_id TEXT,
                notes TEXT,
                is_reviewed INTEGER NOT NULL DEFAULT 1,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              );
            ''');
            await database.execute('''
              CREATE TABLE ingestion_logs (
                id TEXT PRIMARY KEY,
                timestamp INTEGER NOT NULL,
                sender TEXT,
                raw_message_snippet TEXT NOT NULL,
                status TEXT NOT NULL,
                parsed_amount_santims INTEGER,
                confidence_score REAL,
                error_message TEXT
              );
            ''');
            await database.execute('''
              CREATE TABLE settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
              );
            ''');
            await database.execute('''
              CREATE TABLE telecom_bundles (
                id TEXT PRIMARY KEY,
                provider TEXT NOT NULL,
                bundle_name TEXT NOT NULL,
                category TEXT NOT NULL,
                original_allowance REAL NOT NULL,
                remaining_allowance REAL NOT NULL,
                unit TEXT NOT NULL,
                activation_time INTEGER,
                expiry_time INTEGER,
                purchase_price_santims INTEGER,
                linked_transaction_id TEXT,
                source_message TEXT,
                source_fingerprint TEXT,
                last_confirmed_time INTEGER NOT NULL,
                confidence_score REAL NOT NULL,
                status TEXT NOT NULL
              );
            ''');
            await database.execute('''
              CREATE TABLE telecom_observations (
                id TEXT PRIMARY KEY,
                bundle_id TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                remaining_allowance REAL NOT NULL,
                unit TEXT NOT NULL,
                estimated_usage REAL,
                source_message TEXT NOT NULL
              );
            ''');

            await database.insert('accounts', {
              'id': 'acc_telebirr',
              'name': 'Telebirr',
              'type': 'mobile_money',
              'balance_santims': 500000,
              'currency': 'ETB',
              'is_sms_linked': 1,
              'balance_source': 'Latest imported SMS',
              'created_at': DateTime.now().millisecondsSinceEpoch,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            });
          },
        ),
      );

      dbHelper = DatabaseHelper();
      dbHelper.setDatabaseForTesting(db);
      bundleRepo = BundleRepository(dbHelper: dbHelper);
      txRepo = TransactionRepository(dbHelper: dbHelper);
      accountRepo = AccountRepository(dbHelper: dbHelper);
      settingsRepo = SettingsRepository(dbHelper: dbHelper);

      ingestionService = IngestionService(
        dbHelper: dbHelper,
        bundleRepo: bundleRepo,
        transactionRepo: txRepo,
        accountRepo: accountRepo,
        settingsRepo: settingsRepo,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('telecom bundle purchase creates BOTH expense transaction AND bundle record', () async {
      const sms =
          'Dear customer, you have successfully purchased 10GB Monthly Data bundle for ETB 300.00. Valid until 2026-11-24 18:30:00.';
      final res = await ingestionService.processIncomingSms(
        rawMessage: sms,
        sender: '994',
      );

      expect(res.success, isTrue);
      expect(res.isTelecomUpdate, isTrue);
      expect(res.transaction, isNotNull);
      expect(res.transaction!.amountSantims, equals(30000));
      expect(res.transaction!.type, equals(AppConstants.typeExpense));
      expect(res.transaction!.merchant, contains('Ethio telecom'));

      // Check bundle created in repo
      final bundles = await bundleRepo.getAllBundles();
      expect(bundles.isNotEmpty, isTrue);
      expect(bundles.first.originalAllowance, equals(10.0));
      expect(bundles.first.remainingAllowance, equals(10.0));
    });

    test('telecom balance update does NOT create financial transaction (prevents double counting!)', () async {
      const sms =
          'Dear Customer, your remaining package balance is 7.20 GB Data valid until 2026-11-24.';
      final res = await ingestionService.processIncomingSms(
        rawMessage: sms,
        sender: 'Ethio telecom',
      );

      expect(res.success, isTrue);
      expect(res.isTelecomUpdate, isTrue);
      // Crucial: no financial transaction created!
      expect(res.transaction, isNull);

      // Check bundle created or updated
      final bundles = await bundleRepo.getAllBundles();
      expect(bundles.isNotEmpty, isTrue);
      expect(bundles.first.remainingAllowance, equals(7.20));
    });

    test('unlimited activation stores plan type and expiry without a charge', () async {
      const sms =
          'Dear customer, you have successfully activated the new service '
          'offer Monthly Unlimited Premium Internet plan effective as of '
          'Oct 16, 2026 6:09:08 PM and will be expired on '
          'Nov 15, 2026 6:09:08 PM.';
      final res = await ingestionService.processIncomingSms(
        rawMessage: sms,
        sender: '994',
      );

      expect(res.success, isTrue);
      expect(res.isTelecomUpdate, isTrue);
      // No price in the activation SMS, so no financial transaction.
      expect(res.transaction, isNull);
      expect(await txRepo.getTransactions(const FilterCriteria()), isEmpty);

      final bundles = await bundleRepo.getAllBundles();
      expect(bundles.length, equals(1));
      final bundle = bundles.first;
      expect(bundle.unit, equals('Unlimited'));
      expect(bundle.category, equals(AppConstants.bundleCategoryUnlimited));
      expect(
        bundle.bundleName,
        equals('Monthly Unlimited Premium Internet'),
      );
      expect(bundle.status, equals('active'));
      expect(bundle.expiryTime, isNotNull);
      expect(bundle.expiryTime!.year, 2026);
      expect(bundle.expiryTime!.month, 11);
      expect(bundle.expiryTime!.day, 15);
      expect(bundle.expiryTime!.hour, 18);
      expect(bundle.expiryTime!.minute, 9);
    });

    test('a newer unlimited package supersedes the previous one', () async {
      const first =
          'Dear customer, you have activated an Unlimited Internet monthly '
          'plan effective as of Oct 16, 2026 6:09:08 PM and will be expired '
          'on Nov 15, 2026 6:09:08 PM.';
      const second =
          'Dear customer, you have activated an Unlimited Internet monthly '
          'plan effective as of Nov 15, 2026 6:10:00 PM and will be expired '
          'on Dec 15, 2026 6:10:00 PM.';

      await ingestionService.processIncomingSms(
        rawMessage: first,
        sender: '994',
        messageTime: DateTime(2026, 10, 16, 18, 9, 8),
      );
      await ingestionService.processIncomingSms(
        rawMessage: second,
        sender: '994',
        messageTime: DateTime(2026, 11, 15, 18, 10),
      );

      final bundles = await bundleRepo.getAllBundles();
      final active = bundles.where((b) => b.status == 'active').toList();
      expect(active.length, equals(1));
      expect(active.first.expiryTime!.month, equals(12));
      expect(
        bundles.where((b) => b.status == 'expired').length,
        equals(1),
      );
    });

    test('airtime recharge receipt creates no bundle or transaction', () async {
      const sms =
          'Recharge of Br. 10.00 was successful. Balance: Br. 69.00. '
          'To get 200GB and 500GB MEGA internet packages dial *704#.';
      final res = await ingestionService.processIncomingSms(
        rawMessage: sms,
        sender: '700',
      );

      expect(res.success, isFalse);
      expect(res.isTelecomUpdate, isFalse);
      expect(res.transaction, isNull);
      expect(await bundleRepo.getAllBundles(), isEmpty);
      expect(await txRepo.getTransactions(const FilterCriteria()), isEmpty);
    });

    test('promotional SMS creates no bundle or transaction', () async {
      const sms =
          'Your squad is waiting! Activate your 3GB PUBG Gaming Bundle valid '
          'for 24hrs at only 50 ETB. Dial *777*3*1# now!';
      final res = await ingestionService.processIncomingSms(
        rawMessage: sms,
        sender: 'Safaricom',
        messageTime: DateTime(2026, 10, 17, 9, 58),
      );

      expect(res.success, isFalse);
      expect(res.isTelecomUpdate, isFalse);
      expect(res.transaction, isNull);
      expect(await bundleRepo.getAllBundles(), isEmpty);
      expect(await txRepo.getTransactions(const FilterCriteria()), isEmpty);
    });

    test('genuine Wullo purchase still creates its expense', () async {
      const sms =
          'You have successfully purchased Wullo Unlimited Internet for '
          'Br.60 valid from 6AM to 6PM during the day. '
          'Expiry date: 16-10-2026 18:00:00';
      final res = await ingestionService.processIncomingSms(
        rawMessage: sms,
        sender: 'Safaricom',
        messageTime: DateTime(2026, 10, 16, 11, 15),
      );

      expect(res.success, isTrue);
      expect(res.isTelecomUpdate, isTrue);
      expect(res.transaction, isNotNull);
      expect(res.transaction!.amountSantims, equals(6000));
      expect(res.transaction!.merchant, contains('Wullo Unlimited Internet'));
      expect(await bundleRepo.getAllBundles(), hasLength(1));
    });
  });
}
