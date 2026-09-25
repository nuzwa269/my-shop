import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manager/app.dart';
import 'package:shop_manager/features/demo/presentation/demo_screen.dart';
import 'package:shop_manager/features/ledger/presentation/ledger_screen.dart';
import 'package:shop_manager/features/expenses/presentation/expenses_screen.dart';
import 'package:shop_manager/features/auth/presentation/staff_screen.dart';
import 'package:shop_manager/features/auth/data/local_staff_repository.dart';
import 'package:shop_manager/database/database_provider.dart';
import 'package:shop_manager/features/auth/application/session_provider.dart';
import 'package:shop_manager/features/products/application/product_providers.dart';
import 'package:shop_manager/features/products/domain/product.dart';
import 'package:shop_manager/features/products/presentation/product_editor_screen.dart';
import 'package:shop_manager/features/products/presentation/unit_configuration_screen.dart';
import 'package:shop_manager/core/units/quantity.dart';
import 'package:shop_manager/services/repository_providers.dart';
import 'package:shop_manager/features/trade/presentation/trade_screens.dart';
import 'package:shop_manager/features/trade/domain/trade.dart';
import 'package:shop_manager/features/trade/data/local_trade_repository.dart';

import 'support/test_store.dart';

void main() {
  Future<void> settleIo(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 20; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> mount(WidgetTester tester, TestStore store) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => store.db),
        passwordHasherProvider.overrideWithValue(store.hasher),
        sessionVaultProvider.overrideWithValue(store.vault),
      ],
    );
    await tester.runAsync(() => container.read(sessionProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ShopManagerApp(),
      ),
    );
    await settleIo(tester);
    return container;
  }

  Future<void> enter(
    WidgetTester tester,
    String label,
    String text, {
    double scroll = 200,
  }) async {
    final field = find.widgetWithText(TextField, label);
    await tester.scrollUntilVisible(
      field,
      scroll,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(field, text);
  }

  testWidgets('first-run setup, owner login, dashboard and logout', (
    tester,
  ) async {
    final store = await tester.runAsync(
      () => TestStore.open(configured: false),
    );
    final container = await mount(tester, store!);
    addTearDown(() async {
      container.dispose();
      await store.close();
    });
    expect(find.text('Set up your shop'), findsOneWidget);
    await enter(tester, 'Shop name', 'Neighbourhood Flour');
    await enter(tester, 'Owner full name', 'Aisha Owner');
    await enter(tester, 'Username or email', 'owner@example.com');
    await enter(tester, 'Password or PIN', 'owner-password');
    await enter(tester, 'Confirm password or PIN', 'owner-password');
    await tester.scrollUntilVisible(
      find.text('Create shop'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.runAsync(() => tester.tap(find.text('Create shop')));
    await settleIo(tester);
    expect(find.text('Shop login'), findsOneWidget);
    await enter(tester, 'Username or email', 'owner@example.com');
    await enter(tester, 'Password or PIN', 'owner-password');
    await tester.runAsync(() => tester.tap(find.text('Log in')));
    await settleIo(tester);
    await tester.runAsync(
      () => container.read(
        productListProvider((search: '', active: true)).future,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Neighbourhood Flour'), findsOneWidget);
    expect(find.text('Active products: 0'), findsOneWidget);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Log out'),
      200,
      scrollable: find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.runAsync(() => tester.tap(find.text('Log out')));
    await settleIo(tester);
    expect(find.text('Shop login'), findsOneWidget);
    expect(await tester.runAsync(store.shops.isConfigured), isTrue);
    expect(await tester.runAsync(store.auth.restore), isNull);
  });
  testWidgets('product form saves and details expose units and opening entry', (
    tester,
  ) async {
    final store = await tester.runAsync(() => TestStore.open());
    final container = await mount(tester, store!);
    addTearDown(() async {
      container.dispose();
      await store.close();
    });
    await tester.runAsync(
      () => container.read(
        productListProvider((search: '', active: true)).future,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage products'));
    await settleIo(tester);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Advanced options'), findsOneWidget);
    expect(find.text('SKU / code (optional)'), findsNothing);
    expect(find.text('Canonical base unit: gram'), findsNothing);
    await enter(tester, 'Product name', '1121 Sella');
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bag').last);
    await tester.pumpAndSettle();
    expect(find.text('1 Bag contains how many Kg?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '50');
    await tester.tap(find.text('Save unit'));
    await tester.pumpAndSettle();
    await enter(tester, 'Purchase price (PKR)', '2000.000000');
    await enter(tester, 'Sale price (PKR)', '300.000000');
    await enter(tester, 'Low stock alert (optional)', '20');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Save product'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.runAsync(() => tester.tap(find.text('Save product')));
    await settleIo(tester);
    expect(find.text('Product details'), findsOneWidget);
    expect(find.text('1121 Sella'), findsOneWidget);
    expect(find.text('Purchase price'), findsOneWidget);
    expect(find.textContaining('PKR 2,000 per kg'), findsOneWidget);
    expect(find.textContaining('PKR 300 per kg'), findsOneWidget);
    expect(find.text('Stock: 0 kg'), findsOneWidget);
    expect(find.text('Minimum alert: 20 kg'), findsOneWidget);
    expect(find.textContaining('Primary display unit:'), findsNothing);
    expect(find.textContaining('Default sale unit:'), findsNothing);
    expect(find.textContaining('1 kg = 1000 gram'), findsNothing);
    await tester.tap(find.text('Edit product'));
    await tester.pumpAndSettle();
    final priceInputs = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller?.text)
        .toList();
    expect(priceInputs, contains('2000'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('1 kg = 1000 gram'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Enter opening stock'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enter opening stock'));
    await tester.pumpAndSettle();
    expect(find.text('Reason / audit note'), findsNothing);
    expect(find.text('Opening value override (optional)'), findsNothing);
    expect(find.text('Advanced options'), findsOneWidget);
    expect(
      find.text(DateTime.now().toLocal().toString().split(' ').first),
      findsOneWidget,
    );
    await enter(tester, 'Opening quantity', '2');
    await tester.pump();
    expect(find.text('Estimated opening value: PKR 4000'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save opening stock'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.runAsync(() => tester.tap(find.text('Save opening stock')));
    await settleIo(tester);
    final products = await tester.runAsync(() => store.products.list());
    expect(products!.single.stockScaled, 2000000000);
    final saved = await tester.runAsync(
      () => store.products.details(products.single.id),
    );
    expect(saved!.opening!.valueMinor, 400000);
  });
  testWidgets(
    'editing tolerates duplicate kg unit rows and unique menu values',
    (tester) async {
      final store = await tester.runAsync(() => TestStore.open());
      final container = await mount(tester, store!);
      addTearDown(() async {
        container.dispose();
        await store.close();
      });
      final id = await tester.runAsync(
        () => store.products.save(TestStore.product()),
      );
      final existing = await tester.runAsync(() => store.products.details(id!));
      final duplicateKg = ProductDetails(
        product: existing!.product,
        units: [...existing.units, UnitConversion.kilograms()],
        prices: existing.prices,
        purchasePrice: existing.purchasePrice,
        salePrice: existing.salePrice,
        opening: existing.opening,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ProductEditorScreen(initial: duplicateKg)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit product'), findsOneWidget);
      final dropdowns = tester.widgetList<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdowns, isNotEmpty);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('unit-option:Purchase price (PKR):kg')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unit settings show compact whole ratios and preserve needed fractions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UnitConfigurationScreen(
            baseUnit: 'gram',
            requiredUnits: const {},
            units: [
              UnitConversion.kilograms(),
              UnitConversion(
                unitCode: 'bag',
                baseUnit: 'gram',
                numerator: 50000,
                denominator: 1,
              ),
              UnitConversion(
                unitCode: 'small bag',
                baseUnit: 'gram',
                numerator: 1,
                denominator: 2,
              ),
            ],
          ),
        ),
      );
      expect(find.text('1 kg = 1000 gram'), findsOneWidget);
      expect(find.text('1 bag = 50000 gram'), findsOneWidget);
      expect(find.text('1 small bag = 1/2 gram'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'configured shop restores login gate and renders narrow large-text layout',
    (tester) async {
      final store = await tester.runAsync(
        () => TestStore.open(loggedIn: false),
      );
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      final container = await mount(tester, store!);
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        container.dispose();
        await store.close();
      });
      expect(find.text('Shop login'), findsOneWidget);
      expect(find.text('Set up your shop'), findsNothing);
      expect(find.text('Preview as owner'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('recovered navigation opens contacts and trade screens', (
    tester,
  ) async {
    final store = await tester.runAsync(() => TestStore.open());
    final container = await mount(tester, store!);
    addTearDown(() async {
      container.dispose();
      await store.close();
    });
    for (final entry in {
      'Suppliers': 'Add supplier',
      'Customers': 'Add customer',
      'Purchases': 'New purchase',
      'Sales': 'New sale',
    }.entries) {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text(entry.key),
        ),
        150,
        scrollable: find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text(entry.key),
        ),
      );
      await settleIo(tester);
      expect(find.text(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'discounted sale pay-in-full posts through UI and displays retained receipt',
    (tester) async {
      final store = await tester.runAsync(() => TestStore.open());
      await tester.runAsync(
        () =>
            store!.products.save(TestStore.product(), opening: store.opening()),
      );
      final container = await mount(tester, store!);
      addTearDown(() async {
        container.dispose();
        await store.close();
      });
      final context = tester.element(find.text('Manage products'));
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const TradeEditor(TradeKind.sale),
        ),
      );
      await settleIo(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Walk-in Customer').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add item'));
      await settleIo(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Super Basmati').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Add to document'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Add to document'));
      await tester.pumpAndSettle();
      await enter(tester, 'Discount amount', '10');
      await tester.scrollUntilVisible(
        find.text('Pay in full'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Pay in full'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Paid amount'))
            .controller!
            .text,
        '250',
      );
      await tester.scrollUntilVisible(
        find.text('Post sale'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Post sale'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('Confirm')));
      await settleIo(tester);
      expect(find.text('Receipt / Invoice'), findsOneWidget);
      expect(find.textContaining('260.000000'), findsNothing);
      final rows = await tester.runAsync(
        () => LocalTradeRepository(
          store.db,
          store.auth,
        ).documents(TradeKind.sale),
      );
      expect(rows!.single['total_minor'], 25000);
      expect(rows.single['paid_minor'], 25000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('inventory filters balances and opens posted movement history', (
    tester,
  ) async {
    final store = await tester.runAsync(() => TestStore.open());
    await tester.runAsync(() async {
      await store!.products.save(
        TestStore.product(name: 'Stocked rice', sku: 'RICE', minimum: '50000'),
        opening: store.opening(quantity: '1'),
      );
      await store.products.save(
        TestStore.product(name: 'Empty rice', sku: 'EMPTY'),
      );
    });
    final container = await mount(tester, store!);
    addTearDown(() async {
      container.dispose();
      await store.close();
    });
    Navigator.of(tester.element(find.text('Manage products')))
        .pushReplacementNamed('/inventory');
    await settleIo(tester);
    expect(find.text('Stocked rice'), findsOneWidget);
    expect(find.text('Empty rice'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Out of stock'));
    await tester.pumpAndSettle();
    expect(find.text('Stocked rice'), findsNothing);
    expect(find.text('Empty rice'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Low stock'));
    await tester.pumpAndSettle();
    expect(find.text('Empty rice'), findsNothing);
    await tester.tap(find.text('Stocked rice'));
    await settleIo(tester);
    expect(find.text('Stock movements'), findsOneWidget);
    expect(find.text('Available: 50000.000000 gram'), findsOneWidget);
    expect(find.text('Entered: 1.000000 bag'), findsOneWidget);
    expect(find.text('opening stock'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cashier dashboard and navigation hide owner modules', (
    tester,
  ) async {
    final store = await tester.runAsync(() => TestStore.open());
    await tester.runAsync(() async {
      await LocalStaffRepository(
        store!.db,
        store.auth,
        store.hasher,
      ).create(name: 'Demo Cashier', username: 'cashier', password: '654321');
      await store.auth.login('cashier', '654321');
    });
    final container = await mount(tester, store!);
    addTearDown(() async {
      container.dispose();
      await store.close();
    });
    expect(find.text('Open sales'), findsOneWidget);
    expect(find.text('Manage products'), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Sales'), findsOneWidget);
    for (final label in [
      'Purchases',
      'Suppliers',
      'Settings',
      'Expenses',
      'Inventory',
    ]) {
      expect(find.text(label), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'client demo UI loads samples, settles both khatas, records expense and manages cashier',
    (tester) async {
      final store = await tester.runAsync(() => TestStore.open());
      final container = await mount(tester, store!);
      addTearDown(() async {
        container.dispose();
        await store.close();
      });
      final navigator = Navigator.of(
        tester.element(find.text('Manage products')),
      );
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const DemoScreen()),
      );
      await settleIo(tester);
      await tester.tap(find.text('Load demo data'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('Confirm')));
      await settleIo(tester);
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 15));
        while (find
                .text('Demo data is already loaded. It will not be duplicated.')
                .evaluate()
                .isEmpty &&
            DateTime.now().isBefore(deadline)) {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
      });
      await tester.pumpAndSettle();
      expect(
        find.text('Demo data is already loaded. It will not be duplicated.'),
        findsOneWidget,
      );
      navigator.pop();
      await settleIo(tester);
      for (final kind in [PartyKind.customer, PartyKind.supplier]) {
        final rows = await tester.runAsync(
          () => store.db.select(
            'SELECT id FROM ${kind.table} WHERE name LIKE ?',
            ['DEMO%'],
          ),
        );
        final id = rows!.single['id'] as String;
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => KhataScreen(kind, id)),
        );
        await settleIo(tester);
        await tester.tap(
          find.text(
            kind == PartyKind.customer ? 'Receive payment' : 'Pay supplier',
          ),
        );
        await tester.pumpAndSettle();
        await enter(tester, 'Payment amount', '10');
        await tester.scrollUntilVisible(
          find.text('Record payment'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Record payment'));
        await tester.pumpAndSettle();
        await tester.runAsync(() => tester.tap(find.text('Confirm')));
        await settleIo(tester);
        expect(find.text('${kind.label} khata'), findsOneWidget);
        final accounts = await tester.runAsync(
          () => LocalTradeRepository(store.db, store.auth).khata(kind, id),
        );
        expect(
          accounts!.single.balance,
          kind == PartyKind.customer ? 36000 : 1199000,
        );
        navigator.pop();
        await settleIo(tester);
      }
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const ExpenseEditor()),
      );
      await tester.pumpAndSettle();
      await enter(tester, 'Category', 'Utilities');
      await enter(tester, 'Description', 'Demo electricity');
      await enter(tester, 'Amount', '100');
      await tester.scrollUntilVisible(
        find.text('Post expense'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Post expense'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('Confirm')));
      await settleIo(tester);
      expect(
        await tester.runAsync(() => store.db.select('SELECT id FROM expenses')),
        hasLength(2),
      );
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const StaffScreen()),
      );
      await settleIo(tester);
      await tester.tap(find.text('Add cashier'));
      await tester.pumpAndSettle();
      await enter(tester, 'Staff name', 'Client Cashier');
      await enter(tester, 'Staff username', 'demo.cashier');
      await enter(tester, 'Staff password or PIN', '654321');
      await tester.scrollUntilVisible(
        find.text('Create cashier'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.runAsync(() => tester.tap(find.text('Create cashier')));
      await settleIo(tester);
      expect(find.text('Client Cashier'), findsOneWidget);
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('Confirm')));
      await settleIo(tester);
      expect(find.text('Reactivate'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('startup failures offer a non-destructive retry', (tester) async {
    var calls = 0;
    final store = await tester.runAsync(
      () => TestStore.open(configured: false),
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async {
          calls++;
          if (calls == 1) throw StateError('Unavailable');
          return store!.db;
        }),
        sessionVaultProvider.overrideWithValue(store!.vault),
        passwordHasherProvider.overrideWithValue(store.hasher),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await store.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ShopManagerApp(),
      ),
    );
    await settleIo(tester);
    expect(find.text('Retry'), findsOneWidget);
    // The visible Retry action must reopen storage without test intervention.
    await tester.tap(find.text('Retry'));
    await settleIo(tester);
    expect(find.text('Set up your shop'), findsOneWidget);
    expect(calls, 2);
    expect(
      await tester.runAsync(() => store.db.select('SELECT * FROM shops')),
      isEmpty,
    );
  });
}
