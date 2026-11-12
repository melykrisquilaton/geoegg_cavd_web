import 'package:flutter/material.dart';
import 'package:geoegg_cavd_web/core/supabase/cavd_order_summary.dart';

class CavdOrderReport extends StatefulWidget {
  const CavdOrderReport({super.key, this.pendingOnly = false});

  final bool pendingOnly;

  @override
  State<CavdOrderReport> createState() => _CavdOrderReportState();
}

class _CavdOrderReportState extends State<CavdOrderReport> {
  late Future<CavdOrderSummary> _summary = CavdOrderSummary.load();
  late bool _pendingOnly = widget.pendingOnly;

  static const _statuses = {
    'pending': 'Pending',
    'accepted': 'Accepted',
    'preparing': 'Preparing',
    'ready_for_pickup': 'Ready for pickup',
    'out_for_delivery': 'Out for delivery',
    'completed': 'Completed',
    'rejected': 'Rejected',
    'cancelled': 'Cancelled',
    'expired': 'Expired',
  };

  void _refresh() => setState(() => _summary = CavdOrderSummary.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CavdOrderSummary>(
      future: _summary,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: FilledButton(
              onPressed: _refresh,
              child: const Text('Could not load counts. Retry'),
            ),
          );
        }
        final summary = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              title: const Text('Marketplace order summary'),
              subtitle: const Text('Counts across all GeoEgg orders'),
              trailing: IconButton(
                tooltip: 'Refresh order counts',
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
              ),
            ),
            ListTile(
              title: const Text('Total orders'),
              trailing: Text(summary.total.toString()),
            ),
            SwitchListTile(
              title: const Text('Show pending only'),
              value: _pendingOnly,
              onChanged: (value) => setState(() => _pendingOnly = value),
            ),
            for (final status in _statuses.entries)
              if (!_pendingOnly || status.key == 'pending')
                ListTile(
                  title: Text(status.value),
                  trailing: Text((summary.byStatus[status.key] ?? 0).toString()),
                ),
          ],
        );
      },
    );
  }
}
