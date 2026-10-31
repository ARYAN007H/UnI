import 'package:flutter/material.dart';

/// The one text-field component. Visuals come from the theme's
/// inputDecorationTheme (12r, filled, accent focus); this adds the label
/// pattern and multiline/obscure handling.
class AppTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final bool obscure;
  final bool enabled;
  final int maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final Widget? suffix;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.obscure = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.focusNode,
    this.suffix,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      obscureText: obscure,
      enabled: enabled,
      maxLines: obscure ? 1 : maxLines,
      minLines: obscure ? 1 : minLines,
      keyboardType: keyboardType,
      focusNode: focusNode,
      autofocus: autofocus,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelStyle:
            TextStyle(color: Theme.of(context).colorScheme.primary),
        suffixIcon: suffix,
      ),
    );
  }
}
