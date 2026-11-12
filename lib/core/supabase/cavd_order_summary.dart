import 'package:supabase_flutter/supabase_flutter.dart';

class CavdOrderSummary {
  const CavdOrderSummary(this.total, this.byStatus);

  final int total;
  final Map<String, int> byStatus;

  static Future<CavdOrderSummary> load() async {
    final data = await Supabase.instance.client.rpc('cavd_order_summary');
    final result = Map<String, dynamic>.from(data as Map);
    final counts = Map<String, dynamic>.from(result['by_status'] as Map);
    return CavdOrderSummary(
      (result['total'] as num).toInt(),
      counts.map((status, count) => MapEntry(status, (count as num).toInt())),
    );
  }
}
