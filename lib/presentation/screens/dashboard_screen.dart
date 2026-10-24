import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../domain/models/account_model.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/transaction_model.dart';
import '../../services/app_state.dart';
import 'accounts_screen.dart';
import 'add_transaction_screen.dart';
import 'bundles_screen.dart';
import 'settings_screen.dart';
import 'transaction_detail_screen.dart';
import 'transactions_screen.dart';

class DashboardScreen extends StatelessWidget {
  final AppState appState;
  final VoidCallback? onNavigateToTransactions;
  final VoidCallback? onNavigateToAccounts;
  final VoidCallback? onNavigateToBundles;

  const DashboardScreen({
    super.key,
    required this.appState,
    this.onNavigateToTransactions,
    this.onNavigateToAccounts,
    this.onNavigateToBundles,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = appState.dashboardSummary;
    final totalBalanceMoney = Money(appState.totalBalanceSantims);
    final incomeMoney = Money(summary.totalIncomeSantims);
    final expenseMoney = Money(summary.totalExpenseSantims);
    final telecom = appState.telecomSummary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.offWhiteBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Top App Bar: LedgerLeaf logo & User Avatar "AL"
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: AppColors.forestGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.eco_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'LedgerLeaf',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SettingsScreen(appState: appState)),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF242A26) : const Color(0xFFE8E7DF),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      'AL',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Hero Card: Dark Forest Green (Screen 1 in ui.jpg)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.forestGreenHero,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your total balance',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.forestGreenSubtext,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.more_horiz, color: AppColors.forestGreenSubtext),
                        onPressed: () => appState.togglePrivacyMode(),
                        tooltip: 'Toggle Privacy',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appState.isPrivacyMode ? '••••••••' : totalBalanceMoney.format(includeCurrency: false),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppConstants.defaultCurrency} · Across ${appState.accounts.length} accounts',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.forestGreenSubtext,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF284D3B), height: 1),
                  const SizedBox(height: 16),

                  // Bottom columns: In this month & Out this month
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.north_east, size: 13, color: AppColors.forestGreenSubtext),
                                SizedBox(width: 4),
                                Text(
                                  'In this month',
                                  style: TextStyle(color: AppColors.forestGreenSubtext, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              appState.isPrivacyMode ? '••••' : incomeMoney.format(includeCurrency: false),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 34, width: 1, color: const Color(0xFF284D3B)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.south_east, size: 13, color: AppColors.forestGreenSubtext),
                                SizedBox(width: 4),
                                Text(
                                  'Out this month',
                                  style: TextStyle(color: AppColors.forestGreenSubtext, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              appState.isPrivacyMode ? '••••' : expenseMoney.format(includeCurrency: false),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
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
            const SizedBox(height: 24),

            // Linked Accounts Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Linked accounts',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                InkWell(
                  onTap: () {
                    if (onNavigateToAccounts != null) {
                      onNavigateToAccounts!();
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AccountsScreen(appState: appState)),
                      );
                    }
                  },
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forestGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Horizontal Linked Accounts Cards
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: appState.accounts.length,
                separatorBuilder: (_, index) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) {
                  final acc = appState.accounts[i];
                  return _buildLinkedAccountItem(context, acc, isDark);
                },
              ),
            ),
            const SizedBox(height: 20),

            // Compact Telecom Bundle Summary Card
            _buildTelecomCard(context, telecom, isDark),
            const SizedBox(height: 24),

            // Recent Activity Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent activity',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                InkWell(
                  onTap: () {
                    if (onNavigateToTransactions != null) {
                      onNavigateToTransactions!();
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => TransactionsScreen(appState: appState)),
                      );
                    }
                  },
                  child: const Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forestGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Recent Transactions List
            if (appState.transactions.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderSubtle),
                ),
                child: const Text('No recent activity recorded.', style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderSubtle),
                ),
                child: Column(
                  children: appState.transactions.take(4).map((tx) {
                    final cat = appState.categories.firstWhere(
                      (c) => c.id == tx.categoryId,
                      orElse: () => appState.categories.first,
                    );
                    final acc = appState.accounts.firstWhere(
                      (a) => a.id == tx.accountId,
                      orElse: () => appState.accounts.first,
                    );
                    final isLast = tx == appState.transactions.take(4).last;

                    return Column(
                      children: [
                        _buildRecentActivityTile(context, tx, cat, acc, isDark),
                        if (!isLast)
                          Divider(
                            height: 1,
                            indent: 68,
                            color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 12),

            // Footnote from ui.jpg: "• Via your Shortcuts • Updated at 10:42 AM"
            Center(
              child: Text(
                '• Via your Shortcuts • Updated at ${DateFormat("h:mm a").format(DateTime.now())}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.forestGreen,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AddTransactionScreen(appState: appState)),
          );
        },
      ),
    );
  }

  Widget _buildLinkedAccountItem(BuildContext context, AccountModel acc, bool isDark) {
    final balanceMoney = acc.balance;
    return Container(
      width: 154,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                acc.name.toLowerCase().contains('telebirr') || acc.name.toLowerCase().contains('mpesa')
                    ? Icons.phone_android
                    : Icons.account_balance_outlined,
                size: 16,
                color: AppColors.forestGreen,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  acc.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appState.isPrivacyMode ? '••••' : balanceMoney.format(includeCurrency: false),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${acc.type.toUpperCase()} · ${acc.accountNumberMasked ?? "••••"}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelecomCard(BuildContext context, dynamic telecom, bool isDark) {
    final totalGb = (telecom.ethioDataRemainingGb + telecom.safaricomDataRemainingGb) as double;
    final expiry = telecom.nextKnownExpiry as DateTime?;

    return InkWell(
      onTap: () {
        if (onNavigateToBundles != null) {
          onNavigateToBundles!();
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BundlesScreen(appState: appState)),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.greenAccentPill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cell_tower, size: 20, color: AppColors.forestGreen),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Telecom Bundles (Ethio & Safaricom)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    totalGb > 0
                        ? '${totalGb.toStringAsFixed(1)} GB remaining ${expiry != null ? "· Expires ${DateFormat('MMM d').format(expiry)}" : ""}'
                        : 'No active package reported',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityTile(
    BuildContext context,
    TransactionModel tx,
    CategoryModel cat,
    AccountModel acc,
    bool isDark,
  ) {
    final isIncome = tx.type == AppConstants.typeIncome;
    final amountSign = isIncome ? '+' : '-';
    final amountStr = '$amountSign${tx.money.format(includeCurrency: false)}';
    final timeStr = DateFormat('h:mm a').format(tx.timestamp);

    return InkWell(
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
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Category Icon in subtle container
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF232A25) : const Color(0xFFF3F2EC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                IconData(cat.iconCodePoint, fontFamily: 'MaterialIcons'),
                size: 20,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 14),

            // Merchant & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.merchant,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${cat.name} · ${acc.name}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Amount and Time / SMS import
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  appState.isPrivacyMode ? '••••' : amountStr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isIncome
                        ? AppColors.incomeGreen
                        : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
