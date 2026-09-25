import '../../../core/permissions/permissions.dart';
import '../../../core/validation/validation.dart';
import '../../../database/database_connection.dart';
import '../../auth/domain/auth_repository.dart';
import '../../products/domain/product.dart';
import '../domain/inventory.dart';

class LocalInventoryRepository implements InventoryRepository {
  const LocalInventoryRepository(this.db, this.auth);
  final DatabaseConnection db;
  final AuthRepository auth;
  static const _products = '''
    SELECT p.*, COALESCE(b.quantity_scaled,0) AS stock_scaled FROM products p
    LEFT JOIN stock_balances b ON b.shop_id=p.shop_id AND b.product_id=p.id
  ''';

  @override
  Future<List<Product>> list() => db.transaction((tx) async {
    final session = await auth.authorize(tx, Permission.inventory);
    final rows = await tx.select(
      '$_products WHERE p.shop_id=? ORDER BY p.name COLLATE NOCASE,p.id',
      [session.shopId],
    );
    return rows.map(Product.fromRow).toList();
  });

  @override
  Future<InventoryDetails> details(String productId) =>
      db.transaction((tx) async {
        final session = await auth.authorize(tx, Permission.inventory);
        final rows = await tx.select(
          '$_products WHERE p.shop_id=? AND p.id=?',
          [session.shopId, productId],
        );
        if (rows.isEmpty) {
          throw const ValidationException('Product not found.');
        }
        final movements = await tx.select(
          '''
      SELECT * FROM stock_transactions
      WHERE shop_id=? AND product_id=? AND status='posted'
      ORDER BY occurred_at DESC,created_at DESC,id DESC
    ''',
          [session.shopId, productId],
        );
        return InventoryDetails(
          Product.fromRow(rows.single),
          movements.map(StockMovement.fromRow).toList(),
        );
      });
}
