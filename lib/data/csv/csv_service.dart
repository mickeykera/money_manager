import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/money.dart';
import '../../domain/models/filter_criteria.dart';
import '../../domain/models/transaction_model.dart';
import '../repositories/account_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/transaction_repository.dart';

class CsvService {
  final TransactionRepository _transactionRepo;
  final CategoryRepository _categoryRepo;
  final AccountRepository _accountRepo;

  CsvService({
    TransactionRepository? transactionRepo,
    CategoryRepository? categoryRepo,
    AccountRepository? accountRepo,
  })  : _transactionRepo = transactionRepo ?? TransactionRepository(),
        _categoryRepo = categoryRepo ?? CategoryRepository(),
        _accountRepo = accountRepo ?? AccountRepository();

  /// Exports all transactions to RFC-4180 CSV string
  Future<String> exportTransactionsToCsv() async {
    final transactions = await _transactionRepo.getTransactions(
      const FilterCriteria(sortBy: 'date_desc'),
    );
    final categories = await _categoryRepo.getAllCategories();
    final accounts = await _accountRepo.getAllAccounts();

    final catMap = {for (var c in categories) c.id: c.name};
    final accMap = {for (var a in accounts) a.id: a.name};

    final rows = <List<dynamic>>[];
    // CSV Header
    rows.add([
      'Transaction ID',
      'Date & Time (ISO)',
      'Type',
      'Merchant / Description',
      'Amount (ETB)',
      'Currency',
      'Category',
      'Account',
      'Bank Reference',
      'Source',
      'Notes',
    ]);

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (final tx in transactions) {
      rows.add([
        tx.id,
        dateFormat.format(tx.timestamp),
        tx.type,
        tx.merchant,
        (tx.amountSantims / 100.0).toStringAsFixed(2),
        tx.currency,
        catMap[tx.categoryId] ?? tx.categoryId,
        accMap[tx.accountId] ?? tx.accountId,
        tx.reference ?? '',
        tx.source,
        tx.notes ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Imports transactions from CSV string
  Future<int> importTransactionsFromCsv(String csvString) async {
    final normalized = csvString.replaceAll('\r\n', '\n');
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(normalized);
    if (rows.length < 2) return 0; // Header only or empty

    final categories = await _categoryRepo.getAllCategories();
    final accounts = await _accountRepo.getAllAccounts();

    final catNameToId = {for (var c in categories) c.name.toLowerCase(): c.id};
    final accNameToId = {for (var a in accounts) a.name.toLowerCase(): a.id};

    final defaultCatId = categories.isNotEmpty ? categories.first.id : 'cat_other';
    final defaultAccId = accounts.isNotEmpty ? accounts.first.id : 'acc_cash';

    const uuid = Uuid();
    int importedCount = 0;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 5) continue;

      final dateStr = row[1].toString().trim();
      final typeStr = row[2].toString().trim().toLowerCase();
      final merchant = row[3].toString().trim();
      final amountStr = row[4].toString().trim();
      final currency = row.length > 5 ? row[5].toString().trim() : AppConstants.defaultCurrency;
      final categoryName = row.length > 6 ? row[6].toString().trim().toLowerCase() : '';
      final accountName = row.length > 7 ? row[7].toString().trim().toLowerCase() : '';
      final reference = row.length > 8 ? row[8].toString().trim() : null;
      final notes = row.length > 10 ? row[10].toString().trim() : null;

      final money = Money.parseString(amountStr, currency: currency);
      if (money.santims == 0 && merchant.isEmpty) continue;

      DateTime parsedDate;
      try {
        parsedDate = DateTime.parse(dateStr);
      } catch (_) {
        parsedDate = DateTime.now();
      }

      final type = AppConstants.allTransactionTypes.contains(typeStr)
          ? typeStr
          : AppConstants.typeExpense;

      final catId = catNameToId[categoryName] ?? defaultCatId;
      final accId = accNameToId[accountName] ?? defaultAccId;

      final tx = TransactionModel(
        id: uuid.v4(),
        amountSantims: money.santims.abs(),
        currency: currency.isNotEmpty ? currency : AppConstants.defaultCurrency,
        type: type,
        merchant: merchant.isNotEmpty ? merchant : 'Imported Transaction',
        timestamp: parsedDate,
        categoryId: catId,
        accountId: accId,
        source: AppConstants.sourceCsv,
        reference: reference?.isNotEmpty == true ? reference : null,
        notes: notes?.isNotEmpty == true ? notes : null,
        isReviewed: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _transactionRepo.insertTransaction(tx);
      importedCount++;
    }

    return importedCount;
  }
}
