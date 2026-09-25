import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/app_modules.dart';
import 'core/theme/app_theme.dart';
import 'database/database_provider.dart';
import 'features/auth/application/session_provider.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/settings/presentation/shop_setup_screen.dart';
import 'shared/widgets/form_support.dart';
import 'shared/widgets/module_shell.dart';

class ShopManagerApp extends ConsumerStatefulWidget {
  const ShopManagerApp({super.key});
  @override
  ConsumerState<ShopManagerApp> createState() => _ShopManagerAppState();
}

class _ShopManagerAppState extends ConsumerState<ShopManagerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(sessionProvider);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    return MaterialApp(
      key: ValueKey(session.asData?.value.owner?.userId ?? 'locked'),
      title: 'Shop Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => Consumer(
          builder: (context, ref, _) => ref
              .watch(sessionProvider)
              .when(
                loading: () => const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Scaffold(
                  body: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              actionError(error),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () {
                                ref.invalidate(databaseProvider);
                                ref.invalidate(sessionProvider);
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                data: (state) {
                  if (!state.configured) return const ShopSetupScreen();
                  if (state.owner == null) return const LoginScreen();
                  final module = AppModules.find(
                    settings.name == '/' ? '/dashboard' : settings.name,
                  );
                  return module == null
                      ? const Scaffold(
                          body: Center(child: Text('Screen not found')),
                        )
                      : ModuleShell(module: module);
                },
              ),
        ),
      ),
    );
  }
}
