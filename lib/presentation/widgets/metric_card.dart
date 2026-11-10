import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import 'skeuomorphic.dart';

class MetricCard extends StatelessWidget {
  final String title;
  final Money amount;
  final IconData icon;
  final Color? color;
  final bool isPositive;
  final bool hideAmount;
  final String? subtitle;

  const MetricCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    this.color,
    this.isPositive = false,
    this.hideAmount = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = AppColors.textPrimaryOf(context);
    final secondaryTextColor = AppColors.textSecondaryOf(context);

    final resolvedColor = color ??
        (isPositive ? AppColors.incomeOf(context) : primaryTextColor);

    return SkeuoPanel(
      padding: const EdgeInsets.all(16),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeuoIconWell(icon: icon, size: 34, iconSize: 17, radius: 10),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                    letterSpacing: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hideAmount ? '••••••' : amount.format(),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: resolvedColor,
              letterSpacing: -0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: secondaryTextColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
