import '../../../core/money/money.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/units/quantity.dart';
import '../../../core/validation/validation.dart';

typedef DataRow = Map<String, Object?>;

class KhataAccount {
  const KhataAccount(this.party, this.currency, this.entries, this.balance);
  final DataRow party;
  final Currency currency;
  final List<DataRow> entries;
  final int balance;
}

enum PartyKind {
  supplier,
  customer;

  String get table => '${name}s';
  String get key => '${name}_id';
  String get ledger => '${name}_ledger_entries';
  Permission get permission =>
      this == supplier ? Permission.suppliers : Permission.customers;
  String get label => this == supplier ? 'Supplier' : 'Customer';
}

enum TradeKind {
  purchase,
  sale;

  String get table => this == purchase ? 'purchases' : 'sales';
  String get key => '${name}_id';
  String get items => '${name}_items';
  PartyKind get party =>
      this == purchase ? PartyKind.supplier : PartyKind.customer;
  Permission get permission =>
      this == purchase ? Permission.purchases : Permission.sales;
  String get label => this == purchase ? 'Purchase' : 'Sale';
}

class TradeLineInput {
  const TradeLineInput({
    required this.productId,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.expectedRevision,
  });
  final String productId, unit, quantity, rate;
  final int expectedRevision;
}

class TradeInput {
  const TradeInput({
    required this.partyId,
    required this.lines,
    required this.occurredAt,
    this.paid = '0',
    this.discount = '0',
    this.note = '',
  });
  final String partyId, paid, discount, note;
  final List<TradeLineInput> lines;
  final int occurredAt;
}

class TradeTotals {
  const TradeTotals(this.subtotal, this.discount, this.total, this.paid);
  final int subtotal, discount, total, paid;
  int get balance => total - paid;
  String get paymentType => paid == total
      ? 'cash'
      : paid == 0
      ? 'credit'
      : 'partial';
  static TradeTotals calculate(List<int> lines, int discount, int paid) {
    final subtotal = Money.sum(lines);
    if (discount < 0 || discount > subtotal) {
      throw const ValidationException(
        'Discount must be between zero and the subtotal.',
      );
    }
    final total = subtotal - discount;
    if (paid < 0 || paid > total) {
      throw const ValidationException(
        'Paid amount must be between zero and the total.',
      );
    }
    return TradeTotals(subtotal, discount, total, paid);
  }
}

class CatalogItem {
  CatalogItem(this.row, this.units, this.rate, this.pricingUnit);
  final DataRow row;
  final List<UnitConversion> units;
  final String rate, pricingUnit;
  String get id => row['id'] as String;
  String get name => row['name'] as String;
  int get revision => row['revision'] as int;
}
