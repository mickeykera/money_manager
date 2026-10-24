import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../domain/models/filter_criteria.dart';
import '../../domain/models/transaction_model.dart';
import '../../services/app_state.dart';
import 'add_transaction_screen.dart';
import 'transaction_detail_screen.dart';

class TransactionsScreen extends StatefulWidget {
  final AppState appState;
  final bool? initialFilterReviewed;

  const TransactionsScreen({
    super.key,
    required this.appState,
    this.initialFilterReviewed,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  late FilterCriteria _criteria;
  String _typeFilter = 'all'; // 'all', 'in', 'out'

  @override
  void initState() {
    super.initState();
    _criteria = widget.appState.filterCriteria;
    if (widget.initialFilterReviewed != null) {
      _criteria = _criteria.copyWith(isReviewed: widget.initialFilterReviewed);
      widget.appState.updateFilter(_criteria);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _criteria = _criteria.copyWith(searchQuery: val);
    widget.appState.updateFilter(_criteria);
  }

  void _setTypeFilter(String type) {
    setState(() {
      _typeFilter = type;
      if (type == 'in') {
        _criteria = _criteria.copyWith(transactionType: AppConstants.typeIncome);
      } else if (type == 'out') {
        _criteria = _criteria.copyWith(transactionType: AppConstants.typeExpense);
      } else {
        _criteria = _criteria.copyWith(clearType: true);
      }
    });
    widget.appState.updateFilter(_criteria);
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  left: 20,
                  right: 20,
                  top: 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filter Transactions',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _criteria = const FilterCriteria();
                                _typeFilter = 'all';
                              });
                              widget.appState.updateFilter(_criteria);
                              Navigator.pop(ctx);
                            },
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Review Status', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: _criteria.isReviewed == null,
                            onSelected: (_) {
                              setModalState(() => _criteria = _criteria.copyWith(isReviewed: null));
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Needs Review'),
                            selected: _criteria.isReviewed == false,
                            onSelected: (_) {
                              setModalState(() => _criteria = _criteria.copyWith(isReviewed: false));
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Reviewed'),
                            selected: _criteria.isReviewed == true,
                            onSelected: (_) {
                              setModalState(() => _criteria = _criteria.copyWith(isReviewed: true));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Accounts', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: widget.appState.accounts.map((acc) {
                          final isSelected = _criteria.accountId == acc.id;
                          return FilterChip(
                            label: Text(acc.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                _criteria = _criteria.copyWith(
                                  accountId: selected ? acc.id : null,
                                  clearAccount: !selected,
                                );
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            widget.appState.updateFilter(_criteria);
                            Navigator.pop(ctx);
                          },
                          child: const Text('Apply Filters'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final transactions = widget.appState.transactions;
    final summary = widget.appState.dashboardSummary;
    final incomeMoney = Money(summary.totalIncomeSantims);
    final expenseMoney = Money(summary.totalExpenseSantims);

    // Group transactions by Date Header
    final grouped = _groupTransactionsByDate(transactions);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.offWhiteBg,
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Transaction',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AddTransactionScreen(appState: widget.appState)),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Subtitle (Screen 2 in ui.jpg)
          const Text(
            'A little clarity in every transaction.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 18),

          // Search Bar with Filter Slider Button
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderSubtle),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search merchants, amounts...',
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.tune, size: 20, color: AppColors.textPrimary),
                  onPressed: _showFilterModal,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Filter Chips: All, Money in, Money out
          Row(
            children: [
              _buildFilterChip('All', 'all', isDark),
              const SizedBox(width: 8),
              _buildFilterChip('Money in', 'in', isDark),
              const SizedBox(width: 8),
              _buildFilterChip('Money out', 'out', isDark),
            ],
          ),
          const SizedBox(height: 20),

          // Month Summary Card (Screen 2 in ui.jpg)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.cardWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MONEY IN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.appState.isPrivacyMode ? '••••' : incomeMoney.format(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.incomeGreen,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MONEY OUT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.appState.isPrivacyMode ? '••••' : expenseMoney.format(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
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

          // Grouped Transactions
          if (transactions.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: const Text('No transactions match the criteria.', style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ...grouped.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderSubtle),
                    ),
                    child: Column(
                      children: entry.value.map((tx) {
                        final cat = widget.appState.categories.firstWhere(
                          (c) => c.id == tx.categoryId,
                          orElse: () => widget.appState.categories.first,
                        );
                        final acc = widget.appState.accounts.firstWhere(
                          (a) => a.id == tx.accountId,
                          orElse: () => widget.appState.accounts.first,
                        );
                        final isLast = tx == entry.value.last;

                        return Column(
                          children: [
                            _buildTransactionItem(context, tx, cat, acc, isDark),
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
                ],
              );
            }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _typeFilter == value;
    return InkWell(
      onTap: () => _setTypeFilter(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.forestGreen
              : (isDark ? AppColors.darkCard : AppColors.cardWhite),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.forestGreen
                : (isDark ? AppColors.darkBorder : AppColors.borderSubtle),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
          ),
        ),
      ),
    );
  }

  Map<String, List<TransactionModel>> _groupTransactionsByDate(List<TransactionModel> list) {
    final Map<String, List<TransactionModel>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final tx in list) {
      final txDate = DateTime(tx.timestamp.year, tx.timestamp.month, tx.timestamp.day);
      String key;
      if (txDate == today) {
        key = 'TODAY · ${DateFormat("MMM d").format(tx.timestamp).toUpperCase()}';
      } else if (txDate == yesterday) {
        key = 'YESTERDAY · ${DateFormat("MMM d").format(tx.timestamp).toUpperCase()}';
      } else {
        key = 'EARLIER THIS MONTH · ${DateFormat("MMM d").format(tx.timestamp).toUpperCase()}';
      }

      groups.putIfAbsent(key, () => []).add(tx);
    }
    return groups;
  }

  Widget _buildTransactionItem(
    BuildContext context,
    TransactionModel tx,
    dynamic cat,
    dynamic acc,
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
              appState: widget.appState,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.appState.isPrivacyMode ? '••••' : amountStr,
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
