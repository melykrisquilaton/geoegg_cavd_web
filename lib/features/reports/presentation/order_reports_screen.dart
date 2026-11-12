import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderReportsScreen extends StatefulWidget {
  const OrderReportsScreen({super.key});

  @override
  State<OrderReportsScreen> createState() => _OrderReportsScreenState();
}

class _OrderReportsScreenState extends State<OrderReportsScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  bool _hasMore = false;
  bool _updating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final last = more ? _reports.last : null;
      final result = await _client.rpc('cavd_order_reports', params: {
        'p_before': last?['created_at'],
        'p_before_id': last?['id'],
      });
      if (!mounted) return;
      final rows = (result as List).cast<Map<String, dynamic>>();
      setState(() {
        _reports = more ? [..._reports, ...rows] : rows;
        _hasMore = rows.length == 25;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load reports. Refresh to retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(Map<String, dynamic> report) async {
    setState(() => _updating = true);
    try {
      final closing = report['status'] == 'under_review';
      final outcome = closing
          ? await showDialog<String>(
              context: context, builder: (_) => const _CloseReportDialog(),
            )
          : null;
      if (!mounted || (closing && outcome == null)) return;
      await _client.rpc('review_order_report', params: {
        'p_report_id': report['id'],
        'p_status': closing ? 'closed' : 'under_review',
        'p_outcome': outcome,
      });
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this report. Refresh to check its current status.')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  static const _reasons = {
    'price_mismatch': 'Price mismatch',
    'stock_unavailable': 'Eggs unavailable',
    'seller_no_show': 'Seller no-show',
    'other': 'Other',
  };

  static const _statuses = {
    'submitted': 'Submitted',
    'under_review': 'Under review',
    'closed': 'Closed',
  };

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            title: const Text('Private order reports'),
            subtitle: const Text('Buyer complaints submitted to CAVD'),
            trailing: IconButton(
              tooltip: 'Refresh reports',
              onPressed: _loading || _updating ? null : () => _load(),
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ListTile(title: Text(_error!)),
          if (!_loading && _error == null && _reports.isEmpty)
            const ListTile(title: Text('No reports submitted.')),
          for (final report in _reports)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_reasons[report['reason']]} · ${_statuses[report['status']]}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('Seller: ${report['seller_name']}'),
                    SelectableText('Seller ID: ${report['seller_id']}'),
                    SelectableText('Order reference: ${report['order_id']}'),
                    const SizedBox(height: 8),
                    Text(report['description'] as String),
                    if (report['outcome'] case final String outcome)
                      Text('Outcome shared with buyer: $outcome'),
                    if (report['status'] != 'closed')
                      TextButton(
                        onPressed: _updating || _loading ? null : () => _review(report),
                        child: Text(report['status'] == 'submitted' ? 'Start review' : 'Close report'),
                      ),
                  ],
                ),
              ),
            ),
          if (_hasMore)
            TextButton(
              onPressed: _loading || _updating ? null : () => _load(more: true),
              child: const Text('Load older reports'),
            ),
        ],
      );
}

class _CloseReportDialog extends StatefulWidget {
  const _CloseReportDialog();

  @override
  State<_CloseReportDialog> createState() => _CloseReportDialogState();
}

class _CloseReportDialogState extends State<_CloseReportDialog> {
  final _outcome = TextEditingController();

  @override
  void dispose() {
    _outcome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Close report'),
        content: TextField(
          controller: _outcome,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Optional outcome visible to the buyer',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, _outcome.text.trim()),
            child: const Text('Close report'),
          ),
        ],
      );
}
