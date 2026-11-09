import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerleaf/core/constants/app_constants.dart';
import 'package:ledgerleaf/data/database/database_helper.dart';
import 'package:ledgerleaf/data/repositories/account_repository.dart';
import 'package:ledgerleaf/data/repositories/settings_repository.dart';
import 'package:ledgerleaf/data/repositories/transaction_repository.dart';
import 'package:ledgerleaf/domain/models/filter_criteria.dart';
import 'package:ledgerleaf/parser/parser_engine.dart';
import 'package:ledgerleaf/services/ingestion_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Automatic Ingestion Service & Pipeline Tests', () {
    late Database db;
    late DatabaseHelper dbHelper;
    late TransactionRepository txRepo;
    late AccountRepository accountRepo;
    late SettingsRepository settingsRepo;
    late IngestionService ingestionService;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            dbHelper = DatabaseHelper();
            dbHelper.setDatabaseForTesting(db);

            await db.execute('''
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
            await db.execute('''
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
            await db.execute('''
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
            await db.execute('''
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
            await db.execute('''
              CREATE TABLE settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
              );
            ''');

            final now = DateTime.now().millisecondsSinceEpoch;
            await db.insert('accounts', {
              'id': 'acc_cbe',
              'name': 'Commercial Bank of Ethiopia (CBE)',
              'type': 'bank',
              'balance_santims': 500000,
              'currency': 'ETB',
              'created_at': now,
              'updated_at': now,
            });
            await db.insert('accounts', {
              'id': 'acc_telebirr',
              'name': 'Telebirr Wallet',
              'type': 'mobile_money',
              'balance_santims': 200000,
              'currency': 'ETB',
              'created_at': now,
              'updated_at': now,
            });
            await db.insert('categories', {
              'id': 'cat_food',
              'name': 'Food & Groceries',
              'icon_code_point': 0xe532,
              'color_value': 0xFFE07A5F,
              'monthly_budget_santims': 1000000,
              'is_income': 0,
              'created_at': now,
            });
            await db.insert('categories', {
              'id': 'cat_transport',
              'name': 'Transport',
              'icon_code_point': 0xe1d5,
              'color_value': 0xFF3D5A80,
              'monthly_budget_santims': 300000,
              'is_income': 0,
              'created_at': now,
            });
            await db.insert('categories', {
              'id': 'cat_income',
              'name': 'Income',
              'icon_code_point': 0xe041,
              'color_value': 0xFF2A9D8F,
              'monthly_budget_santims': 0,
              'is_income': 1,
              'created_at': now,
            });
            await db.insert('categories', {
              'id': 'cat_other',
              'name': 'Other',
              'icon_code_point': 0xe3e3,
              'color_value': 0xFF8D99AE,
              'monthly_budget_santims': 0,
              'is_income': 0,
              'created_at': now,
            });
            await db.insert('settings', {'key': AppConstants.keyRetainOriginalSms, 'value': 'true'});
          },
        ),
      );

      dbHelper = DatabaseHelper();
      dbHelper.setDatabaseForTesting(db);

      txRepo = TransactionRepository(dbHelper: dbHelper);
      accountRepo = AccountRepository(dbHelper: dbHelper);
      settingsRepo = SettingsRepository(dbHelper: dbHelper);

      ingestionService = IngestionService(
        parserEngine: ParserEngine(),
        transactionRepo: txRepo,
        accountRepo: accountRepo,
        settingsRepo: settingsRepo,
        dbHelper: dbHelper,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Successful import: CBE debit message updates balance and logs', () async {
      // SYNTHETIC TEST FIXTURE
      const msg =
          'Dear Customer, your Account 1000****1234 has been debited with ETB 350.00 on 24/10/2026 for Purchase at Fresh Corner. Current Balance is ETB 14,250.75. Ref: FT242981234.';

      final response = await ingestionService.processIncomingSms(
        rawMessage: msg,
        sender: 'CBE',
      );

      expect(response.success, isTrue);
      expect(response.isDuplicate, isFalse);
      expect(response.transaction, isNotNull);
      expect(response.transaction?.amountSantims, 35000);
      expect(response.transaction?.merchant, 'Fresh Corner');
      expect(response.transaction?.categoryId, 'cat_food'); // Auto-categorized to food
      expect(response.transaction?.accountId, 'acc_cbe');

      // The SMS reports Current Balance ETB 14,250.75, which is authoritative
      // and reconciles the account (instead of the old 5,000 - 350 value).
      final acc = await accountRepo.getAccountById('acc_cbe');
      expect(acc?.balanceSantims, 1425075);

      // Verify audit log entry created
      final logs = await db.query('ingestion_logs');
      expect(logs.length, 1);
      expect(logs.first['status'], 'success');
      expect(logs.first['parsed_amount_santims'], 35000);
    });

    test('Duplicate prevention: second delivery of same message is rejected as duplicate', () async {
      const msg =
          'You have paid ETB 250.00 to Kaldi\'s Coffee (0911****00) on 2026-10-24 14:30:15. Transaction number is TB261024.1430.A12345. Your current balance is ETB 1,840.50.';

      final time = DateTime(2026, 10, 24, 14, 30);
      final firstRes = await ingestionService.processIncomingSms(
        rawMessage: msg,
        sender: 'telebirr',
        messageTime: time,
      );
      expect(firstRes.success, isTrue);
      expect(firstRes.isDuplicate, isFalse);

      // Second delivery (e.g. cellular retry)
      final secondRes = await ingestionService.processIncomingSms(
        rawMessage: msg,
        sender: 'telebirr',
        messageTime: time,
      );
      expect(secondRes.success, isTrue);
      expect(secondRes.isDuplicate, isTrue);
      expect(secondRes.message, contains('already recorded'));

      // Transactions count must strictly remain 1
      final txList = await txRepo.getTransactions(const FilterCriteria());
      expect(txList.length, 1);
    });

    test('Refund handling: refund credits account and offsets spending', () async {
      const msg = 'Dear Customer, your Account 1000****1234 has been credited with ETB 150.00 refund from Store. Ref: FT243990001.';
      final res = await ingestionService.processIncomingSms(rawMessage: msg, sender: 'CBE');

      expect(res.success, isTrue);
      expect(res.transaction?.type, AppConstants.typeRefund);
      expect(res.transaction?.amountSantims, 15000);

      // Account balance increased by 150 ETB (5000 + 150 = 5150 ETB)
      final acc = await accountRepo.getAccountById('acc_cbe');
      expect(acc?.balanceSantims, 515000);
    });

    test('Unknown senders & invalid text fail safely without crashing', () async {
      // 1. Casual chat
      final casualRes = await ingestionService.processIncomingSms(
        rawMessage: 'Hello, are you coming home early today?',
        sender: '0911000000',
      );
      expect(casualRes.success, isFalse);

      // 2. Empty string
      final emptyRes = await ingestionService.processIncomingSms(
        rawMessage: '',
        sender: null,
      );
      expect(emptyRes.success, isFalse);

      // 3. OTP code
      final otpRes = await ingestionService.processIncomingSms(
        rawMessage: 'Your CBE OTP is 123456. Do not share.',
        sender: 'CBE',
      );
      expect(otpRes.success, isFalse);
      expect(otpRes.message, contains('dropped'));

      // Database should have zero transactions added
      final txList = await txRepo.getTransactions(const FilterCriteria());
      expect(txList.isEmpty, isTrue);
    });

    test('Concurrent ingestion: multiple simultaneous messages execute safely', () async {
      final futures = <Future<IngestionResponse>>[];

      for (int i = 1; i <= 5; i++) {
        final msg =
            'You have paid ETB ${(i * 10)}.00 to Merchant $i on 2026-10-24 10:0$i:00. Transaction number is TB_CONC_$i. Balance ETB 1000.00.';
        futures.add(ingestionService.processIncomingSms(rawMessage: msg, sender: 'telebirr'));
      }

      final results = await Future.wait(futures);
      for (final res in results) {
        expect(res.success, isTrue);
      }

      final txList = await txRepo.getTransactions(const FilterCriteria());
      expect(txList.length, 5);
    });

    test('Offline resilience: entire pipeline runs 100% offline without network', () async {
      const msg = 'Dear Customer, Account 1000****1234 debited with ETB 80.00 for Ride Fare. Ref: FT_OFFLINE_1.';
      final res = await ingestionService.processIncomingSms(rawMessage: msg, sender: 'CBE');
      expect(res.success, isTrue);
      expect(res.transaction?.amountSantims, 8000);
    });

    test('real CBE alert records the debit and reconciles 723.27', () async {
      const msg =
          'Dear Mr Michael your Account 1********1189 has been debited with '
          'ETB 200.85 including Service charge ETB0.70ETB0.04 and VAT(15%) '
          'ETB0.11. Your Current Balance is ETB 723.27.';
      final res = await ingestionService.processIncomingSms(
        rawMessage: msg,
        sender: 'CBE',
        messageTime: DateTime(2026, 5, 9, 17, 47),
      );

      expect(res.success, isTrue);
      expect(res.transaction?.amountSantims, 20085);
      expect(res.reconciledAccountId, 'acc_cbe');
      final acc = await accountRepo.getAccountById('acc_cbe');
      expect(acc?.balanceSantims, 72327);
    });

    test('real Telebirr alert from sender 127 updates the wallet', () async {
      const msg =
          'You have transferred ETB 3,500.00 to Mr Yared on 09/05/2026 at '
          '16:56:00. Transaction number is TB260509.1656.A12345. '
          'Your current balance is ETB 2,087.47.';
      final res = await ingestionService.processIncomingSms(
        rawMessage: msg,
        sender: '127',
        messageTime: DateTime(2026, 5, 9, 16, 56),
      );

      expect(res.success, isTrue);
      expect(res.transaction?.accountId, 'acc_telebirr');
      expect(res.transaction?.amountSantims, 350000);
      final acc = await accountRepo.getAccountById('acc_telebirr');
      expect(acc?.balanceSantims, 208747);
    });

    test('pure balance SMS reconciles without creating a transaction', () async {
      const msg = 'Dear Customer, your Current Balance is ETB 723.27.';
      final res = await ingestionService.processIncomingSms(
        rawMessage: msg,
        sender: 'CBE',
      );

      expect(res.success, isTrue);
      expect(res.isBalanceUpdate, isTrue);
      expect(res.transaction, isNull);
      expect(res.reconciledAccountId, 'acc_cbe');
      expect(await txRepo.getTransactions(const FilterCriteria()), isEmpty);

      final acc = await accountRepo.getAccountById('acc_cbe');
      expect(acc?.balanceSantims, 72327);
    });

    test('duplicate balance SMS still reconciles a restored database', () async {
      const msg =
          'You have transferred ETB 3,500.00 to Mr Yared on 09/05/2026 at '
          '16:56:00. Transaction number is TB260509.1656.A12345. '
          'Your current balance is ETB 2,087.47.';
      final time = DateTime(2026, 5, 9, 16, 56);

      final first = await ingestionService.processIncomingSms(
        rawMessage: msg,
        sender: '127',
        messageTime: time,
      );
      expect(first.isDuplicate, isFalse);

      // Simulate a restored database whose balance is stale.
      await accountRepo.setBalance('acc_telebirr', 0);

      final second = await ingestionService.processIncomingSms(
        rawMessage: msg,
        sender: '127',
        messageTime: time,
      );
      expect(second.isDuplicate, isTrue);
      expect(second.reconciledAccountId, 'acc_telebirr');

      final acc = await accountRepo.getAccountById('acc_telebirr');
      expect(acc?.balanceSantims, 208747);
    });

    test('zero-amount marketing SMS creates no ledger entry', () async {
      const msg =
          'Dear customer, enjoy our new internet offers. Dial *804# to '
          'subscribe and get more data.';
      final res = await ingestionService.processIncomingSms(
        rawMessage: msg,
        sender: '127',
      );

      expect(res.success, isFalse);
      expect(res.isPendingReview, isFalse);
      expect(await txRepo.getTransactions(const FilterCriteria()), isEmpty);
    });

    test('deleteZeroAmountSmsTransactions removes only bogus SMS rows', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('transactions', {
        'id': 'tx_zero',
        'amount_santims': 0,
        'currency': 'ETB',
        'type': 'expense',
        'merchant': 'Promo',
        'timestamp': now,
        'timezone_offset_minutes': 180,
        'category_id': 'cat_other',
        'account_id': 'acc_cbe',
        'source': AppConstants.sourceSms,
        'import_status': AppConstants.statusPendingReview,
        'is_reviewed': 0,
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('transactions', {
        'id': 'tx_real',
        'amount_santims': 5000,
        'currency': 'ETB',
        'type': 'expense',
        'merchant': 'Shop',
        'timestamp': now,
        'timezone_offset_minutes': 180,
        'category_id': 'cat_other',
        'account_id': 'acc_cbe',
        'source': AppConstants.sourceSms,
        'import_status': AppConstants.statusPosted,
        'is_reviewed': 1,
        'created_at': now,
        'updated_at': now,
      });

      final removed = await txRepo.deleteZeroAmountSmsTransactions();
      expect(removed, equals(1));

      final remaining = await txRepo.getTransactions(const FilterCriteria());
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('tx_real'));
    });

    test('resetSmsLinkedBalancesExcept clears only stale linked accounts', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('accounts', {
        'id': 'acc_cash',
        'name': 'Cash in Hand',
        'type': 'cash',
        'balance_santims': 10000,
        'currency': 'ETB',
        'is_sms_linked': 0,
        'created_at': now,
        'updated_at': now,
      });

      await accountRepo.resetSmsLinkedBalancesExcept({'acc_cbe'});

      expect((await accountRepo.getAccountById('acc_cbe'))?.balanceSantims, 500000);
      expect((await accountRepo.getAccountById('acc_telebirr'))?.balanceSantims, 0);
      expect((await accountRepo.getAccountById('acc_cash'))?.balanceSantims, 10000);
    });

    test('Ethio telecom airtime transfer does not overwrite the Telebirr wallet', () async {
      const telebirr =
          'You have transferred ETB 3,500.00 to Mr Yared on 09/05/2026 at '
          '16:56:00. Transaction number is TB260509.1656.A12345. '
          'Your current balance is ETB 2,087.47.';
      await ingestionService.processIncomingSms(
        rawMessage: telebirr,
        sender: '127',
        messageTime: DateTime(2026, 5, 9, 16, 56),
      );
      expect(
        (await accountRepo.getAccountById('acc_telebirr'))?.balanceSantims,
        208747,
      );

      const airtime =
          'Dear customer,0936650202 subscriber transferred 240.00 Birr for '
          'you.Your balance is 1590.00 Birr now.ethio telecom';
      final res = await ingestionService.processIncomingSms(
        rawMessage: airtime,
        sender: '251994',
        messageTime: DateTime(2026, 8, 17, 8, 25),
      );

      expect(res.success, isFalse);
      expect(res.transaction, isNull);
      expect(res.reconciledAccountId, isNull);
      expect(
        (await accountRepo.getAccountById('acc_telebirr'))?.balanceSantims,
        208747,
      );
    });

    test('Ethio telecom prepaid recharge and bonus notices create no ledger entries', () async {
      final before = await txRepo.getTransactions(const FilterCriteria());

      const messages = <String>[
        'Dear Customer, \n Your prepaid account has been recharged '
            'successfully. Your Recharged balance is 50.00 Birr. Your balance '
            'is 1746.57 Birr. Download and use telebirr SuperApp from '
            'https://onelink.to/uecbbr and get bonus during airtime & package '
            'purchase. \n Ethio telecom',
        'Dear Customer,     your remaining amount from Bonus Fund is 262.50 '
            'Birr and validity until 01/01/2037, From Win-back and Tele-birr. '
            '   Thank you Ethio telecom.',
        'Dear Customer, \n You have been awarded an ETB 87.50 bonus for '
            'recharging your prepaid account using telebirr SuperApp Day Deal '
            'airtime recharge. \n Thank you!\n Ethio telecom',
        'Dear Customer; \n You have successfully redeemed Airtime via service '
            'number 0986402248. \nThank you \nEthio telecom',
      ];

      for (final msg in messages) {
        final res = await ingestionService.processIncomingSms(
          rawMessage: msg,
          sender: '251994',
        );
        expect(res.success, isFalse);
        expect(res.transaction, isNull);
      }

      final after = await txRepo.getTransactions(const FilterCriteria());
      expect(after.length, before.length);
      expect(
        (await accountRepo.getAccountById('acc_telebirr'))?.balanceSantims,
        200000,
      );
    });

    test('Telebirr airtime-received receipts do not credit the wallet', () async {
      const receipt =
          'Dear Customer\nYou have received ETB 250.00 airtime from '
          '251936650202 on 16/10/2026 18:02:41. Your transaction number is '
          'DJG0VEEI8K.\nThank you for using telebirr\nethio telecom';
      final res = await ingestionService.processIncomingSms(
        rawMessage: receipt,
        sender: '127',
        messageTime: DateTime(2026, 10, 16, 18, 2, 41),
      );

      expect(res.success, isFalse);
      expect(res.transaction, isNull);
      expect(res.reconciledAccountId, isNull);
      expect(
        (await accountRepo.getAccountById('acc_telebirr'))?.balanceSantims,
        200000,
      );
    });

    test('deletePrepaidAirtimeSmsTransactions removes only airtime notice rows', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      Future<void> insert(String id, String original, int amount) async {
        await db.insert('transactions', {
          'id': id,
          'amount_santims': amount,
          'currency': 'ETB',
          'type': 'expense',
          'merchant': 'Test',
          'timestamp': now,
          'timezone_offset_minutes': 180,
          'category_id': 'cat_other',
          'account_id': 'acc_telebirr',
          'source': AppConstants.sourceSms,
          'import_status': AppConstants.statusPosted,
          'original_message': original,
          'is_reviewed': 1,
          'created_at': now,
          'updated_at': now,
        });
      }

      await insert(
        'tx_airtime_transfer',
        'Dear customer,0936650202 subscriber transferred 240.00 Birr for '
            'you.Your balance is 1590.00 Birr now.ethio telecom',
        24000,
      );
      await insert(
        'tx_bonus',
        'You have been awarded an ETB 87.50 bonus for recharging your prepaid '
            'account using telebirr SuperApp Day Deal airtime recharge.',
        8750,
      );
      await insert(
        'tx_airtime_received',
        'Dear Customer\nYou have received ETB 250.00 airtime from '
            '251936650202 on 16/10/2026 18:02:41. Your transaction number is '
            'DJG0VEEI8K.\nThank you for using telebirr\nethio telecom',
        25000,
      );
      // A genuine Telebirr wallet airtime purchase must survive.
      await insert(
        'tx_real_airtime',
        'You have recharged ETB 100.00 airtime for 986402248 on 18/04/2026 '
            '22:28:24. Your current balance is ETB 0.00. Thank you for using '
            'telebirr.',
        10000,
      );

      final removed = await txRepo.deletePrepaidAirtimeSmsTransactions();
      expect(removed, equals(3));

      final remaining = await txRepo.getTransactions(const FilterCriteria());
      expect(remaining.length, equals(1));
      expect(remaining.single.id, equals('tx_real_airtime'));
    });

    test('deletePromotionalSmsTransactions removes only promo rows', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      Future<void> insert(String id, String original, int amount) async {
        await db.insert('transactions', {
          'id': id,
          'amount_santims': amount,
          'currency': 'ETB',
          'type': 'expense',
          'merchant': 'Safaricom Ethiopia',
          'timestamp': now,
          'timezone_offset_minutes': 180,
          'category_id': 'cat_other',
          'account_id': 'acc_telebirr',
          'source': AppConstants.sourceSms,
          'import_status': AppConstants.statusPosted,
          'original_message': original,
          'is_reviewed': 1,
          'created_at': now,
          'updated_at': now,
        });
      }

      await insert(
        'tx_pubg',
        'Your squad is waiting! Activate your 3GB PUBG Gaming Bundle valid '
            'for 24hrs at only 50 ETB. Dial *777*3*1# now!',
        5000,
      );
      await insert(
        'tx_dont_miss',
        'Don’t miss out!  Enjoy daily 24 minutes ( 12 tele minutes + 12 '
            'Safaricom minutes) for just 5 Birr and talk more with your loved '
            'ones.  To buy the package Dial *777*1*1*1# Today!',
        500,
      );
      await insert(
        'tx_doubled',
        '30 birr = 120 Mins + 120 Mins, ALL weekly & monthly package doubled '
            'for New year',
        3000,
      );
      // A genuine bundle purchase must survive.
      await insert(
        'tx_wullo',
        'You have successfully purchased Wullo Unlimited Internet for Br.60 '
            'valid from 6AM to 6PM during the day. '
            'Expiry date: 16-10-2026 18:00:00',
        6000,
      );

      final removed = await txRepo.deletePromotionalSmsTransactions();
      expect(removed, equals(3));

      final remaining = await txRepo.getTransactions(const FilterCriteria());
      expect(remaining.length, equals(1));
      expect(remaining.single.id, equals('tx_wullo'));
    });
  });
}
