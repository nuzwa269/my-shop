import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/app_modules.dart';
import '../../core/permissions/permissions.dart';
import '../../features/auth/application/session_provider.dart';
import 'form_support.dart';

class ModuleShell extends ConsumerWidget {
  const ModuleShell({required this.module, super.key});
  final AppModule module;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).asData?.value;
    if (!RolePermissions.allows(session?.owner?.role, module.permission)) {
      return const Scaffold(body: Center(child: Text('Access unavailable')));
    }
    return Scaffold(
      appBar: AppBar(title: Text(module.title)),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  session?.shop?.name ?? 'Shop Manager',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(session!.owner!.fullName),
              ),
              const Divider(height: 32),
              for (final destination in AppModules.allowed(session.owner!.role))
                ListTile(
                  leading: Icon(destination.icon),
                  title: Text(destination.title),
                  selected: destination.path == module.path,
                  onTap: () {
                    Navigator.of(context).pop();
                    if (destination.path != module.path) {
                      Navigator.of(context)
                          .pushReplacementNamed(destination.path);
                    }
                  },
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                onTap: () async {
                  try {
                    await ref.read(sessionProvider.notifier).logout();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(actionError(e))));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(child: module.screen),
    );
  }
}
