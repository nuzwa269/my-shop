import 'package:flutter/material.dart';

import '../../core/validation/validation.dart';

String actionError(Object error) => error is ValidationException
    ? error.message
    : 'The action could not be completed. Your changes were not saved. Please try again.';

class EntryField extends StatelessWidget {
  const EntryField(
    this.controller,
    this.label, {
    super.key,
    this.obscure = false,
    this.numeric = false,
    this.lines = 1,
    this.hint,
    this.enabled = true,
  });
  final TextEditingController controller;
  final String label;
  final bool obscure, numeric, enabled;
  final int lines;
  final String? hint;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      maxLines: lines,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      autocorrect: !obscure,
      enableSuggestions: !obscure,
      decoration: InputDecoration(labelText: label, helperText: hint),
    ),
  );
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.message, {super.key});
  final String? message;
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            message!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        );
}
