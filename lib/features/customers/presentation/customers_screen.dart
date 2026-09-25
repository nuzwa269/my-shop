import 'package:flutter/material.dart';

import '../../trade/domain/trade.dart';
import '../../trade/presentation/party_screens.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const PartyListScreen(PartyKind.customer);
}
