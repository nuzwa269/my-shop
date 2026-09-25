import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/form_support.dart';
import '../../auth/application/session_provider.dart';
import '../domain/shop_setup.dart';

class ShopSetupScreen extends ConsumerStatefulWidget {
  const ShopSetupScreen({super.key});
  @override
  ConsumerState<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends ConsumerState<ShopSetupScreen> {
  final shop = TextEditingController(),
      owner = TextEditingController(),
      customCategory = TextEditingController(),
      currency = TextEditingController(text: 'PKR'),
      digits = TextEditingController(text: '2'),
      country = TextEditingController(text: 'Pakistan'),
      phone = TextEditingController(),
      address = TextEditingController(),
      username = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  String category = 'Rice Shop';
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in [
      shop,
      owner,
      customCategory,
      currency,
      digits,
      country,
      phone,
      address,
      username,
      password,
      confirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (password.text != confirm.text) {
        setState(() => error = 'Passwords/PINs do not match.');
        return;
      }
      await ref
          .read(sessionProvider.notifier)
          .setup(
            ShopSetupInput(
              shopName: shop.text,
              ownerName: owner.text,
              category: category == 'Other' ? customCategory.text : category,
              currencyCode: currency.text,
              minorDigits: int.tryParse(digits.text) ?? -1,
              country: country.text,
              username: username.text,
              password: password.text,
              phone: phone.text,
              address: address.text,
            ),
          );
    } catch (e) {
      if (mounted) setState(() => error = actionError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Set up your shop')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AbsorbPointer(
            absorbing: busy,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('Create your shop and local owner account.'),
                const SizedBox(height: 20),
                EntryField(shop, 'Shop name'),
                EntryField(owner, 'Owner full name'),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Business category',
                  ),
                  items:
                      [
                            'Rice Shop',
                            'Flour Shop',
                            'Wheat Shop',
                            'Spice Shop',
                            'Other',
                          ]
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => category = v!),
                ),
                const SizedBox(height: 16),
                if (category == 'Other')
                  EntryField(customCategory, 'Custom category'),
                EntryField(
                  currency,
                  'Currency code',
                  hint: 'For example PKR, USD, AED',
                ),
                EntryField(
                  digits,
                  'Currency decimal places',
                  numeric: true,
                  hint: 'PKR uses 2; other currencies require their correct scale.',
                ),
                EntryField(country, 'Country'),
                EntryField(phone, 'Phone (optional)'),
                EntryField(address, 'Address (optional)', lines: 2),
                const Divider(height: 32),
                Text(
                  'Owner account',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                EntryField(username, 'Username or email'),
                EntryField(
                  password,
                  'Password or PIN',
                  obscure: true,
                  hint: '6–12 digit PIN or 12–128 character password',
                ),
                EntryField(confirm, 'Confirm password or PIN', obscure: true),
                ErrorNotice(error),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Text(busy ? 'Creating shop…' : 'Create shop'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Keep your password/PIN safe. Recovery is not available in this phase.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
