// Additive MVP snapshots. Existing migrations and posted financial payloads stay intact.
final mvpSchema = <String>[
  "ALTER TABLE customers ADD COLUMN is_walk_in INTEGER NOT NULL DEFAULT 0 CHECK(is_walk_in IN (0,1))",
  "CREATE UNIQUE INDEX one_walk_in_per_shop ON customers(shop_id) WHERE is_walk_in=1",
  for (final table in ['purchases', 'sales']) ...[
    'ALTER TABLE $table ADD COLUMN subtotal_minor INTEGER NOT NULL DEFAULT 0 CHECK(typeof(subtotal_minor)=\'integer\' AND subtotal_minor>=0)',
    'ALTER TABLE $table ADD COLUMN discount_minor INTEGER NOT NULL DEFAULT 0 CHECK(typeof(discount_minor)=\'integer\' AND discount_minor>=0)',
    'ALTER TABLE $table ADD COLUMN paid_minor INTEGER NOT NULL DEFAULT 0 CHECK(typeof(paid_minor)=\'integer\' AND paid_minor>=0)',
    'ALTER TABLE $table ADD COLUMN receipt_json TEXT',
    '''CREATE TRIGGER protect_${table}_snapshots BEFORE UPDATE ON $table
       WHEN OLD.status!='draft' AND (NEW.subtotal_minor IS NOT OLD.subtotal_minor
       OR NEW.discount_minor IS NOT OLD.discount_minor OR NEW.paid_minor IS NOT OLD.paid_minor
       OR NEW.receipt_json IS NOT OLD.receipt_json)
       BEGIN SELECT RAISE(ABORT,'Financial snapshots are immutable'); END''',
  ],
  for (final table in ['purchase_items', 'sale_items'])
    'ALTER TABLE $table ADD COLUMN product_name TEXT',
  for (final table in ['customers', 'suppliers'])
    '''CREATE TRIGGER preserve_$table BEFORE DELETE ON $table
       BEGIN SELECT RAISE(ABORT,'Deactivate contacts instead of deleting'); END''',
  '''CREATE TRIGGER preserve_walk_in BEFORE UPDATE ON customers
     WHEN OLD.is_walk_in=1 AND (NEW.is_walk_in!=1 OR NEW.status!='active' OR NEW.name!=OLD.name)
     BEGIN SELECT RAISE(ABORT,'Keep the default Walk-in Customer active'); END''',
];
