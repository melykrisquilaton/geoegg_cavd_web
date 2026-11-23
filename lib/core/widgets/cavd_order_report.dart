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

  static const _statusColors = {
    'pending': Color(0xFFE96B32),
    'accepted': Color(0xFF4F8A5B),
    'preparing': Color(0xFF7A68A6),
    'ready_for_pickup': Color(0xFF398A83),
    'out_for_delivery': Color(0xFF5476A8),
    'completed': Color(0xFF4F8A5B),
    'rejected': Color(0xFFC65C53),
    'cancelled': Color(0xFF887A72),
    'expired': Color(0xFF887A72),
  };

  void _refresh() => setState(() => _summary = CavdOrderSummary.load());

  Widget _summaryCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0E5DE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF887A72),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$count',
                  style: const TextStyle(
                    color: Color(0xFF3D3029),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(String status, String label, int count) {
    final color = _statusColors[status]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0E5DE)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.circle, size: 12, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF3D3029),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

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
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final pagePadding = width < 560 ? 16.0 : 28.0;
            final summaryColumns = width < 600 ? 1 : 2;
            final statusColumns = width >= 1000
                ? 3
                : width >= 600
                    ? 2
                    : 1;
            final visibleStatuses = _statuses.entries.where(
              (status) => !_pendingOnly || status.key == 'pending',
            );

            return ListView(
              padding: EdgeInsets.all(pagePadding),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Marketplace order summary',
                            style: TextStyle(
                              color: Color(0xFF3D3029),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Counts across all GeoEgg orders',
                            style: TextStyle(
                              color: Color(0xFF887A72),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh order counts',
                      icon: const Icon(Icons.refresh),
                      onPressed: _refresh,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: summaryColumns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 105,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _summaryCard(
                      title: 'Total orders',
                      count: summary.total,
                      icon: Icons.receipt_long_outlined,
                      color: const Color(0xFFE96B32),
                    ),
                    _summaryCard(
                      title: 'Pending orders',
                      count: summary.byStatus['pending'] ?? 0,
                      icon: Icons.pending_actions_outlined,
                      color: const Color(0xFFE96B32),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF0E5DE)),
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 2,
                    ),
                    title: const Text(
                      'Show pending only',
                      style: TextStyle(
                        color: Color(0xFF3D3029),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: _pendingOnly,
                    activeThumbColor: const Color(0xFFE96B32),
                    onChanged: (value) =>
                        setState(() => _pendingOnly = value),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _pendingOnly ? 'Pending orders' : 'Orders by status',
                  style: const TextStyle(
                    color: Color(0xFF3D3029),
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: statusColumns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 72,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final status in visibleStatuses)
                      _statusCard(
                        status.key,
                        status.value,
                        summary.byStatus[status.key] ?? 0,
                      ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
