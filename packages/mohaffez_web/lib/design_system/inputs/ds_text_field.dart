import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

class DSTextField extends StatelessWidget {
  const DSTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.error,
    this.leading,
    this.trailing,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.maxLines = 1,
    this.autofocus = false,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? error;
  final Widget? leading;
  final Widget? trailing;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final int maxLines;
  final bool autofocus;
  final FocusNode? focusNode;

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
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          enabled: enabled,
          maxLines: maxLines,
          autofocus: autofocus,
          focusNode: focusNode,
          style: DSText.body(context),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: DSText.body(context, color: DSColors.text3),
            prefixIcon: leading,
            suffixIcon: trailing,
            errorText: error,
            filled: true,
            fillColor: enabled ? DSColors.surface : DSColors.surfaceMuted,
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
            errorBorder: const OutlineInputBorder(
              borderRadius: DSRadius.mdAll,
              borderSide: BorderSide(color: DSColors.error),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: DSRadius.mdAll,
              borderSide: BorderSide(color: DSColors.error, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: DSRadius.mdAll,
              borderSide: BorderSide(color: DSColors.border.withValues(alpha: 0.5)),
            ),
          ),
        ),
        if (helper != null && error == null) ...[
          const SizedBox(height: DSSpacing.xs),
          Text(helper!, style: DSText.caption(context, color: DSColors.text3)),
        ],
      ],
    );
  }
}
