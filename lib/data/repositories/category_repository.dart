import 'package:sqflite/sqflite.dart';

import '../../domain/models/category_model.dart';
import '../database/database_helper.dart';

class CategoryRepository {
  final DatabaseHelper _dbHelper;

  CategoryRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<List<CategoryModel>> getAllCategories({bool? isIncome}) async {
    final db = await _dbHelper.database;
    final where = isIncome != null ? 'is_income = ?' : null;
    final whereArgs = isIncome != null ? [isIncome ? 1 : 0] : null;

    final rows = await db.query('categories',
        where: where, whereArgs: whereArgs, orderBy: 'name ASC');
    return rows.map((e) => CategoryModel.fromMap(e)).toList();
  }

  Future<CategoryModel?> getCategoryById(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return CategoryModel.fromMap(rows.first);
  }

  Future<void> insertCategory(CategoryModel category) async {
    final db = await _dbHelper.database;
    await db.insert('categories', category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCategory(CategoryModel category) async {
    final db = await _dbHelper.database;
    await db.update('categories', category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
  }

  Future<void> updateBudget(String categoryId, int monthlyBudgetSantims) async {
    final db = await _dbHelper.database;
    await db.update(
      'categories',
      {'monthly_budget_santims': monthlyBudgetSantims},
      where: 'id = ?',
      whereArgs: [categoryId],
    );
  }

  Future<void> deleteCategory(String id) async {
    final db = await _dbHelper.database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}
