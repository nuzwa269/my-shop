import 'package:flutter/material.dart';

import '../../trade/domain/trade.dart';
import '../../trade/presentation/trade_screens.dart';

class PurchasesScreen extends StatelessWidget {
  const PurchasesScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const TradeListScreen(TradeKind.purchase);
}
