import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manager/core/permissions/permissions.dart';
import 'package:shop_manager/core/navigation/app_modules.dart';
import 'package:shop_manager/services/id_service.dart';

void main() {
  test('owner has all declared permissions', () {
    for (final permission in Permission.values) {
      expect(RolePermissions.allows(ShopRole.owner, permission), isTrue);
    }
  });
  test('cashier grants are narrow and anonymous sessions are denied', () {
    const expected = {
      Permission.dashboard,
      Permission.sales,
      Permission.customers,
      Permission.paymentCollection,
      Permission.receiptGeneration,
    };
    for (final permission in Permission.values) {
      expect(
        RolePermissions.allows(ShopRole.cashier, permission),
        expected.contains(permission),
      );
      expect(RolePermissions.allows(null, permission), isFalse);
    }
    expect(AppModules.allowed(ShopRole.cashier).map((m) => m.path), [
      '/dashboard',
      '/sales',
      '/customers',
    ]);
    expect(AppModules.find('/unknown'), isNull);
  });
  test('identifiers are unique UUID v4 strings', () {
    final ids = List.generate(100, (_) => IdService.newId());
    expect(ids.toSet(), hasLength(100));
    for (final id in ids) {
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    }
  });
}
