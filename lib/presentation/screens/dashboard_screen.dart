import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../services/app_state.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';
import 'automation_setup_screen.dart';
import 'budgets_screen.dart';
import 'settings_screen.dart';
import 'transaction_detail_screen.dart';
import 'transactions_screen.dart';

class DashboardScreen extends StatelessWidget {
  final AppState appState;

  const DashboardScreen({super.key, required this.appState});

  void _showDateRangePicker(BuildContext context) async {
    final now = DateTime.now();
    final firstDayCurrentMonth = DateTime(now.year, now.month, 1);
    final lastDayCurrentMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final firstDayLastMonth = DateTime(now.year, now.month - 1, 1);
    final lastDayLastMonth = DateTime(now.year, now.month, 0, 23, 59, 59);

    final firstDayYear = DateTime(now.year, 1, 1);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Select Time Period',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('This Month'),
                  subtitle: Text(DateFormat('MMMM yyyy').format(now)),
                  onTap: () {
                    appState.setDateRange(firstDayCurrentMonth, lastDayCurrentMonth);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Last Month'),
                  subtitle: Text(DateFormat('MMMM yyyy').format(firstDayLastMonth)),
                  onTap: () {
                    appState.setDateRange(firstDayLastMonth, lastDayLastMonth);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.date_range),
                  title: const Text('This Year (YTD)'),
                  subtitle: Text(DateFormat('yyyy').format(now)),
                  onTap: () {
                    appState.setDateRange(firstDayYear, lastDayCurrentMonth);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_calendar),
                  title: const Text('Custom Range...'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      initialDateRange: DateTimeRange(
                        start: appState.startDate,
                        end: appState.endDate,
                      ),
                    );
                    if (picked != null) {
                      appState.setDateRange(
                        picked.start,
                        DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final summary = appState.dashboardSummary;
    final monthFormat = DateFormat('MMMM yyyy');
    final isCurrentMonth = appState.startDate.month == DateTime.now().month &&
        appState.startDate.year == DateTime.now().year;

    final dateLabel = isCurrentMonth
        ? 'This Month (${monthFormat.format(appState.startDate)})'
        : '${DateFormat('MMM d').format(appState.startDate)} - ${DateFormat('MMM d, yyyy').format(appState.endDate)}';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LedgerLeaf',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5),
            ),
            InkWell(
              onTap: () => _showDateRangePicker(context),
              borderRadius: BorderRadius.circular(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dateLabel,
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 16, color: secondaryTextColor),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: appState.isPrivacyMode ? 'Show Balances' : 'Hide Balances',
            icon: Icon(
              appState.isPrivacyMode ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            ),
            onPressed: appState.togglePrivacyMode,
          ),
          IconButton(
            tooltip: 'Automation Setup',
            icon: const Icon(Icons.bolt_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AutomationSetupScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SettingsScreen(appState: appState)),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: appState.reloadAll,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Review Queue Banner (if any unreviewed SMS transactions exist)
            if (appState.pendingReviewTransactions.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.clayContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.clayPrimary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.clayPrimary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${appState.pendingReviewTransactions.length} transaction(s) require your review',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TransactionsScreen(
                              appState: appState,
                              initialFilterReviewed: false,
                            ),
                          ),
                        );
                      },
                      child: const Text('Review', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],

            // Net Cashflow Hero Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Net Cash Flow',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appState.isPrivacyMode
                        ? '••••••••'
                        : summary.netCashflow.format(),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: summary.netCashflow.isPositive
                          ? (isDark ? AppColors.sageLight : AppColors.sagePrimary)
                          : (summary.netCashflow.isNegative
                              ? (isDark ? AppColors.clayLight : AppColors.clayPrimary)
                              : primaryTextColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.sagePrimary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Income',
                                  style: TextStyle(fontSize: 12, color: secondaryTextColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              appState.isPrivacyMode
                                  ? '••••••'
                                  : summary.income.format(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.sageLight : AppColors.sagePrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 36, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.clayPrimary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Expenses',
                                  style: TextStyle(fontSize: 12, color: secondaryTextColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              appState.isPrivacyMode
                                  ? '••••••'
                                  : summary.expense.format(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.clayLight : AppColors.clayPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Budget Status Card
            if (summary.totalBudgetSantims > 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Monthly Budget',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: secondaryTextColor),
                        ),
                        Text(
                          appState.isPrivacyMode
                              ? '••••••'
                              : 'Remaining: ${summary.remainingBudget.format()}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: summary.remainingBudget.isNegative
                                ? AppColors.clayPrimary
                                : (isDark ? AppColors.sageLight : AppColors.sagePrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (summary.totalExpenseSantims / summary.totalBudgetSantims).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          summary.totalExpenseSantims > summary.totalBudgetSantims
                              ? AppColors.clayPrimary
                              : (isDark ? AppColors.sageLight : AppColors.sagePrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Spending by Category Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spending by Category',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: primaryTextColor,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => BudgetsScreen(appState: appState)),
                    );
                  },
                  child: const Text('Manage Budgets'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Category breakdown items
            if (summary.categoryBreakdown.isEmpty || summary.totalExpenseSantims == 0)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                alignment: Alignment.center,
                child: Text(
                  'No expenses recorded for this period.',
                  style: TextStyle(color: secondaryTextColor, fontSize: 13),
                ),
              )
            else
              ...summary.categoryBreakdown.where((c) => c.spentSantims > 0).take(5).map((cat) {
                final percent = summary.totalExpenseSantims > 0
                    ? (cat.spentSantims / summary.totalExpenseSantims * 100).toStringAsFixed(1)
                    : '0';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(cat.colorValue).withOpacity(0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          IconData(cat.iconCodePoint, fontFamily: 'MaterialIcons'),
                          size: 18,
                          color: Color(cat.colorValue),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.categoryName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                              ),
                            ),
                            Text(
                              '$percent% of expenses',
                              style: TextStyle(fontSize: 12, color: secondaryTextColor),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        appState.isPrivacyMode ? '••••••' : cat.spent.format(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 24),

            // Recent Transactions Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: primaryTextColor,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => TransactionsScreen(appState: appState)),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Recent Transactions List
            if (appState.transactions.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: secondaryTextColor.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Text(
                      'No transactions yet.',
                      style: TextStyle(color: secondaryTextColor, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add First Transaction'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => AddTransactionScreen(appState: appState)),
                        );
                      },
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  children: appState.transactions.take(5).map((tx) {
                    final cat = appState.categories.firstWhere(
                      (c) => c.id == tx.categoryId,
                      orElse: () => appState.categories.first,
                    );
                    final acc = appState.accounts.firstWhere(
                      (a) => a.id == tx.accountId,
                      orElse: () => appState.accounts.first,
                    );

                    return Column(
                      children: [
                        TransactionTile(
                          transaction: tx,
                          category: cat,
                          account: acc,
                          hideAmount: appState.isPrivacyMode,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TransactionDetailScreen(
                                  transaction: tx,
                                  category: cat,
                                  account: acc,
                                  appState: appState,
                                ),
                              ),
                            );
                          },
                        ),
                        if (tx != appState.transactions.take(5).last)
                          Divider(
                            height: 1,
                            indent: 72,
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 80), // Padding for floating action button
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isDark ? AppColors.sageLight : AppColors.sagePrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AddTransactionScreen(appState: appState)),
          );
        },
      ),
    );
  }
}
