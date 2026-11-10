import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/account_model.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/transaction_model.dart';
import 'skeuomorphic.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final CategoryModel? category;
  final AccountModel? account;
  final bool hideAmount;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.category,
    this.account,
    this.hideAmount = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = AppColors.textPrimaryOf(context);
    final secondaryTextColor = AppColors.textSecondaryOf(context);

    final isIncome = transaction.isIncome || transaction.isRefund;
    final isExpense = transaction.isExpense;

    final amountColor = isIncome
        ? AppColors.incomeOf(context)
        : (isExpense ? AppColors.expenseOf(context) : secondaryTextColor);

    final sign = isIncome ? '+' : (isExpense ? '-' : '');

    final catIcon = category != null
        ? IconData(category!.iconCodePoint, fontFamily: 'MaterialIcons')
        : Icons.receipt;

    final dateFormat = DateFormat('MMM d, h:mm a');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Category Icon Badge in a debossed well
            SkeuoInset(
              width: 44,
              height: 44,
              radius: 12,
              child: Icon(catIcon, color: AppColors.accentOf(context), size: 21),
            ),
            const SizedBox(width: 14),

            // Merchant, Account, and Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          transaction.merchant,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!transaction.isReviewed) ...[
                        const SizedBox(width: 6),
                        const SkeuoBadge(
                          label: 'Review',
                          tone: SkeuoBadgeTone.danger,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        dateFormat.format(transaction.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                      if (account != null) ...[
                        Text(' • ', style: TextStyle(color: secondaryTextColor)),
                        Flexible(
                          child: Text(
                            account!.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (transaction.source == AppConstants.sourceSms) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.sms_outlined, size: 12, color: secondaryTextColor),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Amount
            Text(
              hideAmount
                  ? '••••••'
                  : '$sign${transaction.money.format()}',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: amountColor,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
