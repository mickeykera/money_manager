import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../data/csv/csv_service.dart';
import '../data/database/database_helper.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/transaction_repository.dart';
import '../domain/models/account_model.dart';
import '../domain/models/budget_summary.dart';
import '../domain/models/category_model.dart';
import '../domain/models/filter_criteria.dart';
import '../domain/models/transaction_model.dart';
import 'ingestion_service.dart';

class AppState extends ChangeNotifier {
  final TransactionRepository _transactionRepo;
  final AccountRepository _accountRepo;
  final CategoryRepository _categoryRepo;
  final SettingsRepository _settingsRepo;
  final IngestionService _ingestionService;
  final CsvService _csvService;
  final DatabaseHelper _dbHelper;

  AppState({
    TransactionRepository? transactionRepo,
    AccountRepository? accountRepo,
    CategoryRepository? categoryRepo,
    SettingsRepository? settingsRepo,
    IngestionService? ingestionService,
    CsvService? csvService,
    DatabaseHelper? dbHelper,
  })  : _dbHelper = dbHelper ?? DatabaseHelper(),
        _transactionRepo = transactionRepo ?? TransactionRepository(),
        _accountRepo = accountRepo ?? AccountRepository(),
        _categoryRepo = categoryRepo ?? CategoryRepository(),
        _settingsRepo = settingsRepo ?? SettingsRepository(),
        _csvService = csvService ?? CsvService(),
        _ingestionService = ingestionService ?? IngestionService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isPrivacyMode = false;
  bool get isPrivacyMode => _isPrivacyMode;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0, 23, 59, 59);
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;

  FinancialDashboardSummary _dashboardSummary = FinancialDashboardSummary.empty;
  FinancialDashboardSummary get dashboardSummary => _dashboardSummary;

  List<TransactionModel> _transactions = [];
  List<TransactionModel> get transactions => _transactions;

  List<TransactionModel> _pendingReviewTransactions = [];
  List<TransactionModel> get pendingReviewTransactions => _pendingReviewTransactions;

  List<AccountModel> _accounts = [];
  List<AccountModel> get accounts => _accounts;

  List<CategoryModel> _categories = [];
  List<CategoryModel> get categories => _categories;

  FilterCriteria _filterCriteria = const FilterCriteria();
  FilterCriteria get filterCriteria => _filterCriteria;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    // Load settings
    final privacySetting = await _settingsRepo.getSetting(AppConstants.keyPrivacyMode);
    _isPrivacyMode = privacySetting == 'true';

    final themeSetting = await _settingsRepo.getSetting(AppConstants.keyThemeMode);
    if (themeSetting == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeSetting == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    await reloadAll();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> reloadAll() async {
    _accounts = await _accountRepo.getAllAccounts();
    _categories = await _categoryRepo.getAllCategories();
    _transactions = await _transactionRepo.getTransactions(_filterCriteria);
    _pendingReviewTransactions = await _transactionRepo.getPendingReviewTransactions();
    _dashboardSummary = await _transactionRepo.getDashboardSummary(
      startDate: _startDate,
      endDate: _endDate,
    );
    notifyListeners();
  }

  void setDateRange(DateTime start, DateTime end) {
    _startDate = start;
    _endDate = end;
    _filterCriteria = _filterCriteria.copyWith(startDate: start, endDate: end);
    reloadAll();
  }

  void updateFilter(FilterCriteria criteria) {
    _filterCriteria = criteria;
    reloadAll();
  }

  void togglePrivacyMode() async {
    _isPrivacyMode = !_isPrivacyMode;
    await _settingsRepo.setSetting(AppConstants.keyPrivacyMode, _isPrivacyMode ? 'true' : 'false');
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    await _settingsRepo.setSetting(AppConstants.keyThemeMode, modeStr);
    notifyListeners();
  }

  Future<void> addTransaction(TransactionModel tx) async {
    await _transactionRepo.insertTransaction(tx);
    await reloadAll();
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    await _transactionRepo.updateTransaction(tx);
    await reloadAll();
  }

  Future<void> deleteTransaction(String id) async {
    await _transactionRepo.deleteTransaction(id);
    await reloadAll();
  }

  Future<void> markReviewed(String id, bool isReviewed) async {
    await _transactionRepo.markAsReviewed(id, isReviewed);
    await reloadAll();
  }

  Future<void> updateBudget(String categoryId, int monthlyBudgetSantims) async {
    await _categoryRepo.updateBudget(categoryId, monthlyBudgetSantims);
    await reloadAll();
  }

  Future<IngestionResponse> ingestSms(String message, {String? sender}) async {
    final response = await _ingestionService.processIncomingSms(
      rawMessage: message,
      sender: sender,
    );
    await reloadAll();
    return response;
  }

  Future<String> exportCsv() => _csvService.exportTransactionsToCsv();

  Future<int> importCsv(String csvContent) async {
    final count = await _csvService.importTransactionsFromCsv(csvContent);
    await reloadAll();
    return count;
  }

  Future<void> wipeAllData() async {
    await _dbHelper.wipeAllData();
    await reloadAll();
  }
}
