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
    final isDark = AppColors.isDark(context);
    final accent = AppColors.accentOf(context);
    final selectedInk = isDark ? const Color(0xFF15130D) : const Color(0xFFF7F2E7);

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(
        IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'),
        size: 16,
        color: isSelected ? selectedInk : AppColors.textSecondaryOf(context),
      ),
      label: Text(
        category.name,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? selectedInk : AppColors.textPrimaryOf(context),
        ),
      ),
      backgroundColor: isDark ? const Color(0xFF191C1E) : const Color(0xFFF1ECE1),
      selectedColor: accent,
      side: BorderSide(
        color: isSelected ? accent : AppColors.borderOf(context),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onSelected: onSelected,
    );
  }
}
