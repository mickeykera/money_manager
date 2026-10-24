import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/account_model.dart';
import '../../domain/models/category_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;

  /// Custom database instance (used for testing in-memory databases)
  void setDatabaseForTesting(Database db) {
    _db = db;
  }

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    // If on Linux/Windows/Mac desktop without standard sqflite runner, use FFI
    if (kIsWeb) {
      throw UnsupportedError('Web is not supported');
    }

    if (Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await _getDatabasePath();
    final dbDir = Directory(p.dirname(dbPath));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    final db = await openDatabase(
      dbPath,
      version: AppConstants.databaseVersion,
      onConfigure: (db) async {
        // Enable WAL mode and busy timeout for concurrent native & Flutter access
        await db.execute('PRAGMA journal_mode = WAL;');
        await db.execute('PRAGMA busy_timeout = 5000;');
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedDefaultData(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Migration logic for future versions
      },
    );

    return db;
  }

  Future<String> _getDatabasePath() async {
    // On iOS, if App Group path is available, use it. Otherwise, use application documents directory.
    // For standard Flutter execution, application documents directory is safe.
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, AppConstants.databaseName);
  }

  Future<void> _createTables(DatabaseExecutor db) async {
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
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE RESTRICT,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_timestamp ON transactions (timestamp DESC);
    ''');
    await db.execute('''
      CREATE INDEX idx_transactions_category ON transactions (category_id);
    ''');
    await db.execute('''
      CREATE INDEX idx_transactions_account ON transactions (account_id);
    ''');
    await db.execute('''
      CREATE INDEX idx_transactions_type ON transactions (type);
    ''');
    await db.execute('''
      CREATE INDEX idx_transactions_fingerprint ON transactions (source_fingerprint);
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
  }

  Future<void> _seedDefaultData(DatabaseExecutor db) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Default Accounts
    final accounts = [
      AccountModel(
        id: 'acc_cbe',
        name: 'Commercial Bank of Ethiopia (CBE)',
        type: AppConstants.accountTypeBank,
        balanceSantims: 0,
        currency: AppConstants.defaultCurrency,
        accountNumberMasked: '1000****0001',
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
      AccountModel(
        id: 'acc_telebirr',
        name: 'Telebirr Wallet',
        type: AppConstants.accountTypeMobileMoney,
        balanceSantims: 0,
        currency: AppConstants.defaultCurrency,
        accountNumberMasked: '09****1234',
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
      AccountModel(
        id: 'acc_boa',
        name: 'Bank of Abyssinia',
        type: AppConstants.accountTypeBank,
        balanceSantims: 0,
        currency: AppConstants.defaultCurrency,
        accountNumberMasked: 'BOA****0002',
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
      AccountModel(
        id: 'acc_cash',
        name: 'Cash in Hand',
        type: AppConstants.accountTypeCash,
        balanceSantims: 0,
        currency: AppConstants.defaultCurrency,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
    ];

    for (final acc in accounts) {
      await db.insert('accounts', acc.toMap());
    }

    // Default Categories with appropriate icons & colors
    final categories = [
      CategoryModel(
        id: 'cat_food',
        name: 'Food & Groceries',
        iconCodePoint: Icons.restaurant.codePoint,
        colorValue: 0xFFE07A5F,
        monthlyBudgetSantims: 1500000, // 15,000 ETB
        isIncome: false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
      CategoryModel(
        id: 'cat_transport',
        name: 'Transport & Fuel',
        iconCodePoint: Icons.directions_car.codePoint,
        colorValue: 0xFF3D5A80,
        monthlyBudgetSantims: 500000, // 5,000 ETB
        isIncome: false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
      CategoryModel(
        id: 'cat_housing',
        name: 'Housing & Rent',
        iconCodePoint: Icons.home.codePoint,
        colorValue: 0xFF6B705C,
        monthlyBudgetSantims: 2500000, // 25,000 ETB
        isIncome: false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
      CategoryModel(
        id: 'cat_utilities',
        name: 'Utilities & Bills',
        iconCodePoint: Icons.bolt.codePoint,
        colorValue: 0xFF588157,
        monthlyBudgetSantims: 300000, // 3,000 ETB
        isIncome: false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
      CategoryModel(
        id: 'cat_shopping',
        name: 'Shopping',
        iconCodePoint: Icons.shopping_bag.codePoint,
        colorValue: 0xFFDDA15E,
        monthlyBudgetSantims: 600000, // 6,000 ETB
        isIncome: false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
      CategoryModel(
        id: 'cat_health',
        name: 'Health & Medical',
        iconCodePoint: Icons.local_hospital.codePoint,
        colorValue: 0xFFBC4749,
        monthlyBudgetSantims: 200000, // 2,000 ETB
        isIncome: false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
      CategoryModel(
        id: 'cat_education',
        name: 'Education',
        iconCodePoint: Icons.school.codePoint,
        colorValue: 0xFF457B9D,
        monthlyBudgetSantims: 200000, // 2,000 ETB
        isIncome: false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
      CategoryModel(
        id: 'cat_entertainment',
        name: 'Entertainment & Leisure',
        iconCodePoint: Icons.movie.codePoint,
        colorValue: 0xFF9B5DE5,
        monthlyBudgetSantims: 300000, // 3,000 ETB
        isIncome: false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
      CategoryModel(
        id: 'cat_transfer',
        name: 'Transfers & Financial',
        iconCodePoint: Icons.swap_horiz.codePoint,
        colorValue: 0xFF6C757D,
        monthlyBudgetSantims: 0,
        isIncome: false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
      CategoryModel(
        id: 'cat_fees',
        name: 'Bank & Mobile Fees',
        iconCodePoint: Icons.receipt_long.codePoint,
        colorValue: 0xFF7F4F24,
        monthlyBudgetSantims: 100000, // 1,000 ETB
        isIncome: false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
      CategoryModel(
        id: 'cat_income',
        name: 'Salary & Income',
        iconCodePoint: Icons.account_balance_wallet.codePoint,
        colorValue: 0xFF2A9D8F,
        monthlyBudgetSantims: 0,
        isIncome: true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
      CategoryModel(
        id: 'cat_other',
        name: 'Other',
        iconCodePoint: Icons.more_horiz.codePoint,
        colorValue: 0xFF8D99AE,
        monthlyBudgetSantims: 200000, // 2,000 ETB
        isIncome: false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
    ];

    for (final cat in categories) {
      await db.insert('categories', cat.toMap());
    }

    // Default Settings
    final settings = {
      AppConstants.keyCurrency: AppConstants.defaultCurrency,
      AppConstants.keyRetainOriginalSms: 'true',
      AppConstants.keySmsRetentionDays: '30',
      AppConstants.keyPrivacyMode: 'false',
      AppConstants.keyOnboardingCompleted: 'false',
      AppConstants.keyAutoCategorization: 'true',
      AppConstants.keyThemeMode: 'system',
    };

    for (final entry in settings.entries) {
      await db.insert('settings', {'key': entry.key, 'value': entry.value});
    }
  }

  /// Wipe all data and re-seed
  Future<void> wipeAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('ingestion_logs');
      await txn.delete('categories');
      await txn.delete('accounts');
      await txn.delete('settings');
      await _seedDefaultData(txn);
    });
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
