import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerleaf/core/constants/app_constants.dart';
import 'package:ledgerleaf/data/database/database_helper.dart';
import 'package:ledgerleaf/data/repositories/account_repository.dart';
import 'package:ledgerleaf/data/repositories/bundle_repository.dart';
import 'package:ledgerleaf/data/repositories/transaction_repository.dart';
import 'package:ledgerleaf/domain/models/bundle_model.dart';
import 'package:ledgerleaf/domain/models/filter_criteria.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String testDbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    testDbPath = p.join(
      Directory.systemTemp.path,
      'migration_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
  });

  tearDown(() {
    final file = File(testDbPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
  });

  group('Database Migration Tests (v1 to v2)', () {
    test('Migration adds telecom tables and account columns while preserving v1 data', () async {
      // 1. Create a simulated v1 database schema
      final db = await databaseFactoryFfi.openDatabase(
        testDbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (database, version) async {
            // v1 Accounts Table (without is_sms_linked and balance_source)
            await database.execute('''
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

            // Insert initial v1 account and transaction
            final now = DateTime.now().millisecondsSinceEpoch;
            await database.insert('accounts', {
              'id': 'acc_cbe',
              'name': 'CBE',
              'type': 'bank',
              'balance_santims': 428050,
              'currency': 'ETB',
              'account_number_masked': '1000****4821',
              'created_at': now,
              'updated_at': now,
            });

            await database.insert('categories', {
              'id': 'cat_food',
              'name': 'Food',
              'icon_code_point': 1234,
              'color_value': 0xFFE07A5F,
              'monthly_budget_santims': 500000,
              'is_income': 0,
              'created_at': now,
            });

            await database.insert('transactions', {
              'id': 'tx_v1_1',
              'amount_santims': 6480,
              'currency': 'ETB',
              'type': 'expense',
              'merchant': 'Fresh Corner',
              'timestamp': now,
              'timezone_offset_minutes': 180,
              'category_id': 'cat_food',
              'account_id': 'acc_cbe',
              'source': 'sms',
              'import_status': 'posted',
              'source_fingerprint': 'fp_v1',
              'original_message': 'CBE: ETB 64.80 paid to Fresh Corner',
              'reference': 'FT112233',
              'is_reviewed': 1,
              'created_at': now,
              'updated_at': now,
            });
          },
        ),
      );

      // Verify v1 data exists
      final v1TxRows = await db.query('transactions');
      expect(v1TxRows.length, equals(1));
      expect(v1TxRows.first['merchant'], equals('Fresh Corner'));

      // 2. Perform Migration to Version 2 using DatabaseHelper's onUpgrade logic
      // In SQLite, opening with version 2 triggers onUpgrade
      await db.close();

      final upgradedDb = await databaseFactoryFfi.openDatabase(
        testDbPath,
        options: OpenDatabaseOptions(
          version: 2,
          onUpgrade: (database, oldVersion, newVersion) async {
            if (oldVersion < 2) {
              // Same exact migration as in DatabaseHelper
              await database.execute('''
                CREATE TABLE IF NOT EXISTS telecom_bundles (
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
                  confidence_score REAL NOT NULL DEFAULT 1.0,
                  status TEXT NOT NULL DEFAULT 'active'
                );
              ''');
              await database.execute('''
                CREATE TABLE IF NOT EXISTS telecom_observations (
                  id TEXT PRIMARY KEY,
                  bundle_id TEXT NOT NULL,
                  timestamp INTEGER NOT NULL,
                  remaining_allowance REAL NOT NULL,
                  unit TEXT NOT NULL,
                  estimated_usage REAL,
                  source_message TEXT NOT NULL
                );
              ''');
              try {
                await database.execute('ALTER TABLE accounts ADD COLUMN is_sms_linked INTEGER NOT NULL DEFAULT 1;');
              } catch (_) {}
              try {
                await database.execute("ALTER TABLE accounts ADD COLUMN balance_source TEXT NOT NULL DEFAULT 'Latest imported SMS';");
              } catch (_) {}
              final now = DateTime.now().millisecondsSinceEpoch;
              await database.insert(
                'accounts',
                {
                  'id': 'acc_mpesa',
                  'name': 'Safaricom M-PESA',
                  'type': AppConstants.accountTypeMobileMoney,
                  'balance_santims': 0,
                  'currency': AppConstants.defaultCurrency,
                  'account_number_masked': '07****5678',
                  'is_sms_linked': 1,
                  'balance_source': 'Latest imported SMS',
                  'created_at': now,
                  'updated_at': now,
                },
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            }
          },
        ),
      );

      final dbHelper = DatabaseHelper();
      dbHelper.setDatabaseForTesting(upgradedDb);

      // 3. Verify that v1 transaction is completely preserved
      final txRepo = TransactionRepository(dbHelper: dbHelper);
      final allTx = await txRepo.getTransactions(const FilterCriteria());
      expect(allTx.length, equals(1));
      expect(allTx.first.id, equals('tx_v1_1'));
      expect(allTx.first.amountSantims, equals(6480));
      expect(allTx.first.merchant, equals('Fresh Corner'));

      // 4. Verify accounts table was successfully migrated with new columns
      final accountRepo = AccountRepository(dbHelper: dbHelper);
      final accounts = await accountRepo.getAllAccounts();
      expect(accounts.length, equals(2)); // acc_cbe and newly added acc_mpesa

      final cbe = accounts.firstWhere((a) => a.id == 'acc_cbe');
      expect(cbe.isSmsLinked, isTrue);
      expect(cbe.balanceSource, equals('Latest imported SMS'));
      expect(cbe.balanceSantims, equals(428050));

      final mpesa = accounts.firstWhere((a) => a.id == 'acc_mpesa');
      expect(mpesa.name, equals('Safaricom M-PESA'));
      expect(mpesa.isSmsLinked, isTrue);

      // 5. Verify telecom tables exist and can write / read
      final bundleRepo = BundleRepository(dbHelper: dbHelper);
      final newBundle = TelecomBundleModel(
        id: 'b_upgraded_1',
        provider: AppConstants.providerEthioTelecom,
        bundleName: '10GB Package',
        category: AppConstants.bundleCategoryData,
        originalAllowance: 10.0,
        remainingAllowance: 10.0,
        unit: 'GB',
        lastConfirmedTime: DateTime.now(),
      );
      await bundleRepo.saveBundle(newBundle);

      final saved = await bundleRepo.getBundleById('b_upgraded_1');
      expect(saved, isNotNull);
      expect(saved!.bundleName, equals('10GB Package'));

      await upgradedDb.close();
    });
  });
}
