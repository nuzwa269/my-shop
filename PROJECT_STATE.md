# Project state

## Current checkpoint - client-demo finalization

Branch: `feature/client-demo-finalization`. Schema remains **3**; no released
migrations, Phase 2, inventory or trade posting were rebuilt.

Final host validation: `flutter analyze` PASS (no issues); `flutter test
--reporter expanded` PASS (**73 tests**). Relevant module tests were run after each
major addition. UI coverage includes optional seeding, both khata settlements,
expense entry, staff creation/deactivation and restricted cashier navigation.

`flutter build apk --debug`: **PASS**. Artifact:
`build/app/outputs/flutter-apk/app-debug.apk` (191,967,342 bytes).
SHA-256: `24EB26FD66F817F6909641120C8C08BCFAA2F20DC63B9C26B5D21FC8AEC74934`.
The existing Android SDK XML-version warning was non-fatal. APK remains a local
ignored build artifact; source, tests and documentation are committed on this
branch. Do not merge into main automatically.

Completed in this session, in the requested order:
1. Customer khata: chronological posted entries, currency-separated running and
   current balances, cash collection, stale-balance/overpayment rejection.
2. Supplier khata: retained payable history and cash supplier payments with the
   same atomicity, authorization and repeat-request protection.
3. Expenses: positive cash expenses plus linked payment and audit in one transaction.
   Posted records are immutable; expenses do not change stock or party ledgers.
4. Staff: owner-created cashier accounts, activation/deactivation with session
   revocation, common password hashing/lockout/expiration, restricted repositories
   and navigation. The existing owner_credentials table name is retained for both
   supported roles; existing owner credentials are untouched.
5. Optional demo data: explicit owner confirmation, empty-shop checks inside one
   transaction, no duplicate loading, no clear/reset, no seeded credentials.
   Sample transactions use normal repositories and a shared SQL transaction.
6. Dashboard: local-day posted totals, all-time account balances, stock counts,
   module shortcuts and demo banner. Cashiers see their own daily sales only.
7. Final Android debug APK built after passing analysis and the full test suite.

Client-demo feature scope is implemented: suppliers, purchases, customers, sales,
on-screen receipt/invoice, stock/inventory, both khatas, expenses, dashboard,
owner/cashier access and optional sample data. See DEMO_WALKTHROUGH.md for setup,
demo presentation steps and device checks. No production data was seeded here.

Preserved invariants: integer money and quantities; currency/scale separation;
exact conversions; append-only posted history; repository authorization; atomic
posting. Account payments do not rewrite issued receipts or allocate against
individual invoices. All payment workflows in this demo use cash.

Physical Android runtime/secure-storage validation remains a device acceptance
step, not established by host tests or compilation. Printing/export, cancellation,
tax/costing, password recovery and advanced reports are not included. No cloud,
Firebase, barcode, desktop runner or other out-of-scope feature was added.

## Previous checkpoint - client demo: inventory

Branch: `feature/client-demo-finalization`, created after switching to main and
pulling GitHub main with `--ff-only`. Existing Phase 2/trade code retained.

Validation this session: `flutter analyze` PASS (no issues); `flutter test
--reporter expanded` PASS (all 53 tests). Android APK is deferred until the remaining
client-demo modules are ready. No merge into main is authorized for this session.

This session completes the next unfinished module, stock/inventory:
- Search by product name/SKU, low-stock/out-of-stock filters and inactive visibility.
- Exact balances from the existing posted stock view; no mutable balance field.
- Movement history retains original units, signed base quantities, dates, notes
  and reversals. Includes opening stock, corrections, purchases and sales.
- Inventory-authorized repository reads stay shop-scoped and transaction-scoped.
- Riverpod refresh follows existing product/opening/trade invalidation, with manual
  refresh/retry. No schema migration or stock-adjustment workflow was introduced.
- Added repository tests for correction/trade history, stock thresholds, archived
  products and authorization; added an inventory navigation/filter/history UI test.

Client-demo module status (the user's current scope supersedes older scope notes):
- Implemented: suppliers, purchases, customers, sales, on-screen receipt/invoice,
  stock/inventory, owner login. Phase 2 and trade integration must not be repeated.
- Next unfinished module: customer khata and supplier khata browsing, followed by
  their payment workflows. Invoice/payment entries at issue already exist.
- Still pending: expenses; cashier/staff account access; opt-in demo data; final
  Android debug APK and device/secure-storage validation.
- Dashboard exists with shop identity and active-product count; demo metrics and
  shortcuts remain unfinished. Receipt printing/export is not implemented.
- No cloud sync, Firebase, barcode, Windows app or advanced reports are in scope.

## Previous checkpoint - recovered MVP trade integration

Updated: 2026-09-25 after unexpected shutdown. Schema: **3**.
The Phase 2 checkpoint below is historical; it predates the MVP files written at
10:36-10:39. Phase 2 was preserved, not restarted.

Recovery findings:
- `git status`: no Git repository; no `.git` directory or diff history available.
- Existing source readable, with no obvious truncation, invalid UTF-8, null bytes
  or conflict markers. Empty Gradle cache markers are not source corruption.
- Completed before shutdown: Phase 2 and substantial newer MVP code: migration 3,
  trade domain/repository/providers, contact forms and transaction/receipt screens.
- Partial: new screens had compile errors and were not connected to navigation;
  trade tests were absent and existing schema tests still expected v2.
- Initial validation: analysis failed (5 errors, 2 warnings, 3 lint findings);
  36 tests passed, 3 failed due to outdated schema-version expectations.
- Pre-edit source, tests and notes: `.recovery/pre-resume-20260925/`.

Continuation completed:
- Fixed contact ConsumerWidget signature/import conflict and analyzer findings.
- Connected Customers, Suppliers, Purchases and Sales to the recovered screens.
- Fixed discounted Pay in full and catalog refresh after product changes.
- Preserved widgets -> Riverpod -> repository -> SQLite and migrations 1/2.
- Preserved recovered posting rules: exact conversions, no overselling,
  cash/credit/partial payments, fixed sale discounts, fully paid walk-in sales,
  atomic stock/payment/ledger/audit writes and immutable receipt snapshots.
- Added v2 -> v3 preservation/reopen, rollback/concurrency/precision/auth tests,
  module navigation and discounted-sale UI regression coverage.
- `flutter analyze`: **PASS, no issues found**.
- `flutter test --reporter expanded`: **PASS, all 49 tests**.
  Deliberate "Database downgrade 4 -> 3 refused" output is a passing negative test.

Next continuation: preserve this working MVP slice. The original full MVP brief is
not in the workspace, so do not infer completion of unknown requirements.
Standalone later payments, khata browsing, inventory screens, expenses/reports,
printing/export and document cancellation are still unimplemented. Receipt viewing
and ledger posting exist; those do not imply the other workflows exist.
Android runtime/secure-storage validation remains pending. No APK rebuild or device
audit was performed in this recovery, following the request for minimum checks.

## Historical Phase 2 checkpoint (superseded above)

Updated: 2026-09-25. Project: shop_manager. Target: Android.
Flutter 3.47.5 / Dart 3.13.4. Database schema: 2.
**Phase 3 has not started and is outside the current instruction.**

On resumption, README.md and this file still described only Phase 1, while the
workspace already contained substantial Phase 2 implementation and tests. Continued
from those existing files; did not recreate setup, auth, products or migrations.
There is no Git repository in this workspace, so no commit history was available
to reconstruct a more precise previous-session checkpoint.

## Existing Phase 2 work retained and verified

- Atomic first-run shop/owner setup: category, currency/precision, country, optional
  contact/address, credentials, setup marker and audit event.
- Local owner authentication replaces preview access. Salted PBKDF2-SHA256 at
  600,000 iterations; secure-storage token, SQLite token digest, 12-hour expiry,
  persistent failed-attempt lockout, restoration, logout and repository authorization.
- Dashboard shop identity and active product count.
- Product creation, details, editing, name/SKU search, status filtering,
  deactivation/reactivation, duplicate checks and stale revision rejection.
- Weight/custom base units, explicit per-product factors, primary/default sale
  units, minimum stock, purchase/sale prices and immutable price history.
- Opening quantity/date/unit and optional total value; exact reversal/replacement
  corrections with atomic audit. No party ledger entries or costing assumptions.
- Additive migration 2, preserving migration 1 and its financial/history guardrails.
- Repository, authentication, migration, precision and widget tests.

## Changes completed in this continuation

1. Fixed setup/login route placement. They were returned from MaterialApp.builder
   outside the Navigator, causing EditableText to throw "No Overlay widget found".
   The startup/auth gate now renders inside generated routes, below the Navigator.
   Session identity still resets navigation on login/logout/expiry.
2. Fixed visible startup Retry to invalidate the failed database dependency as
   well as session bootstrap. Removed the test's manual database invalidation;
   the regression now verifies two open attempts through the real button.
3. Corrected widget-test scrolling to target the outer form, and ran real SQLite
   interactions/pumping in the real async zone. All four end-to-end widget flows pass.
4. Fixed the missing-braces lint in the test store and formatted Dart files.
5. Replaced stale README/checkpoint documentation with the actual Phase 2 state.

## Verification in this continuation

- dart format lib test: PASS (67 files).
- flutter analyze: PASS, no issues found.
- flutter test --reporter expanded: PASS, all 39 tests.
- Widget suite: PASS, all 4 tests, also included in the full regression run.
- flutter build apk --debug: PASS; build/app/outputs/flutter-apk/app-debug.apk.
- flutter devices: Windows/Chrome/Edge only; no connected Android device.
- flutter emulators: no emulator sources / Android AVD images available.
- Physical Android runtime / secure-storage smoke test: NOT RUN.

The expected "Database downgrade 3 -> 2 refused" message comes from a passing
negative test; it is not a failure. Initial continuation test failures exposed the
route-overlay and test-harness issues above; the final suite passes.

The Android build automatically installed required Android SDK Platform 35 and
CMake 3.22.1 using already accepted licenses. It emitted an SDK XML version warning.

## Exact next step / remaining Phase 2 validation

Android build validation is complete. When an Android device is available, run a
smoke test of setup, login, process restart/session restoration, product/unit/price
editing, opening correction, logout and database reopening. Do not clear data to
work around failures. Host tests use a memory token vault, so they do not establish
that secure storage works on an Android device.

Do not repeat completed implementation or start Phase 3. The original detailed
Phase 2 brief is not present in the workspace; the implementation above is the
recovered scope, not a claim that every unknown prior acceptance criterion is met.

## Known boundaries

- General Settings/profile editing and Inventory remain placeholders, as do
  purchases, sales, customers, suppliers, ledgers, expenses and reports.
- No cashier/staff account administration, password recovery, backup/export,
  database encryption, receipts, profit, posting/cancellation service or cloud sync.
- Existing populated Phase 1 shops without setup credentials are preserved but
  require an explicit recovery/migration design. Empty Phase 1 databases can set up.
- Opening corrections are blocked after other posted movement types exist.
- No negative-stock, costing, discount, tax or allocation policy has been selected.
- Application ID and release signing remain scaffold/debug settings.
- Phase 2 is host-verified; Android runtime acceptance remains pending.

## Phase 1 - completed and retained

Android-only Flutter/Riverpod foundation, navigation/permissions, placeholders,
SQLite boundary and migration 1, UUIDs and metadata, integer money/quantity rules,
17 initial tables, stock balance view, immutable posted records, exact reversal
constraints and audit groundwork. The Phase 1 checkpoint recorded 23 passing
unit/widget/SQLite tests. Current Phase 2 tests supersede that historical count.

Core invariants remain: integer minor-unit money; 10,000 price ticks per minor
unit; 1,000,000 quantity ticks per base unit; grams for weight products; exact
rational normalization; stock derived from posted movements; retained immutable
history; transaction-scoped writes; no destructive schema downgrade.

