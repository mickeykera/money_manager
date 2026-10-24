import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerleaf/core/constants/app_constants.dart';
import 'package:ledgerleaf/core/utils/money.dart';
import 'package:ledgerleaf/data/csv/csv_service.dart';
import 'package:ledgerleaf/data/database/database_helper.dart';
import 'package:ledgerleaf/data/repositories/account_repository.dart';
import 'package:ledgerleaf/data/repositories/category_repository.dart';
import 'package:ledgerleaf/data/repositories/transaction_repository.dart';
import 'package:ledgerleaf/domain/models/filter_criteria.dart';
import 'package:ledgerleaf/domain/models/transaction_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Monetary Arithmetic & Minor Units Tests', () {
    test('Basic minor unit integrity (1 ETB = 100 Santims)', () {
      const m1 = Money(15000); // 150.00 ETB
      const m2 = Money(2550); // 25.50 ETB

      final sum = m1 + m2;
      expect(sum.santims, 17550);
      expect(sum.format(), 'ETB 175.50');

      final diff = m1 - m2;
      expect(diff.santims, 12450);
      expect(diff.format(), 'ETB 124.50');
    });

    test('Strict avoidance of floating-point drift', () {
      // 0.10 + 0.20 in float is 0.30000000000000004
      final tenCents = Money.parseString('0.10');
      final twentyCents = Money.parseString('0.20');
      final sum = tenCents + twentyCents;

      expect(sum.santims, 30);
      expect(sum.format(), 'ETB 0.30');
    });

    test('String parsing for various real-world numeric formats', () {
      expect(Money.parseString('1,250.75').santims, 125075);
      expect(Money.parseString('500').santims, 50000);
      expect(Money.parseString('500.5').santims, 50050);
      expect(Money.parseString('0.05').santims, 5);
      expect(Money.parseString('-45.20').santims, -4520);
      expect(Money.parseString('').santims, 0);
      expect(Money.parseString('   2,000,000.00   ').santims, 200000000);
    });

    test('Formatted output with commas and negative numbers', () {
      expect(const Money(123456789).format(), 'ETB 1,234,567.89');
      expect(const Money(-5000).format(), '-ETB 50.00');
      expect(const Money(0).format(), 'ETB 0.00');
    });
  });

  group('SQLite Persistence & Transaction Domain Tests', () {
    late Database db;
    late DatabaseHelper dbHelper;
    late TransactionRepository txRepo;
    late AccountRepository accountRepo;
    late CategoryRepository categoryRepo;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON;');
          },
          onCreate: (db, version) async {
            dbHelper = DatabaseHelper();
            dbHelper.setDatabaseForTesting(db);
            // Use internal tables creation & seeding
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
                updated_at INTEGER NOT NULL,
                FOREIGN KEY (category_id) REFERENCES categories (id),
                FOREIGN KEY (account_id) REFERENCES accounts (id)
              );
            ''');

            // Seed test account and categories
            final now = DateTime.now().millisecondsSinceEpoch;
            await db.insert('accounts', {
              'id': 'acc_cbe',
              'name': 'CBE Account',
              'type': 'bank',
              'balance_santims': 100000, // 1,000 ETB initial
              'currency': 'ETB',
              'created_at': now,
              'updated_at': now,
            });
            await db.insert('accounts', {
              'id': 'acc_telebirr',
              'name': 'Telebirr Wallet',
              'type': 'mobile_money',
              'balance_santims': 50000, // 500 ETB initial
              'currency': 'ETB',
              'created_at': now,
              'updated_at': now,
            });
            await db.insert('categories', {
              'id': 'cat_food',
              'name': 'Food & Groceries',
              'icon_code_point': 0xe532,
              'color_value': 0xFFE07A5F,
              'monthly_budget_santims': 500000, // 5,000 ETB
              'is_income': 0,
              'created_at': now,
            });
            await db.insert('categories', {
              'id': 'cat_income',
              'name': 'Salary & Income',
              'icon_code_point': 0xe041,
              'color_value': 0xFF2A9D8F,
              'monthly_budget_santims': 0,
              'is_income': 1,
              'created_at': now,
            });
          },
        ),
      );

      dbHelper = DatabaseHelper();
      dbHelper.setDatabaseForTesting(db);
      txRepo = TransactionRepository(dbHelper: dbHelper);
      accountRepo = AccountRepository(dbHelper: dbHelper);
      categoryRepo = CategoryRepository(dbHelper: dbHelper);
    });

    tearDown(() async {
      await db.close();
    });

    test('Expense insertion decreases account balance correctly', () async {
      final tx = TransactionModel(
        id: 'tx_1',
        amountSantims: 25000, // 250 ETB expense
        type: AppConstants.typeExpense,
        merchant: 'Kaldi\'s Coffee',
        timestamp: DateTime.now(),
        categoryId: 'cat_food',
        accountId: 'acc_cbe',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await txRepo.insertTransaction(tx);

      final acc = await accountRepo.getAccountById('acc_cbe');
      expect(acc?.balanceSantims, 75000); // 1000 - 250 = 750 ETB
    });

    test('Income insertion increases account balance correctly', () async {
      final tx = TransactionModel(
        id: 'tx_income_1',
        amountSantims: 150000, // 1,500 ETB income
        type: AppConstants.typeIncome,
        merchant: 'Client Payment',
        timestamp: DateTime.now(),
        categoryId: 'cat_income',
        accountId: 'acc_cbe',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await txRepo.insertTransaction(tx);

      final acc = await accountRepo.getAccountById('acc_cbe');
      expect(acc?.balanceSantims, 250000); // 1000 + 1500 = 2500 ETB
    });

    test('Refund and Reversal credit back account balance', () async {
      final refundTx = TransactionModel(
        id: 'tx_refund_1',
        amountSantims: 5000, // 50 ETB refund
        type: AppConstants.typeRefund,
        merchant: 'Supermarket Refund',
        timestamp: DateTime.now(),
        categoryId: 'cat_food',
        accountId: 'acc_cbe',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await txRepo.insertTransaction(refundTx);

      final acc = await accountRepo.getAccountById('acc_cbe');
      expect(acc?.balanceSantims, 105000); // 1000 + 50 = 1050 ETB
    });

    test('Transaction deletion restores account balance accurately', () async {
      final tx = TransactionModel(
        id: 'tx_del_1',
        amountSantims: 30000, // 300 ETB expense
        type: AppConstants.typeExpense,
        merchant: 'Bookstore',
        timestamp: DateTime.now(),
        categoryId: 'cat_food',
        accountId: 'acc_cbe',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await txRepo.insertTransaction(tx);
      var acc = await accountRepo.getAccountById('acc_cbe');
      expect(acc?.balanceSantims, 70000); // 1000 - 300 = 700

      // Delete transaction
      await txRepo.deleteTransaction('tx_del_1');
      acc = await accountRepo.getAccountById('acc_cbe');
      expect(acc?.balanceSantims, 100000); // Restored to 1000
    });

    test('Transaction update adjusts balance accurately', () async {
      final tx = TransactionModel(
        id: 'tx_upd_1',
        amountSantims: 20000, // 200 ETB expense
        type: AppConstants.typeExpense,
        merchant: 'Lunch',
        timestamp: DateTime.now(),
        categoryId: 'cat_food',
        accountId: 'acc_cbe',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await txRepo.insertTransaction(tx);
      var acc = await accountRepo.getAccountById('acc_cbe');
      expect(acc?.balanceSantims, 80000); // 1000 - 200 = 800

      // Edit amount to 350 ETB
      final updatedTx = tx.copyWith(amountSantims: 35000);
      await txRepo.updateTransaction(updatedTx);

      acc = await accountRepo.getAccountById('acc_cbe');
      expect(acc?.balanceSantims, 65000); // 1000 - 350 = 650
    });

    test('Deduplication prevents double-insertion of duplicate messages', () async {
      final now = DateTime.now();
      const fingerprint = 'sha256_mock_fingerprint_123';
      const reference = 'FT242980001';

      final tx = TransactionModel(
        id: 'tx_dup_1',
        amountSantims: 15000,
        type: AppConstants.typeExpense,
        merchant: 'Cafe',
        timestamp: now,
        categoryId: 'cat_food',
        accountId: 'acc_cbe',
        sourceFingerprint: fingerprint,
        reference: reference,
        createdAt: now,
        updatedAt: now,
      );

      await txRepo.insertTransaction(tx);

      // Check duplicate by fingerprint
      expect(await txRepo.isDuplicate(fingerprint), isTrue);

      // Check duplicate by bank reference
      expect(await txRepo.isDuplicate('', reference: reference), isTrue);

      // Check duplicate by 10-minute sliding window with same amount
      expect(
        await txRepo.isDuplicate('', amountSantims: 15000, timestamp: now.add(const Duration(minutes: 3))),
        isTrue,
      );

      // Different legitimate transaction outside window is NOT duplicate
      expect(
        await txRepo.isDuplicate('different_fp',
            reference: 'DIFF_REF',
            amountSantims: 15000,
            timestamp: now.add(const Duration(minutes: 45))),
        isFalse,
      );
    });

    test('Dashboard calculations compute net cash flow & remaining budget', () async {
      final start = DateTime(2026, 10, 1);
      final end = DateTime(2026, 10, 31, 23, 59, 59);

      // Income: 10,000 ETB
      await txRepo.insertTransaction(TransactionModel(
        id: 'dash_in_1',
        amountSantims: 1000000,
        type: AppConstants.typeIncome,
        merchant: 'Monthly Salary',
        timestamp: DateTime(2026, 10, 5),
        categoryId: 'cat_income',
        accountId: 'acc_cbe',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Expense 1: 1,500 ETB
      await txRepo.insertTransaction(TransactionModel(
        id: 'dash_ex_1',
        amountSantims: 150000,
        type: AppConstants.typeExpense,
        merchant: 'Groceries',
        timestamp: DateTime(2026, 10, 10),
        categoryId: 'cat_food',
        accountId: 'acc_cbe',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Expense 2: 500 ETB
      await txRepo.insertTransaction(TransactionModel(
        id: 'dash_ex_2',
        amountSantims: 50000,
        type: AppConstants.typeExpense,
        merchant: 'Snacks',
        timestamp: DateTime(2026, 10, 12),
        categoryId: 'cat_food',
        accountId: 'acc_cbe',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final summary = await txRepo.getDashboardSummary(startDate: start, endDate: end);

      expect(summary.totalIncomeSantims, 1000000); // 10,000 ETB
      expect(summary.totalExpenseSantims, 200000); // 2,000 ETB
      expect(summary.netCashflow.santims, 800000); // 8,000 ETB net cash flow
      expect(summary.totalBudgetSantims, 500000); // 5,000 ETB food budget
      expect(summary.totalRemainingBudgetSantims, 300000); // 3,000 ETB remaining

      final foodSummary = summary.categoryBreakdown.firstWhere((c) => c.categoryId == 'cat_food');
      expect(foodSummary.spentSantims, 200000);
      expect(foodSummary.percentageUsed, 0.40); // 40% utilized
    });

    test('CSV export and import round-trip preserves transactions', () async {
      final csvService = CsvService(
        transactionRepo: txRepo,
        categoryRepo: categoryRepo,
        accountRepo: accountRepo,
      );

      final exportedCsv = await csvService.exportTransactionsToCsv();
      expect(exportedCsv.contains('Transaction ID'), isTrue);
      expect(exportedCsv.contains('Amount (ETB)'), isTrue);

      // Create new CSV string with a test transaction
      const syntheticCsv = '''Transaction ID,Date & Time (ISO),Type,Merchant / Description,Amount (ETB),Currency,Category,Account,Bank Reference,Source,Notes
tx_csv_1,2026-10-24 10:00:00,expense,Shoa Mart,750.50,ETB,Food & Groceries,CBE Account,FT242989999,csv,Weekly fruits
''';

      final importedCount = await csvService.importTransactionsFromCsv(syntheticCsv);
      expect(importedCount, 1);

      final importedTx = await txRepo.getTransactions(
        const FilterCriteria(searchQuery: 'Shoa Mart'),
      );
      expect(importedTx.isNotEmpty, isTrue);
      expect(importedTx.first.amountSantims, 75050);
      expect(importedTx.first.merchant, 'Shoa Mart');
    });
  });
}
