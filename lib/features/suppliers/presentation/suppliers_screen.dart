import 'package:flutter/material.dart';

import '../../trade/domain/trade.dart';
import '../../trade/presentation/party_screens.dart';

class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const PartyListScreen(PartyKind.supplier);
}
