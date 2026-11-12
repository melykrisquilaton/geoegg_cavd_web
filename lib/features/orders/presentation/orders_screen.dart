import 'package:flutter/material.dart';
import 'package:geoegg_cavd_web/core/widgets/cavd_order_report.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key, this.initialFilter = 'all'});

  final String initialFilter;

  @override
  Widget build(BuildContext context) =>
      CavdOrderReport(pendingOnly: initialFilter == 'pending');
}
