import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerleaf/core/constants/app_constants.dart';
import 'package:ledgerleaf/data/database/database_helper.dart';
import 'package:ledgerleaf/data/repositories/account_repository.dart';
import 'package:ledgerleaf/data/repositories/bundle_repository.dart';
import 'package:ledgerleaf/data/repositories/settings_repository.dart';
import 'package:ledgerleaf/data/repositories/transaction_repository.dart';
import 'package:ledgerleaf/domain/models/bundle_model.dart';
import 'package:ledgerleaf/domain/models/filter_criteria.dart';
import 'package:ledgerleaf/parser/models/parse_result.dart';
import 'package:ledgerleaf/parser/parser_engine.dart';
import 'package:ledgerleaf/services/ingestion_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Provider Verification Matrix Tests', () {
    late Database db;
    late DatabaseHelper dbHelper;
    late IngestionService ingestionService;
    late TransactionRepository txRepo;
    late BundleRepository bundleRepo;
    late AccountRepository accountRepo;
    late SettingsRepository settingsRepo;
    final parserEngine = ParserEngine();

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

            final now = DateTime.now().millisecondsSinceEpoch;
            await database.insert('accounts', {
              'id': 'acc_cbe',
              'name': 'Commercial Bank of Ethiopia',
              'type': 'bank',
              'balance_santims': 1000000,
              'currency': 'ETB',
              'is_sms_linked': 1,
              'balance_source': 'Latest imported SMS',
              'created_at': now,
              'updated_at': now,
            });
            await database.insert('accounts', {
              'id': 'acc_telebirr',
              'name': 'Telebirr',
              'type': 'mobile_money',
              'balance_santims': 500000,
              'currency': 'ETB',
              'is_sms_linked': 1,
              'balance_source': 'Latest imported SMS',
              'created_at': now,
              'updated_at': now,
            });
            await database.insert('accounts', {
              'id': 'acc_mpesa',
              'name': 'Safaricom M-PESA',
              'type': 'mobile_money',
              'balance_santims': 200000,
              'currency': 'ETB',
              'is_sms_linked': 1,
              'balance_source': 'Latest imported SMS',
              'created_at': now,
              'updated_at': now,
            });
            await database.insert('accounts', {
              'id': 'acc_boa',
              'name': 'Bank of Abyssinia',
              'type': 'bank',
              'balance_santims': 800000,
              'currency': 'ETB',
              'is_sms_linked': 1,
              'balance_source': 'Latest imported SMS',
              'created_at': now,
              'updated_at': now,
            });
            await database.insert('categories', {
              'id': 'cat_food',
              'name': 'Food',
              'icon_code_point': 1,
              'color_value': 1,
              'monthly_budget_santims': 500000,
              'is_income': 0,
              'created_at': now,
            });
            await database.insert('categories', {
              'id': 'cat_utilities',
              'name': 'Utilities',
              'icon_code_point': 2,
              'color_value': 2,
              'monthly_budget_santims': 200000,
              'is_income': 0,
              'created_at': now,
            });
          },
        ),
      );

      dbHelper = DatabaseHelper();
      dbHelper.setDatabaseForTesting(db);
      txRepo = TransactionRepository(dbHelper: dbHelper);
      bundleRepo = BundleRepository(dbHelper: dbHelper);
      accountRepo = AccountRepository(dbHelper: dbHelper);
      settingsRepo = SettingsRepository(dbHelper: dbHelper);
      ingestionService = IngestionService(
        dbHelper: dbHelper,
        transactionRepo: txRepo,
        bundleRepo: bundleRepo,
        accountRepo: accountRepo,
        settingsRepo: settingsRepo,
      );
    });

    tearDown(() async {
      await db.close();
    });

    // 1. Commercial Bank of Ethiopia (CBE)
    group('1. Commercial Bank of Ethiopia (CBE) Matrix', () {
      test('CBE: Successful debit parsing with exact santims and reference', () {
        const sms = 'Dear Customer, your Account 1000****4821 has been debited with ETB 350.00 on 24/10/2026 for Purchase at Fresh Corner. Current Balance is ETB 14,250.75. Ref: FT242981234.';
        final res = parserEngine.parse(sms, sender: '127');
        expect(res.isSuccess, isTrue);
        expect(res.amountSantims, equals(35000));
        expect(res.merchant, equals('Fresh Corner'));
        expect(res.reference, equals('FT242981234'));
        expect(res.balanceSantims, equals(1425075));
      });

      test('CBE: Wrong sender without bank keywords fails safely', () {
        const sms = 'Your account debited with ETB 350.00';
        final res = parserEngine.parse(sms, sender: 'UnknownRandomUser');
        // Falls back to generic with low confidence or pending review because no reference
        expect(res.isPendingReview, isTrue);
      });

      test('CBE: Missing or ambiguous amount flags for pending review', () {
        const sms = 'Dear Customer, your Account 1000****4821 has been debited on 24/10/2026 for Fresh Corner. Ref: FT242981234.';
        final res = parserEngine.parse(sms, sender: 'CBE');
        expect(res.isSuccess, isFalse);
        expect(res.status, equals(ParseStatus.pendingReview));
      });

      test('CBE: Duplicate delivery prevents duplicate transaction expense', () async {
        const sms = 'Dear Customer, your Account 1000****4821 has been debited with ETB 350.00 on 24/10/2026 for Purchase at Fresh Corner. Ref: FT242981234.';
        final res1 = await ingestionService.processIncomingSms(rawMessage: sms, sender: 'CBE');
        expect(res1.success, isTrue);
        expect(res1.isDuplicate, isFalse);

        // Second delivery of same message
        final res2 = await ingestionService.processIncomingSms(rawMessage: sms, sender: 'CBE');
        expect(res2.success, isTrue);
        expect(res2.isDuplicate, isTrue);

        final transactions = await txRepo.getTransactions(const FilterCriteria());
        expect(transactions.length, equals(1)); // Only one transaction saved!
      });

      test('CBE: Pure balance notification does NOT create transaction', () {
        const sms = 'Dear Customer, your Current Balance for Account 1000****4821 is ETB 14,250.75.';
        final res = parserEngine.parse(sms, sender: 'CBE');
        expect(res.status, equals(ParseStatus.rejectedNonFinancial));
      });
    });

    // 2. Telebirr
    group('2. Telebirr Matrix', () {
      test('Telebirr: Successful payment parsing', () {
        const sms = 'You have paid ETB 250.00 to Kaldi\'s Coffee (0911****00) on 2026-10-24 14:30:15. Transaction number is TB261024.1430.A12345. Your current balance is ETB 1,840.50.';
        final res = parserEngine.parse(sms, sender: 'telebirr');
        expect(res.isSuccess, isTrue);
        expect(res.amountSantims, equals(25000));
        expect(res.merchant, equals('Kaldi\'s Coffee'));
        expect(res.reference, equals('TB261024.1430.A12345'));
        expect(res.balanceSantims, equals(184050));
      });

      test('Telebirr: Missing amount flags for review', () {
        const sms = 'You have paid to Kaldi\'s Coffee on 2026-10-24 14:30:15. Transaction number is TB261024.1430.A12345.';
        final res = parserEngine.parse(sms, sender: 'telebirr');
        expect(res.isSuccess, isFalse);
        expect(res.status, equals(ParseStatus.pendingReview));
      });
    });

    // 3. Bank of Abyssinia (BOA)
    group('3. Bank of Abyssinia (BOA) Matrix', () {
      test('BOA: Successful debit and reversal handling', () {
        const debitSms = 'Dear Customer, your account BOA****5678 has been debited by ETB 820.50 on 24-Oct-2026 11:20:00. Txn Ref: BOA261024987. Available Bal: ETB 8,450.00.';
        final res = parserEngine.parse(debitSms, sender: 'BOA');
        expect(res.isSuccess, isTrue);
        expect(res.amountSantims, equals(82050));
        expect(res.transactionType, equals(AppConstants.typeExpense));

        const revSms = 'Dear Customer, reversal of ETB 820.50 on account BOA****5678 completed. Txn Ref: BOA261024REV.';
        final revRes = parserEngine.parse(revSms, sender: 'BOA');
        expect(revRes.isSuccess, isTrue);
        expect(revRes.transactionType, equals(AppConstants.typeReversal));
      });
    });

    // 4. Dashen Bank
    group('4. Dashen Bank Matrix', () {
      test('Dashen: Successful POS purchase parsing', () {
        const sms = 'Dear Customer, Account 5100****4321 debited with ETB 1,450.00 on 24/10/2026. Reason: POS Purchase at Shoa Supermarket. Avail Bal: ETB 6,200.00. Txn ID: DSH261024001.';
        final res = parserEngine.parse(sms, sender: 'Dashen');
        expect(res.isSuccess, isTrue);
        expect(res.amountSantims, equals(145000));
        expect(res.merchant, contains('Shoa Supermarket'));
        expect(res.reference, equals('DSH261024001'));
      });
    });

    // 5. Safaricom M-PESA
    group('5. Safaricom M-PESA Matrix', () {
      test('M-PESA: Outgoing payment vs incoming credit vs airtime', () {
        const outSms = 'TD94RNM67E Confirmed. ETB 450.00 sent to Abebe Bikila 0712345678 on 24/10/26 at 10:30 AM. New M-PESA balance is ETB 1,820.00.';
        final outRes = parserEngine.parse(outSms, sender: '700');
        expect(outRes.isSuccess, isTrue);
        expect(outRes.transactionType, equals(AppConstants.typeExpense));
        expect(outRes.amountSantims, equals(45000));

        const inSms = 'TD94RNM68F Confirmed. You have received ETB 2,000.00 from Aster Aweke 0798765432 on 24/10/26 at 11:15 AM. New M-PESA balance is ETB 3,820.00.';
        final inRes = parserEngine.parse(inSms, sender: 'MPESA');
        expect(inRes.isSuccess, isTrue);
        expect(inRes.transactionType, equals(AppConstants.typeIncome));
        expect(inRes.amountSantims, equals(200000));

        const airtimeSms = 'TD94RNM70H Confirmed. You have bought ETB 50.00 of airtime on 24/10/26 at 1:00 PM. New M-PESA balance is ETB 3,590.00.';
        final airRes = parserEngine.parse(airtimeSms, sender: '700');
        expect(airRes.isSuccess, isTrue);
        expect(airRes.merchant, equals('Safaricom Airtime Top-up'));
      });

      test('M-PESA: Pure balance alert does NOT create transaction', () {
        const balSms = 'Dear Customer, your New M-PESA balance is ETB 3,590.00.';
        final res = parserEngine.parse(balSms, sender: '700');
        expect(res.status, equals(ParseStatus.rejectedNonFinancial));
      });
    });

    // 6. Ethio telecom and Safaricom Telecom Matrix
    group('6. Ethio telecom & Safaricom Telecom Matrix', () {
      test('Ethio telecom: Package purchase creates expense transaction and bundle model', () async {
        const buySms = 'Dear customer, you have successfully purchased 10GB Monthly Data bundle for ETB 300.00. Valid until 2026-11-24 18:30:00.';
        final res = await ingestionService.processIncomingSms(rawMessage: buySms, sender: '994');
        expect(res.success, isTrue);
        expect(res.isTelecomUpdate, isTrue);
        expect(res.transaction, isNotNull);
        expect(res.transaction!.amountSantims, equals(30000));

        final bundles = await bundleRepo.getAllBundles();
        expect(bundles.isNotEmpty, isTrue);
        expect(bundles.first.originalAllowance, equals(10.0));
      });

      test('Ethio telecom: *804# balance check updates bundle without creating transaction', () async {
        const balSms = 'Dear Customer, your remaining package balance is 7.20 GB Data valid until 2026-11-24.';
        final res = await ingestionService.processIncomingSms(rawMessage: balSms, sender: 'Ethio telecom');
        expect(res.success, isTrue);
        expect(res.isTelecomUpdate, isTrue);
        expect(res.transaction, isNull); // Never creates an expense!

        final bundles = await bundleRepo.getAllBundles();
        expect(bundles.first.remainingAllowance, equals(7.20));
      });

      test('Safaricom Ethiopia: Package purchase creates expense and balance check does not', () async {
        const buySms = 'Dear customer, you have successfully purchased 5GB Weekly Data bundle for ETB 150.00. Valid until 2026-11-01 23:59:59.';
        final buyRes = await ingestionService.processIncomingSms(rawMessage: buySms, sender: 'Safaricom');
        expect(buyRes.success, isTrue);
        expect(buyRes.transaction, isNotNull);
        expect(buyRes.transaction!.amountSantims, equals(15000));

        const balSms = 'Your Safaricom balance: Data: 3.85 GB valid until 2026-11-01 23:59:59. Voice: 42 Minutes. SMS: 15.';
        final balRes = await ingestionService.processIncomingSms(rawMessage: balSms, sender: '704');
        expect(balRes.success, isTrue);
        expect(balRes.transaction, isNull); // Zero transaction generated!
      });

      test('Telecom: Unit conversions and renewal resets calculate usage accurately', () async {
        final now = DateTime.now();
        final bundle = TelecomBundleModel(
          id: 'b_unit_test',
          provider: AppConstants.providerEthioTelecom,
          bundleName: '500MB Daily',
          category: AppConstants.bundleCategoryData,
          originalAllowance: 500.0,
          remainingAllowance: 500.0,
          unit: 'MB',
          lastConfirmedTime: now,
        );
        await bundleRepo.saveBundle(bundle);

        // Used 150 MB
        final obs1 = await bundleRepo.recordObservation(
          bundleId: bundle.id,
          remainingAllowance: 350.0,
          unit: 'MB',
          sourceMessage: 'Remaining 350 MB',
          timestamp: now.add(const Duration(hours: 3)),
        );
        expect(obs1.estimatedUsageSincePrevious, equals(150.0));

        // Renewal / top-up: balance increases to 500 MB (usage must be 0, not negative!)
        final obs2 = await bundleRepo.recordObservation(
          bundleId: bundle.id,
          remainingAllowance: 500.0,
          unit: 'MB',
          sourceMessage: 'Renewed: 500 MB',
          timestamp: now.add(const Duration(hours: 6)),
        );
        expect(obs2.estimatedUsageSincePrevious, equals(0.0));
      });
    });
  });
}
