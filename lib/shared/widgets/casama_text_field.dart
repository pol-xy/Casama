import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';

class CasamaTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int maxLines;
  final void Function(String)? onChanged;
  final bool readOnly;
  final bool enabled;
  final VoidCallback? onTap;
  final Color? fillColor;

  const CasamaTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.helperText,
    this.prefixIcon,
    this.suffix,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.focusNode,
    this.onFieldSubmitted,
    this.autofillHints,
    this.inputFormatters,
    this.validator,
    this.maxLines = 1,
    this.onChanged,
    this.readOnly = false,
    this.enabled = true,
    this.onTap,
    this.fillColor,
  });

  @override
  State<CasamaTextField> createState() => _CasamaTextFieldState();
}

class _CasamaTextFieldState extends State<CasamaTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    Widget? effectiveSuffix = widget.suffix;
    if (widget.isPassword && effectiveSuffix == null) {
      effectiveSuffix = IconButton(
        tooltip: _obscure ? 'Show password' : 'Hide password',
        onPressed: widget.enabled
            ? () => setState(() => _obscure = !_obscure)
            : null,
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
          color: pal.textSecondary,
        ),
      );
    }

    return Semantics(
      textField: true,
      label: widget.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                widget.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: pal.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: CasamaSpacing.xs),
          TextFormField(
            controller: widget.controller,
            obscureText: widget.isPassword ? _obscure : false,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            textInputAction: widget.textInputAction,
            focusNode: widget.focusNode,
            onFieldSubmitted: widget.onFieldSubmitted,
            autofillHints: widget.autofillHints,
            inputFormatters: widget.inputFormatters,
            validator: widget.validator,
            maxLines: widget.isPassword ? 1 : widget.maxLines,
            onChanged: widget.onChanged,
            readOnly: widget.readOnly,
            enabled: widget.enabled,
            onTap: widget.onTap,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: pal.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: widget.fillColor ?? pal.track,
              hintText: widget.hint,
              helperText: widget.helperText,
              errorMaxLines: 2,
              prefixIcon: widget.prefixIcon != null
                  ? Icon(widget.prefixIcon, size: 20, color: pal.textSecondary)
                  : null,
              suffixIcon: effectiveSuffix,
            ),
          ),
        ],
      ),
    );
  }
}
