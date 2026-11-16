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
    this.initialValue,
    this.focusNode,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.obscureText = false,
    this.labelAbove = false,
    this.maxLines = 1,
    this.keyboardType,
    super.key,
  });

  final String label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final IconData? icon;
  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool obscureText;
  final bool labelAbove;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final input = TextFormField(
      controller: controller,
      initialValue: initialValue,
      focusNode: focusNode,
      onChanged: onChanged,
      validator: validator,
      enabled: enabled,
      obscureText: obscureText,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: enabled ? NeoColors.ink : NeoColors.muted),
      decoration: InputDecoration(
        labelText: labelAbove ? null : label,
        hintText: hint,
        helperText: helper,
        errorText: errorText,
        prefixIcon: icon == null ? null : Icon(icon),
        fillColor: enabled ? null : NeoColors.disabled,
      ),
    );
    if (!labelAbove) return input;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(child: Text(label, style: NeoType.badge)),
        const SizedBox(height: NeoSpace.xxs),
        Semantics(label: label, child: input),
      ],
    );
  }
}
