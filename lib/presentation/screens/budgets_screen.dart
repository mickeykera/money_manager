import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../widgets/skeuomorphic.dart';
import '../../domain/models/budget_summary.dart';
import '../../services/app_state.dart';

class BudgetsScreen extends StatelessWidget {
  final AppState appState;

  const BudgetsScreen({super.key, required this.appState});

  void _editBudget(BuildContext context, CategoryBudgetSummary cat) {
    final controller = TextEditingController(
      text: cat.budgetSantims > 0 ? (cat.budgetSantims / 100.0).toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set Budget for ${cat.categoryName}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Monthly Limit (ETB)',
            prefixText: 'ETB ',
            hintText: 'e.g. 5000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final money = Money.parseString(controller.text.trim());
              await appState.updateBudget(cat.categoryId, money.santims.abs());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = AppColors.textPrimaryOf(context);
    final secondaryTextColor = AppColors.textSecondaryOf(context);

    final summary = appState.dashboardSummary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Budgets & Reports'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Total Budget plaque
          SkeuoPanel(
            padding: const EdgeInsets.all(20),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL MONTHLY BUDGET',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  appState.isPrivacyMode ? '••••••••' : summary.totalRemainingBudgetSantims >= 0
                      ? '${Money(summary.totalRemainingBudgetSantims).format()} remaining'
                      : '${Money(-summary.totalRemainingBudgetSantims).format()} over budget',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: summary.totalRemainingBudgetSantims >= 0
                        ? AppColors.incomeOf(context)
                        : AppColors.expenseOf(context),
                  ),
                ),
                const SizedBox(height: 14),
                SkeuoProgressBar(
                  value: summary.totalBudgetSantims > 0
                      ? (summary.totalExpenseSantims / summary.totalBudgetSantims).clamp(0.0, 1.0)
                      : 0.0,
                  height: 10,
                  color: summary.totalExpenseSantims > summary.totalBudgetSantims
                      ? AppColors.expenseOf(context)
                      : AppColors.accentOf(context),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Spent: ${appState.isPrivacyMode ? '••••' : summary.expense.format()}',
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                    ),
                    Text(
                      'Limit: ${appState.isPrivacyMode ? '••••' : Money(summary.totalBudgetSantims).format()}',
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Category Budgets Header
          Text(
            'Category budgets',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap any category to update its monthly budget limit.',
            style: TextStyle(fontSize: 12, color: secondaryTextColor),
          ),
          const SizedBox(height: 12),

          // Category list with progress
          ...summary.categoryBreakdown.map((cat) {
            final hasBudget = cat.budgetSantims > 0;
            final progress = hasBudget ? (cat.spentSantims / cat.budgetSantims).clamp(0.0, 1.0) : 0.0;
            final isOver = cat.isOverBudget;

            return SkeuoPanel(
              margin: const EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.zero,
              radius: 16,
              child: InkWell(
                onTap: () => _editBudget(context, cat),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SkeuoInset(
                            width: 36,
                            height: 36,
                            radius: 10,
                            child: Icon(
                              IconData(cat.iconCodePoint, fontFamily: 'MaterialIcons'),
                              size: 18,
                              color: AppColors.accentOf(context),
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
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: primaryTextColor,
                                  ),
                                ),
                                Text(
                                  hasBudget
                                      ? (isOver
                                          ? '${cat.remaining.abs().format()} over budget'
                                          : '${cat.remaining.format()} left')
                                      : 'No budget set (tap to set)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isOver ? AppColors.expenseOf(context) : secondaryTextColor,
                                    fontWeight: isOver ? FontWeight.w700 : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                appState.isPrivacyMode ? '••••••' : cat.spent.format(),
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isOver ? AppColors.expenseOf(context) : primaryTextColor,
                                ),
                              ),
                              if (hasBudget)
                                Text(
                                  'of ${appState.isPrivacyMode ? '••••' : cat.budget.format()}',
                                  style: TextStyle(fontSize: 12, color: secondaryTextColor),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (hasBudget) ...[
                        const SizedBox(height: 12),
                        SkeuoProgressBar(
                          value: progress,
                          height: 7,
                          color: isOver
                              ? AppColors.expenseOf(context)
                              : AppColors.accentOf(context),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 24),

          // Accounts Balance Summary
          Text(
            'Accounts summary',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 12),
          SkeuoPanel(
            padding: EdgeInsets.zero,
            radius: 16,
            child: Column(
              children: appState.accounts.map((acc) {
                return Column(
                  children: [
                    ListTile(
                      leading: SkeuoIconWell(
                        icon: acc.type == 'mobile_money'
                            ? Icons.phone_android
                            : (acc.type == 'cash' ? Icons.money : Icons.account_balance),
                        size: 34,
                        iconSize: 17,
                        radius: 10,
                      ),
                      title: Text(
                        acc.name,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: primaryTextColor,
                        ),
                      ),
                      subtitle: acc.accountNumberMasked != null ? Text(acc.accountNumberMasked!) : null,
                      trailing: Text(
                        appState.isPrivacyMode ? '••••••' : acc.balance.format(),
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: acc.balance.isNegative
                              ? AppColors.expenseOf(context)
                              : primaryTextColor,
                        ),
                      ),
                    ),
                    if (acc != appState.accounts.last)
                      const SkeuoDivider(indent: 56, height: 0),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
