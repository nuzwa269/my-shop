import 'package:flutter/material.dart';

import '../../trade/domain/trade.dart';
import '../../trade/presentation/trade_screens.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});
  @override
  Widget build(BuildContext context) => const TradeListScreen(TradeKind.sale);
}
