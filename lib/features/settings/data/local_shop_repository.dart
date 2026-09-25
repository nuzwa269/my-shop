import '../../../core/money/money.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/validation/validation.dart';
import '../../../database/database_connection.dart';
import '../../../database/row_writer.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/password_hasher.dart';
import '../domain/shop_setup.dart';

class LocalShopRepository implements ShopRepository {
  LocalShopRepository(this.db, this.auth, this.hasher, {int Function()? clock})
    : now = clock ?? (() => DateTime.now().toUtc().millisecondsSinceEpoch);
  final DatabaseConnection db;
  final AuthRepository auth;
  final PasswordHasher hasher;
  final int Function() now;

  @override
  Future<bool> isConfigured() async {
    final shops = await db.select('SELECT setup_completed_at FROM shops');
    if (shops.isEmpty) return false;
    if (shops.length != 1 || shops.single['setup_completed_at'] == null) {
      throw const ValidationException(
        'Existing shop data needs an explicit migration/recovery. Setup will not overwrite it.',
      );
    }
    return true;
  }

  @override
  Future<void> setup(ShopSetupInput input) async {
    final name = Validation.requiredText(input.shopName, 'Shop name');
    final owner = Validation.requiredText(input.ownerName, 'Owner name');
    final category = Validation.requiredText(
      input.category,
      'Business category',
    );
    final country = Validation.requiredText(input.country, 'Country');
    final username = Validation.username(input.username);
    Validation.password(input.password);
    final code = input.currencyCode.trim().toUpperCase();
    Currency currency;
    try {
      currency = Currency(code, minorDigits: input.minorDigits);
    } on ArgumentError {
      throw const ValidationException(
        'Enter a three-letter currency code and 0–4 decimal places.',
      );
    }
    if (currency.code == 'PKR' && currency.minorDigits != 2) {
      throw const ValidationException(
        'PKR requires 2 decimal places (100 minor units per PKR).',
      );
    }
    final phone = Validation.optional(input.phone, max: 40);
    final address = Validation.optional(input.address);
    final hash = await hasher.hash(input.password);
    await db.transaction((tx) async {
      if ((await tx.select('SELECT id FROM shops LIMIT 1')).isNotEmpty) {
        throw const ValidationException(
          'Shop setup is already complete or existing data requires recovery.',
        );
      }
      final timestamp = now();
      final shop = await RowWriter.insert(tx, 'shops', {
        'name': name,
        'owner_name': owner,
        'business_category': category,
        'currency_code': currency.code,
        'currency_minor_digits': currency.minorDigits,
        'country': country,
        'phone': phone,
        'address': address,
        'setup_completed_at': timestamp,
      }, timestamp);
      final user = await RowWriter.insert(tx, 'users', {
        'shop_id': shop,
        'display_name': owner,
        'role': 'owner',
      }, timestamp);
      await RowWriter.insert(tx, 'owner_credentials', {
        'shop_id': shop,
        'user_id': user,
        'username': username,
        'password_hash': hash,
      }, timestamp);
      await RowWriter.insert(tx, 'settings', {
        'shop_id': shop,
        'key': 'setup_complete',
        'value_json': 'true',
      }, timestamp);
      await RowWriter.audit(
        tx,
        shopId: shop,
        actorId: user,
        table: 'shops',
        entityId: shop,
        action: 'setup',
        reason: 'First-run shop and owner setup',
        now: timestamp,
        after: {'name': name, 'owner_name': owner, 'category': category},
      );
    });
  }

  @override
  Future<ShopProfile> current() => db.transaction((tx) async {
    final session = await auth.authorize(tx, Permission.dashboard);
    return ShopProfile.fromRow(
      (await tx.select('SELECT * FROM shops WHERE id=?', [
        session.shopId,
      ])).single,
    );
  });
}
