enum ShopRole { owner, cashier }

enum Permission {
  dashboard,
  products,
  purchases,
  sales,
  inventory,
  customers,
  suppliers,
  ledger,
  expenses,
  reports,
  settings,
  purchaseCosts,
  profit,
  staffManagement,
  stockAdjustments,
  paymentCollection,
  receiptGeneration,
}

/// UI and future application services must consult this single policy.
/// Route guards are a foundation, not authentication or a security boundary.
abstract final class RolePermissions {
  static final Map<ShopRole, Set<Permission>> _grants = {
    ShopRole.owner: Set.unmodifiable(Permission.values),
    ShopRole.cashier: Set.unmodifiable({
      Permission.dashboard,
      Permission.sales,
      Permission.customers,
      Permission.paymentCollection,
      Permission.receiptGeneration,
    }),
  };
  static bool allows(ShopRole? role, Permission permission) =>
      _grants[role]?.contains(permission) ?? false;
}
