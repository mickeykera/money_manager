import '../../core/utils/money.dart';

class CategoryBudgetSummary {
  final String categoryId;
  final String categoryName;
  final int iconCodePoint;
  final int colorValue;
  final int budgetSantims;
  final int spentSantims;

  const CategoryBudgetSummary({
    required this.categoryId,
    required this.categoryName,
    required this.iconCodePoint,
    required this.colorValue,
    required this.budgetSantims,
    required this.spentSantims,
  });

  Money get budget => Money(budgetSantims);
  Money get spent => Money(spentSantims);
  Money get remaining => Money(budgetSantims - spentSantims);

  double get percentageUsed {
    if (budgetSantims <= 0) return 0.0;
    return (spentSantims / budgetSantims).clamp(0.0, 2.0);
  }

  bool get isOverBudget => spentSantims > budgetSantims && budgetSantims > 0;
}

class FinancialDashboardSummary {
  final int totalIncomeSantims;
  final int totalExpenseSantims;
  final int totalBudgetSantims;
  final List<CategoryBudgetSummary> categoryBreakdown;

  const FinancialDashboardSummary({
    required this.totalIncomeSantims,
    required this.totalExpenseSantims,
    required this.totalBudgetSantims,
    required this.categoryBreakdown,
  });

  Money get income => Money(totalIncomeSantims);
  Money get expense => Money(totalExpenseSantims);
  Money get netCashflow => Money(totalIncomeSantims - totalExpenseSantims);
  Money get remainingBudget => Money(totalBudgetSantims - totalExpenseSantims);
  int get totalRemainingBudgetSantims => totalBudgetSantims - totalExpenseSantims;

  static const empty = FinancialDashboardSummary(
    totalIncomeSantims: 0,
    totalExpenseSantims: 0,
    totalBudgetSantims: 0,
    categoryBreakdown: [],
  );
}
