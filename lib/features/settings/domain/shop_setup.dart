import '../../../core/money/money.dart';

class ShopSetupInput {
  const ShopSetupInput({
    required this.shopName,
    required this.ownerName,
    required this.category,
    required this.currencyCode,
    required this.minorDigits,
    required this.country,
    required this.username,
    required this.password,
    this.phone = '',
    this.address = '',
  });
  final String shopName,
      ownerName,
      category,
      currencyCode,
      country,
      username,
      password,
      phone,
      address;
  final int minorDigits;
}

class ShopProfile {
  const ShopProfile({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.category,
    required this.currency,
    required this.country,
    this.phone,
    this.address,
  });
  final String id, name, ownerName, category, country;
  final Currency currency;
  final String? phone, address;

  factory ShopProfile.fromRow(Map<String, Object?> row) => ShopProfile(
    id: row['id'] as String,
    name: row['name'] as String,
    ownerName: row['owner_name'] as String,
    category: row['business_category'] as String,
    currency: Currency(
      row['currency_code'] as String,
      minorDigits: row['currency_minor_digits'] as int,
    ),
    country: row['country'] as String? ?? '',
    phone: row['phone'] as String?,
    address: row['address'] as String?,
  );
}

abstract interface class ShopRepository {
  Future<bool> isConfigured();
  Future<void> setup(ShopSetupInput input);
  Future<ShopProfile> current();
}
