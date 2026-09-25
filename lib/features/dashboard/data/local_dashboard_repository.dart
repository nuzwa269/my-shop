import '../../../core/money/money.dart';
import '../../../core/permissions/permissions.dart';
import '../../../database/database_connection.dart';
import '../../auth/domain/auth_repository.dart';

class DashboardMoney {
  DashboardMoney(this.currency);
  final Currency currency;
  int sales = 0, purchases = 0, expenses = 0, receivable = 0, payable = 0;
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.cashier,
    required this.money,
    required this.date,
    this.activeProducts = 0,
    this.lowStock = 0,
    this.outOfStock = 0,
    this.demo = false,
  });
  final bool cashier, demo;
  final List<DashboardMoney> money;
  final DateTime date;
  final int activeProducts, lowStock, outOfStock;
}

class LocalDashboardRepository {
  LocalDashboardRepository(this.db, this.auth, {int Function()? clock})
    : now = clock ?? (() => DateTime.now().millisecondsSinceEpoch);
  final DatabaseConnection db;
  final AuthRepository auth;
  final int Function() now;
  Future<DashboardSnapshot> summary() => db.transaction((tx) async {
    final user = await auth.authorize(tx, Permission.dashboard);
    final cashier = user.role == ShopRole.cashier;
    final date = DateTime.fromMillisecondsSinceEpoch(now());
    final start = DateTime(
      date.year,
      date.month,
      date.day,
    ).millisecondsSinceEpoch;
    final end = DateTime(
      date.year,
      date.month,
      date.day + 1,
    ).millisecondsSinceEpoch;
    final shop = (await tx.select(
      'SELECT currency_code,currency_minor_digits FROM shops WHERE id=?',
      [user.shopId],
    )).single;
    final buckets = <String, DashboardMoney>{};
    DashboardMoney bucket(Map<String, Object?> row) => buckets.putIfAbsent(
      '${row['currency_code']}:${row['currency_minor_digits']}',
      () => DashboardMoney(
        Currency(
          row['currency_code'] as String,
          minorDigits: row['currency_minor_digits'] as int,
        ),
      ),
    );
    bucket(shop);
    for (final table
        in cashier ? ['sales'] : ['sales', 'purchases', 'expenses']) {
      final rows = await tx.select(
        "SELECT currency_code,currency_minor_digits,total_minor FROM $table WHERE shop_id=? AND status='posted' AND occurred_at>=? AND occurred_at<?${cashier ? ' AND created_by=?' : ''}",
        [user.shopId, start, end, if (cashier) user.userId],
      );
      for (final row in rows) {
        final b = bucket(row), amount = row['total_minor'] as int;
        switch (table) {
          case 'sales':
            b.sales = Money.sum([b.sales, amount]);
          case 'purchases':
            b.purchases = Money.sum([b.purchases, amount]);
          case 'expenses':
            b.expenses = Money.sum([b.expenses, amount]);
        }
      }
    }
    var active = 0, low = 0, out = 0;
    if (!cashier) {
      for (final table in [
        'customer_ledger_entries',
        'supplier_ledger_entries',
      ]) {
        final rows = await tx.select(
          "SELECT currency_code,currency_minor_digits,amount_delta_minor FROM $table WHERE shop_id=? AND status='posted'",
          [user.shopId],
        );
        for (final row in rows) {
          final b = bucket(row), delta = row['amount_delta_minor'] as int;
          if (table == 'customer_ledger_entries') {
            b.receivable = Money.sum([b.receivable, delta]);
          } else {
            b.payable = Money.sum([b.payable, delta]);
          }
        }
      }
      final products = await tx.select(
        '''SELECT p.minimum_stock_scaled,COALESCE(b.quantity_scaled,0) AS stock
        FROM products p LEFT JOIN stock_balances b ON b.product_id=p.id AND b.shop_id=p.shop_id
        WHERE p.shop_id=? AND p.status='active' ''',
        [user.shopId],
      );
      active = products.length;
      for (final p in products) {
        final stock = p['stock'] as int;
        if (stock <= 0) {
          out++;
        } else if (stock <= (p['minimum_stock_scaled'] as int)) {
          low++;
        }
      }
    }
    final demo = (await tx.select(
      "SELECT id FROM settings WHERE shop_id=? AND key='demo_seed_v1'",
      [user.shopId],
    )).isNotEmpty;
    return DashboardSnapshot(
      cashier: cashier,
      money: buckets.values.toList(),
      date: date,
      activeProducts: active,
      lowStock: low,
      outOfStock: out,
      demo: demo,
    );
  });
}
