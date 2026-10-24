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
        content: const Text('This will permanently delete this transaction and recalculate your account balance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.clayPrimary),
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
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final isIncome = transaction.isIncome || transaction.isRefund;
    final isExpense = transaction.isExpense;

    final amountColor = isIncome
        ? (isDark ? AppColors.sageLight : AppColors.sagePrimary)
        : (isExpense
            ? (isDark ? AppColors.clayLight : AppColors.clayPrimary)
            : primaryTextColor);

    final sign = isIncome ? '+' : (isExpense ? '-' : '');
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy • h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
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
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, color: AppColors.clayPrimary),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Amount Card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                Text(
                  transaction.merchant,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor),
                ),
                const SizedBox(height: 10),
                Text(
                  '$sign${transaction.money.format()}',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dateFormat.format(transaction.timestamp),
                  style: TextStyle(fontSize: 13, color: secondaryTextColor),
                ),
                const SizedBox(height: 14),
                // Review badge
                if (!transaction.isReviewed)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.clayPrimary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Mark as Reviewed'),
                    onPressed: () async {
                      await appState.markReviewed(transaction.id, true);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Metadata List
          _buildInfoTile('Category', category.name, Icons.category_outlined, primaryTextColor, secondaryTextColor),
          _buildInfoTile('Account / Source', account.name, Icons.account_balance_wallet_outlined, primaryTextColor, secondaryTextColor),
          _buildInfoTile('Transaction Type', transaction.type.toUpperCase(), Icons.swap_horiz_outlined, primaryTextColor, secondaryTextColor),
          _buildInfoTile('Import Method', transaction.source.toUpperCase(), Icons.input_outlined, primaryTextColor, secondaryTextColor),
          if (transaction.reference != null)
            _buildInfoTile('Bank Reference', transaction.reference!, Icons.tag, primaryTextColor, secondaryTextColor),
          if (transaction.notes != null)
            _buildInfoTile('Notes', transaction.notes!, Icons.note_outlined, primaryTextColor, secondaryTextColor),

          // Original SMS Message (if retained)
          if (transaction.originalMessage != null && transaction.originalMessage!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Original SMS Message',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: SelectableText(
                transaction.originalMessage!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontFamily: 'monospace',
                  color: secondaryTextColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon, Color primary, Color secondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: secondary),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontSize: 14, color: secondary)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
          ),
        ],
      ),
    );
  }
}
