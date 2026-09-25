import 'package:flutter/material.dart';

import '../../auth/presentation/staff_screen.dart';
import '../../demo/presentation/demo_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      ListTile(
        leading: const Icon(Icons.science_outlined),
        title: const Text('Optional demo data'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const DemoScreen()),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.badge_outlined),
        title: const Text('Cashier / staff access'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const StaffScreen()),
        ),
      ),
    ],
  );
}
