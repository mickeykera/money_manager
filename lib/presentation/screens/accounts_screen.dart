import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../data/database/database_helper.dart';
import '../../domain/models/account_model.dart';
import '../../domain/models/filter_criteria.dart';
import '../../services/app_state.dart';
import 'transactions_screen.dart';

class AccountsScreen extends StatefulWidget {
  final AppState appState;

  const AccountsScreen({super.key, required this.appState});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  // Track which accounts are expanded
  final Set<String> _expandedAccountIds = {};

  @override
  void initState() {
    super.initState();
    // Default the first account to expanded
    if (widget.appState.accounts.isNotEmpty) {
      _expandedAccountIds.add(widget.appState.accounts.first.id);
    }
  }

  void _toggleExpand(String id) {
    setState(() {
      if (_expandedAccountIds.contains(id)) {
        _expandedAccountIds.remove(id);
      } else {
        _expandedAccountIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appState = widget.appState;
    final totalBalanceSantims = appState.totalBalanceSantims;
    final totalMoney = Money(totalBalanceSantims);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.offWhiteBg,
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Account',
            onPressed: () => _showAddAccountDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Subtitle
          const Text(
            'Your money, with a place for every part.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 20),

          // Total across X accounts
          Text(
            'Total across ${appState.accounts.length} accounts',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),

          // Big Total Balance
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                appState.isPrivacyMode ? '••••••' : totalMoney.format(includeCurrency: false),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                AppConstants.defaultCurrency,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Account Cards List
          ...appState.accounts.map((acc) {
            final isExpanded = _expandedAccountIds.contains(acc.id);
            return _buildAccountCard(context, acc, isExpanded, isDark);
          }),

          const SizedBox(height: 24),

          // Balances Disclaimer Footer Note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard.withOpacity(0.5) : Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderSubtle),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Balances reflect imported alerts or manual updates, not a live connection to your bank.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, AccountModel acc, bool isExpanded, bool isDark) {
    final balanceMoney = acc.balance;
    final cardBg = isDark ? AppColors.darkCard : AppColors.cardWhite;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.borderSubtle;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Bank/Wallet Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2822) : const Color(0xFFF3F2EC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getAccountIcon(acc),
                    size: 20,
                    color: isDark ? const Color(0xFF98C5AA) : AppColors.forestGreen,
                  ),
                ),
                const SizedBox(width: 12),
                // Name & Type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        acc.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${acc.type.toUpperCase()} · ${acc.accountNumberMasked ?? "••••"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge
                _buildBadge(acc.isSmsLinked),
              ],
            ),
          ),

          // Available balance section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available balance',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.appState.isPrivacyMode ? '••••••' : balanceMoney.format(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        letterSpacing: -0.6,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
                      ),
                      onPressed: () => _toggleExpand(acc.id),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Expanded details (Screen 3 in ui.jpg)
          if (isExpanded) ...[
            Divider(color: borderColor, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                children: [
                  _buildDetailRow(
                    label: 'Currency',
                    value: '${acc.currency == "ETB" ? "Ethiopian birr" : acc.currency} - ${acc.currency}',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    label: 'Balance source',
                    value: acc.balanceSource,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    label: 'Last updated',
                    value: DateFormat('MMM d, h:mm a').format(DateTime.now()),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  // View Transactions Link
                  InkWell(
                    onTap: () {
                      widget.appState.updateFilter(
                        FilterCriteria(accountId: acc.id),
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TransactionsScreen(appState: widget.appState),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'View transactions',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.forestGreen,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.forestGreen,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(bool isSmsLinked) {
    if (isSmsLinked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.greenAccentPill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 12, color: AppColors.greenAccentText),
            SizedBox(width: 5),
            Text(
              'SMS linked',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.greenAccentText,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFEA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, size: 12, color: AppColors.textSecondary),
            SizedBox(width: 5),
            Text(
              'Manual',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDetailRow({required String label, required String value, required bool isDark}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  IconData _getAccountIcon(AccountModel acc) {
    final lower = acc.name.toLowerCase();
    if (lower.contains('telebirr') || lower.contains('mpesa') || lower.contains('m-pesa')) {
      return Icons.phone_android;
    }
    if (lower.contains('cash')) {
      return Icons.payments_outlined;
    }
    return Icons.account_balance_outlined;
  }

  void _showAddAccountDialog(BuildContext context) {
    final nameController = TextEditingController();
    final balanceController = TextEditingController();
    String type = 'bank';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Account Name (e.g. Dashen Bank)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Starting Balance (ETB)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(labelText: 'Account Type'),
              items: const [
                DropdownMenuItem(value: 'bank', child: Text('Bank Account')),
                DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
                DropdownMenuItem(value: 'cash', child: Text('Cash Wallet')),
              ],
              onChanged: (val) {
                if (val != null) type = val;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                final bal = Money.parseString(balanceController.text.trim()).santims;
                final newAcc = AccountModel(
                  id: 'acc_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameController.text.trim(),
                  type: type,
                  currency: AppConstants.defaultCurrency,
                  balanceSantims: bal,
                  isSmsLinked: false,
                  balanceSource: 'Manual entry',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                // Save through repo
                final db = await DatabaseHelper().database;
                await db.insert('accounts', newAcc.toMap());
                await widget.appState.reloadAll();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
