import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/budget_summary.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/filter_criteria.dart';
import '../../domain/models/transaction_model.dart';
import '../database/database_helper.dart';

class TransactionRepository {
  final DatabaseHelper _dbHelper;

  TransactionRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<void> insertTransaction(TransactionModel tx) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert('transactions', tx.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      // Adjust account balance
      await _applyBalanceChange(txn, tx.accountId, tx.type, tx.amountSantims, isReversal: false);

      // If it's a transfer with a linked transaction or account
      if (tx.isTransfer && tx.linkedTransactionId != null) {
        // Linked transaction logic handled if paired
      }
    });
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Fetch old transaction to revert balance
      final oldRows = await txn.query('transactions', where: 'id = ?', whereArgs: [tx.id]);
      if (oldRows.isNotEmpty) {
        final oldTx = TransactionModel.fromMap(oldRows.first);
        await _applyBalanceChange(txn, oldTx.accountId, oldTx.type, oldTx.amountSantims, isReversal: true);
      }

      await txn.update('transactions', tx.toMap(), where: 'id = ?', whereArgs: [tx.id]);
      await _applyBalanceChange(txn, tx.accountId, tx.type, tx.amountSantims, isReversal: false);
    });
  }

  Future<void> deleteTransaction(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final oldRows = await txn.query('transactions', where: 'id = ?', whereArgs: [id]);
      if (oldRows.isNotEmpty) {
        final oldTx = TransactionModel.fromMap(oldRows.first);
        await _applyBalanceChange(txn, oldTx.accountId, oldTx.type, oldTx.amountSantims, isReversal: true);
      }
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> _applyBalanceChange(
    DatabaseExecutor txn,
    String accountId,
    String type,
    int amountSantims, {
    required bool isReversal,
  }) async {
    int delta = 0;
    switch (type) {
      case AppConstants.typeExpense:
        delta = -amountSantims;
        break;
      case AppConstants.typeIncome:
      case AppConstants.typeRefund:
      case AppConstants.typeReversal:
        delta = amountSantims;
        break;
      case AppConstants.typeTransfer:
        delta = -amountSantims;
        break;
    }

    if (isReversal) {
      delta = -delta;
    }

    await txn.rawUpdate('''
      UPDATE accounts 
      SET balance_santims = balance_santims + ?, updated_at = ?
      WHERE id = ?
    ''', [delta, DateTime.now().millisecondsSinceEpoch, accountId]);
  }

  Future<TransactionModel?> getTransactionById(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return TransactionModel.fromMap(rows.first);
  }

  Future<TransactionModel?> findByFingerprint(String fingerprint) async {
    if (fingerprint.isEmpty) return null;
    final db = await _dbHelper.database;
    final rows = await db.query('transactions',
        where: 'source_fingerprint = ?', whereArgs: [fingerprint], limit: 1);
    if (rows.isEmpty) return null;
    return TransactionModel.fromMap(rows.first);
  }

  Future<bool> isDuplicate(String fingerprint, {String? reference, int? amountSantims, DateTime? timestamp}) async {
    final db = await _dbHelper.database;
    // 1. Direct fingerprint match
    if (fingerprint.isNotEmpty) {
      final rows = await db.query('transactions',
          where: 'source_fingerprint = ?', whereArgs: [fingerprint], limit: 1);
      if (rows.isNotEmpty) return true;
    }

    // 2. Exact bank reference match (if reference is available and meaningful)
    if (reference != null && reference.trim().length >= 4) {
      final rows = await db.query('transactions',
          where: 'reference = ?', whereArgs: [reference.trim()], limit: 1);
      if (rows.isNotEmpty) return true;
    }

    // 3. Sliding time window match (same amount within 10 minutes)
    if (amountSantims != null && timestamp != null) {
      final windowStart = timestamp.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch;
      final windowEnd = timestamp.add(const Duration(minutes: 10)).millisecondsSinceEpoch;
      final rows = await db.query('transactions',
          where: 'amount_santims = ? AND timestamp BETWEEN ? AND ?',
          whereArgs: [amountSantims, windowStart, windowEnd],
          limit: 1);
      if (rows.isNotEmpty) return true;
    }

    return false;
  }

  Future<List<TransactionModel>> getTransactions(FilterCriteria criteria) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    // Search query on merchant, reference, or notes
    if (criteria.searchQuery.trim().isNotEmpty) {
      final q = '%${criteria.searchQuery.trim()}%';
      whereClauses.add('(merchant LIKE ? OR reference LIKE ? OR notes LIKE ?)');
      whereArgs.addAll([q, q, q]);
    }

    if (criteria.categoryId != null) {
      whereClauses.add('category_id = ?');
      whereArgs.add(criteria.categoryId);
    }

    if (criteria.accountId != null) {
      whereClauses.add('account_id = ?');
      whereArgs.add(criteria.accountId);
    }

    if (criteria.transactionType != null) {
      whereClauses.add('type = ?');
      whereArgs.add(criteria.transactionType);
    }

    if (criteria.startDate != null) {
      whereClauses.add('timestamp >= ?');
      whereArgs.add(criteria.startDate!.millisecondsSinceEpoch);
    }

    if (criteria.endDate != null) {
      whereClauses.add('timestamp <= ?');
      whereArgs.add(criteria.endDate!.millisecondsSinceEpoch);
    }

    if (criteria.isReviewed != null) {
      whereClauses.add('is_reviewed = ?');
      whereArgs.add(criteria.isReviewed! ? 1 : 0);
    }

    String orderBy;
    switch (criteria.sortBy) {
      case 'date_asc':
        orderBy = 'timestamp ASC';
        break;
      case 'amount_desc':
        orderBy = 'amount_santims DESC';
        break;
      case 'amount_asc':
        orderBy = 'amount_santims ASC';
        break;
      case 'date_desc':
      default:
        orderBy = 'timestamp DESC';
        break;
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final rows = await db.query(
      'transactions',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderBy,
    );

    return rows.map((e) => TransactionModel.fromMap(e)).toList();
  }

  Future<void> markAsReviewed(String id, bool isReviewed) async {
    final db = await _dbHelper.database;
    await db.update(
      'transactions',
      {
        'is_reviewed': isReviewed ? 1 : 0,
        'import_status': isReviewed ? AppConstants.statusPosted : AppConstants.statusPendingReview,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<TransactionModel>> getPendingReviewTransactions() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'transactions',
      where: 'import_status = ? OR is_reviewed = 0',
      whereArgs: [AppConstants.statusPendingReview],
      orderBy: 'timestamp DESC',
    );
    return rows.map((e) => TransactionModel.fromMap(e)).toList();
  }

  /// Calculates Dashboard Summary for the selected date range
  Future<FinancialDashboardSummary> getDashboardSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _dbHelper.database;
    final startMs = startDate.millisecondsSinceEpoch;
    final endMs = endDate.millisecondsSinceEpoch;

    // Income
    final incomeResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount_santims), 0) as total
      FROM transactions
      WHERE type = ? AND timestamp BETWEEN ? AND ?
    ''', [AppConstants.typeIncome, startMs, endMs]);
    final totalIncome = (incomeResult.first['total'] as int?) ?? 0;

    // Expense (Transfers are excluded to avoid double-counting)
    final expenseResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount_santims), 0) as total
      FROM transactions
      WHERE type = ? AND timestamp BETWEEN ? AND ?
    ''', [AppConstants.typeExpense, startMs, endMs]);
    final totalExpense = (expenseResult.first['total'] as int?) ?? 0;

    // Categories with budgets and actual spending
    final catRows = await db.query('categories', where: 'is_income = 0');
    final categoryBreakdown = <CategoryBudgetSummary>[];
    int totalBudget = 0;

    for (final catRow in catRows) {
      final cat = CategoryModel.fromMap(catRow);
      totalBudget += cat.monthlyBudgetSantims;

      final spentResult = await db.rawQuery('''
        SELECT COALESCE(SUM(amount_santims), 0) as spent
        FROM transactions
        WHERE category_id = ? AND type = ? AND timestamp BETWEEN ? AND ?
      ''', [cat.id, AppConstants.typeExpense, startMs, endMs]);

      final spent = (spentResult.first['spent'] as int?) ?? 0;

      categoryBreakdown.add(CategoryBudgetSummary(
        categoryId: cat.id,
        categoryName: cat.name,
        iconCodePoint: cat.iconCodePoint,
        colorValue: cat.colorValue,
        budgetSantims: cat.monthlyBudgetSantims,
        spentSantims: spent,
      ));
    }

    // Sort category breakdown: highest spent first
    categoryBreakdown.sort((a, b) => b.spentSantims.compareTo(a.spentSantims));

    return FinancialDashboardSummary(
      totalIncomeSantims: totalIncome,
      totalExpenseSantims: totalExpense,
      totalBudgetSantims: totalBudget,
      categoryBreakdown: categoryBreakdown,
    );
  }
}
