import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/account_model.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/transaction_model.dart';
import '../../services/app_state.dart';
import 'add_transaction_screen.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionModel transaction;
  final CategoryModel category;
  final AccountModel account;
  final AppState appState;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    required this.category,
    required this.account,
    required this.appState,
  });

  void _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text('This will permanently delete this transaction and recalculate your balance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.expenseClay),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await appState.deleteTransaction(transaction.id);
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = transaction.isIncome || transaction.isRefund;
    final isExpense = transaction.isExpense;
    final sign = isIncome ? '+' : (isExpense ? '-' : '');
    final amountFormatted = '$sign${transaction.money.format(includeCurrency: false)}';
    final cardBg = isDark ? AppColors.darkCard : AppColors.cardWhite;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.borderSubtle;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.offWhiteBg,
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => AddTransactionScreen(
                    appState: appState,
                    existingTransaction: transaction,
                  ),
                ),
              );
            },
            child: const Text(
              'Edit',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.forestGreen,
                fontSize: 15,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textSecondary),
            tooltip: 'Delete',
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Centered Header (Screen 5 in ui.jpg)
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF242C26) : const Color(0xFFF3F2EC),
                shape: BoxShape.circle,
              ),
              child: Icon(
                IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'),
                size: 26,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              transaction.merchant,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              appState.isPrivacyMode ? '••••••' : amountFormatted,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: isIncome
                    ? AppColors.incomeGreen
                    : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                letterSpacing: -1.0,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Status Badge: e.g. "Imported · Needs review" or "SMS imported · Verified"
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: transaction.isReviewed
                    ? AppColors.greenAccentPill
                    : const Color(0xFFFDECE9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    transaction.isReviewed ? Icons.check_circle_outline : Icons.priority_high,
                    size: 13,
                    color: transaction.isReviewed
                        ? AppColors.greenAccentText
                        : AppColors.expenseClay,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    transaction.isReviewed
                        ? 'SMS imported · Verified'
                        : 'Imported · Needs review',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: transaction.isReviewed
                          ? AppColors.greenAccentText
                          : AppColors.expenseClay,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Key-Value Rows Card with Chevrons
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _buildKeyValueRow(
                  label: 'Account',
                  value: '${account.name} · ${account.accountNumberMasked ?? ""}',
                  hasChevron: true,
                  borderColor: borderColor,
                  isDark: isDark,
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => AddTransactionScreen(
                          appState: appState,
                          existingTransaction: transaction,
                        ),
                      ),
                    );
                  },
                ),
                _buildKeyValueRow(
                  label: 'Category',
                  value: category.name,
                  hasChevron: true,
                  borderColor: borderColor,
                  isDark: isDark,
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => AddTransactionScreen(
                          appState: appState,
                          existingTransaction: transaction,
                        ),
                      ),
                    );
                  },
                ),
                _buildKeyValueRow(
                  label: 'Date',
                  value: DateFormat('MMM d, yyyy · h:mm a').format(transaction.timestamp),
                  hasChevron: true,
                  borderColor: borderColor,
                  isDark: isDark,
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => AddTransactionScreen(
                          appState: appState,
                          existingTransaction: transaction,
                        ),
                      ),
                    );
                  },
                ),
                _buildKeyValueRow(
                  label: 'Balance after',
                  value: account.balance.format(),
                  hasChevron: false,
                  borderColor: borderColor,
                  isLast: true,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // "Source SMS" Card (Screen 5 in ui.jpg)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header row with "Via Shortcuts" badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Source SMS',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.greenAccentPill,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 11, color: AppColors.forestGreen),
                          SizedBox(width: 4),
                          Text(
                            'Via Shortcuts',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.forestGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Sender and Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${account.name} · Alert',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, h:mm a').format(transaction.timestamp),
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Inset raw SMS text container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF191D1A) : const Color(0xFFF6F5EF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: SelectableText(
                    transaction.originalMessage ??
                        'Dear Customer, ${transaction.money.format()} has been processed for ${transaction.merchant}. Ref: ${transaction.reference ?? "None"}.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      fontFamily: 'monospace',
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Footer instructions
                Text(
                  'Check the parsed details against your message. Tap Edit to correct anything before marking reviewed.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Bottom Action Button: "Mark as reviewed"
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              icon: const Icon(Icons.check, size: 20),
              label: Text(
                transaction.isReviewed ? 'Reviewed' : 'Mark as reviewed',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              onPressed: () async {
                await appState.markReviewed(transaction.id, !transaction.isReviewed);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildKeyValueRow({
    required String label,
    required String value,
    required bool hasChevron,
    required Color borderColor,
    bool isLast = false,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    if (hasChevron) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!isLast) Divider(color: borderColor, height: 1),
        ],
      ),
    );
  }
}
