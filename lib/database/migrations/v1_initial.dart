// Migration 1 is immutable once released. Add a new migration for later changes.
// All timestamps are UTC Unix milliseconds. All numeric business values are INTEGER.
// See README for scales, sign conventions, and service-level invariants.
const initialSchema = <String>[
  '''
CREATE TABLE shops (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36),
  created_at INTEGER NOT NULL CHECK(typeof(created_at) = 'integer'),
  updated_at INTEGER NOT NULL CHECK(typeof(updated_at) = 'integer' AND updated_at >= created_at),
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision) = 'integer' AND revision > 0),
  status TEXT NOT NULL CHECK(status IN ('active','archived')),
  name TEXT NOT NULL,
  owner_name TEXT NOT NULL,
  business_category TEXT NOT NULL,
  currency_code TEXT NOT NULL CHECK(length(currency_code) = 3),
  currency_minor_digits INTEGER NOT NULL CHECK(typeof(currency_minor_digits) = 'integer' AND currency_minor_digits BETWEEN 0 AND 4)
)
  ''',
  '''
CREATE TABLE users (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36),
  created_at INTEGER NOT NULL CHECK(typeof(created_at) = 'integer'),
  updated_at INTEGER NOT NULL CHECK(typeof(updated_at) = 'integer' AND updated_at >= created_at),
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision) = 'integer' AND revision > 0),
  status TEXT NOT NULL CHECK(status IN ('active','archived')),
  shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  display_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK(role IN ('owner','cashier')),
  UNIQUE(shop_id, id)
)
  ''',
  '''
CREATE INDEX idx_users_shop_status ON users(shop_id, status)
  ''',
  '''
CREATE TABLE products (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36),
  created_at INTEGER NOT NULL CHECK(typeof(created_at) = 'integer'),
  updated_at INTEGER NOT NULL CHECK(typeof(updated_at) = 'integer' AND updated_at >= created_at),
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision) = 'integer' AND revision > 0),
  status TEXT NOT NULL CHECK(status IN ('active','archived')),
  shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  base_unit TEXT NOT NULL,
  measurement_kind TEXT NOT NULL CHECK(measurement_kind IN ('weight','custom')),
  UNIQUE(shop_id, id),
  CHECK(measurement_kind != 'weight' OR base_unit = 'gram'),
  UNIQUE(shop_id, id, base_unit)
)
  ''',
  '''
CREATE INDEX idx_products_shop_status ON products(shop_id, status)
  ''',
  '''
CREATE TABLE customers (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36),
  created_at INTEGER NOT NULL CHECK(typeof(created_at) = 'integer'),
  updated_at INTEGER NOT NULL CHECK(typeof(updated_at) = 'integer' AND updated_at >= created_at),
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision) = 'integer' AND revision > 0),
  status TEXT NOT NULL CHECK(status IN ('active','archived')),
  shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  phone TEXT,
  address TEXT,
  note TEXT,
  UNIQUE(shop_id, id)
)
  ''',
  '''
CREATE INDEX idx_customers_shop_status ON customers(shop_id, status)
  ''',
  '''
CREATE TABLE suppliers (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36),
  created_at INTEGER NOT NULL CHECK(typeof(created_at) = 'integer'),
  updated_at INTEGER NOT NULL CHECK(typeof(updated_at) = 'integer' AND updated_at >= created_at),
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision) = 'integer' AND revision > 0),
  status TEXT NOT NULL CHECK(status IN ('active','archived')),
  shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  phone TEXT,
  address TEXT,
  note TEXT,
  UNIQUE(shop_id, id)
)
  ''',
  '''
CREATE INDEX idx_suppliers_shop_status ON suppliers(shop_id, status)
  ''',
  '''
CREATE TABLE product_units (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36),
  created_at INTEGER NOT NULL CHECK(typeof(created_at) = 'integer'),
  updated_at INTEGER NOT NULL CHECK(typeof(updated_at) = 'integer' AND updated_at >= created_at),
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision) = 'integer' AND revision > 0),
  status TEXT NOT NULL CHECK(status IN ('active','archived')),
  shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  product_id TEXT NOT NULL,
  unit_code TEXT NOT NULL,
  base_unit TEXT NOT NULL,
  conversion_numerator INTEGER NOT NULL CHECK(typeof(conversion_numerator) = 'integer' AND conversion_numerator BETWEEN 1 AND 1000000000),
  conversion_denominator INTEGER NOT NULL CHECK(typeof(conversion_denominator) = 'integer' AND conversion_denominator BETWEEN 1 AND 1000000000),
  UNIQUE(shop_id, id),
  UNIQUE(shop_id, product_id, unit_code),
  FOREIGN KEY(shop_id, product_id, base_unit) REFERENCES products(shop_id, id, base_unit) ON DELETE RESTRICT,
  CHECK(unit_code != 'gram' OR (base_unit = 'gram' AND conversion_numerator = conversion_denominator)),
  CHECK(unit_code != 'kg' OR (base_unit = 'gram' AND conversion_numerator = conversion_denominator * 1000))
)
  ''',
  '''
CREATE INDEX idx_product_units_shop_status ON product_units(shop_id, status)
  ''',
  '''
CREATE TABLE purchases (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36),
  created_at INTEGER NOT NULL CHECK(typeof(created_at) = 'integer'),
  updated_at INTEGER NOT NULL CHECK(typeof(updated_at) = 'integer' AND updated_at >= created_at),
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision) = 'integer' AND revision > 0),
  status TEXT NOT NULL CHECK(status IN ('draft','posted','cancelled')),
  shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  currency_code TEXT NOT NULL CHECK(length(currency_code) = 3),
  currency_minor_digits INTEGER NOT NULL CHECK(typeof(currency_minor_digits) = 'integer' AND currency_minor_digits BETWEEN 0 AND 4),
  occurred_at INTEGER NOT NULL,
  created_by TEXT NOT NULL,
  posted_at INTEGER,
  posted_by TEXT,
  cancelled_at INTEGER,
  cancelled_by TEXT,
  cancellation_reason TEXT,
  reverses_id TEXT,
  corrects_id TEXT,
  note TEXT,
  supplier_id TEXT NOT NULL,
  document_number TEXT,
  document_kind TEXT NOT NULL DEFAULT 'normal' CHECK(document_kind IN ('normal','reversal','correction')),
  total_minor INTEGER NOT NULL CHECK(typeof(total_minor) = 'integer' AND total_minor >= 0),
  UNIQUE(shop_id, id),
  CHECK((status = 'posted' AND posted_at IS NOT NULL AND posted_by IS NOT NULL) OR status != 'posted'),
  CHECK(status != 'cancelled' OR (cancelled_at IS NOT NULL AND cancelled_by IS NOT NULL AND cancellation_reason IS NOT NULL AND length(trim(cancellation_reason)) > 0)),
  CHECK(reverses_id IS NULL OR reverses_id != id),
  CHECK(corrects_id IS NULL OR corrects_id != id),
  FOREIGN KEY(shop_id, created_by) REFERENCES users(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, posted_by) REFERENCES users(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, cancelled_by) REFERENCES users(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, supplier_id) REFERENCES suppliers(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, reverses_id) REFERENCES purchases(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, corrects_id) REFERENCES purchases(shop_id, id) ON DELETE RESTRICT,
  UNIQUE(shop_id, document_number)
)
  ''',
  '''
CREATE INDEX idx_purchases_shop_status ON purchases(shop_id, status)
  ''',
  '''
CREATE TABLE sales (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36),
  created_at INTEGER NOT NULL CHECK(typeof(created_at) = 'integer'),
  updated_at INTEGER NOT NULL CHECK(typeof(updated_at) = 'integer' AND updated_at >= created_at),
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision) = 'integer' AND revision > 0),
  status TEXT NOT NULL CHECK(status IN ('draft','posted','cancelled')),
  shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  currency_code TEXT NOT NULL CHECK(length(currency_code) = 3),
  currency_minor_digits INTEGER NOT NULL CHECK(typeof(currency_minor_digits) = 'integer' AND currency_minor_digits BETWEEN 0 AND 4),
  occurred_at INTEGER NOT NULL,
  created_by TEXT NOT NULL,
  posted_at INTEGER,
  posted_by TEXT,
  cancelled_at INTEGER,
  cancelled_by TEXT,
  cancellation_reason TEXT,
  reverses_id TEXT,
  corrects_id TEXT,
  note TEXT,
  customer_id TEXT,
  document_number TEXT,
  document_kind TEXT NOT NULL DEFAULT 'normal' CHECK(document_kind IN ('normal','reversal','correction')),
  total_minor INTEGER NOT NULL CHECK(typeof(total_minor) = 'integer' AND total_minor >= 0),
  UNIQUE(shop_id, id),
  CHECK((status = 'posted' AND posted_at IS NOT NULL AND posted_by IS NOT NULL) OR status != 'posted'),
  CHECK(status != 'cancelled' OR (cancelled_at IS NOT NULL AND cancelled_by IS NOT NULL AND cancellation_reason IS NOT NULL AND length(trim(cancellation_reason)) > 0)),
  CHECK(reverses_id IS NULL OR reverses_id != id),
  CHECK(corrects_id IS NULL OR corrects_id != id),
  FOREIGN KEY(shop_id, created_by) REFERENCES users(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, posted_by) REFERENCES users(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, cancelled_by) REFERENCES users(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, customer_id) REFERENCES customers(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, reverses_id) REFERENCES sales(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, corrects_id) REFERENCES sales(shop_id, id) ON DELETE RESTRICT,
  UNIQUE(shop_id, document_number)
)
  ''',
  '''
CREATE INDEX idx_sales_shop_status ON sales(shop_id, status)
  ''',
  '''
CREATE TABLE purchase_items (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36),
  created_at INTEGER NOT NULL CHECK(typeof(created_at) = 'integer'),
  updated_at INTEGER NOT NULL CHECK(typeof(updated_at) = 'integer' AND updated_at >= created_at),
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision) = 'integer' AND revision > 0),
  status TEXT NOT NULL CHECK(status IN ('active','void')),
  shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  purchase_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  original_unit_code TEXT NOT NULL,
  base_unit TEXT NOT NULL,
  original_quantity_scaled INTEGER NOT NULL CHECK(typeof(original_quantity_scaled) = 'integer' AND original_quantity_scaled > 0),
  base_quantity_scaled INTEGER NOT NULL CHECK(typeof(base_quantity_scaled) = 'integer' AND base_quantity_scaled > 0),
  conversion_numerator INTEGER NOT NULL CHECK(typeof(conversion_numerator) = 'integer' AND conversion_numerator > 0),
  conversion_denominator INTEGER NOT NULL CHECK(typeof(conversion_denominator) = 'integer' AND conversion_denominator > 0),
  unit_price_ticks INTEGER NOT NULL CHECK(typeof(unit_price_ticks) = 'integer' AND unit_price_ticks >= 0),
  line_total_minor INTEGER NOT NULL CHECK(typeof(line_total_minor) = 'integer' AND line_total_minor >= 0),
  UNIQUE(shop_id, id),
  FOREIGN KEY(shop_id, product_id, base_unit) REFERENCES products(shop_id, id, base_unit) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, purchase_id) REFERENCES purchases(shop_id, id) ON DELETE RESTRICT
)
  ''',
  '''
CREATE INDEX idx_purchase_items_shop_status ON purchase_items(shop_id, status)
  ''',
  '''
CREATE TABLE sale_items (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36),
  created_at INTEGER NOT NULL CHECK(typeof(created_at) = 'integer'),
  updated_at INTEGER NOT NULL CHECK(typeof(updated_at) = 'integer' AND updated_at >= created_at),
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision) = 'integer' AND revision > 0),
  status TEXT NOT NULL CHECK(status IN ('active','void')),
  shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  sale_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  original_unit_code TEXT NOT NULL,
  base_unit TEXT NOT NULL,
  original_quantity_scaled INTEGER NOT NULL CHECK(typeof(original_quantity_scaled) = 'integer' AND original_quantity_scaled > 0),
  base_quantity_scaled INTEGER NOT NULL CHECK(typeof(base_quantity_scaled) = 'integer' AND base_quantity_scaled > 0),
  conversion_numerator INTEGER NOT NULL CHECK(typeof(conversion_numerator) = 'integer' AND conversion_numerator > 0),
  conversion_denominator INTEGER NOT NULL CHECK(typeof(conversion_denominator) = 'integer' AND conversion_denominator > 0),
  unit_price_ticks INTEGER NOT NULL CHECK(typeof(unit_price_ticks) = 'integer' AND unit_price_ticks >= 0),
  line_total_minor INTEGER NOT NULL CHECK(typeof(line_total_minor) = 'integer' AND line_total_minor >= 0),
  UNIQUE(shop_id, id),
  FOREIGN KEY(shop_id, product_id, base_unit) REFERENCES products(shop_id, id, base_unit) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, sale_id) REFERENCES sales(shop_id, id) ON DELETE RESTRICT
)
  ''',
  '''
CREATE INDEX idx_sale_items_shop_status ON sale_items(shop_id, status)
  ''',
  '''
CREATE TABLE expenses (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36),
  created_at INTEGER NOT NULL CHECK(typeof(created_at) = 'integer'),
  updated_at INTEGER NOT NULL CHECK(typeof(updated_at) = 'integer' AND updated_at >= created_at),
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision) = 'integer' AND revision > 0),
  status TEXT NOT NULL CHECK(status IN ('draft','posted','cancelled')),
  shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  currency_code TEXT NOT NULL CHECK(length(currency_code) = 3),
  currency_minor_digits INTEGER NOT NULL CHECK(typeof(currency_minor_digits) = 'integer' AND currency_minor_digits BETWEEN 0 AND 4),
  occurred_at INTEGER NOT NULL,
  created_by TEXT NOT NULL,
  posted_at INTEGER,
  posted_by TEXT,
  cancelled_at INTEGER,
  cancelled_by TEXT,
  cancellation_reason TEXT,
  reverses_id TEXT,
  corrects_id TEXT,
  note TEXT,
  category TEXT NOT NULL,
  description TEXT NOT NULL,
  total_minor INTEGER NOT NULL CHECK(typeof(total_minor) = 'integer' AND total_minor > 0),
  UNIQUE(shop_id, id),
  CHECK((status = 'posted' AND posted_at IS NOT NULL AND posted_by IS NOT NULL) OR status != 'posted'),
  CHECK(status != 'cancelled' OR (cancelled_at IS NOT NULL AND cancelled_by IS NOT NULL AND cancellation_reason IS NOT NULL AND length(trim(cancellation_reason)) > 0)),
  CHECK(reverses_id IS NULL OR reverses_id != id),
  CHECK(corrects_id IS NULL OR corrects_id != id),
  FOREIGN KEY(shop_id, created_by) REFERENCES users(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, posted_by) REFERENCES users(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, cancelled_by) REFERENCES users(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, reverses_id) REFERENCES expenses(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, corrects_id) REFERENCES expenses(shop_id, id) ON DELETE RESTRICT
)
  ''',
  '''
CREATE INDEX idx_expenses_shop_status ON expenses(shop_id, status)
  ''',
  '''
CREATE TABLE payments (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36),
  created_at INTEGER NOT NULL CHECK(typeof(created_at) = 'integer'),
  updated_at INTEGER NOT NULL CHECK(typeof(updated_at) = 'integer' AND updated_at >= created_at),
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision) = 'integer' AND revision > 0),
  status TEXT NOT NULL CHECK(status IN ('draft','posted','cancelled')),
  shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  currency_code TEXT NOT NULL CHECK(length(currency_code) = 3),
  currency_minor_digits INTEGER NOT NULL CHECK(typeof(currency_minor_digits) = 'integer' AND currency_minor_digits BETWEEN 0 AND 4),
  occurred_at INTEGER NOT NULL,
  created_by TEXT NOT NULL,
  posted_at INTEGER,
  posted_by TEXT,
  cancelled_at INTEGER,
  cancelled_by TEXT,
  cancellation_reason TEXT,
  reverses_id TEXT,
  corrects_id TEXT,
  note TEXT,
  direction TEXT NOT NULL CHECK(direction IN ('incoming','outgoing')),
  method TEXT NOT NULL,
  amount_minor INTEGER NOT NULL CHECK(typeof(amount_minor) = 'integer' AND amount_minor > 0),
  customer_id TEXT,
  supplier_id TEXT,
  sale_id TEXT,
  purchase_id TEXT,
  expense_id TEXT,
  UNIQUE(shop_id, id),
  CHECK((status = 'posted' AND posted_at IS NOT NULL AND posted_by IS NOT NULL) OR status != 'posted'),
  CHECK(status != 'cancelled' OR (cancelled_at IS NOT NULL AND cancelled_by IS NOT NULL AND cancellation_reason IS NOT NULL AND length(trim(cancellation_reason)) > 0)),
  CHECK(reverses_id IS NULL OR reverses_id != id),
  CHECK(corrects_id IS NULL OR corrects_id != id),
  FOREIGN KEY(shop_id, created_by) REFERENCES users(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, posted_by) REFERENCES users(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, cancelled_by) REFERENCES users(shop_id, id) ON DELETE RESTRICT,
  CHECK(NOT (customer_id IS NOT NULL AND supplier_id IS NOT NULL)),
  CHECK((sale_id IS NOT NULL) + (purchase_id IS NOT NULL) + (expense_id IS NOT NULL) <= 1),
  FOREIGN KEY(shop_id, customer_id) REFERENCES customers(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, supplier_id) REFERENCES suppliers(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, sale_id) REFERENCES sales(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, purchase_id) REFERENCES purchases(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, expense_id) REFERENCES expenses(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, reverses_id) REFERENCES payments(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, corrects_id) REFERENCES payments(shop_id, id) ON DELETE RESTRICT
)
  ''',
  '''
CREATE INDEX idx_payments_shop_status ON payments(shop_id, status)
  ''',
  '''
CREATE TABLE stock_transactions (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36),
  created_at INTEGER NOT NULL CHECK(typeof(created_at) = 'integer'),
  updated_at INTEGER NOT NULL CHECK(typeof(updated_at) = 'integer' AND updated_at >= created_at),
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision) = 'integer' AND revision > 0),
  status TEXT NOT NULL CHECK(status IN ('draft','posted','cancelled')),
  shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  product_id TEXT NOT NULL,
  original_unit_code TEXT NOT NULL,
  base_unit TEXT NOT NULL,
  original_quantity_scaled INTEGER NOT NULL CHECK(typeof(original_quantity_scaled) = 'integer' AND original_quantity_scaled > 0),
  base_quantity_scaled INTEGER NOT NULL CHECK(typeof(base_quantity_scaled) = 'integer' AND base_quantity_scaled > 0),
  conversion_numerator INTEGER NOT NULL CHECK(typeof(conversion_numerator) = 'integer' AND conversion_numerator > 0),
  conversion_denominator INTEGER NOT NULL CHECK(typeof(conversion_denominator) = 'integer' AND conversion_denominator > 0),
  occurred_at INTEGER NOT NULL,
  created_by TEXT NOT NULL,
  reason TEXT NOT NULL CHECK(reason IN ('opening_stock','purchase','sale','return','damage','manual_adjustment','reversal','correction')),
  quantity_delta_scaled INTEGER NOT NULL CHECK(typeof(quantity_delta_scaled) = 'integer' AND quantity_delta_scaled != 0 AND (quantity_delta_scaled = base_quantity_scaled OR quantity_delta_scaled = -base_quantity_scaled)),
  purchase_item_id TEXT,
  sale_item_id TEXT,
  reverses_id TEXT,
  note TEXT NOT NULL CHECK(length(trim(note)) > 0),
  UNIQUE(shop_id, id),
  FOREIGN KEY(shop_id, product_id, base_unit) REFERENCES products(shop_id, id, base_unit) ON DELETE RESTRICT,
  CHECK(NOT (purchase_item_id IS NOT NULL AND sale_item_id IS NOT NULL)),
  CHECK(reason != 'purchase' OR (purchase_item_id IS NOT NULL AND quantity_delta_scaled > 0)),
  CHECK(reason != 'sale' OR (sale_item_id IS NOT NULL AND quantity_delta_scaled < 0)),
  CHECK(reason != 'damage' OR quantity_delta_scaled < 0),
  CHECK((reason = 'reversal' AND reverses_id IS NOT NULL) OR (reason != 'reversal' AND reverses_id IS NULL)),
  CHECK(reverses_id IS NULL OR reverses_id != id),
  FOREIGN KEY(shop_id, created_by) REFERENCES users(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, purchase_item_id) REFERENCES purchase_items(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, sale_item_id) REFERENCES sale_items(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, reverses_id) REFERENCES stock_transactions(shop_id, id) ON DELETE RESTRICT
)
  ''',
  '''
CREATE INDEX idx_stock_transactions_shop_status ON stock_transactions(shop_id, status)
  ''',
  '''
CREATE TABLE customer_ledger_entries (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36),
  created_at INTEGER NOT NULL CHECK(typeof(created_at) = 'integer'),
  updated_at INTEGER NOT NULL CHECK(typeof(updated_at) = 'integer' AND updated_at >= created_at),
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision) = 'integer' AND revision > 0),
  status TEXT NOT NULL CHECK(status IN ('draft','posted','cancelled')),
  shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  currency_code TEXT NOT NULL CHECK(length(currency_code) = 3),
  currency_minor_digits INTEGER NOT NULL CHECK(typeof(currency_minor_digits) = 'integer' AND currency_minor_digits BETWEEN 0 AND 4),
  customer_id TEXT NOT NULL,
  sale_id TEXT,
  payment_id TEXT,
  reverses_id TEXT,
  occurred_at INTEGER NOT NULL,
  created_by TEXT NOT NULL,
  entry_kind TEXT NOT NULL CHECK(entry_kind IN ('opening_balance','invoice','payment','adjustment','reversal')),
  amount_delta_minor INTEGER NOT NULL CHECK(typeof(amount_delta_minor) = 'integer' AND amount_delta_minor != 0),
  note TEXT NOT NULL CHECK(length(trim(note)) > 0),
  UNIQUE(shop_id, id),
  CHECK(NOT (sale_id IS NOT NULL AND payment_id IS NOT NULL)),
  CHECK(entry_kind != 'invoice' OR sale_id IS NOT NULL),
  CHECK(entry_kind != 'payment' OR payment_id IS NOT NULL),
  CHECK((entry_kind = 'reversal' AND reverses_id IS NOT NULL) OR (entry_kind != 'reversal' AND reverses_id IS NULL)),
  CHECK(reverses_id IS NULL OR reverses_id != id),
  FOREIGN KEY(shop_id, customer_id) REFERENCES customers(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, sale_id) REFERENCES sales(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, payment_id) REFERENCES payments(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, created_by) REFERENCES users(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, reverses_id) REFERENCES customer_ledger_entries(shop_id, id) ON DELETE RESTRICT
)
  ''',
  '''
CREATE INDEX idx_customer_ledger_entries_shop_status ON customer_ledger_entries(shop_id, status)
  ''',
  '''
CREATE TABLE supplier_ledger_entries (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36),
  created_at INTEGER NOT NULL CHECK(typeof(created_at) = 'integer'),
  updated_at INTEGER NOT NULL CHECK(typeof(updated_at) = 'integer' AND updated_at >= created_at),
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision) = 'integer' AND revision > 0),
  status TEXT NOT NULL CHECK(status IN ('draft','posted','cancelled')),
  shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  currency_code TEXT NOT NULL CHECK(length(currency_code) = 3),
  currency_minor_digits INTEGER NOT NULL CHECK(typeof(currency_minor_digits) = 'integer' AND currency_minor_digits BETWEEN 0 AND 4),
  supplier_id TEXT NOT NULL,
  purchase_id TEXT,
  payment_id TEXT,
  reverses_id TEXT,
  occurred_at INTEGER NOT NULL,
  created_by TEXT NOT NULL,
  entry_kind TEXT NOT NULL CHECK(entry_kind IN ('opening_balance','invoice','payment','adjustment','reversal')),
  amount_delta_minor INTEGER NOT NULL CHECK(typeof(amount_delta_minor) = 'integer' AND amount_delta_minor != 0),
  note TEXT NOT NULL CHECK(length(trim(note)) > 0),
  UNIQUE(shop_id, id),
  CHECK(NOT (purchase_id IS NOT NULL AND payment_id IS NOT NULL)),
  CHECK(entry_kind != 'invoice' OR purchase_id IS NOT NULL),
  CHECK(entry_kind != 'payment' OR payment_id IS NOT NULL),
  CHECK((entry_kind = 'reversal' AND reverses_id IS NOT NULL) OR (entry_kind != 'reversal' AND reverses_id IS NULL)),
  CHECK(reverses_id IS NULL OR reverses_id != id),
  FOREIGN KEY(shop_id, supplier_id) REFERENCES suppliers(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, purchase_id) REFERENCES purchases(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, payment_id) REFERENCES payments(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, created_by) REFERENCES users(shop_id, id) ON DELETE RESTRICT,
  FOREIGN KEY(shop_id, reverses_id) REFERENCES supplier_ledger_entries(shop_id, id) ON DELETE RESTRICT
)
  ''',
  '''
CREATE INDEX idx_supplier_ledger_entries_shop_status ON supplier_ledger_entries(shop_id, status)
  ''',
  '''
CREATE TABLE settings (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36),
  created_at INTEGER NOT NULL CHECK(typeof(created_at) = 'integer'),
  updated_at INTEGER NOT NULL CHECK(typeof(updated_at) = 'integer' AND updated_at >= created_at),
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision) = 'integer' AND revision > 0),
  status TEXT NOT NULL CHECK(status IN ('active','archived')),
  shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  key TEXT NOT NULL,
  value_json TEXT NOT NULL,
  UNIQUE(shop_id, id),
  UNIQUE(shop_id, key)
)
  ''',
  '''
CREATE INDEX idx_settings_shop_status ON settings(shop_id, status)
  ''',
  '''
CREATE TABLE audit_events (
  id TEXT PRIMARY KEY NOT NULL CHECK(length(id) = 36),
  created_at INTEGER NOT NULL CHECK(typeof(created_at) = 'integer'),
  updated_at INTEGER NOT NULL CHECK(typeof(updated_at) = 'integer' AND updated_at >= created_at),
  revision INTEGER NOT NULL DEFAULT 1 CHECK(typeof(revision) = 'integer' AND revision > 0),
  status TEXT NOT NULL CHECK(status IN ('recorded')),
  shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
  actor_id TEXT NOT NULL,
  entity_table TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  action TEXT NOT NULL,
  reason TEXT NOT NULL,
  before_json TEXT,
  after_json TEXT,
  UNIQUE(shop_id, id),
  FOREIGN KEY(shop_id, actor_id) REFERENCES users(shop_id, id) ON DELETE RESTRICT
)
  ''',
  '''
CREATE INDEX idx_audit_events_shop_status ON audit_events(shop_id, status)
  ''',
  '''
CREATE TRIGGER protect_purchases_update BEFORE UPDATE ON purchases
WHEN OLD.status != 'draft' AND (
  OLD.status = 'cancelled' OR NEW.status != 'cancelled' OR
  NEW.id IS NOT OLD.id OR NEW.created_at IS NOT OLD.created_at OR NEW.shop_id IS NOT OLD.shop_id OR NEW.currency_code IS NOT OLD.currency_code OR NEW.currency_minor_digits IS NOT OLD.currency_minor_digits OR NEW.occurred_at IS NOT OLD.occurred_at OR NEW.created_by IS NOT OLD.created_by OR NEW.posted_at IS NOT OLD.posted_at OR NEW.posted_by IS NOT OLD.posted_by OR NEW.reverses_id IS NOT OLD.reverses_id OR NEW.corrects_id IS NOT OLD.corrects_id OR NEW.note IS NOT OLD.note OR NEW.supplier_id IS NOT OLD.supplier_id OR NEW.document_number IS NOT OLD.document_number OR NEW.document_kind IS NOT OLD.document_kind OR NEW.total_minor IS NOT OLD.total_minor
)
BEGIN SELECT RAISE(ABORT, 'Completed documents are immutable; use cancellation or linked reversal/correction'); END
  ''',
  '''
CREATE TRIGGER protect_purchases_delete BEFORE DELETE ON purchases
WHEN OLD.status != 'draft'
BEGIN SELECT RAISE(ABORT, 'Completed documents cannot be deleted'); END
  ''',
  '''
CREATE TRIGGER protect_sales_update BEFORE UPDATE ON sales
WHEN OLD.status != 'draft' AND (
  OLD.status = 'cancelled' OR NEW.status != 'cancelled' OR
  NEW.id IS NOT OLD.id OR NEW.created_at IS NOT OLD.created_at OR NEW.shop_id IS NOT OLD.shop_id OR NEW.currency_code IS NOT OLD.currency_code OR NEW.currency_minor_digits IS NOT OLD.currency_minor_digits OR NEW.occurred_at IS NOT OLD.occurred_at OR NEW.created_by IS NOT OLD.created_by OR NEW.posted_at IS NOT OLD.posted_at OR NEW.posted_by IS NOT OLD.posted_by OR NEW.reverses_id IS NOT OLD.reverses_id OR NEW.corrects_id IS NOT OLD.corrects_id OR NEW.note IS NOT OLD.note OR NEW.customer_id IS NOT OLD.customer_id OR NEW.document_number IS NOT OLD.document_number OR NEW.document_kind IS NOT OLD.document_kind OR NEW.total_minor IS NOT OLD.total_minor
)
BEGIN SELECT RAISE(ABORT, 'Completed documents are immutable; use cancellation or linked reversal/correction'); END
  ''',
  '''
CREATE TRIGGER protect_sales_delete BEFORE DELETE ON sales
WHEN OLD.status != 'draft'
BEGIN SELECT RAISE(ABORT, 'Completed documents cannot be deleted'); END
  ''',
  '''
CREATE TRIGGER protect_expenses_update BEFORE UPDATE ON expenses
WHEN OLD.status != 'draft' AND (
  OLD.status = 'cancelled' OR NEW.status != 'cancelled' OR
  NEW.id IS NOT OLD.id OR NEW.created_at IS NOT OLD.created_at OR NEW.shop_id IS NOT OLD.shop_id OR NEW.currency_code IS NOT OLD.currency_code OR NEW.currency_minor_digits IS NOT OLD.currency_minor_digits OR NEW.occurred_at IS NOT OLD.occurred_at OR NEW.created_by IS NOT OLD.created_by OR NEW.posted_at IS NOT OLD.posted_at OR NEW.posted_by IS NOT OLD.posted_by OR NEW.reverses_id IS NOT OLD.reverses_id OR NEW.corrects_id IS NOT OLD.corrects_id OR NEW.note IS NOT OLD.note OR NEW.category IS NOT OLD.category OR NEW.description IS NOT OLD.description OR NEW.total_minor IS NOT OLD.total_minor
)
BEGIN SELECT RAISE(ABORT, 'Completed documents are immutable; use cancellation or linked reversal/correction'); END
  ''',
  '''
CREATE TRIGGER protect_expenses_delete BEFORE DELETE ON expenses
WHEN OLD.status != 'draft'
BEGIN SELECT RAISE(ABORT, 'Completed documents cannot be deleted'); END
  ''',
  '''
CREATE TRIGGER protect_payments_update BEFORE UPDATE ON payments
WHEN OLD.status != 'draft' AND (
  OLD.status = 'cancelled' OR NEW.status != 'cancelled' OR
  NEW.id IS NOT OLD.id OR NEW.created_at IS NOT OLD.created_at OR NEW.shop_id IS NOT OLD.shop_id OR NEW.currency_code IS NOT OLD.currency_code OR NEW.currency_minor_digits IS NOT OLD.currency_minor_digits OR NEW.occurred_at IS NOT OLD.occurred_at OR NEW.created_by IS NOT OLD.created_by OR NEW.posted_at IS NOT OLD.posted_at OR NEW.posted_by IS NOT OLD.posted_by OR NEW.reverses_id IS NOT OLD.reverses_id OR NEW.corrects_id IS NOT OLD.corrects_id OR NEW.note IS NOT OLD.note OR NEW.direction IS NOT OLD.direction OR NEW.method IS NOT OLD.method OR NEW.amount_minor IS NOT OLD.amount_minor OR NEW.customer_id IS NOT OLD.customer_id OR NEW.supplier_id IS NOT OLD.supplier_id OR NEW.sale_id IS NOT OLD.sale_id OR NEW.purchase_id IS NOT OLD.purchase_id OR NEW.expense_id IS NOT OLD.expense_id
)
BEGIN SELECT RAISE(ABORT, 'Completed documents are immutable; use cancellation or linked reversal/correction'); END
  ''',
  '''
CREATE TRIGGER protect_payments_delete BEFORE DELETE ON payments
WHEN OLD.status != 'draft'
BEGIN SELECT RAISE(ABORT, 'Completed documents cannot be deleted'); END
  ''',
  '''
CREATE TRIGGER protect_purchase_items_insert BEFORE INSERT ON purchase_items
WHEN (SELECT status FROM purchases WHERE id = NEW.purchase_id) != 'draft'
BEGIN SELECT RAISE(ABORT, 'Items of completed documents are immutable'); END
  ''',
  '''
CREATE TRIGGER protect_purchase_items_update BEFORE UPDATE ON purchase_items
WHEN (SELECT status FROM purchases WHERE id = NEW.purchase_id) != 'draft' OR (SELECT status FROM purchases WHERE id = OLD.purchase_id) != 'draft'
BEGIN SELECT RAISE(ABORT, 'Items of completed documents are immutable'); END
  ''',
  '''
CREATE TRIGGER protect_purchase_items_delete BEFORE DELETE ON purchase_items
WHEN (SELECT status FROM purchases WHERE id = OLD.purchase_id) != 'draft'
BEGIN SELECT RAISE(ABORT, 'Items of completed documents are immutable'); END
  ''',
  '''
CREATE TRIGGER protect_sale_items_insert BEFORE INSERT ON sale_items
WHEN (SELECT status FROM sales WHERE id = NEW.sale_id) != 'draft'
BEGIN SELECT RAISE(ABORT, 'Items of completed documents are immutable'); END
  ''',
  '''
CREATE TRIGGER protect_sale_items_update BEFORE UPDATE ON sale_items
WHEN (SELECT status FROM sales WHERE id = NEW.sale_id) != 'draft' OR (SELECT status FROM sales WHERE id = OLD.sale_id) != 'draft'
BEGIN SELECT RAISE(ABORT, 'Items of completed documents are immutable'); END
  ''',
  '''
CREATE TRIGGER protect_sale_items_delete BEFORE DELETE ON sale_items
WHEN (SELECT status FROM sales WHERE id = OLD.sale_id) != 'draft'
BEGIN SELECT RAISE(ABORT, 'Items of completed documents are immutable'); END
  ''',
  '''
CREATE TRIGGER protect_stock_transactions_update BEFORE UPDATE ON stock_transactions
WHEN OLD.status != 'draft'
BEGIN SELECT RAISE(ABORT, 'Posted movements and audit events are append-only'); END
  ''',
  '''
CREATE TRIGGER protect_stock_transactions_delete BEFORE DELETE ON stock_transactions
WHEN OLD.status != 'draft'
BEGIN SELECT RAISE(ABORT, 'Posted movements and audit events are append-only'); END
  ''',
  '''
CREATE TRIGGER protect_customer_ledger_entries_update BEFORE UPDATE ON customer_ledger_entries
WHEN OLD.status != 'draft'
BEGIN SELECT RAISE(ABORT, 'Posted movements and audit events are append-only'); END
  ''',
  '''
CREATE TRIGGER protect_customer_ledger_entries_delete BEFORE DELETE ON customer_ledger_entries
WHEN OLD.status != 'draft'
BEGIN SELECT RAISE(ABORT, 'Posted movements and audit events are append-only'); END
  ''',
  '''
CREATE TRIGGER protect_supplier_ledger_entries_update BEFORE UPDATE ON supplier_ledger_entries
WHEN OLD.status != 'draft'
BEGIN SELECT RAISE(ABORT, 'Posted movements and audit events are append-only'); END
  ''',
  '''
CREATE TRIGGER protect_supplier_ledger_entries_delete BEFORE DELETE ON supplier_ledger_entries
WHEN OLD.status != 'draft'
BEGIN SELECT RAISE(ABORT, 'Posted movements and audit events are append-only'); END
  ''',
  '''
CREATE TRIGGER protect_audit_events_update BEFORE UPDATE ON audit_events

BEGIN SELECT RAISE(ABORT, 'Posted movements and audit events are append-only'); END
  ''',
  '''
CREATE TRIGGER protect_audit_events_delete BEFORE DELETE ON audit_events

BEGIN SELECT RAISE(ABORT, 'Posted movements and audit events are append-only'); END
  ''',
  '''
CREATE UNIQUE INDEX idx_stock_transactions_reversal ON stock_transactions(reverses_id) WHERE reverses_id IS NOT NULL AND status = 'posted'
  ''',
  '''
CREATE TRIGGER validate_stock_transactions_reversal_insert BEFORE INSERT ON stock_transactions
WHEN NEW.status = 'posted' AND NEW.reverses_id IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM stock_transactions AS original WHERE original.id = NEW.reverses_id
 AND original.shop_id = NEW.shop_id AND original.product_id = NEW.product_id
 AND original.status = 'posted' AND original.quantity_delta_scaled = -NEW.quantity_delta_scaled AND original.base_unit = NEW.base_unit
)
BEGIN SELECT RAISE(ABORT, 'Reversal must exactly offset a posted movement for the same subject'); END
  ''',
  '''
CREATE TRIGGER validate_stock_transactions_reversal_update BEFORE UPDATE ON stock_transactions
WHEN NEW.status = 'posted' AND NEW.reverses_id IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM stock_transactions AS original WHERE original.id = NEW.reverses_id
 AND original.shop_id = NEW.shop_id AND original.product_id = NEW.product_id
 AND original.status = 'posted' AND original.quantity_delta_scaled = -NEW.quantity_delta_scaled AND original.base_unit = NEW.base_unit
)
BEGIN SELECT RAISE(ABORT, 'Reversal must exactly offset a posted movement for the same subject'); END
  ''',
  '''
CREATE UNIQUE INDEX idx_customer_ledger_entries_reversal ON customer_ledger_entries(reverses_id) WHERE reverses_id IS NOT NULL AND status = 'posted'
  ''',
  '''
CREATE TRIGGER validate_customer_ledger_entries_reversal_insert BEFORE INSERT ON customer_ledger_entries
WHEN NEW.status = 'posted' AND NEW.reverses_id IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM customer_ledger_entries AS original WHERE original.id = NEW.reverses_id
 AND original.shop_id = NEW.shop_id AND original.customer_id = NEW.customer_id
 AND original.status = 'posted' AND original.amount_delta_minor = -NEW.amount_delta_minor AND original.currency_code = NEW.currency_code AND original.currency_minor_digits = NEW.currency_minor_digits
)
BEGIN SELECT RAISE(ABORT, 'Reversal must exactly offset a posted movement for the same subject'); END
  ''',
  '''
CREATE TRIGGER validate_customer_ledger_entries_reversal_update BEFORE UPDATE ON customer_ledger_entries
WHEN NEW.status = 'posted' AND NEW.reverses_id IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM customer_ledger_entries AS original WHERE original.id = NEW.reverses_id
 AND original.shop_id = NEW.shop_id AND original.customer_id = NEW.customer_id
 AND original.status = 'posted' AND original.amount_delta_minor = -NEW.amount_delta_minor AND original.currency_code = NEW.currency_code AND original.currency_minor_digits = NEW.currency_minor_digits
)
BEGIN SELECT RAISE(ABORT, 'Reversal must exactly offset a posted movement for the same subject'); END
  ''',
  '''
CREATE UNIQUE INDEX idx_supplier_ledger_entries_reversal ON supplier_ledger_entries(reverses_id) WHERE reverses_id IS NOT NULL AND status = 'posted'
  ''',
  '''
CREATE TRIGGER validate_supplier_ledger_entries_reversal_insert BEFORE INSERT ON supplier_ledger_entries
WHEN NEW.status = 'posted' AND NEW.reverses_id IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM supplier_ledger_entries AS original WHERE original.id = NEW.reverses_id
 AND original.shop_id = NEW.shop_id AND original.supplier_id = NEW.supplier_id
 AND original.status = 'posted' AND original.amount_delta_minor = -NEW.amount_delta_minor AND original.currency_code = NEW.currency_code AND original.currency_minor_digits = NEW.currency_minor_digits
)
BEGIN SELECT RAISE(ABORT, 'Reversal must exactly offset a posted movement for the same subject'); END
  ''',
  '''
CREATE TRIGGER validate_supplier_ledger_entries_reversal_update BEFORE UPDATE ON supplier_ledger_entries
WHEN NEW.status = 'posted' AND NEW.reverses_id IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM supplier_ledger_entries AS original WHERE original.id = NEW.reverses_id
 AND original.shop_id = NEW.shop_id AND original.supplier_id = NEW.supplier_id
 AND original.status = 'posted' AND original.amount_delta_minor = -NEW.amount_delta_minor AND original.currency_code = NEW.currency_code AND original.currency_minor_digits = NEW.currency_minor_digits
)
BEGIN SELECT RAISE(ABORT, 'Reversal must exactly offset a posted movement for the same subject'); END
  ''',
  '''
CREATE INDEX idx_stock_product_time ON stock_transactions(shop_id, product_id, occurred_at)
  ''',
  '''
CREATE INDEX idx_customer_ledger_time ON customer_ledger_entries(shop_id, customer_id, occurred_at)
  ''',
  '''
CREATE INDEX idx_supplier_ledger_time ON supplier_ledger_entries(shop_id, supplier_id, occurred_at)
  ''',
  '''
CREATE VIEW stock_balances AS
SELECT shop_id, product_id, base_unit, SUM(quantity_delta_scaled) AS quantity_scaled
FROM stock_transactions WHERE status = 'posted'
GROUP BY shop_id, product_id, base_unit
  ''',
];
