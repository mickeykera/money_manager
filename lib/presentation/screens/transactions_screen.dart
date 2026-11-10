import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../domain/models/filter_criteria.dart';
import '../../domain/models/transaction_model.dart';
import '../../services/app_state.dart';
import '../widgets/skeuomorphic.dart';
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
      backgroundColor: Colors.transparent,
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
          // Subtitle
          Text(
            'A little clarity in every transaction.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondaryOf(context),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 18),

          // Search Bar with Filter Slider Button
          SkeuoPanel(
            inset: true,
            radius: 16,
            padding: EdgeInsets.zero,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(color: AppColors.textPrimaryOf(context)),
              decoration: InputDecoration(
                hintText: 'Search merchants, amounts...',
                hintStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13.5,
                  color: AppColors.textMutedOf(context),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: AppColors.textMutedOf(context),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    Icons.tune,
                    size: 20,
                    color: AppColors.textPrimaryOf(context),
                  ),
                  onPressed: _showFilterModal,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
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

          // Month Summary Card
          SkeuoPanel(
            padding: const EdgeInsets.all(19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(DateTime.now()),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MONEY IN',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.3,
                              color: AppColors.textMutedOf(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.appState.isPrivacyMode ? '••••' : incomeMoney.format(),
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.incomeOf(context),
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
                          Text(
                            'MONEY OUT',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.3,
                              color: AppColors.textMutedOf(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.appState.isPrivacyMode ? '••••' : expenseMoney.format(),
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryOf(context),
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
            SkeuoPanel(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Center(
                child: Text(
                  'No transactions match the criteria.',
                  style: TextStyle(color: AppColors.textSecondaryOf(context)),
                ),
              ),
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
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondaryOf(context),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  SkeuoPanel(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.zero,
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
                              const SkeuoDivider(indent: 68, height: 0),
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
    final accent = AppColors.accentOf(context);
    return InkWell(
      onTap: () => _setTypeFilter(value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [const Color(0xFF2C3033), const Color(0xFF101214)]
                      : [const Color(0xFF34383B), const Color(0xFF171A1C)],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [const Color(0xFF1E2124), const Color(0xFF141617)]
                      : [const Color(0xFFF8F4EC), const Color(0xFFE5DFD3)],
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.18)
                : AppColors.borderOf(context),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
              blurRadius: isSelected ? 6 : 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: isSelected
                ? (isDark ? accent : const Color(0xFFF3EEE4))
                : AppColors.textPrimaryOf(context),
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
      final sameMonth =
          tx.timestamp.year == now.year && tx.timestamp.month == now.month;
      String key;
      if (txDate == today) {
        key = 'TODAY · ${DateFormat("MMM d").format(tx.timestamp).toUpperCase()}';
      } else if (txDate == yesterday) {
        key = 'YESTERDAY · ${DateFormat("MMM d").format(tx.timestamp).toUpperCase()}';
      } else if (sameMonth) {
        key = 'EARLIER THIS MONTH · ${DateFormat("MMM d").format(tx.timestamp).toUpperCase()}';
      } else {
        key = DateFormat("MMM d, yyyy").format(tx.timestamp).toUpperCase();
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.appState.isPrivacyMode ? '••••' : amountStr,
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
