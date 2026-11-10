import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../data/database/database_helper.dart';
import '../../domain/models/account_model.dart';
import '../../domain/models/filter_criteria.dart';
import '../../services/app_state.dart';
import '../widgets/skeuomorphic.dart';
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
      backgroundColor: Colors.transparent,
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
          Text(
            'Your money, with a place for every part.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondaryOf(context),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 20),

          // Total across X accounts
          Text(
            'TOTAL ACROSS ${appState.accounts.length} ACCOUNTS',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              color: AppColors.textSecondaryOf(context),
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
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryOf(context),
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppConstants.defaultCurrency,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: AppColors.textMutedOf(context),
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
          SkeuoPanel(
            inset: true,
            radius: 14,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.textSecondaryOf(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Balances reflect imported alerts or manual updates, not a live connection to your bank.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.textSecondaryOf(context),
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

    return SkeuoPanel(
      margin: const EdgeInsets.only(bottom: 16),
      radius: 18,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Bank/Wallet icon in a debossed well
                SkeuoIconWell(
                  icon: _getAccountIcon(acc),
                  size: 42,
                  iconSize: 20,
                  radius: 12,
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
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryOf(context),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${acc.type.toUpperCase()} · ${acc.accountNumberMasked ?? "••••"}',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.7,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondaryOf(context),
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
                  'AVAILABLE BALANCE',
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMutedOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.appState.isPrivacyMode ? '••••••' : balanceMoney.format(),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryOf(context),
                        letterSpacing: -0.6,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: AppColors.textSecondaryOf(context),
                      ),
                      onPressed: () => _toggleExpand(acc.id),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Expanded details
          if (isExpanded) ...[
            const SkeuoDivider(height: 0),
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
                    value: (acc.isSmsLinked && acc.balanceSantims == 0)
                        ? 'Awaiting first SMS alert'
                        : acc.balanceSource,
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
                          Text(
                            'View transactions',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              color: AppColors.accentOf(context),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 13,
                            color: AppColors.accentOf(context),
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
      return const SkeuoBadge(
        label: 'SMS linked',
        icon: Icons.chat_bubble_outline,
        tone: SkeuoBadgeTone.accent,
      );
    } else {
      return const SkeuoBadge(
        label: 'Manual',
        icon: Icons.edit_outlined,
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
            fontSize: 12.5,
            color: AppColors.textMutedOf(context),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimaryOf(context),
            ),
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
