import 'package:sqflite/sqflite.dart';

import '../../domain/models/account_model.dart';
import '../database/database_helper.dart';

class AccountRepository {
  final DatabaseHelper _dbHelper;

  AccountRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<List<AccountModel>> getAllAccounts() async {
    final db = await _dbHelper.database;
    final rows = await db.query('accounts', orderBy: 'name ASC');
    return rows.map((e) => AccountModel.fromMap(e)).toList();
  }

  Future<AccountModel?> getAccountById(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return AccountModel.fromMap(rows.first);
  }

  Future<void> insertAccount(AccountModel account) async {
    final db = await _dbHelper.database;
    await db.insert('accounts', account.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateAccount(AccountModel account) async {
    final db = await _dbHelper.database;
    await db.update('accounts', account.toMap(),
        where: 'id = ?', whereArgs: [account.id]);
  }

  Future<void> deleteAccount(String id) async {
    final db = await _dbHelper.database;
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  /// Recalculates balance from all transactions
  Future<int> recalculateBalance(String accountId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT 
        SUM(CASE 
          WHEN type IN ('income', 'refund', 'reversal') THEN amount_santims 
          WHEN type IN ('expense', 'transfer') THEN -amount_santims 
          ELSE 0 
        END) as net_balance
      FROM transactions
      WHERE account_id = ?
    ''', [accountId]);

    final balance = (rows.first['net_balance'] as int?) ?? 0;
    await db.update(
      'accounts',
      {'balance_santims': balance, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [accountId],
    );
    return balance;
  }
}
