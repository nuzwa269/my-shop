import 'package:flutter/material.dart';

class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({required this.title, super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'This module will be available in a later phase.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
