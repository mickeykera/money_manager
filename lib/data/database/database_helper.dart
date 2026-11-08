import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/account_model.dart';
import '../../domain/models/bundle_model.dart';
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

    return _openDatabaseWithRecovery(dbPath);
  }

  /// Opens the local vault and recovers from the failures that can otherwise
  /// leave the app stuck on the startup error screen.
  ///
  /// Recovery order:
  /// 1. Normal open (runs schema creation/migrations).
  /// 2. One short retry for a transient lock.
  /// 3. In-place repair of a partially migrated or inconsistent schema.
  /// 4. Quarantine the unusable file (keeping a copy) and create a fresh vault.
  Future<Database> _openDatabaseWithRecovery(String dbPath) async {
    try {
      return await _openDatabaseAt(dbPath);
    } catch (error, stackTrace) {
      debugPrint(
        'LedgerLeaf database open failed: $error\n$stackTrace',
      );

      if (_isLockError(error)) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        try {
          return await _openDatabaseAt(dbPath);
        } catch (retryError) {
          debugPrint('LedgerLeaf database retry failed: $retryError');
          rethrow;
        }
      }

      final repaired = await _tryRepairInPlace(dbPath);
      if (repaired != null) return repaired;

      // The file cannot be opened or repaired. Preserve it for manual recovery
      // and start with a fresh schema so the user can keep using the app.
      debugPrint('LedgerLeaf database is unusable; quarantining $dbPath');
      await _quarantineDatabase(dbPath);
      return _openDatabaseAt(dbPath);
    }
  }

  Future<Database> _openDatabaseAt(String dbPath) {
    return openDatabase(
      dbPath,
      version: AppConstants.databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA journal_mode = WAL;');
        await db.execute('PRAGMA busy_timeout = 5000;');
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedDefaultData(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Migration to v2: Add telecom bundles and observations
          await _createTelecomTables(db);
          try {
            await db.execute('ALTER TABLE accounts ADD COLUMN is_sms_linked INTEGER NOT NULL DEFAULT 1;');
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE accounts ADD COLUMN balance_source TEXT NOT NULL DEFAULT 'Latest imported SMS';");
          } catch (_) {}
          // Add M-PESA account if not present
          final now = DateTime.now().millisecondsSinceEpoch;
          await db.insert(
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
      onOpen: (db) async {
        // Repairs databases whose user_version already matches but whose
        // schema is incomplete (for example after an interrupted migration).
        await repairSchema(db);
      },
    );
  }

  /// Opens the raw file without version checks, verifies integrity, repairs the
  /// schema in place, then reopens normally. Returns null when the file cannot
  /// be repaired.
  Future<Database?> _tryRepairInPlace(String dbPath) async {
    Database? raw;
    try {
      raw = await openDatabase(dbPath);
      final integrity = await raw.rawQuery('PRAGMA integrity_check;');
      final integrityResult = integrity.isEmpty
          ? null
          : integrity.first.values.first?.toString().toLowerCase();
      if (integrityResult != 'ok') {
        debugPrint(
          'LedgerLeaf database integrity check failed: $integrityResult',
        );
        await raw.close();
        return null;
      }

      await repairSchema(raw);
      await raw.close();
      return await _openDatabaseAt(dbPath);
    } catch (error, stackTrace) {
      debugPrint(
        'LedgerLeaf database repair failed: $error\n$stackTrace',
      );
      try {
        await raw?.close();
      } catch (_) {}
      return null;
    }
  }

  /// Makes the schema idempotent so an older or partially migrated database can
  /// be opened without losing its transactions.
  Future<void> repairSchema(DatabaseExecutor db) async {
    // Add v2 account columns before creating/altering anything else. If the
    // accounts table does not exist yet, _createTables below creates it with
    // the full schema.
    final accountColumns = await _columnNames(db, 'accounts');
    if (accountColumns.isNotEmpty) {
      if (!accountColumns.contains('is_sms_linked')) {
        await db.execute(
          'ALTER TABLE accounts ADD COLUMN is_sms_linked INTEGER NOT NULL DEFAULT 1;',
        );
      }
      if (!accountColumns.contains('balance_source')) {
        await db.execute(
          "ALTER TABLE accounts ADD COLUMN balance_source TEXT NOT NULL DEFAULT 'Latest imported SMS';",
        );
      }
    }

    await _createTables(db);

    // Seed defaults only when a core table is empty (fresh or heavily damaged
    // database). Each table is handled independently so user deletions in other
    // tables are preserved.
    final hasAccounts = await _tableHasRows(db, 'accounts');
    final hasCategories = await _tableHasRows(db, 'categories');
    final hasSettings = await _tableHasRows(db, 'settings');
    if (!hasAccounts) {
      await _seedDefaultData(
        db,
        includeSample: false,
        seedCategories: false,
        seedSettings: false,
      );
    }
    if (!hasCategories) {
      await _seedDefaultData(
        db,
        includeSample: false,
        seedAccounts: false,
        seedSettings: false,
      );
    }
    if (!hasSettings) {
      await _seedDefaultData(
        db,
        includeSample: false,
        seedAccounts: false,
        seedCategories: false,
      );
    }
  }

  Future<bool> _tableHasRows(DatabaseExecutor db, String table) async {
    try {
      final rows = await db.rawQuery('SELECT 1 FROM $table LIMIT 1;');
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<Set<String>> _columnNames(
    DatabaseExecutor db,
    String table,
  ) async {
    try {
      final rows = await db.rawQuery('PRAGMA table_info($table);');
      return rows
          .map((row) => row['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  bool _isLockError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('locked') || message.contains('busy');
  }

  /// Keeps the original file (with a `.corrupt-<timestamp>` suffix) for manual
  /// recovery, then removes the SQLite sidecar files so a fresh database can be
  /// created at the same path.
  Future<void> _quarantineDatabase(String dbPath) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (final suffix in const ['', '-wal', '-shm']) {
      final file = File('$dbPath$suffix');
      if (!await file.exists()) continue;
      try {
        await file.rename('$dbPath.corrupt-$stamp$suffix');
      } catch (_) {
        // If the file cannot be renamed, deleting is the only way to recover.
        await file.delete();
      }
    }
  }

  Future<String> _getDatabasePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, AppConstants.databaseName);
  }

  Future<void> _createTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
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
      CREATE TABLE IF NOT EXISTS categories (
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
      CREATE TABLE IF NOT EXISTS transactions (
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
      CREATE INDEX IF NOT EXISTS idx_transactions_timestamp ON transactions (timestamp DESC);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions (category_id);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transactions_account ON transactions (account_id);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions (type);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_transactions_fingerprint ON transactions (source_fingerprint);
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ingestion_logs (
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
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    await _createTelecomTables(db);
  }

  Future<void> _createTelecomTables(DatabaseExecutor db) async {
    await db.execute('''
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS telecom_observations (
        id TEXT PRIMARY KEY,
        bundle_id TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        remaining_allowance REAL NOT NULL,
        unit TEXT NOT NULL,
        estimated_usage REAL,
        source_message TEXT NOT NULL,
        FOREIGN KEY (bundle_id) REFERENCES telecom_bundles (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_telecom_bundles_provider ON telecom_bundles (provider);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_telecom_observations_bundle ON telecom_observations (bundle_id);
    ''');
  }

  Future<void> _seedDefaultData(
    DatabaseExecutor db, {
    bool includeSample = true,
    bool seedAccounts = true,
    bool seedCategories = true,
    bool seedSettings = true,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Default Ethiopian Accounts
    final accounts = [
      AccountModel(
        id: 'acc_cbe',
        name: 'Commercial Bank of Ethiopia (CBE)',
        type: AppConstants.accountTypeBank,
        balanceSantims: 0,
        currency: AppConstants.defaultCurrency,
        accountNumberMasked: '1000****0001',
        isSmsLinked: true,
        balanceSource: 'Latest imported SMS',
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
        isSmsLinked: true,
        balanceSource: 'Latest imported SMS',
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
      AccountModel(
        id: 'acc_mpesa',
        name: 'Safaricom M-PESA',
        type: AppConstants.accountTypeMobileMoney,
        balanceSantims: 0,
        currency: AppConstants.defaultCurrency,
        accountNumberMasked: '07****5678',
        isSmsLinked: true,
        balanceSource: 'Latest imported SMS',
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
        isSmsLinked: true,
        balanceSource: 'Latest imported SMS',
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
      AccountModel(
        id: 'acc_cash',
        name: 'Cash in Hand',
        type: AppConstants.accountTypeCash,
        balanceSantims: 0,
        currency: AppConstants.defaultCurrency,
        isSmsLinked: false,
        balanceSource: 'Manual entry',
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      ),
    ];

    if (seedAccounts) {
      for (final acc in accounts) {
        await db.insert(
          'accounts',
          acc.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
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
        id: 'cat_telecom',
        name: 'Telecom & Internet',
        iconCodePoint: Icons.wifi.codePoint,
        colorValue: 0xFF2B533E,
        monthlyBudgetSantims: 100000, // 1,000 ETB
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

    if (seedCategories) {
      for (final cat in categories) {
        await db.insert(
          'categories',
          cat.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
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

    if (seedSettings) {
      for (final entry in settings.entries) {
        await db.insert(
          'settings',
          {'key': entry.key, 'value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }

    if (!includeSample) return;

    // Seed realistic sample active bundle for immediate preview
    final expiry = DateTime.now().add(const Duration(days: 20));
    final sampleBundle = TelecomBundleModel(
      id: 'bundle_ethio_sample',
      provider: AppConstants.providerEthioTelecom,
      bundleName: '[Sample Preview] Monthly 10GB Data',
      category: AppConstants.bundleCategoryData,
      originalAllowance: 10.0,
      remainingAllowance: 7.20,
      unit: 'GB',
      activationTime: DateTime.now().subtract(const Duration(days: 10)),
      expiryTime: expiry,
      purchasePriceSantims: 30000, // 300 ETB
      lastConfirmedTime: DateTime.now(),
      status: 'active',
      sourceMessage: '[Sample Preview] Dear customer, your remaining data balance is 7.20 GB valid until ${expiry.toIso8601String().substring(0, 10)}.',
    );
    await db.insert(
      'telecom_bundles',
      sampleBundle.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    final sampleObs = BundleObservationModel(
      id: 'obs_sample_1',
      bundleId: 'bundle_ethio_sample',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      remainingAllowance: 7.20,
      unit: 'GB',
      estimatedUsageSincePrevious: 0.80,
      sourceMessage: sampleBundle.sourceMessage ?? '',
    );
    await db.insert(
      'telecom_observations',
      sampleObs.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Wipe all data and re-seed
  Future<void> wipeAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('ingestion_logs');
      await txn.delete('telecom_observations');
      await txn.delete('telecom_bundles');
      await txn.delete('categories');
      await txn.delete('accounts');
      await txn.delete('settings');
      await _seedDefaultData(txn);
    });
  }

  /// Completely deletes the local database file (including WAL and SHM journals)
  /// and recreates a fresh database instance from scratch.
  Future<void> wipeAndRecreateDatabase() async {
    await close();
    final dbPath = await _getDatabasePath();
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }
    final walFile = File('$dbPath-wal');
    if (await walFile.exists()) {
      await walFile.delete();
    }
    final shmFile = File('$dbPath-shm');
    if (await shmFile.exists()) {
      await shmFile.delete();
    }
    _db = await _initDatabase();
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
