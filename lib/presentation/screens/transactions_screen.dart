import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/filter_criteria.dart';
import '../../services/app_state.dart';
import '../widgets/category_chip.dart';
import '../widgets/transaction_tile.dart';
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

  void _clearFilter() {
    _searchController.clear();
    _criteria = const FilterCriteria();
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
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter Transactions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _criteria = _criteria.copyWith(
                                clearCategory: true,
                                clearAccount: true,
                                clearType: true,
                                clearReviewed: true,
                              );
                            });
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Transaction Type
                    const Text('Transaction Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: AppConstants.allTransactionTypes.map((type) {
                        final isSel = _criteria.transactionType == type;
                        return ChoiceChip(
                          label: Text(type.toUpperCase()),
                          selected: isSel,
                          onSelected: (sel) {
                            setModalState(() {
                              _criteria = _criteria.copyWith(
                                transactionType: sel ? type : null,
                                clearType: !sel,
                              );
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Review Status
                    const Text('Review Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _criteria.isReviewed == null,
                          onSelected: (sel) {
                            setModalState(() {
                              _criteria = _criteria.copyWith(clearReviewed: true);
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Reviewed'),
                          selected: _criteria.isReviewed == true,
                          onSelected: (sel) {
                            setModalState(() {
                              _criteria = _criteria.copyWith(isReviewed: true);
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Needs Review'),
                          selected: _criteria.isReviewed == false,
                          onSelected: (sel) {
                            setModalState(() {
                              _criteria = _criteria.copyWith(isReviewed: false);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sort By
                    const Text('Sort By', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Newest First'),
                          selected: _criteria.sortBy == 'date_desc',
                          onSelected: (s) => setModalState(() => _criteria = _criteria.copyWith(sortBy: 'date_desc')),
                        ),
                        ChoiceChip(
                          label: const Text('Oldest First'),
                          selected: _criteria.sortBy == 'date_asc',
                          onSelected: (s) => setModalState(() => _criteria = _criteria.copyWith(sortBy: 'date_asc')),
                        ),
                        ChoiceChip(
                          label: const Text('Highest Amount'),
                          selected: _criteria.sortBy == 'amount_desc',
                          onSelected: (s) => setModalState(() => _criteria = _criteria.copyWith(sortBy: 'amount_desc')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Apply Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final txList = widget.appState.transactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            tooltip: 'Filter',
            icon: Badge(
              isLabelVisible: _criteria.hasActiveFilters,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _showFilterModal,
          ),
          IconButton(
            tooltip: 'Add Transaction',
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AddTransactionScreen(appState: widget.appState)),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar & Quick Categories
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search merchant, ref, notes...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),

          // Horizontal Category Filter Strip
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All Categories'),
                    selected: _criteria.categoryId == null,
                    showCheckmark: false,
                    onSelected: (sel) {
                      setState(() {
                        _criteria = _criteria.copyWith(clearCategory: true);
                        widget.appState.updateFilter(_criteria);
                      });
                    },
                  ),
                ),
                ...widget.appState.categories.map((cat) {
                  final isSel = _criteria.categoryId == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CategoryChip(
                      category: cat,
                      isSelected: isSel,
                      onSelected: (sel) {
                        setState(() {
                          _criteria = _criteria.copyWith(
                            categoryId: sel ? cat.id : null,
                            clearCategory: !sel,
                          );
                          widget.appState.updateFilter(_criteria);
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Active filter banner (if any)
          if (_criteria.hasActiveFilters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${txList.length} matching transaction(s)',
                    style: TextStyle(fontSize: 12, color: secondaryTextColor, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _clearFilter,
                    child: const Text(
                      'Clear Filters',
                      style: TextStyle(fontSize: 12, color: AppColors.clayPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // Transaction List View
          Expanded(
            child: txList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 56, color: secondaryTextColor.withOpacity(0.4)),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primaryTextColor),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try clearing your search query or filters',
                          style: TextStyle(fontSize: 13, color: secondaryTextColor),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: txList.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 72,
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                    itemBuilder: (context, index) {
                      final tx = txList[index];
                      final cat = widget.appState.categories.firstWhere(
                        (c) => c.id == tx.categoryId,
                        orElse: () => widget.appState.categories.first,
                      );
                      final acc = widget.appState.accounts.firstWhere(
                        (a) => a.id == tx.accountId,
                        orElse: () => widget.appState.accounts.first,
                      );

                      return TransactionTile(
                        transaction: tx,
                        category: cat,
                        account: acc,
                        hideAmount: widget.appState.isPrivacyMode,
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
