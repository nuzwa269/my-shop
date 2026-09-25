import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manager/core/permissions/permissions.dart';
import 'package:shop_manager/core/validation/validation.dart';
import 'package:shop_manager/features/auth/data/local_auth_repository.dart';
import 'package:shop_manager/features/auth/data/password_hasher.dart';
import 'package:shop_manager/features/settings/domain/shop_setup.dart';

import '../support/test_store.dart';

void main() {
  group('Production password hasher', () {
    test(
      'random salts, versioned work factor and constant-length verifiers',
      () async {
        const hasher = Pbkdf2PasswordHasher();
        final first = await hasher.hash('a-long-owner-password');
        final second = await hasher.hash('a-long-owner-password');
        expect(first, startsWith('pbkdf2-sha256:v1:600000:'));
        expect(first, isNot(second));
        expect(first, isNot(contains('a-long-owner-password')));
        expect(base64Decode(first.split(':')[3]), hasLength(16));
        expect(base64Decode(first.split(':')[4]), hasLength(32));
        expect(await hasher.verify('a-long-owner-password', first), isTrue);
        expect(await hasher.verify('wrong-password', first), isFalse);
        expect(await hasher.verify('password', 'broken'), isFalse);
        expect(
          await hasher.verify('password', first.replaceFirst('600000', '1')),
          isFalse,
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
    test('PBKDF2 SHA-256 known vector', () async {
      final bytes = await Pbkdf2PasswordHasher.derive(
        'password',
        utf8.encode('salt'),
        1,
      );
      expect(
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });
  });
  group('Setup and local owner auth', () {
    late TestStore store;
    setUp(() async {
      store = await TestStore.open(configured: false);
    });
    tearDown(() => store.close());
    test(
      'one-time setup persists shop, owner, credentials and marker atomically',
      () async {
        expect(await store.shops.isConfigured(), isFalse);
        await store.shops.setup(TestStore.setupInput);
        expect(await store.shops.isConfigured(), isTrue);
        final shop = (await store.db.select('SELECT * FROM shops')).single;
        expect(shop['country'], 'Pakistan');
        expect(shop['phone'], '03001234567');
        expect(shop['business_category'], 'Flour Shop');
        final user = (await store.db.select('SELECT * FROM users')).single;
        expect(user['role'], 'owner');
        expect(user['status'], 'active');
        final credential = (await store.db.select(
          'SELECT * FROM owner_credentials',
        )).single;
        expect(
          credential['password_hash'],
          isNot(TestStore.setupInput.password),
        );
        expect(
          await store.db.select(
            "SELECT * FROM settings WHERE key='setup_complete'",
          ),
          hasLength(1),
        );
        expect(
          await store.db.select('SELECT * FROM audit_events'),
          hasLength(1),
        );
        await expectLater(
          store.shops.setup(TestStore.setupInput),
          throwsA(isA<ValidationException>()),
        );
        expect(await store.db.select('SELECT * FROM shops'), hasLength(1));
      },
    );
    test('invalid setup leaves no partial shop or account', () async {
      await expectLater(
        store.shops.setup(
          const ShopSetupInput(
            shopName: '',
            ownerName: 'Owner',
            category: 'Other',
            currencyCode: 'PKR',
            minorDigits: 2,
            country: 'Pakistan',
            username: 'owner',
            password: '123456',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(await store.db.select('SELECT * FROM shops'), isEmpty);
      expect(
        () => Validation.password('123'),
        throwsA(isA<ValidationException>()),
      );
      expect(() => Validation.password('123456'), returnsNormally);
      expect(() => Validation.password('long passphrase'), returnsNormally);
    });
    test('login, restore, token hashing and logout work without plaintext session storage', () async {
      await store.shops.setup(TestStore.setupInput);
      await expectLater(
        store.auth.login('owner@example.com', 'wrong'),
        throwsA(isA<ValidationException>()),
      );
      final session = await store.auth.login(
        'OWNER@example.com',
        'owner-password',
      );
      expect(session.fullName, 'Aisha Owner');
      expect(session.role, ShopRole.owner);
      final stored = (await store.db.select(
        "SELECT * FROM local_sessions WHERE status='active'",
      )).single;
      expect(stored['token_hash'], isNot(store.vault.token));
      final newRepository = LocalAuthRepository(
        store.db,
        store.hasher,
        store.vault,
        clock: store.clock,
      );
      expect((await newRepository.restore())!.userId, session.userId);
      await store.auth.logout();
      expect(await newRepository.restore(), isNull);
      expect(store.vault.token, isNull);
      await expectLater(
        store.products.list(),
        throwsA(isA<ValidationException>()),
      );
      expect(
        (await store.db.select('SELECT status FROM local_sessions'))
            .single['status'],
        'revoked',
      );
    });
    test(
      'lockout persists, expires, and successful login resets attempts',
      () async {
        await store.shops.setup(TestStore.setupInput);
        for (var i = 0; i < 5; i++) {
          await expectLater(
            store.auth.login('owner@example.com', 'wrong'),
            throwsA(isA<ValidationException>()),
          );
        }
        await expectLater(
          store.auth.login('owner@example.com', 'owner-password'),
          throwsA(isA<ValidationException>()),
        );
        store.offset += const Duration(minutes: 2).inMilliseconds;
        await store.auth.login('owner@example.com', 'owner-password');
        expect(
          (await store.db.select(
            'SELECT failed_attempts FROM owner_credentials',
          )).single['failed_attempts'],
          0,
        );
      },
    );
    test('expired or inactive sessions cannot authorize data access', () async {
      await store.shops.setup(TestStore.setupInput);
      final user = await store.auth.login(
        'owner@example.com',
        'owner-password',
      );
      store.offset += const Duration(hours: 13).inMilliseconds;
      expect(await store.auth.restore(), isNull);
      await expectLater(
        store.products.save(TestStore.product()),
        throwsA(isA<ValidationException>()),
      );
      store.offset = 0;
      await store.db.execute("UPDATE users SET status='archived' WHERE id=?", [
        user.userId,
      ]);
      expect(await store.auth.restore(), isNull);
    });
  });
}
