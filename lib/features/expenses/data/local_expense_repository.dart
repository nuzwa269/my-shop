import '../../../core/money/money.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/validation/validation.dart';
import '../../../database/database_connection.dart';
import '../../../database/row_writer.dart';
import '../../auth/domain/auth_repository.dart';

class LocalExpenseRepository {
  LocalExpenseRepository(this.db, this.auth, {int Function()? clock})
    : now = clock ?? (() => DateTime.now().millisecondsSinceEpoch);
  final DatabaseConnection db;
  final AuthRepository auth;
  final int Function() now;
  Future<List<Map<String, Object?>>> list() => db.transaction((tx) async {
    final user = await auth.authorize(tx, Permission.expenses);
    return tx.select(
      "SELECT * FROM expenses WHERE shop_id=? AND status='posted' ORDER BY occurred_at DESC,created_at DESC,rowid DESC",
      [user.shopId],
    );
  });
  Future<String> post({
    required String category,
    required String description,
    required String amount,
    required int occurredAt,
    required String requestId,
  }) => db.transaction((tx) async {
    final user = await auth.authorize(tx, Permission.expenses);
    final shop = (await tx.select('SELECT * FROM shops WHERE id=?', [
      user.shopId,
    ])).single;
    final c = Currency(
      shop['currency_code'] as String,
      minorDigits: shop['currency_minor_digits'] as int,
    );
    final cat = Validation.requiredText(category, 'Category');
    final text = Validation.requiredText(description, 'Description', max: 500);
    int total;
    try {
      total = Money.parse(amount, c);
    } on FormatException {
      throw const ValidationException(
        'Enter a valid amount in the shop currency.',
      );
    } on ArgumentError {
      throw const ValidationException('Amount is too large.');
    }
    if (total <= 0) {
      throw const ValidationException('Expense must be greater than zero.');
    }
    if (occurredAt <= 0 || occurredAt > now()) {
      throw const ValidationException('Choose a current or past date.');
    }
    if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(requestId)) {
      throw const ValidationException('Invalid expense request.');
    }
    final existing = await tx.select('SELECT * FROM expenses WHERE id=?', [
      requestId,
    ]);
    if (existing.isNotEmpty) {
      final row = existing.single;
      if (row['shop_id'] == user.shopId &&
          row['category'] == cat &&
          row['description'] == text &&
          row['total_minor'] == total &&
          row['occurred_at'] == occurredAt &&
          row['currency_code'] == c.code &&
          row['currency_minor_digits'] == c.minorDigits) {
        return requestId;
      }
      throw const ValidationException(
        'Expense request already used. Reopen the form.',
      );
    }
    final fields = <String, Object?>{
      'shop_id': user.shopId,
      'status': 'posted',
      'created_by': user.userId,
      'posted_by': user.userId,
      'posted_at': now(),
      'occurred_at': occurredAt,
      'currency_code': c.code,
      'currency_minor_digits': c.minorDigits,
    };
    await RowWriter.insert(tx, 'expenses', {
      ...fields,
      'id': requestId,
      'category': cat,
      'description': text,
      'total_minor': total,
    }, now());
    await RowWriter.insert(tx, 'payments', {
      ...fields,
      'direction': 'outgoing',
      'method': 'cash',
      'amount_minor': total,
      'expense_id': requestId,
      'note': text,
    }, now());
    await RowWriter.audit(
      tx,
      shopId: user.shopId,
      actorId: user.userId,
      table: 'expenses',
      entityId: requestId,
      action: 'post_expense',
      reason: text,
      now: now(),
      after: {'category': cat, 'total_minor': total, 'currency_code': c.code},
    );
    return requestId;
  });
}
