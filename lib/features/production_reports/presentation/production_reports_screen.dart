import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/production_report_repository.dart';

class ProductionReportsScreen extends StatefulWidget {
  const ProductionReportsScreen({super.key});

  @override
  State<ProductionReportsScreen> createState() =>
      _ProductionReportsScreenState();
}

class _ProductionReportsScreenState extends State<ProductionReportsScreen> {
  static const _orange = Color(0xFFE96B32);
  static const _darkBrown = Color(0xFF3D3029);
  static const _muted = Color(0xFF887A72);
  static const _border = Color(0xFFF0E5DE);

  final _repository = ProductionReportRepository(Supabase.instance.client);
  final _searchController = TextEditingController();
  final _workingRecordIds = <String>{};

  List<ProductionReport> _reports = const [];
  int _page = 0;
  int _totalCount = 0;
  int _requestId = 0;
  Timer? _searchDebounce;
  bool _checkingAccess = true;
  bool _authorized = false;
  bool _loading = false;
  String? _error;
  String _reviewFilter = 'all';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAccessAndLoad() async {
    try {
      final isAdmin = await _repository.currentUserIsAdmin();
      if (!mounted) return;
      setState(() {
        _authorized = isAdmin;
        _checkingAccess = false;
      });
      if (isAdmin) await _loadPage();
    } catch (error) {
      debugPrint('PRODUCTION REPORT ACCESS CHECK ERROR: $error');
      if (!mounted) return;
      setState(() {
        _checkingAccess = false;
        _error = 'Could not verify administrator access. Please retry.';
      });
    }
  }

  Future<void> _loadPage({int? page}) async {
    if (!_authorized) return;
    var nextPage = page ?? _page;
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      var result = await _repository.loadPage(
        page: nextPage,
        searchText: _searchController.text,
        reviewStatus: _reviewFilter,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      final lastPage = result.totalCount == 0
          ? 0
          : (result.totalCount - 1) ~/ productionReportPageSize;
      if (nextPage > lastPage) {
        nextPage = lastPage;
        result = await _repository.loadPage(
          page: nextPage,
          searchText: _searchController.text,
          reviewStatus: _reviewFilter,
          dateFrom: _dateFrom,
          dateTo: _dateTo,
        );
      }
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _reports = result.reports;
        _totalCount = result.totalCount;
        _page = nextPage;
      });
    } catch (error) {
      debugPrint('PRODUCTION REPORT LOAD ERROR: $error');
      if (!mounted || requestId != _requestId) return;
      setState(
        () => _error =
            'Production reports could not be loaded. Check your connection and permissions, then retry.',
      );
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  void _onSearchChanged(String _) {
    // Invalidate any request for the previous term while the debounce runs.
    _requestId++;
    setState(() => _page = 0);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadPage(page: 0),
    );
  }

  Future<void> _pickDate({required bool startDate}) async {
    final initialDate = startDate
        ? (_dateFrom ?? _dateTo ?? DateTime.now())
        : (_dateTo ?? _dateFrom ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: startDate ? 'Filter from date' : 'Filter through date',
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (startDate) {
        _dateFrom = picked;
        if (_dateTo != null && _dateTo!.isBefore(picked)) _dateTo = picked;
      } else {
        _dateTo = picked;
        if (_dateFrom != null && _dateFrom!.isAfter(picked)) {
          _dateFrom = picked;
        }
      }
      _page = 0;
    });
    await _loadPage(page: 0);
  }

  Future<void> _clearDates() async {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
      _page = 0;
    });
    await _loadPage(page: 0);
  }

  Future<void> _openDetails(ProductionReport report) async {
    final reviewed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ProductionReportDetailsDialog(
        report: report,
        repository: _repository,
        onReview: (status) => _confirmAndSubmitReview(report, status),
      ),
    );
    if (reviewed == true && mounted) await _loadPage();
  }

  Future<bool> _confirmAndSubmitReview(
    ProductionReport report,
    String status,
  ) async {
    if (_workingRecordIds.contains(report.id)) return false;
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ReviewNoteDialog(status: status),
    );
    if (note == null || !mounted) return false;

    setState(() => _workingRecordIds.add(report.id));
    try {
      await _repository.submitReview(
        recordId: report.id,
        status: status,
        note: note.isEmpty ? null : note,
      );
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review marked ${_statusLabel(status)}.')),
      );
      return true;
    } catch (error) {
      debugPrint('PRODUCTION REPORT REVIEW RPC ERROR: $error');
      if (mounted) {
        final message = error.toString().contains('not_allowed')
            ? 'Your account is not authorized to review production reports.'
            : error.toString().contains('production_record_not_complete')
            ? 'Only completed production reports can be reviewed.'
            : 'The review could not be saved. Refresh and check its current status before retrying.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return false;
    } finally {
      if (mounted) setState(() => _workingRecordIds.remove(report.id));
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'verified':
        return 'Verified';
      case 'needs_correction':
        return 'Needs Correction';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  static String _formatDate(dynamic raw, {bool includeTime = false}) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    if (parsed == null) return 'Date unavailable';
    final value = parsed.toLocal();
    final date =
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.day.toString().padLeft(2, '0')}/${value.year}';
    if (!includeTime) return date;
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final meridiem = value.hour < 12 ? 'AM' : 'PM';
    return '$date · $hour:$minute $meridiem';
  }

  Widget _dateButton(String label, DateTime? value, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : onPressed,
      icon: const Icon(Icons.calendar_today_outlined, size: 17),
      label: Text(value == null ? label : _formatDate(value)),
      style: OutlinedButton.styleFrom(foregroundColor: _darkBrown),
    );
  }

  Widget _filters() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 270,
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search all completed reports',
              prefixIcon: const Icon(Icons.search, color: _muted),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border),
              ),
            ),
          ),
        ),
        DropdownButton<String>(
          value: _reviewFilter,
          onChanged: _loading
              ? null
              : (value) {
                  if (value != null) {
                    setState(() {
                      _reviewFilter = value;
                      _page = 0;
                    });
                    _loadPage(page: 0);
                  }
                },
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All review statuses')),
            DropdownMenuItem(value: 'pending', child: Text('Pending')),
            DropdownMenuItem(value: 'verified', child: Text('Verified')),
            DropdownMenuItem(
              value: 'needs_correction',
              child: Text('Needs Correction'),
            ),
            DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
          ],
        ),
        _dateButton('From date', _dateFrom, () => _pickDate(startDate: true)),
        _dateButton('Through date', _dateTo, () => _pickDate(startDate: false)),
        if (_dateFrom != null || _dateTo != null)
          TextButton.icon(
            onPressed: _loading ? null : _clearDates,
            icon: const Icon(Icons.clear),
            label: const Text('Clear dates'),
          ),
      ],
    );
  }

  Widget _quantitySummary(ProductionReport report) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final entry in productionReportSizes.entries)
          _QuantityChip(
            label: entry.value,
            value: report.record['qty_${entry.key}'],
          ),
      ],
    );
  }

  Widget _reportCard(ProductionReport report) {
    final reviewDate = report.reviewedAt;
    final busy = _workingRecordIds.contains(report.id);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _formatDate(report.record['collection_date']),
                  style: const TextStyle(
                    color: _darkBrown,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _StatusBadge(status: report.reviewStatus),
                const _CompletedBadge(),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              report.farmName,
              style: const TextStyle(
                color: _darkBrown,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${report.sellerName} · ${report.locationLabel}',
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            _quantitySummary(report),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    reviewDate == null
                        ? 'No review recorded'
                        : 'Reviewed ${_formatDate(reviewDate, includeTime: true)}',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _openDetails(report),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View report'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    if (_checkingAccess) {
      return const Center(child: CircularProgressIndicator(color: _orange));
    }
    if (!_authorized) {
      return const _MessagePanel(
        icon: Icons.lock_outline,
        title: 'Administrator access required',
        message: 'Sign in with an authorized CAVD administrator account.',
      );
    }
    if (_loading && _reports.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _orange));
    }
    if (_error != null && _reports.isEmpty) {
      return _MessagePanel(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load production reports',
        message: _error!,
        action: FilledButton.icon(
          onPressed: _loading ? null : () => _loadPage(),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }

    return Column(
      children: [
        if (_loading) const LinearProgressIndicator(color: _orange),
        if (_error != null)
          MaterialBanner(
            content: Text(_error!),
            actions: [
              TextButton(onPressed: _loadPage, child: const Text('Retry')),
            ],
          ),
        Expanded(
          child: _reports.isEmpty
              ? _MessagePanel(
                  icon: Icons.inventory_2_outlined,
                  title: 'No reports match these filters',
                  message: 'Try another search, review status, or date range.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(top: 14, bottom: 12),
                  itemCount: _reports.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 3),
                  itemBuilder: (context, index) => _reportCard(_reports[index]),
                ),
        ),
        _pagination(),
      ],
    );
  }

  Widget _pagination() {
    final pageCount = (_totalCount / productionReportPageSize).ceil();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            _totalCount == 0
                ? '0 reports'
                : '$_totalCount reports · Page ${_page + 1} of $pageCount',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _loading || _page == 0
                ? null
                : () => _loadPage(page: _page - 1),
            icon: const Icon(Icons.chevron_left),
            label: const Text('Previous'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _loading || _page + 1 >= pageCount
                ? null
                : () => _loadPage(page: _page + 1),
            icon: const Icon(Icons.chevron_right),
            label: const Text('Next'),
            iconAlignment: IconAlignment.end,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Production Reports',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: _darkBrown,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Review completed harvest submissions from GeoEgg sellers.',
                      style: TextStyle(fontSize: 14, color: _muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh reports',
                onPressed: _loading || !_authorized ? null : _loadPage,
                icon: const Icon(Icons.refresh, color: _orange),
              ),
            ],
          ),
          const SizedBox(height: 19),
          _filters(),
          const SizedBox(height: 7),
          const Text(
            'Search, review status, and date filters apply across all matching completed reports.',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
          const SizedBox(height: 12),
          Expanded(child: _content()),
        ],
      ),
    );
  }
}

class _ProductionReportDetailsDialog extends StatefulWidget {
  const _ProductionReportDetailsDialog({
    required this.report,
    required this.repository,
    required this.onReview,
  });

  final ProductionReport report;
  final ProductionReportRepository repository;
  final Future<bool> Function(String status) onReview;

  @override
  State<_ProductionReportDetailsDialog> createState() =>
      _ProductionReportDetailsDialogState();
}

class _ProductionReportDetailsDialogState
    extends State<_ProductionReportDetailsDialog> {
  static const _orange = Color(0xFFE96B32);
  static const _darkBrown = Color(0xFF3D3029);
  static const _muted = Color(0xFF887A72);

  late final Future<List<Map<String, dynamic>>> _history = widget.repository
      .loadHistory(widget.report.id);
  bool _reviewing = false;

  Future<void> _review(String status) async {
    if (_reviewing) return;
    setState(() => _reviewing = true);
    try {
      final saved = await widget.onReview(status);
      if (saved && mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  String _number(dynamic value) => value?.toString() ?? '0';

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final record = report.record;
    final width = MediaQuery.sizeOf(context).width;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      title: Row(
        children: [
          const Expanded(
            child: Text(
              'Production report details',
              style: TextStyle(color: _darkBrown, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: width < 700 ? width * .88 : 650,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusBadge(status: report.reviewStatus),
                  const _CompletedBadge(),
                ],
              ),
              const SizedBox(height: 16),
              _sectionTitle('Seller and farm'),
              _detail('Seller', report.sellerName),
              _detail('Email', _value(report.seller['email'])),
              _detail('Contact', _value(report.seller['contact_number'])),
              _detail('Farm', report.farmName),
              _detail('Farm owner', _value(report.farm['owner_name'])),
              const SizedBox(height: 12),
              _sectionTitle('Collection'),
              _detail(
                'Collection date',
                _formatDate(record['collection_date'])
              ),
              _detail('Location', _value(record['location_name'])),
              _detail('Current location', _value(report.location['name'])),
              _detail('Area', report.locationLabel),
              _detail('Address', _value(report.location['address'])),
              _detail(
                'Confirmed at',
                record['confirmed_at'] == null
                    ? 'Not available'
                    : _formatDate(record['confirmed_at'], includeTime: true),
              ),
              const SizedBox(height: 12),
              _sectionTitle('Collected and damaged quantities'),
              for (final size in productionReportSizes.entries)
                _detail(
                  size.value,
                  '${_number(record['qty_${size.key}'])} collected · '
                  '${_number(record['damaged_${size.key}'])} damaged',
                ),
              const SizedBox(height: 12),
              _sectionTitle('Recorded weights (kg)'),
              for (final size in productionReportSizes.entries)
                _detail(
                  size.value,
                  _value(record['weight_${size.key}_kg'], 'Not recorded'),
                ),
              const SizedBox(height: 12),
              _sectionTitle('Current review'),
              _detail('Status', _statusLabel(report.reviewStatus)),
              _detail('Review note', _value(report.review?['review_note'])),
              _detail(
                'Reviewed at',
                report.reviewedAt == null
                    ? 'Pending'
                    : _formatDate(report.reviewedAt, includeTime: true),
              ),
              _detail('Reviewer', _reviewerName(report)),
              const SizedBox(height: 12),
              _sectionTitle('Review history'),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _history,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: CircularProgressIndicator(color: _orange),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Text(
                      'Review history could not be loaded.',
                      style: TextStyle(color: _muted),
                    );
                  }
                  final history = snapshot.data ?? const [];
                  if (history.isEmpty) {
                    return const Text(
                      'No review history yet.',
                      style: TextStyle(color: _muted),
                    );
                  }
                  return Column(
                    children: [
                      for (final entry in history)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _StatusBadge(
                                status: entry['review_status'].toString(),
                              ),
                              Text(
                                _formatDate(
                                  entry['reviewed_at'],
                                  includeTime: true,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              'By ${entry['reviewer_name']}\n'
                              '${_value(entry['review_note'], 'No note')}',
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (_reviewing)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else ...[
          OutlinedButton.icon(
            onPressed: () => _review('rejected'),
            icon: const Icon(Icons.block_outlined),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC34D4D),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _review('needs_correction'),
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('Needs Correction'),
          ),
          FilledButton.icon(
            onPressed: () => _review('verified'),
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Verify'),
            style: FilledButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      title,
      style: const TextStyle(
        color: _darkBrown,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    ),
  );

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 135,
          child: Text(label, style: const TextStyle(color: _muted)),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(color: _darkBrown),
          ),
        ),
      ],
    ),
  );

  String _reviewerName(ProductionReport report) {
    final reviewerId = report.review?['reviewed_by'];
    if (reviewerId == null) return 'Pending';
    return _value(report.reviewer['name'], reviewerId.toString());
  }

  String _value(dynamic value, [String fallback = 'Not provided']) {
    if (value == null || value.toString().trim().isEmpty) return fallback;
    return value.toString();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'verified':
        return 'Verified';
      case 'needs_correction':
        return 'Needs Correction';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  String _formatDate(dynamic raw, {bool includeTime = false}) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    if (parsed == null) return 'Date unavailable';
    final value = parsed.toLocal();
    final date =
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.day.toString().padLeft(2, '0')}/${value.year}';
    if (!includeTime) return date;
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$date · $hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
  }
}

class _ReviewNoteDialog extends StatefulWidget {
  const _ReviewNoteDialog({required this.status});

  final String status;

  @override
  State<_ReviewNoteDialog> createState() => _ReviewNoteDialogState();
}

class _ReviewNoteDialogState extends State<_ReviewNoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Confirm ${_statusLabel(widget.status)}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will record the report as ${_statusLabel(widget.status)}.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 2000,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Review note (optional)',
              hintText: 'Add context for the seller and review history.',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _controller.text.runes.length > 2000
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text('Confirm ${_statusLabel(widget.status)}'),
        ),
      ],
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'verified':
        return 'Verification';
      case 'needs_correction':
        return 'Needs Correction';
      default:
        return 'Rejection';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      'verified' => (
        'Verified',
        const Color(0xFF287A50),
        const Color(0xFFE4F3EA),
      ),
      'needs_correction' => (
        'Needs Correction',
        const Color(0xFF9B6413),
        const Color(0xFFFFF1D8),
      ),
      'rejected' => (
        'Rejected',
        const Color(0xFFB43D3D),
        const Color(0xFFFBE7E5),
      ),
      _ => ('Pending', const Color(0xFF866D5E), const Color(0xFFF2EDE9)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CompletedBadge extends StatelessWidget {
  const _CompletedBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF1F7),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      'Completed',
      style: TextStyle(
        color: Color(0xFF45657F),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _QuantityChip extends StatelessWidget {
  const _QuantityChip({required this.label, required this.value});

  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8F4),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFF0E5DE)),
    ),
    child: Text(
      '$label  ${value ?? 0}',
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF3D3029),
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 46, color: const Color(0xFFE96B32)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D3029),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF887A72)),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}
