import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final summary = appState.dashboardSummary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets & Reports'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Total Budget Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Monthly Budget',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: secondaryTextColor),
                ),
                const SizedBox(height: 8),
                Text(
                  appState.isPrivacyMode ? '••••••••' : summary.totalRemainingBudgetSantims >= 0
                      ? '${Money(summary.totalRemainingBudgetSantims).format()} remaining'
                      : '${Money(-summary.totalRemainingBudgetSantims).format()} over budget',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: summary.totalRemainingBudgetSantims >= 0
                        ? (isDark ? AppColors.sageLight : AppColors.sagePrimary)
                        : AppColors.clayPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: summary.totalBudgetSantims > 0
                        ? (summary.totalExpenseSantims / summary.totalBudgetSantims).clamp(0.0, 1.0)
                        : 0.0,
                    minHeight: 10,
                    backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      summary.totalExpenseSantims > summary.totalBudgetSantims
                          ? AppColors.clayPrimary
                          : (isDark ? AppColors.sageLight : AppColors.sagePrimary),
                    ),
                  ),
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
            'Category Budgets',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
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

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
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
                                    color: isOver ? AppColors.clayPrimary : secondaryTextColor,
                                    fontWeight: isOver ? FontWeight.bold : FontWeight.normal,
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isOver ? AppColors.clayPrimary : primaryTextColor,
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isOver ? AppColors.clayPrimary : Color(cat.colorValue),
                            ),
                          ),
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
            'Accounts Summary',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: appState.accounts.map((acc) {
                return Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        acc.type == 'mobile_money'
                            ? Icons.phone_android
                            : (acc.type == 'cash' ? Icons.money : Icons.account_balance),
                        color: isDark ? AppColors.sageLight : AppColors.sagePrimary,
                      ),
                      title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: acc.accountNumberMasked != null ? Text(acc.accountNumberMasked!) : null,
                      trailing: Text(
                        appState.isPrivacyMode ? '••••••' : acc.balance.format(),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: acc.balance.isNegative ? AppColors.clayPrimary : primaryTextColor,
                        ),
                      ),
                    ),
                    if (acc != appState.accounts.last)
                      Divider(height: 1, indent: 56, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
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
