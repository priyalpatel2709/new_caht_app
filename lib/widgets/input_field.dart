import 'package:flutter/material.dart';

class InputField extends StatelessWidget {
  const InputField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.readOnly = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      autofillHints: autofillHints,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 8),
                child: prefix,
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        suffixIcon: suffix,
      ),
    );
  }
}
