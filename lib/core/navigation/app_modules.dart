import 'package:flutter/material.dart';

import '../permissions/permissions.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/purchases/presentation/purchases_screen.dart';
import '../../features/sales/presentation/sales_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/suppliers/presentation/suppliers_screen.dart';
import '../../features/ledger/presentation/ledger_screen.dart';
import '../../features/expenses/presentation/expenses_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

class AppModule {
  const AppModule(
    this.path,
    this.title,
    this.icon,
    this.permission,
    this.screen,
  );
  final String path;
  final String title;
  final IconData icon;
  final Permission permission;
  final Widget screen;
}

abstract final class AppModules {
  static const all = [
    AppModule(
      '/dashboard',
      'Dashboard',
      Icons.space_dashboard_outlined,
      Permission.dashboard,
      DashboardScreen(),
    ),
    AppModule(
      '/products',
      'Products',
      Icons.category_outlined,
      Permission.products,
      ProductsScreen(),
    ),
    AppModule(
      '/purchases',
      'Purchases',
      Icons.shopping_bag_outlined,
      Permission.purchases,
      PurchasesScreen(),
    ),
    AppModule(
      '/sales',
      'Sales',
      Icons.point_of_sale_outlined,
      Permission.sales,
      SalesScreen(),
    ),
    AppModule(
      '/inventory',
      'Inventory',
      Icons.inventory_2_outlined,
      Permission.inventory,
      InventoryScreen(),
    ),
    AppModule(
      '/customers',
      'Customers',
      Icons.people_outline,
      Permission.customers,
      CustomersScreen(),
    ),
    AppModule(
      '/suppliers',
      'Suppliers',
      Icons.local_shipping_outlined,
      Permission.suppliers,
      SuppliersScreen(),
    ),
    AppModule(
      '/ledger',
      'Khata / Ledger',
      Icons.menu_book_outlined,
      Permission.ledger,
      LedgerScreen(),
    ),
    AppModule(
      '/expenses',
      'Expenses',
      Icons.payments_outlined,
      Permission.expenses,
      ExpensesScreen(),
    ),
    AppModule(
      '/reports',
      'Reports',
      Icons.bar_chart_outlined,
      Permission.reports,
      ReportsScreen(),
    ),
    AppModule(
      '/settings',
      'Settings',
      Icons.settings_outlined,
      Permission.settings,
      SettingsScreen(),
    ),
  ];
  static AppModule? find(String? path) {
    for (final module in all) {
      if (module.path == path) return module;
    }
    return null;
  }

  static Iterable<AppModule> allowed(ShopRole? role) =>
      all.where((module) => RolePermissions.allows(role, module.permission));
}
