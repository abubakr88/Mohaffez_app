import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

class DSSelectItem<T> {
  const DSSelectItem({required this.value, required this.label});
  final T value;
  final String label;
}

class DSSelect<T> extends StatelessWidget {
  const DSSelect({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.label,
    this.hint,
    this.error,
  });

  final List<DSSelectItem<T>> items;
  final ValueChanged<T?> onChanged;
  final T? value;
  final String? label;
  final String? hint;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: DSText.caption(context, color: DSColors.text2)),
          const SizedBox(height: DSSpacing.xs),
        ],
        DropdownButtonFormField<T>(
          value: value,
          onChanged: onChanged,
          style: DSText.body(context),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: DSText.body(context, color: DSColors.text3),
            errorText: error,
            filled: true,
            fillColor: DSColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: DSSpacing.lg,
              vertical: DSSpacing.md,
            ),
            border: const OutlineInputBorder(
              borderRadius: DSRadius.mdAll,
              borderSide: BorderSide(color: DSColors.border),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: DSRadius.mdAll,
              borderSide: BorderSide(color: DSColors.border),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: DSRadius.mdAll,
              borderSide: BorderSide(color: DSColors.primary, width: 1.5),
            ),
          ),
          items: items
              .map((i) => DropdownMenuItem<T>(
                    value: i.value,
                    child: Text(i.label, style: DSText.body(context)),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
