import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manager/app.dart';
import 'package:shop_manager/database/database_provider.dart';
import 'package:shop_manager/features/auth/application/session_provider.dart';
import 'package:shop_manager/features/products/application/product_providers.dart';
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
    expect(find.text('Owner login'), findsOneWidget);
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
    expect(find.text('Owner login'), findsOneWidget);
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
    await enter(tester, 'Product / variety name', '1121 Sella');
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
    await tester.scrollUntilVisible(
      find.text('Enter opening stock'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enter opening stock'));
    await tester.pumpAndSettle();
    await enter(tester, 'Opening quantity', '2');
    await tester.scrollUntilVisible(
      find.text('Save opening stock'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.runAsync(() => tester.tap(find.text('Save opening stock')));
    await settleIo(tester);
    final products = await tester.runAsync(() => store.products.list());
    expect(products!.single.stockScaled, 2000000000);
  });
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
      expect(find.text('Owner login'), findsOneWidget);
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
        find.text(entry.key),
        150,
        scrollable: find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text(entry.key));
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
        '250.00',
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
