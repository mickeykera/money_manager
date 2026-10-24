import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerleaf/core/constants/app_constants.dart';
import 'package:ledgerleaf/data/database/database_helper.dart';
import 'package:ledgerleaf/data/repositories/account_repository.dart';
import 'package:ledgerleaf/data/repositories/bundle_repository.dart';
import 'package:ledgerleaf/data/repositories/settings_repository.dart';
import 'package:ledgerleaf/data/repositories/transaction_repository.dart';
import 'package:ledgerleaf/domain/models/bundle_model.dart';
import 'package:ledgerleaf/parser/telecom/ethio_telecom_parser.dart';
import 'package:ledgerleaf/parser/telecom/safaricom_telecom_parser.dart';
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

    test('canParse recognizes Ethio telecom senders and text', () {
      expect(parser.canParse('You have purchased 10GB monthly package', '994'), isTrue);
      expect(parser.canParse('Dear Customer, your remaining balance is 7.2GB Data', 'ethiotelecom'), isTrue);
      expect(parser.canParse('ኢትዮ ቴሌኮም፡ የ 10GB ፓኬጅ በተሳካ ሁኔታ ገዝተዋል', '127'), isTrue);
      expect(parser.canParse('CBE: You spent ETB 50.00', '127'), isFalse);
    });

    test('parses 10GB monthly purchase with price and expiry', () {
      const sms = 'Dear customer, you have successfully purchased 10GB Monthly Data bundle for ETB 300.00. Valid until 2026-11-24 18:30:00.';
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
      const sms = 'Dear Customer, your remaining package balance is 7.20 GB Data valid until 2026-11-24.';
      final result = parser.parse(sms, 'Ethio telecom');

      expect(result.isRecognized, isTrue);
      expect(result.isBalanceUpdate, isTrue);
      expect(result.isPurchase, isFalse);
      expect(result.purchasePriceSantims, isNull);
      expect(result.remainingAllowance, equals(7.20));
      expect(result.unit, equals('GB'));
    });

    test('parses Amharic package purchase', () {
      const sms = 'ውድ ደንበኛችን፡ የ 500 MB ዕለታዊ የኢንተርኔት ፓኬጅ በብር 35.00 በተሳካ ሁኔታ ገዝተዋል እስከ 2026-10-25 ድረስ የሚያገለግል።';
      final result = parser.parse(sms, 'Ethio telecom');

      expect(result.isRecognized, isTrue);
      expect(result.isPurchase, isTrue);
      expect(result.originalAllowance, equals(500.0));
      expect(result.unit, equals('MB'));
      expect(result.purchasePriceSantims, equals(3500));
    });
  });

  group('SafaricomTelecomParser Tests', () {
    late SafaricomTelecomParser parser;

    setUp(() {
      parser = SafaricomTelecomParser();
    });

    test('canParse recognizes Safaricom telecom senders and text', () {
      expect(parser.canParse('You have successfully purchased 5GB Weekly Data bundle for ETB 150.00', '700'), isTrue);
      expect(parser.canParse('Your Safaricom balance: Data: 3.85 GB valid until 2026-11-01', '704'), isTrue);
    });

    test('parses 5GB weekly purchase with price and expiry', () {
      const sms = 'Dear customer, you have successfully purchased 5GB Weekly Data bundle for ETB 150.00. Valid until 2026-11-01 23:59:59.';
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
      const sms = 'Your Safaricom balance: Data: 3.85 GB valid until 2026-11-01 23:59:59. Voice: 42 Minutes. SMS: 15.';
      final result = parser.parse(sms, '704');

      expect(result.isRecognized, isTrue);
      expect(result.isBalanceUpdate, isTrue);
      expect(result.isPurchase, isFalse);
      expect(result.remainingAllowance, equals(3.85));
      expect(result.unit, equals('GB'));
      expect(result.purchasePriceSantims, isNull);
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

    test('saves bundle and tracks multiple observations with usage calculation', () async {
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
    });

    test('getTelecomSummary aggregates active bundles correctly', () async {
      final now = DateTime.now();
      await bundleRepo.saveBundle(TelecomBundleModel(
        id: 'ethio_1',
        provider: AppConstants.providerEthioTelecom,
        bundleName: 'Ethio 10GB',
        category: AppConstants.bundleCategoryData,
        originalAllowance: 10.0,
        remainingAllowance: 7.20,
        unit: 'GB',
        expiryTime: now.add(const Duration(days: 10)),
        lastConfirmedTime: now,
      ));

      await bundleRepo.saveBundle(TelecomBundleModel(
        id: 'safari_1',
        provider: AppConstants.providerSafaricom,
        bundleName: 'Safaricom 5GB',
        category: AppConstants.bundleCategoryData,
        originalAllowance: 5.0,
        remainingAllowance: 3.85,
        unit: 'GB',
        expiryTime: now.add(const Duration(days: 5)),
        lastConfirmedTime: now,
      ));

      final summary = await bundleRepo.getTelecomSummary();
      expect(summary.ethioDataRemainingGb, equals(7.20));
      expect(summary.safaricomDataRemainingGb, equals(3.85));
      expect(summary.totalDataRemainingGb, equals(11.05));
      expect(summary.activeBundles.length, equals(2));
      expect(summary.nextKnownExpiry, isNotNull);
      expect(summary.nextKnownExpiry!.day, equals(now.add(const Duration(days: 5)).day));
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
      const sms = 'Dear customer, you have successfully purchased 10GB Monthly Data bundle for ETB 300.00. Valid until 2026-11-24 18:30:00.';
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
      const sms = 'Dear Customer, your remaining package balance is 7.20 GB Data valid until 2026-11-24.';
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
  });
}
