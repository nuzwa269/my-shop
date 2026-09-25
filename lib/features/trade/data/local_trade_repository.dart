import 'dart:convert';

import '../../../core/money/money.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/units/quantity.dart';
import '../../../core/units/unit_conversion_service.dart';
import '../../../core/validation/validation.dart';
import '../../../database/database_connection.dart';
import '../../../database/row_writer.dart';
import '../../../services/id_service.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/trade.dart';

// Shared transaction boundary for purchasing/selling and their party ledgers.
class LocalTradeRepository {
  LocalTradeRepository(this.db, this.auth, {int Function()? clock})
    : now = clock ?? (() => DateTime.now().millisecondsSinceEpoch);
  final DatabaseConnection db;
  final AuthRepository auth;
  final int Function() now;

  Future<DataRow> _shop(SqlSession tx, String shop) async =>
      (await tx.select('SELECT * FROM shops WHERE id=?', [shop])).single;
  Currency currency(DataRow row) => Currency(
    row['currency_code'] as String,
    minorDigits: row['currency_minor_digits'] as int,
  );
  Map<String, Object?> _money(Currency c) => {
    'currency_code': c.code,
    'currency_minor_digits': c.minorDigits,
  };
  int amount(String text, Currency c, {bool rate = false}) {
    try {
      final result = rate
          ? Money.parseUnitPrice(text, c)
          : Money.parse(text, c);
      if (result < 0) {
        throw const ValidationException('Amounts cannot be negative.');
      }
      return result;
    } on ArgumentError {
      throw const ValidationException('Amount is too large.');
    } on FormatException {
      throw ValidationException(
        'Enter an amount with at most ${c.minorDigits + (rate ? 4 : 0)} decimal places.',
      );
    }
  }

  void _date(int time) {
    if (time <= 0 || time > now()) {
      throw const ValidationException('Choose a current or past date.');
    }
  }

  Future<DataRow> _party(
    SqlSession tx,
    PartyKind kind,
    String shop,
    String id,
  ) async {
    final rows = await tx.select(
      'SELECT * FROM ${kind.table} WHERE shop_id=? AND id=?',
      [shop, id],
    );
    if (rows.isEmpty) throw ValidationException('${kind.label} not found.');
    return rows.single;
  }

  Future<void> _audit(
    SqlSession tx,
    OwnerSession user,
    String table,
    String id,
    String action, {
    DataRow? before,
    DataRow? after,
    String? reason,
  }) => RowWriter.audit(
    tx,
    shopId: user.shopId,
    actorId: user.userId,
    table: table,
    entityId: id,
    action: action,
    reason: reason ?? action,
    now: now(),
    before: before,
    after: after,
  );

  Future<String> _walkIn(SqlSession tx, OwnerSession user) async {
    final rows = await tx.select(
      'SELECT id FROM customers WHERE shop_id=? AND is_walk_in=1',
      [user.shopId],
    );
    if (rows.isNotEmpty) return rows.single['id'] as String;
    final id = await RowWriter.insert(tx, 'customers', {
      'shop_id': user.shopId,
      'name': 'Walk-in Customer',
      'is_walk_in': 1,
    }, now());
    await _audit(tx, user, 'customers', id, 'create_walk_in');
    return id;
  }

  Future<List<DataRow>> parties(PartyKind kind) => db.transaction((tx) async {
    final user = await auth.authorize(tx, kind.permission);
    if (kind == PartyKind.customer) await _walkIn(tx, user);
    return tx.select(
      'SELECT * FROM ${kind.table} WHERE shop_id=? ORDER BY name COLLATE NOCASE,id',
      [user.shopId],
    );
  });
  Future<String> saveParty(
    PartyKind kind, {
    required String name,
    String phone = '',
    String address = '',
    String note = '',
    bool active = true,
    String? id,
    int? revision,
  }) => db.transaction((tx) async {
    final user = await auth.authorize(tx, kind.permission);
    final fields = <String, Object?>{
      'name': Validation.requiredText(name, '${kind.label} name'),
      'phone': Validation.optional(phone, max: 40),
      'address': Validation.optional(address),
      'note': Validation.optional(note),
      'status': active ? 'active' : 'archived',
    };
    DataRow? before;
    if (id == null) {
      id = await RowWriter.insert(tx, kind.table, {
        'shop_id': user.shopId,
        ...fields,
      }, now());
    } else {
      before = await _party(tx, kind, user.shopId, id!);
      if (before['revision'] != revision) {
        throw const ValidationException(
          'This contact changed. Reopen it before saving.',
        );
      }
      if (before['is_walk_in'] == 1) {
        throw const ValidationException(
          'The default Walk-in Customer cannot be edited.',
        );
      }
      await tx.execute(
        'UPDATE ${kind.table} SET ${fields.keys.map((k) => '$k=?').join(',')},updated_at=?,revision=revision+1 WHERE id=? AND shop_id=?',
        [...fields.values, now(), id, user.shopId],
      );
    }
    await _audit(
      tx,
      user,
      kind.table,
      id!,
      'save_contact',
      before: before,
      after: fields,
    );
    return id!;
  });

  Future<List<CatalogItem>> catalog(TradeKind kind) =>
      db.transaction((tx) async {
        final user = await auth.authorize(tx, kind.permission);
        final c = currency(await _shop(tx, user.shopId));
        final rows = await tx.select(
          "SELECT * FROM products WHERE shop_id=? AND status='active' ORDER BY name COLLATE NOCASE",
          [user.shopId],
        );
        final result = <CatalogItem>[];
        for (final row in rows) {
          final units = await tx.select(
            "SELECT * FROM product_units WHERE product_id=? AND shop_id=? AND status='active' ORDER BY unit_code",
            [row['id'], user.shopId],
          );
          final prices = await tx.select(
            'SELECT * FROM product_prices WHERE id=? AND shop_id=?',
            [row['${kind.name}_price_id'], user.shopId],
          );
          if (prices.isEmpty || units.isEmpty) continue;
          final price = prices.single;
          result.add(
            CatalogItem(
              row,
              units.map(UnitConversionService.fromRow).toList(),
              Money.formatUnitPrice(price['amount_ticks'] as int, c),
              price['unit_code'] as String,
            ),
          );
        }
        return result;
      });

  Future<List<DataRow>> documents(TradeKind kind) => db.transaction((tx) async {
    final user = await auth.authorize(tx, kind.permission);
    return tx.select(
      'SELECT d.*,p.name AS party_name FROM ${kind.table} d JOIN ${kind.party.table} p ON p.id=d.${kind.party.key} AND p.shop_id=d.shop_id WHERE d.shop_id=? ORDER BY d.occurred_at DESC,d.id DESC',
      [user.shopId],
    );
  });
  Future<DataRow> document(TradeKind kind, String id) => db.transaction((
    tx,
  ) async {
    final user = await auth.authorize(tx, kind.permission);
    final rows = await tx.select(
      'SELECT * FROM ${kind.table} WHERE id=? AND shop_id=?',
      [id, user.shopId],
    );
    if (rows.isEmpty) throw const ValidationException('Document not found.');
    if (kind == TradeKind.purchase) {
      // Display-only metadata; never replace the stored document number.
      final details = await tx.select(
        '''
        SELECT s.phone AS supplier_phone, s.address AS supplier_address,
          (SELECT COUNT(*) FROM purchases p WHERE p.shop_id=d.shop_id
            AND (p.created_at<d.created_at OR
              (p.created_at=d.created_at AND p.id<=d.id))) AS display_sequence
        FROM purchases d LEFT JOIN suppliers s
          ON s.id=d.supplier_id AND s.shop_id=d.shop_id
        WHERE d.id=? AND d.shop_id=?
      ''',
        [id, user.shopId],
      );
      return {...rows.single, ...details.single};
    }
    return rows.single;
  });

  Future<String> post(TradeKind kind, TradeInput input) => db.transaction((
    tx,
  ) async {
    final user = await auth.authorize(tx, kind.permission);
    final shop = await _shop(tx, user.shopId);
    final c = currency(shop);
    _date(input.occurredAt);
    if (input.lines.isEmpty || input.lines.length > 100) {
      throw const ValidationException('Add between 1 and 100 items.');
    }
    final party = await _party(tx, kind.party, user.shopId, input.partyId);
    if (party['status'] != 'active') {
      throw const ValidationException('Choose an active contact.');
    }
    final lines = <DataRow>[];
    final requiredStock = <String, int>{};
    for (final inputLine in input.lines) {
      final products = await tx.select(
        "SELECT * FROM products WHERE id=? AND shop_id=? AND status='active'",
        [inputLine.productId, user.shopId],
      );
      if (products.isEmpty) {
        throw const ValidationException(
          'A selected product is no longer active.',
        );
      }
      final product = products.single;
      if (product['revision'] != inputLine.expectedRevision) {
        throw const ValidationException(
          'A product or its units changed. Remove and add that item again.',
        );
      }
      final units = await tx.select(
        "SELECT * FROM product_units WHERE shop_id=? AND product_id=? AND unit_code=? AND status='active'",
        [user.shopId, inputLine.productId, inputLine.unit],
      );
      if (units.isEmpty) {
        throw const ValidationException(
          'Selected unit is no longer available.',
        );
      }
      final quantity = UnitConversionService.snapshot(
        inputLine.quantity,
        UnitConversionService.fromRow(units.single),
      );
      final rate = amount(inputLine.rate, c, rate: true);
      final total = Money.lineTotal(
        unitPriceTicks: rate,
        originalQuantityScaled: quantity.originalQuantityScaled,
      );
      lines.add({
        'product_id': inputLine.productId,
        'product_name': product['name'],
        ...quantity.toRow(),
        'unit_price_ticks': rate,
        'line_total_minor': total,
      });
      requiredStock[inputLine.productId] = Money.sum([
        requiredStock[inputLine.productId] ?? 0,
        quantity.baseQuantityScaled,
      ]);
    }
    final totals = TradeTotals.calculate(
      lines.map((r) => r['line_total_minor'] as int).toList(),
      amount(input.discount, c),
      amount(input.paid, c),
    );
    if (kind == TradeKind.purchase && totals.discount != 0) {
      throw const ValidationException(
        'Purchase discounts are outside this MVP.',
      );
    }
    if (party['is_walk_in'] == 1 && totals.balance != 0) {
      throw const ValidationException(
        'Walk-in sales must be fully paid. Choose a named customer for credit.',
      );
    }
    for (final entry in requiredStock.entries) {
      final stock = await tx.select(
        'SELECT quantity_scaled FROM stock_balances WHERE shop_id=? AND product_id=?',
        [user.shopId, entry.key],
      );
      final available = stock.isEmpty
          ? 0
          : stock.single['quantity_scaled'] as int;
      if (kind == TradeKind.sale && available < entry.value) {
        throw const ValidationException(
          'Insufficient stock. Reduce the quantity or record a purchase first.',
        );
      }
      Money.sum([
        available,
        kind == TradeKind.sale ? -entry.value : entry.value,
      ]);
    }
    final id = IdService.newId();
    // Full UUID avoids sequence collisions across imported/offline histories.
    final number = '${kind == TradeKind.sale ? 'S' : 'P'}-$id';
    final note = Validation.optional(input.note, max: 500);
    final receipt = <String, Object?>{
      'shop_name': shop['name'],
      'shop_phone': shop['phone'],
      'shop_address': shop['address'],
      'party_name': party['name'],
      'user_name': user.fullName,
      'number': number,
      'occurred_at': input.occurredAt,
      ..._money(c),
      'items': lines,
      'subtotal': totals.subtotal,
      'discount': totals.discount,
      'total': totals.total,
      'paid': totals.paid,
      'balance': totals.balance,
      'payment_type': totals.paymentType,
      'note': note,
    };
    await RowWriter.insert(tx, kind.table, {
      'id': id,
      'status': 'draft',
      'shop_id': user.shopId,
      ..._money(c),
      'occurred_at': input.occurredAt,
      'created_by': user.userId,
      kind.party.key: input.partyId,
      'document_number': number,
      'total_minor': totals.total,
      'subtotal_minor': totals.subtotal,
      'discount_minor': totals.discount,
      'paid_minor': totals.paid,
      'receipt_json': jsonEncode(receipt),
      'note': note,
    }, now());
    for (final line in lines) {
      final itemId = await RowWriter.insert(tx, kind.items, {
        'shop_id': user.shopId,
        kind.key: id,
        ...line,
      }, now());
      await RowWriter.insert(tx, 'stock_transactions', {
        'shop_id': user.shopId,
        'product_id': line['product_id'],
        ...QuantitySnapshot.fromRow(line).toRow(),
        'status': 'posted',
        'occurred_at': input.occurredAt,
        'created_by': user.userId,
        'reason': kind.name,
        'quantity_delta_scaled':
            (line['base_quantity_scaled'] as int) *
            (kind == TradeKind.sale ? -1 : 1),
        '${kind.name}_item_id': itemId,
        'note': number,
      }, now());
    }
    await tx.execute(
      "UPDATE ${kind.table} SET status='posted',posted_at=?,posted_by=?,updated_at=?,revision=revision+1 WHERE id=?",
      [now(), user.userId, now(), id],
    );
    if (totals.total > 0) {
      await _ledger(
        tx,
        user,
        kind.party,
        input.partyId,
        c,
        totals.total,
        input.occurredAt,
        number,
        documentId: id,
      );
    }
    if (totals.paid > 0) {
      await _payment(
        tx,
        user,
        kind.party,
        input.partyId,
        c,
        totals.paid,
        input.occurredAt,
        number,
        documentId: id,
      );
    }
    await _balance(
      tx,
      kind.party,
      user.shopId,
      input.partyId,
      c,
    ); // Detect aggregate overflow before commit.
    await _audit(tx, user, kind.table, id, 'post_${kind.name}', after: receipt);
    return id;
  });

  Future<int> _balance(
    SqlSession tx,
    PartyKind kind,
    String shop,
    String id,
    Currency c,
  ) async {
    final rows = await tx.select(
      "SELECT amount_delta_minor FROM ${kind.ledger} WHERE shop_id=? AND ${kind.key}=? AND currency_code=? AND currency_minor_digits=? AND status='posted'",
      [shop, id, c.code, c.minorDigits],
    );
    return Money.sum(rows.map((r) => r['amount_delta_minor'] as int));
  }

  Future<List<KhataAccount>> khata(PartyKind kind, String partyId) =>
      db.transaction((tx) async {
        final user = await auth.authorize(
          tx,
          kind == PartyKind.customer ? Permission.customers : Permission.ledger,
        );
        final party = await _party(tx, kind, user.shopId, partyId);
        final current = currency(await _shop(tx, user.shopId));
        final rows = await tx.select(
          '''SELECT * FROM ${kind.ledger}
      WHERE shop_id=? AND ${kind.key}=? AND status='posted'
      ORDER BY occurred_at,created_at,rowid''',
          [user.shopId, partyId],
        );
        final groups = <String, List<DataRow>>{
          '${current.code}:${current.minorDigits}': [],
        };
        for (final row in rows) {
          groups
              .putIfAbsent(
                '${row['currency_code']}:${row['currency_minor_digits']}',
                () => [],
              )
              .add(row);
        }
        return groups.entries.map((group) {
          final parts = group.key.split(':');
          var balance = 0;
          final entries = group.value.map((row) {
            balance = Money.sum([balance, row['amount_delta_minor'] as int]);
            return <String, Object?>{...row, 'running_balance': balance};
          }).toList();
          return KhataAccount(
            party,
            Currency(parts[0], minorDigits: int.parse(parts[1])),
            entries,
            balance,
          );
        }).toList();
      });

  Future<String> settle(
    PartyKind kind,
    String partyId, {
    required Currency currency,
    required String amountText,
    required int expectedBalance,
    required int occurredAt,
    required String requestId,
    String note = '',
  }) => db.transaction((tx) async {
    final user = await auth.authorize(
      tx,
      kind == PartyKind.customer
          ? Permission.paymentCollection
          : Permission.ledger,
    );
    _date(occurredAt);
    final party = await _party(tx, kind, user.shopId, partyId);
    if (party['is_walk_in'] == 1) {
      throw const ValidationException('Walk-in sales are settled at issue.');
    }
    final paid = amount(amountText, currency);
    if (paid <= 0) {
      throw const ValidationException('Payment must be greater than zero.');
    }
    if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(requestId)) {
      throw const ValidationException('Invalid payment request.');
    }
    final existing = await tx.select('SELECT * FROM payments WHERE id=?', [
      requestId,
    ]);
    if (existing.isNotEmpty) {
      final p = existing.single;
      if (p['shop_id'] == user.shopId &&
          p[kind.key] == partyId &&
          p['amount_minor'] == paid &&
          p['currency_code'] == currency.code &&
          p['currency_minor_digits'] == currency.minorDigits &&
          p['occurred_at'] == occurredAt &&
          p['note'] == Validation.optional(note)) {
        return requestId;
      }
      throw const ValidationException(
        'Payment request already used. Reopen the account.',
      );
    }
    final balance = await _balance(tx, kind, user.shopId, partyId, currency);
    if (balance != expectedBalance) {
      throw const ValidationException(
        'Balance changed. Refresh the khata before paying.',
      );
    }
    if (paid > balance) {
      throw const ValidationException(
        'Payment cannot exceed the outstanding balance.',
      );
    }
    await RowWriter.insert(tx, 'payments', {
      'id': requestId,
      'shop_id': user.shopId,
      ..._money(currency),
      'status': 'posted',
      'occurred_at': occurredAt,
      'created_by': user.userId,
      'posted_at': now(),
      'posted_by': user.userId,
      'direction': kind == PartyKind.customer ? 'incoming' : 'outgoing',
      'method': 'cash',
      'amount_minor': paid,
      kind.key: partyId,
      'note': Validation.optional(note),
    }, now());
    await _ledger(
      tx,
      user,
      kind,
      partyId,
      currency,
      -paid,
      occurredAt,
      Validation.optional(note) ?? 'Account payment',
      paymentId: requestId,
    );
    await _audit(
      tx,
      user,
      'payments',
      requestId,
      'settle_${kind.name}',
      after: {
        kind.key: partyId,
        ..._money(currency),
        'amount_minor': paid,
        'balance_minor': balance - paid,
      },
    );
    return requestId;
  });

  Future<void> _ledger(
    SqlSession tx,
    OwnerSession user,
    PartyKind kind,
    String party,
    Currency c,
    int delta,
    int date,
    String note, {
    String? documentId,
    String? paymentId,
  }) async {
    final documentKey = kind == PartyKind.supplier ? 'purchase_id' : 'sale_id';
    await RowWriter.insert(tx, kind.ledger, {
      'shop_id': user.shopId,
      kind.key: party,
      ..._money(c),
      'status': 'posted',
      'occurred_at': date,
      'created_by': user.userId,
      'entry_kind': paymentId == null ? 'invoice' : 'payment',
      'amount_delta_minor': delta,
      'note': note,
      documentKey: ?documentId,
      'payment_id': ?paymentId,
    }, now());
  }

  Future<String> _payment(
    SqlSession tx,
    OwnerSession user,
    PartyKind kind,
    String party,
    Currency c,
    int paid,
    int date,
    String note, {
    String? documentId,
  }) async {
    final id = await RowWriter.insert(tx, 'payments', {
      'shop_id': user.shopId,
      ..._money(c),
      'status': 'posted',
      'occurred_at': date,
      'created_by': user.userId,
      'posted_at': now(),
      'posted_by': user.userId,
      'direction': kind == PartyKind.customer ? 'incoming' : 'outgoing',
      'method': 'cash',
      'amount_minor': paid,
      kind.key: party,
      (kind == PartyKind.customer ? 'sale_id' : 'purchase_id'): ?documentId,
      'note': note,
    }, now());
    await _ledger(tx, user, kind, party, c, -paid, date, note, paymentId: id);
    return id;
  }
}
