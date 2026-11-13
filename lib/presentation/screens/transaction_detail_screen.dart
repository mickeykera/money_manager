import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/account_model.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/transaction_model.dart';
import '../../services/app_state.dart';
import '../widgets/skeuomorphic.dart';
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
    final isDark = AppColors.isDark(context);
    final isIncome = transaction.isIncome || transaction.isRefund;
    final isExpense = transaction.isExpense;
    final sign = isIncome ? '+' : (isExpense ? '-' : '');
    final amountFormatted = '$sign${transaction.money.format(includeCurrency: false)}';
    final borderColor = AppColors.borderOf(context);
    final hasSourceSms =
        (transaction.originalMessage ?? '').trim().isNotEmpty;
    final sourceLabel = transaction.source == AppConstants.sourceSms
        ? 'SMS imported'
        : transaction.source == 'csv'
            ? 'CSV imported'
            : 'Manual entry';
    final sourceBadgeLabel =
        Theme.of(context).platform == TargetPlatform.iOS
            ? 'Via Shortcuts'
            : 'From inbox';

    return Scaffold(
      backgroundColor: Colors.transparent,
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
            child: Text(
              'Edit',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w600,
                color: AppColors.accentOf(context),
                fontSize: 15,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 20,
              color: AppColors.textSecondaryOf(context),
            ),
            tooltip: 'Delete',
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Centered header medallion
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF262A2D), const Color(0xFF0E1011)]
                      : [const Color(0xFFF9F5ED), const Color(0xFFD9D3C6)],
                ),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.65),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Center(
                child: SkeuoInset(
                  width: 46,
                  height: 46,
                  radius: 23,
                  child: Icon(
                    IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'),
                    size: 22,
                    color: AppColors.accentOf(context),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              transaction.merchant,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              appState.isPrivacyMode ? '••••••' : amountFormatted,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 35,
                fontWeight: FontWeight.w700,
                color: isIncome
                    ? AppColors.incomeOf(context)
                    : AppColors.textPrimaryOf(context),
                letterSpacing: -1.0,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Status badge
          Center(
            child: SkeuoBadge(
              label: transaction.isReviewed
                  ? '$sourceLabel · Verified'
                  : '$sourceLabel · Needs review',
              icon: transaction.isReviewed
                  ? Icons.check_circle_outline
                  : Icons.priority_high,
              tone: transaction.isReviewed
                  ? SkeuoBadgeTone.accent
                  : SkeuoBadgeTone.danger,
            ),
          ),
          const SizedBox(height: 28),

          // Key-Value Rows Card with Chevrons
          SkeuoPanel(
            padding: EdgeInsets.zero,
            radius: 18,
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

          // "Source SMS" panel — only for transactions captured from a message
          if (hasSourceSms) ...[
            SkeuoPanel(
              padding: const EdgeInsets.all(18),
              radius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Source SMS',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      SkeuoBadge(
                        label: sourceBadgeLabel,
                        icon: Icons.auto_awesome,
                        tone: SkeuoBadgeTone.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Sender and Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${account.name} · Alert',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('MMM d, h:mm a')
                            .format(transaction.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedOf(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Inset raw SMS well
                  SkeuoPanel(
                    inset: true,
                    radius: 12,
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(
                      width: double.infinity,
                      child: SelectableText(
                        transaction.originalMessage!,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          fontFamily: 'monospace',
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Check the parsed details against your message. Tap Edit to correct anything before marking reviewed.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],

          // Bottom action
          SkeuoButton(
            label: transaction.isReviewed ? 'Reviewed' : 'Mark as reviewed',
            icon: Icons.check,
            height: 54,
            onPressed: () async {
              await appState.markReviewed(transaction.id, !transaction.isReviewed);
              if (context.mounted) Navigator.pop(context);
            },
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
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          textAlign: TextAlign.end,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (hasChevron) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.textMuted,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isLast) const SkeuoDivider(height: 0),
        ],
      ),
    );
  }
}
