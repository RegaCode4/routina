import 'package:flutter/material.dart';
import 'package:routina/presentation/design_system/neo_tokens.dart';

class NeoFormField extends StatelessWidget {
  const NeoFormField({
    required this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.icon,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    super.key,
  });

  final String label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final IconData? icon;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      validator: validator,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: enabled ? NeoColors.ink : NeoColors.muted),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        errorText: errorText,
        prefixIcon: icon == null ? null : Icon(icon),
        fillColor: enabled ? null : NeoColors.disabled,
      ),
    );
  }
}
