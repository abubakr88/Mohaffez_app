import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

class DSSearchField extends StatefulWidget {
  const DSSearchField({
    super.key,
    this.hint = 'بحث...',
    this.onChanged,
    this.onSubmitted,
    this.controller,
  });

  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;

  @override
  State<DSSearchField> createState() => _DSSearchFieldState();
}

class _DSSearchFieldState extends State<DSSearchField> {
  late final TextEditingController _ctrl;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? TextEditingController();
    _ctrl.addListener(() => setState(() => _hasText = _ctrl.text.isNotEmpty));
  }

  @override
  void dispose() {
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      style: DSText.body(context),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: DSText.body(context, color: DSColors.text3),
        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: DSColors.text3),
        suffixIcon: _hasText
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 16, color: DSColors.text3),
                onPressed: () {
                  _ctrl.clear();
                  widget.onChanged?.call('');
                },
              )
            : null,
        filled: true,
        fillColor: DSColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DSSpacing.lg,
          vertical: DSSpacing.md,
        ),
        border: const OutlineInputBorder(
          borderRadius: DSRadius.lgAll,
          borderSide: BorderSide(color: DSColors.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: DSRadius.lgAll,
          borderSide: BorderSide(color: DSColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: DSRadius.lgAll,
          borderSide: BorderSide(color: DSColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
