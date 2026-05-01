import 'package:flutter/material.dart';

import '../../../models/quran_mistake_model.dart';
import '../../utils/quran_mistake_utils.dart';
import 'package:mohaffez_finder_app/shared/theme/app_theme_constants.dart';

class MistakeTypeSelector extends StatelessWidget {
  final MistakeType selectedType;
  final ValueChanged<MistakeType> onChanged;

  const MistakeTypeSelector({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppThemeConstants.grey100,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: MistakeType.values.map((type) {
            final isSelected = selectedType == type;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                avatar: Icon(
                  getMistakeIcon(type),
                  size: 16,
                  color: isSelected ? AppThemeConstants.white : AppThemeConstants.black87,
                ),
                label: Text(type.fullLabel),
                selected: isSelected,
                onSelected: (_) => onChanged(type),
                selectedColor: getMistakeColor(type),
                labelStyle: TextStyle(
                  color: isSelected ? AppThemeConstants.white : AppThemeConstants.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
