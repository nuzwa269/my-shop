import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shop_manager/database/sqlite_database.dart';
import 'package:shop_manager/features/auth/data/local_auth_repository.dart';
import 'package:shop_manager/features/auth/data/session_vault.dart';
import 'package:shop_manager/features/auth/domain/password_hasher.dart';
import 'package:shop_manager/features/settings/data/local_shop_repository.dart';
import 'package:shop_manager/features/settings/domain/shop_setup.dart';
import 'package:shop_manager/features/products/data/local_product_repository.dart';
import 'package:shop_manager/features/products/domain/product.dart';
import 'package:shop_manager/core/units/quantity.dart';

/// Test double only: production always uses the slow, salted PBKDF2 implementation.
class FastTestHasher implements PasswordHasher {
  @override
  Future<String> hash(String password) async =>
      base64Encode((await Sha256().hash(utf8.encode(password))).bytes);
  @override
  Future<bool> verify(String password, String encoded) async =>
      await hash(password) == encoded;
}

class MemoryVault implements SessionVault {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

class TestStore {
  TestStore._(this.db) {
    auth = LocalAuthRepository(db, hasher, vault, clock: clock);
    shops = LocalShopRepository(db, auth, hasher, clock: clock);
    products = LocalProductRepository(db, auth, clock: clock);
  }
  final SqliteDatabase db;
  final hasher = FastTestHasher();
  final vault = MemoryVault();
  late final LocalAuthRepository auth;
  late final LocalShopRepository shops;
  late final LocalProductRepository products;
  int offset = 0;
  int clock() => DateTime.now().toUtc().millisecondsSinceEpoch + offset;
  static const setupInput = ShopSetupInput(
    shopName: 'Example Shop',
    ownerName: 'Aisha Owner',
    category: 'Flour Shop',
    currencyCode: 'PKR',
    minorDigits: 2,
    country: 'Pakistan',
    username: 'owner@example.com',
    password: 'owner-password',
    phone: '03001234567',
    address: 'Market Road',
  );
  static Future<TestStore> open({
    bool configured = true,
    bool loggedIn = true,
  }) async {
    sqfliteFfiInit();
    final store = TestStore._(
      await SqliteDatabase.open(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      ),
    );
    if (configured) {
      await store.shops.setup(setupInput);
      if (loggedIn) {
        await store.auth.login(setupInput.username, setupInput.password);
      }
    }
    return store;
  }

  Future<void> close() => db.close();

  static ProductInput product({
    String name = 'Super Basmati',
    String sku = '',
    String purchase = '12000',
    String sale = '260',
    int bagGrams = 50000,
    String minimum = '1000',
    String purchaseUnit = 'bag',
  }) => ProductInput(
    name: name,
    sku: sku,
    description: 'Premium variety',
    baseUnit: 'gram',
    measurementKind: 'weight',
    primaryUnit: 'kg',
    defaultSaleUnit: 'kg',
    purchasePrice: purchase,
    purchasePriceUnit: purchaseUnit,
    salePrice: sale,
    salePriceUnit: 'kg',
    minimumStock: minimum,
    units: [
      UnitConversion.grams(),
      UnitConversion.kilograms(),
      UnitConversion(
        unitCode: 'bag',
        baseUnit: 'gram',
        numerator: bagGrams,
        denominator: 1,
      ),
    ],
  );
  OpeningInput opening({
    String quantity = '2',
    String value = '24000',
    String unit = 'bag',
    String reason = 'Initial count',
  }) => OpeningInput(
    quantity: quantity,
    unit: unit,
    totalValue: value,
    reason: reason,
    occurredAt: clock(),
  );
}
