import '../core/money/money.dart';

/// No product category, shop identity, or bag/maund weight is assumed.
class ShopConfiguration {
  const ShopConfiguration({
    required this.shopName,
    required this.ownerName,
    required this.businessCategory,
    required this.currency,
    this.unitLabels = const ['kg', 'gram', 'bag', 'maund', 'piece'],
  });
  final String shopName;
  final String ownerName;
  final String businessCategory;
  final Currency currency;

  /// Labels only. Custom units cannot normalize stock without a product factor.
  final List<String> unitLabels;
}
