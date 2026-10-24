import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerleaf/core/constants/app_constants.dart';
import 'package:ledgerleaf/data/database/database_helper.dart';
import 'package:ledgerleaf/data/repositories/account_repository.dart';
import 'package:ledgerleaf/data/repositories/category_repository.dart';
import 'package:ledgerleaf/data/repositories/settings_repository.dart';
import 'package:ledgerleaf/data/repositories/transaction_repository.dart';
import 'package:ledgerleaf/domain/models/filter_criteria.dart';
import 'package:ledgerleaf/parser/parser_engine.dart';
import 'package:ledgerleaf/services/app_state.dart';
import 'package:ledgerleaf/services/ingestion_service.dart';
import 'package:ledgerleaf/services/native_bridge.dart';
import 'package:path/path.dart' as p;
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
    late CategoryRepository categoryRepo;
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
      categoryRepo = CategoryRepository(dbHelper: dbHelper);
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

      // Verify account balance updated (5,000 - 350 = 4,650 ETB = 465000 santims)
      final acc = await accountRepo.getAccountById('acc_cbe');
      expect(acc?.balanceSantims, 465000);

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
  });
}
