// Additive Phase 2 migration. Version 1 remains unchanged.
const phase2Schema = <String>[
  '''ALTER TABLE shops ADD COLUMN country TEXT''',
  '''ALTER TABLE shops ADD COLUMN phone TEXT''',
  '''ALTER TABLE shops ADD COLUMN address TEXT''',
  '''ALTER TABLE shops ADD COLUMN setup_completed_at INTEGER''',
  '''ALTER TABLE products ADD COLUMN sku TEXT''',
  '''ALTER TABLE products ADD COLUMN description TEXT''',
  '''ALTER TABLE products ADD COLUMN name_key TEXT''',
  '''ALTER TABLE products ADD COLUMN primary_unit_code TEXT''',
  '''ALTER TABLE products ADD COLUMN default_sale_unit_code TEXT''',
  '''ALTER TABLE products ADD COLUMN minimum_stock_scaled INTEGER NOT NULL DEFAULT 0 CHECK(typeof(minimum_stock_scaled)='integer' AND minimum_stock_scaled>=0)''',
  '''ALTER TABLE products ADD COLUMN purchase_price_id TEXT REFERENCES product_prices(id) ON DELETE RESTRICT''',
  '''ALTER TABLE products ADD COLUMN sale_price_id TEXT REFERENCES product_prices(id) ON DELETE RESTRICT''',
  '''ALTER TABLE products ADD COLUMN opening_transaction_id TEXT REFERENCES stock_transactions(id) ON DELETE RESTRICT''',
  '''ALTER TABLE stock_transactions ADD COLUMN opening_value_minor INTEGER CHECK(opening_value_minor IS NULL OR typeof(opening_value_minor)='integer')''',
  '''ALTER TABLE stock_transactions ADD COLUMN value_currency_code TEXT''',
  '''ALTER TABLE stock_transactions ADD COLUMN value_currency_minor_digits INTEGER''',
  '''CREATE UNIQUE INDEX idx_product_name_key ON products(shop_id,name_key) WHERE name_key IS NOT NULL''',
  '''CREATE UNIQUE INDEX idx_product_sku ON products(shop_id,sku) WHERE sku IS NOT NULL''',
  '''CREATE TABLE owner_credentials (
 id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
 shop_id TEXT NOT NULL,
 user_id TEXT NOT NULL UNIQUE,
 username TEXT NOT NULL UNIQUE,
 password_hash TEXT NOT NULL,
 failed_attempts INTEGER NOT NULL DEFAULT 0,
 locked_until INTEGER NOT NULL DEFAULT 0,
 created_at INTEGER NOT NULL,
 updated_at INTEGER NOT NULL,
 revision INTEGER NOT NULL DEFAULT 1,
 status TEXT NOT NULL CHECK(status IN ('active','archived')),
 FOREIGN KEY(shop_id,user_id) REFERENCES users(shop_id,id) ON DELETE RESTRICT
)''',
  '''CREATE TABLE local_sessions (
 id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
 shop_id TEXT NOT NULL,
 user_id TEXT NOT NULL,
 token_hash TEXT NOT NULL UNIQUE,
 expires_at INTEGER NOT NULL,
 created_at INTEGER NOT NULL,
 updated_at INTEGER NOT NULL,
 revision INTEGER NOT NULL DEFAULT 1,
 status TEXT NOT NULL CHECK(status IN ('active','revoked')),
 FOREIGN KEY(shop_id,user_id) REFERENCES users(shop_id,id) ON DELETE RESTRICT
)''',
  '''CREATE TABLE product_prices (
 id TEXT PRIMARY KEY NOT NULL CHECK(length(id)=36),
 shop_id TEXT NOT NULL,
 product_id TEXT NOT NULL,
 price_kind TEXT NOT NULL CHECK(price_kind IN ('purchase','sale')),
 amount_ticks INTEGER NOT NULL CHECK(typeof(amount_ticks)='integer' AND amount_ticks>=0),
 currency_code TEXT NOT NULL,
 currency_minor_digits INTEGER NOT NULL CHECK(currency_minor_digits BETWEEN 0 AND 4),
 unit_code TEXT NOT NULL,
 base_unit TEXT NOT NULL,
 conversion_numerator INTEGER NOT NULL CHECK(typeof(conversion_numerator)='integer' AND conversion_numerator>0),
 conversion_denominator INTEGER NOT NULL CHECK(typeof(conversion_denominator)='integer' AND conversion_denominator>0),
 created_by TEXT NOT NULL,
 created_at INTEGER NOT NULL,
 updated_at INTEGER NOT NULL,
 revision INTEGER NOT NULL DEFAULT 1,
 status TEXT NOT NULL CHECK(status='recorded'),
 UNIQUE(shop_id,id),
 FOREIGN KEY(shop_id,product_id,base_unit) REFERENCES products(shop_id,id,base_unit) ON DELETE RESTRICT,
 FOREIGN KEY(shop_id,created_by) REFERENCES users(shop_id,id) ON DELETE RESTRICT
)''',
  '''CREATE INDEX idx_product_prices_history ON product_prices(shop_id,product_id,created_at)''',
  '''CREATE TRIGGER immutable_product_base BEFORE UPDATE ON products
WHEN NEW.base_unit IS NOT OLD.base_unit OR NEW.measurement_kind IS NOT OLD.measurement_kind
BEGIN SELECT RAISE(ABORT,'Product base unit cannot be reinterpreted'); END''',
  '''CREATE TRIGGER preserve_products BEFORE DELETE ON products
BEGIN SELECT RAISE(ABORT,'Deactivate products instead of deleting'); END''',
  '''CREATE TRIGGER immutable_prices_update BEFORE UPDATE ON product_prices
BEGIN SELECT RAISE(ABORT,'Price history is append-only'); END''',
  '''CREATE TRIGGER immutable_prices_delete BEFORE DELETE ON product_prices
BEGIN SELECT RAISE(ABORT,'Price history is append-only'); END''',
  '''CREATE TRIGGER validate_product_links_insert BEFORE INSERT ON products
WHEN (NEW.purchase_price_id IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM product_prices WHERE id=NEW.purchase_price_id AND shop_id=NEW.shop_id AND product_id=NEW.id AND price_kind='purchase'
)) OR (NEW.sale_price_id IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM product_prices WHERE id=NEW.sale_price_id AND shop_id=NEW.shop_id AND product_id=NEW.id AND price_kind='sale'
)) OR (NEW.opening_transaction_id IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM stock_transactions WHERE id=NEW.opening_transaction_id AND shop_id=NEW.shop_id AND product_id=NEW.id AND reason='opening_stock' AND status='posted'
)) OR (NEW.primary_unit_code IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM product_units WHERE shop_id=NEW.shop_id AND product_id=NEW.id AND unit_code=NEW.primary_unit_code AND status='active'
)) OR (NEW.default_sale_unit_code IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM product_units WHERE shop_id=NEW.shop_id AND product_id=NEW.id AND unit_code=NEW.default_sale_unit_code AND status='active'
))
BEGIN SELECT RAISE(ABORT,'Invalid product unit, price or opening reference'); END''',
  '''CREATE TRIGGER validate_opening_value_insert BEFORE INSERT ON stock_transactions
WHEN (NEW.opening_value_minor IS NOT NULL AND (
 NEW.reason NOT IN ('opening_stock','reversal') OR
 NEW.value_currency_code IS NULL OR NEW.value_currency_minor_digits IS NULL OR
 NEW.value_currency_minor_digits NOT BETWEEN 0 AND 4 OR
 (NEW.reason='opening_stock' AND NEW.opening_value_minor<0)
)) OR (NEW.opening_value_minor IS NULL AND (NEW.value_currency_code IS NOT NULL OR NEW.value_currency_minor_digits IS NOT NULL))
OR (NEW.reverses_id IS NOT NULL AND NEW.status='posted' AND EXISTS (
 SELECT 1 FROM stock_transactions AS original WHERE original.id=NEW.reverses_id AND (
 NEW.opening_value_minor IS NOT -original.opening_value_minor OR
 NEW.value_currency_code IS NOT original.value_currency_code OR
 NEW.value_currency_minor_digits IS NOT original.value_currency_minor_digits
)))
BEGIN SELECT RAISE(ABORT,'Opening value or reversal value does not match'); END''',
  '''CREATE TRIGGER validate_product_links_update BEFORE UPDATE ON products
WHEN (NEW.purchase_price_id IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM product_prices WHERE id=NEW.purchase_price_id AND shop_id=NEW.shop_id AND product_id=NEW.id AND price_kind='purchase'
)) OR (NEW.sale_price_id IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM product_prices WHERE id=NEW.sale_price_id AND shop_id=NEW.shop_id AND product_id=NEW.id AND price_kind='sale'
)) OR (NEW.opening_transaction_id IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM stock_transactions WHERE id=NEW.opening_transaction_id AND shop_id=NEW.shop_id AND product_id=NEW.id AND reason='opening_stock' AND status='posted'
)) OR (NEW.primary_unit_code IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM product_units WHERE shop_id=NEW.shop_id AND product_id=NEW.id AND unit_code=NEW.primary_unit_code AND status='active'
)) OR (NEW.default_sale_unit_code IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM product_units WHERE shop_id=NEW.shop_id AND product_id=NEW.id AND unit_code=NEW.default_sale_unit_code AND status='active'
))
BEGIN SELECT RAISE(ABORT,'Invalid product unit, price or opening reference'); END''',
  '''CREATE TRIGGER validate_opening_value_update BEFORE UPDATE ON stock_transactions
WHEN (NEW.opening_value_minor IS NOT NULL AND (
 NEW.reason NOT IN ('opening_stock','reversal') OR
 NEW.value_currency_code IS NULL OR NEW.value_currency_minor_digits IS NULL OR
 NEW.value_currency_minor_digits NOT BETWEEN 0 AND 4 OR
 (NEW.reason='opening_stock' AND NEW.opening_value_minor<0)
)) OR (NEW.opening_value_minor IS NULL AND (NEW.value_currency_code IS NOT NULL OR NEW.value_currency_minor_digits IS NOT NULL))
OR (NEW.reverses_id IS NOT NULL AND NEW.status='posted' AND EXISTS (
 SELECT 1 FROM stock_transactions AS original WHERE original.id=NEW.reverses_id AND (
 NEW.opening_value_minor IS NOT -original.opening_value_minor OR
 NEW.value_currency_code IS NOT original.value_currency_code OR
 NEW.value_currency_minor_digits IS NOT original.value_currency_minor_digits
)))
BEGIN SELECT RAISE(ABORT,'Opening value or reversal value does not match'); END''',
];
