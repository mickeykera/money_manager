class FilterCriteria {
  final String searchQuery;
  final String? categoryId;
  final String? accountId;
  final String? transactionType;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool? isReviewed;
  final String sortBy; // 'date_desc', 'date_asc', 'amount_desc', 'amount_asc'

  const FilterCriteria({
    this.searchQuery = '',
    this.categoryId,
    this.accountId,
    this.transactionType,
    this.startDate,
    this.endDate,
    this.isReviewed,
    this.sortBy = 'date_desc',
  });

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      categoryId != null ||
      accountId != null ||
      transactionType != null ||
      startDate != null ||
      endDate != null ||
      isReviewed != null;

  FilterCriteria copyWith({
    String? searchQuery,
    String? categoryId,
    String? accountId,
    String? transactionType,
    DateTime? startDate,
    DateTime? endDate,
    bool? isReviewed,
    String? sortBy,
    bool clearCategory = false,
    bool clearAccount = false,
    bool clearType = false,
    bool clearDates = false,
    bool clearReviewed = false,
  }) {
    return FilterCriteria(
      searchQuery: searchQuery ?? this.searchQuery,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      transactionType: clearType ? null : (transactionType ?? this.transactionType),
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      isReviewed: clearReviewed ? null : (isReviewed ?? this.isReviewed),
      sortBy: sortBy ?? this.sortBy,
    );
  }
}
