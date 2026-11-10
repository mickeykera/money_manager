import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../domain/models/account_model.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/transaction_model.dart';
import '../../services/app_state.dart';
import '../widgets/skeuomorphic.dart';
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
      backgroundColor: Colors.transparent,
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
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF303437), Color(0xFF111314)],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.06),
                            blurRadius: 1,
                            offset: const Offset(0, -1),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.eco_rounded,
                        color: AppColors.accentOf(context),
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'LedgerLeaf',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: AppColors.textPrimaryOf(context),
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
                  child: SkeuoInset(
                    width: 38,
                    height: 38,
                    radius: 19,
                    child: Text(
                      'AL',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Hero balance plaque
            SkeuoPanel(
              hero: true,
              ornament: true,
              radius: 24,
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'YOUR TOTAL BALANCE',
                        style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 1.5,
                          color: AppColors.forestGreenSubtext,
                          fontWeight: FontWeight.w600,
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
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF6F1E7),
                      letterSpacing: -1.2,
                      shadows: [
                        Shadow(
                          color: Color(0x66000000),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppConstants.defaultCurrency} · Across ${appState.accounts.length} accounts',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                      color: AppColors.forestGreenSubtext,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
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
                                SizedBox(width: 5),
                                Text(
                                  'IN THIS MONTH',
                                  style: TextStyle(
                                    color: AppColors.forestGreenSubtext,
                                    fontSize: 9.5,
                                    letterSpacing: 1.1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              appState.isPrivacyMode ? '••••' : incomeMoney.format(includeCurrency: false),
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: Color(0xFFF2EDE3),
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 34,
                        width: 1,
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.south_east, size: 13, color: AppColors.forestGreenSubtext),
                                SizedBox(width: 5),
                                Text(
                                  'OUT THIS MONTH',
                                  style: TextStyle(
                                    color: AppColors.forestGreenSubtext,
                                    fontSize: 9.5,
                                    letterSpacing: 1.1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              appState.isPrivacyMode ? '••••' : expenseMoney.format(includeCurrency: false),
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: Color(0xFFF2EDE3),
                                fontSize: 17,
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
                Text(
                  'Linked accounts',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    color: AppColors.textPrimaryOf(context),
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
                  child: Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: AppColors.accentOf(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Horizontal Linked Accounts Cards
            SizedBox(
              height: 128,
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
                Text(
                  'Recent activity',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    color: AppColors.textPrimaryOf(context),
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
                  child: Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: AppColors.accentOf(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Recent Transactions List
            if (appState.transactions.isEmpty)
              SkeuoPanel(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No recent activity recorded.',
                    style: TextStyle(color: AppColors.textSecondaryOf(context)),
                  ),
                ),
              )
            else
              SkeuoPanel(
                padding: EdgeInsets.zero,
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
                          const SkeuoDivider(indent: 68, height: 0),
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
                  fontSize: 11.5,
                  letterSpacing: 0.2,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
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
    return SizedBox(
      width: 154,
      child: SkeuoPanel(
        radius: 16,
        padding: const EdgeInsets.all(13),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SkeuoIconWell(
                icon: acc.name.toLowerCase().contains('telebirr') || acc.name.toLowerCase().contains('mpesa')
                    ? Icons.phone_android
                    : Icons.account_balance_outlined,
                size: 30,
                iconSize: 15,
                radius: 9,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  acc.name,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: AppColors.textPrimaryOf(context),
                  ),
                  maxLines: 1,
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
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${acc.type.toUpperCase()} · ${acc.accountNumberMasked ?? "••••"}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMutedOf(context),
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildTelecomCard(BuildContext context, dynamic telecom, bool isDark) {
    final totalGb = (telecom.ethioDataRemainingGb + telecom.safaricomDataRemainingGb) as double;
    final hasUnlimited = telecom.hasUnlimitedData as bool;
    final expiry = telecom.nextKnownExpiry as DateTime?;
    final expiryLabel = expiry != null
        ? ' · Expires ${DateFormat('MMM d, yyyy').format(expiry)}'
        : '';
    final summaryText = hasUnlimited
        ? 'Unlimited data$expiryLabel'
        : totalGb > 0
            ? '${totalGb.toStringAsFixed(1)} GB remaining$expiryLabel'
            : 'No active package reported';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (onNavigateToBundles != null) {
          onNavigateToBundles!();
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BundlesScreen(appState: appState)),
          );
        }
      },
      child: SkeuoPanel(
        radius: 16,
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            SkeuoIconWell(
              icon: Icons.cell_tower,
              size: 40,
              iconSize: 19,
              radius: 11,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Telecom Bundles',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    summaryText,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textMutedOf(context),
            ),
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
            // Category icon in a debossed well
            SkeuoInset(
              width: 40,
              height: 40,
              radius: 11,
              child: Icon(
                IconData(cat.iconCodePoint, fontFamily: 'MaterialIcons'),
                size: 19,
                color: AppColors.accentOf(context),
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
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: AppColors.textPrimaryOf(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${cat.name} · ${acc.name}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondaryOf(context),
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
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isIncome
                        ? AppColors.incomeOf(context)
                        : AppColors.textPrimaryOf(context),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMutedOf(context),
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
