# Client demo walkthrough

Use the Android debug APK at `build/app/outputs/flutter-apk/app-debug.apk`.
This is a debug build with the existing `com.example.shop_manager` application ID.
Device runtime and secure-storage behavior still require a physical-device smoke test.

## Prepare a demo shop

1. Install on a dedicated Android demo device/profile. An update can be installed
   with `adb install -r build/app/outputs/flutter-apk/app-debug.apk`; do not uninstall
   or clear an existing shop's data to enable samples.
2. On first launch, create a shop and choose your own owner username/password or PIN.
3. Log in, open Settings -> Optional demo data, then confirm Load demo data.
   This is available only in an empty shop. A shop with real data remains intact
   and cannot load samples. The action cannot be used as a reset.
4. The sample set contains rice and flour, a supplier, a customer, a purchase,
   a credit sale, customer/supplier payments and a cash expense. The dashboard
   displays a DEMO DATA banner. Amounts use the configured shop currency.

## Show the owner workflows

- Dashboard: daily sales, purchases and expenses, all-time customer/supplier
  balances, stock counts and shortcuts. These are not profit or cash-on-hand.
- Suppliers/Purchases: view the sample purchase and recorded units/payment.
- Customers/Sales: open the sale and retained receipt/invoice.
- Inventory: inspect balances, low stock and original stock movement quantities.
- Customer khata: open DEMO Customer -> View khata; receive a payment no greater
  than the outstanding balance. See the new entry and running balance.
- Supplier khata: open DEMO Grain Mill -> View khata; record a supplier payment.
- Expenses: record a cash expense with category, description, amount and date.
  Posted expenses/payments are retained; there is no delete or cancellation flow.

## Show restricted cashier access

1. In Settings -> Cashier / staff access, create a cashier with credentials you choose.
   There are no built-in staff usernames or passwords.
2. Log out and log in as the cashier. Sales, receipts, customers and customer
   payment collection are available. Purchases, suppliers, expenses, inventory,
   staff management and settings are restricted at repository boundaries.
3. Log back in as owner to deactivate/reactivate the cashier. Deactivation revokes
   existing sessions; reactivation requires a fresh login.

## Before presenting on a device

Verify setup/login, app restart/session restoration, a sale/receipt, both account
payments, an expense and cashier restrictions on the actual Android device.
No cloud sync, Firebase, barcode, desktop runner or advanced reports are included.
Receipt viewing is on-screen; printer/PDF export, tax, costing and cancellations
are outside this demo. No production data should be entered into a sample shop.
