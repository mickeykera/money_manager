import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/category_model.dart';

class CategoryChip extends StatelessWidget {
  final CategoryModel category;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;

  const CategoryChip({
    super.key,
    required this.category,
    required this.isSelected,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catColor = Color(category.colorValue);

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(
        IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'),
        size: 16,
        color: isSelected ? Colors.white : catColor,
      ),
      label: Text(
        category.name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected
              ? Colors.white
              : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        ),
      ),
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      selectedColor: catColor,
      side: BorderSide(
        color: isSelected ? catColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onSelected: onSelected,
    );
  }
}
