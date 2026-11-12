import 'dart:async';
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Stream<List<Map<String, dynamic>>> ordersWithItems() {
  return Stream<List<Map<String, dynamic>>>.multi((controller) {
    final itemsByOrder = <String, List<Map<String, dynamic>>>{};

    final orders = supabase.from('orders').stream(primaryKey: ['id']);

    late final StreamSubscription<List<Map<String, dynamic>>> subscription;

    subscription = orders.listen(
      (rows) {
        subscription.pause();

        _attachItems(rows, itemsByOrder)
            .then(controller.add, onError: controller.addError)
            .whenComplete(subscription.resume);
      },
      onError: controller.addError,
      onDone: controller.close,
    );

    controller.onCancel = subscription.cancel;
  });
}

Future<List<Map<String, dynamic>>> _attachItems(
  List<Map<String, dynamic>> orders,
  Map<String, List<Map<String, dynamic>>> itemsByOrder,
) async {
  final missing = [
    for (final order in orders)
      if (!itemsByOrder.containsKey(order['id'].toString()))
        order['id'].toString(),
  ];

  const groupSize = 100;

  for (var start = 0; start < missing.length; start += groupSize) {
    final group = missing.sublist(
      start,
      math.min(start + groupSize, missing.length),
    );

    final items = await supabase
        .from('order_items')
        .select()
        .inFilter('order_id', group);

    for (final item in items) {
      final orderId = item['order_id'].toString();

      itemsByOrder.putIfAbsent(orderId, () => []);
      itemsByOrder[orderId]!.add(
        Map<String, dynamic>.from(item),
      );
    }

    for (final orderId in group) {
      itemsByOrder.putIfAbsent(orderId, () => []);
    }
  }

  return orders.map((order) {
    return <String, dynamic>{
      ...order,
      'items': itemsByOrder[order['id'].toString()] ?? [],
    };
  }).toList();
}