# Shop Manager - Client Demo MVP

Android-first, offline-first Flutter shop setup and product management. Phase 2
includes local owner authentication, products, explicit unit conversions, price
history and opening stock. The recovered MVP adds customers/suppliers, purchases,
sales, atomic stock/payment/party-ledger posting and retained receipt viewing.
See PROJECT_STATE.md for the exact continuation checkpoint and validation results.

## Run

Validated toolchain: Flutter 3.47.5 / Dart 3.13.4, installed at C:\dev\flutter.

```powershell
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter build apk --debug
flutter devices
flutter run -d <android-device-id>
```

Only the Android runner is configured. Running requires an authorized Android
phone or a configured emulator. Do not clear application data to resolve errors.
Startup opens SQLite, applies additive migrations and offers non-destructive retry.

## Available workflows

- First launch: create shop name, owner, category, currency/precision, country,
  optional phone/address, and a local owner username/password or PIN.
- Setup writes shop, owner credentials, completion marker and audit atomically.
  No sample data loads automatically and there is no owner/cashier preview bypass.
- Owner login, persistent 12-hour session, expiration and logout. Five failed
  attempts impose a one-minute lockout. Password/PIN recovery is not available.
- Dashboard shows shop identity, daily posted totals, outstanding party balances,
  active/low/out-of-stock counts and working module shortcuts. Cashiers see only
  their own daily sales and permitted shortcuts. Currency scales remain separate.
- Products: create, view, edit, search by name/SKU, filter active/inactive/all,
  deactivate and reactivate. Products are retained rather than deleted.
- Product configuration: variety name, optional SKU/description, weight or custom
  base unit, primary/default sale unit, minimum stock, purchase and sale prices.
- Explicit per-product unit factors; standard gram/kg and custom bag/sack/maund
  factors. No universal bag or maund size is assumed.
- Append-only purchase/sale price snapshots preserve their own currency and factor.
- Opening stock: positive original quantity/unit, normalized quantity, date,
  optional total value and reason. Corrections atomically append an exact reversal,
  replacement and audit event. They do not write customer/supplier ledgers.

Customers/Suppliers support create/edit/search and deactivation. Purchases/Sales
support item/unit selection, cash/credit/partial payment and receipt viewing.
Sales support fixed discounts and reject insufficient stock; Walk-in Customer
sales must be fully paid. Posted documents cannot be edited or cancelled in this MVP.

Inventory shows exact stock balances, low/out-of-stock filters, name/SKU search,
inactive products and posted movement history with original quantities/units.
Customer and supplier khata show chronological entries and running balances per
currency/precision. Cash collection/supplier payments append immutable payment and
ledger records atomically; overpayment and stale balances are rejected. They settle
the account, without reallocating or rewriting issued invoices.

Expenses post a cash expense, linked payment and audit together. Settings provides
owner-managed cashier creation/deactivation/reactivation and optional demo data.
Cashiers can sell, view receipts, manage customers and collect customer payments;
owner-only modules and their repositories reject cashier access. All logins use
the same salted password hashing, session expiration and lockout rules.

Demo loading requires an empty shop and explicit owner confirmation. It is atomic,
idempotent and marked on the dashboard. Existing data is never cleared or mixed
with samples. No default staff credentials are created. See DEMO_WALKTHROUGH.md.
Shop profile editing, general stock adjustments and reports remain unimplemented.

## Architecture

Widgets -> Riverpod state -> feature repositories -> DatabaseConnection -> SQLite.
Widgets do not issue SQL. Repository operations authorize the current role and use
transaction-scoped SQL sessions for atomic changes. Revisions reject stale edits.

| Location | Responsibility |
| --- | --- |
| lib/app.dart | Startup/auth route gate, lifecycle session refresh, storage retry |
| lib/core/ | Money, quantity, conversions, validation, permissions, navigation, theme |
| lib/database/ | Driver boundary, SQLite adapter, row/audit writer, migrations |
| lib/models/ | Shared entity contracts and metadata |
| lib/services/ | UUIDs and repository dependency injection |
| lib/features/auth/ | Password hashing, secure token vault, authentication, session state, login |
| lib/features/settings/ | Atomic first-run setup and shop profile reads |
| lib/features/products/ | Product repository, prices, units, opening stock and screens |
| lib/features/trade/ | Contacts, purchase/sale posting, providers and receipts |
| lib/features/ledger/ | Customer/supplier khata and account payment screens |
| lib/features/expenses/ | Atomic cash expenses and linked payment records |
| lib/features/demo/ | Explicit, empty-shop-only transactional demo seed |
| lib/features/dashboard/ | Shop identity and active product count |
| lib/shared/widgets/ | Guarded module shell, form fields, error rendering, placeholders |
| test/auth/ | Password algorithm, setup, login, lockout, expiration, authorization |
| test/products/ | CRUD, validation, price/unit history, opening correction and rollback |
| test/trade/ | Posting, rollback, overselling, precision and retained snapshots |
| test/database/ | SQLite integrity, migration, persistence, immutability and reversals |
| test/core/ | Precision, conversions, UUID and permission rules |
| test/widget_test.dart | Setup/login/logout, products/opening, layout and storage retry |

Runtime dependencies: flutter_riverpod, sqflite, path, uuid, cryptography and
flutter_secure_storage. Dev dependencies: Flutter tests/lints and sqflite_common_ffi
for real SQLite host tests. pubspec.lock pins resolved versions. FFI does not add a
desktop application target.

## Storage and authentication

Database: shop_manager.sqlite in the platform app database directory, schema
version **3**. Versions 1 and 2 remain unchanged; v2_shop_products.dart adds Phase 2 fields,
owner_credentials, local_sessions and product_prices. The historical
owner_credentials table now also holds restricted cashier credentials; no migration
or owner credential rewrite is needed. v3_mvp.dart adds walk-in
customer and document/receipt snapshots. There are 20 application
tables plus the stock_balances view. Foreign keys are enabled on each connection;
newer database versions are rejected without destructive downgrade.

The original tables are shops, users, products, product_units, customers, suppliers,
purchases, purchase_items, sales, sale_items, stock_transactions,
customer_ledger_entries, supplier_ledger_entries, expenses, payments, settings and
audit_events. UUID identity, UTC millisecond timestamps, revisions, statuses and
shop-scoped relationships support retained history.

Passwords use salted PBKDF2-HMAC-SHA256 with 600,000 iterations, a random 16-byte salt
and a 32-byte verifier. Passwords are not stored in plaintext. A random 32-byte
session token goes into flutter_secure_storage; SQLite stores its SHA-256 digest.
Sessions expire after 12 hours and are checked at repository boundaries, on resume
and by an in-app expiry timer. Android backup is disabled. SQLite itself is not
encrypted; this is local authentication, with no server or recovery workflow.

An empty Phase 1 database upgrades and proceeds to setup. A database containing
legacy shop data without setup credentials is preserved and explicitly requires a
separately designed migration/recovery path; setup will not overwrite that data.

## Precision and retained history

- Money totals use signed 64-bit integer minor units. PKR has 100 minor units per
  rupee. Currency and precision are snapshotted; no FX conversion is implemented.
- Unit prices use 10,000 ticks per minor unit (six decimal places for PKR).
  Parse decimal strings, never floating-point values; reject excess precision,
  exponent notation and locale separators.
- Line arithmetic uses BigInt intermediates, rounds once to the nearest minor unit
  with ties away from zero, then checks 64-bit bounds. Sum stored line totals.
- Quantities use 1,000,000 ticks per unit. Weight products use grams as their base;
  1 kg = 1,000 grams = 1,000,000,000 base ticks.
- Original quantity and rational numerator/denominator factors are retained.
  Normalization must be exact; no rounding stock. Each factor side is capped at
  1,000,000,000. Non-weight products have an explicitly named custom base unit.
- Base unit/measurement kind cannot change after creation. Historical prices and
  opening movements retain their factors when current product units are edited.
- Stock is the sum of posted signed movements, never an editable product balance.
  Original posted movements stay posted; an opposite linked entry reverses them.
- Posted stock/ledger rows, audit events and price history are immutable.
  Completed financial documents and lines retain their financial payloads.
- Opening corrections require a reason and current revision/opening ID. Opening
  entry is locked after other posted movement types exist. Optional opening value
  is a recorded total, not a costing/profit calculation.
- Customer positive ledger delta means customer owes shop; supplier positive means
  shop owes supplier. Never aggregate unlike currencies or precision scales.

## Boundaries and remaining work

The client-demo modules are implemented. Reports, profit, receipt printing/export,
tax, costing and document cancellation remain outside this demo. Payments at issue
and party-ledger entries post atomically with stock and audit records. Later cash
payments settle accounts without document allocation. Sales reject negative stock.
Cancellation flags alone do not reverse balances.

No cloud sync, Firebase, barcode scanning, e-commerce, payroll, online ordering,
backup/export, account recovery or desktop runner exists.
The application ID com.example.shop_manager and debug release signing are scaffold
settings, not a production distribution configuration.
