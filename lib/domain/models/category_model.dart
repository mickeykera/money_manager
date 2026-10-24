import '../../core/utils/money.dart';

class CategoryModel {
  final String id;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final int monthlyBudgetSantims;
  final bool isIncome;
  final DateTime createdAt;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    this.monthlyBudgetSantims = 0,
    this.isIncome = false,
    required this.createdAt,
  });

  Money get monthlyBudget => Money(monthlyBudgetSantims);

  CategoryModel copyWith({
    String? id,
    String? name,
    int? iconCodePoint,
    int? colorValue,
    int? monthlyBudgetSantims,
    bool? isIncome,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      monthlyBudgetSantims: monthlyBudgetSantims ?? this.monthlyBudgetSantims,
      isIncome: isIncome ?? this.isIncome,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon_code_point': iconCodePoint,
      'color_value': colorValue,
      'monthly_budget_santims': monthlyBudgetSantims,
      'is_income': isIncome ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      iconCodePoint: map['icon_code_point'] as int,
      colorValue: map['color_value'] as int,
      monthlyBudgetSantims: (map['monthly_budget_santims'] as int?) ?? 0,
      isIncome: (map['is_income'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
