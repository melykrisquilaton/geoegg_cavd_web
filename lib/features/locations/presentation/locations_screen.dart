
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  static const peach = Color(0xFFFBE3D5);
  static const orange = Color(0xFFE96B32);
  static const darkBrown = Color(0xFF3D3029);
  static const muted = Color(0xFF887A72);
  static const borderColor = Color(0xFFF0E5DE);

  final supabase = Supabase.instance.client;

  String _section = 'applications';
  String _applicationFilter = 'pending';
  String _correctionFilter = 'pending';

  final Set<String> _processing = {};

  late final Stream<List<Map<String, dynamic>>> _locationsStream =
      supabase
          .from('locations')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false);

  late Future<List<Map<String, dynamic>>> _correctionsFuture =
    _loadCorrections();

  Future<List<Map<String, dynamic>>> _loadCorrections() async {
    final requests = await supabase
        .from('location_change_requests')
        .select(
          'id, location_id, barangay, address, contact_number, '
          'latitude, longitude, status, created_at, reviewed_at, '
          'rejection_reason',
        )
        .order('created_at', ascending: false);

    if (requests.isEmpty) return [];

    final locationIds = requests
        .map((request) => request['location_id'].toString())
        .toSet()
        .toList();

    final locations = await supabase
        .from('locations')
        .select(
          'id, name, type, barangay, address, contact_number, '
          'latitude, longitude',
        )
        .inFilter('id', locationIds);

    final locationsById = {
      for (final location in locations)
        location['id'].toString():
            Map<String, dynamic>.from(location),
    };

    return requests.map((request) {
      final correction = Map<String, dynamic>.from(request);

      correction['_current_location'] =
          locationsById[request['location_id'].toString()];

      return correction;
    }).toList();
  }

  void _refreshCorrections() {
    setState(() {
      _correctionsFuture = _loadCorrections();
    });
  }

  void _selectCorrectionFilter(String status) {
    setState(() {
      _correctionFilter = status;
    });
  }

  String _display(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'N/A';
    }
    return value.toString();
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) return 'Date unavailable';

    final local = date.toLocal();

    return '${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF38845B);
      case 'rejected':
        return const Color(0xFFC34D4D);
      case 'pending':
        return orange;
      default:
        return muted;
    }
  }

  String _statusLabel(String status) {
    if (status.isEmpty) return 'Unknown';

    return '${status[0].toUpperCase()}${status.substring(1)}';
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _sectionHeading(
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: darkBrown,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: muted,
          ),
        ),
      ],
    );
  }

  Widget _filterButton({
    required String label,
    required String value,
    required String selected,
    required int count,
    required VoidCallback onTap,
  }) {
    final isSelected = value == selected;

    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? peach : Colors.white,
          foregroundColor: isSelected ? orange : muted,
          side: BorderSide(
            color: isSelected ? orange : borderColor,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 12,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _sectionSelector() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _locationsStream,
      builder: (context, locationSnapshot) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _correctionsFuture,
          builder: (context, correctionSnapshot) {
            final applicationCount =
                locationSnapshot.data?.length ?? 0;

            final correctionCount =
                correctionSnapshot.data?.length ?? 0;

            return Wrap(
              spacing: 8,
              children: [
                _filterButton(
                  label: 'Applications',
                  value: 'applications',
                  selected: _section,
                  count: applicationCount,
                  onTap: () => setState(
                    () => _section = 'applications',
                  ),
                ),
                _filterButton(
                  label: 'Location Corrections',
                  value: 'corrections',
                  selected: _section,
                  count: correctionCount,
                  onTap: () => setState(
                    () => _section = 'corrections',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmLocationReview(
    String name,
    bool approve,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          approve ? 'Approve Location' : 'Reject Location',
        ),
        content: Text(
          approve
              ? 'Approve "$name" and make it active?'
              : 'Reject the registration for "$name"?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: orange,
              foregroundColor: Colors.white,
            ),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _reviewLocation(
    Map<String, dynamic> location,
    bool approve,
  ) async {
    final id = location['id'].toString();
    final name = location['name']?.toString() ?? 'Unnamed location';

    if (_processing.contains(id)) return;

    final confirmed = await _confirmLocationReview(name, approve);

    if (!confirmed || !mounted) return;

    setState(() => _processing.add(id));

    try {
      await supabase.rpc(
        'review_location',
        params: {
          'p_location_id': id,
          'p_approve': approve,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? '$name approved successfully.'
                : '$name rejected.',
          ),
        ),
      );
    } catch (error) {
      debugPrint('LOCATION REVIEW ERROR: $error');

      if (!mounted) return;

      final message = error.toString().contains('already_reviewed')
          ? 'This application has already been reviewed.'
          : error.toString().contains('not_allowed')
              ? 'Only CAVD administrators can review locations.'
              : 'Location review failed. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _processing.remove(id));
      }
    }
  }

  Future<String?> _askForRejectionReason() async {
    final controller = TextEditingController();
    String? errorText;

    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reject Correction'),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'Rejection reason',
                  hintText:
                      'Explain why this correction is being rejected.',
                  errorText: errorText,
                  alignLabelWithHint: true,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final reason = controller.text.trim();

                    if (reason.isEmpty || reason.length > 500) {
                      setDialogState(() {
                        errorText = reason.isEmpty
                            ? 'A rejection reason is required.'
                            : 'Maximum 500 characters allowed.';
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, reason);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit Rejection'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _reviewCorrection(
    Map<String, dynamic> correction,
    bool approve,
  ) async {
    final requestId = correction['id'].toString();

    if (_processing.contains(requestId)) return;

    setState(() => _processing.add(requestId));

    try {
      String? rejectionReason;

      if (approve) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Approve Correction'),
            content: const Text(
              'Approving this correction will update the existing '
              'location information visible to Buyers. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Approve Correction'),
              ),
            ],
          ),
        );

        if (confirmed != true || !mounted) return;
      } else {
        rejectionReason = await _askForRejectionReason();

        if (rejectionReason == null || !mounted) return;
      }

      try {
        await supabase.rpc(
          'review_location_change',
          params: {
            'p_request_id': requestId,
            'p_approve': approve,
            'p_rejection_reason': rejectionReason,
          },
        );
      } catch (error) {
        debugPrint('LOCATION CORRECTION RPC ERROR: $error');

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Review outcome could not be confirmed. '
              'Refresh the list and check its status before retrying.',
            ),
          ),
        );

        return;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Location correction approved successfully.'
                : 'Location correction rejected.',
          ),
        ),
      );

      _refreshCorrections();
    } finally {
      if (mounted) {
        setState(() => _processing.remove(requestId));
      }
    }
  }

  Widget _applicationCard(
    Map<String, dynamic> location,
  ) {
    final status = location['status']?.toString() ?? 'pending';
    final name = location['name']?.toString() ?? 'Unnamed location';
    final isFarm = location['type'] == 'farm';
    final busy = _processing.contains(location['id'].toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: peach,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  isFarm ? Icons.agriculture : Icons.storefront,
                  color: orange,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: darkBrown,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFarm ? 'Farm' : 'Selling Outlet',
                      style: const TextStyle(
                        color: muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(status),
            ],
          ),
          const Divider(height: 28),
          _infoRow('Barangay', location['barangay']),
          _infoRow('Address', location['address']),
          _infoRow('City', location['city']),
          _infoRow('Contact Number', location['contact_number']),
          _infoRow('Latitude', location['latitude']),
          _infoRow('Longitude', location['longitude']),
          _infoRow('Producer UID', location['producer_id']),
          if (status == 'pending') ...[
            const Divider(height: 25),
            if (busy)
              const Center(
                child: CircularProgressIndicator(color: orange),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _reviewLocation(location, false),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC34D4D),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _reviewLocation(location, true),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: const TextStyle(
                color: muted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _display(value),
              style: const TextStyle(
                color: darkBrown,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplications() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _locationsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('LOCATIONS STREAM ERROR: ${snapshot.error}');

          return _errorState(
            'Unable to load location applications.',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: orange),
          );
        }

        final allLocations = snapshot.data!;

        final pending = allLocations
            .where((item) => item['status'] == 'pending')
            .length;

        final approved = allLocations
            .where((item) => item['status'] == 'approved')
            .length;

        final rejected = allLocations
            .where((item) => item['status'] == 'rejected')
            .length;

        final locations = allLocations
            .where((item) => item['status'] == _applicationFilter)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              children: [
                _filterButton(
                  label: 'Pending',
                  value: 'pending',
                  selected: _applicationFilter,
                  count: pending,
                  onTap: () => setState(
                    () => _applicationFilter = 'pending',
                  ),
                ),
                _filterButton(
                  label: 'Approved',
                  value: 'approved',
                  selected: _applicationFilter,
                  count: approved,
                  onTap: () => setState(
                    () => _applicationFilter = 'approved',
                  ),
                ),
                _filterButton(
                  label: 'Rejected',
                  value: 'rejected',
                  selected: _applicationFilter,
                  count: rejected,
                  onTap: () => setState(
                    () => _applicationFilter = 'rejected',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${locations.length} location application(s)',
              style: const TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            if (locations.isEmpty)
              _emptyState('No $_applicationFilter locations found.')
            else
              ...locations.map(_applicationCard),
          ],
        );
      },
    );
  }

  Widget _comparisonRow(
    String label,
    dynamic current,
    dynamic proposed,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _display(current),
              style: const TextStyle(
                fontSize: 11,
                color: darkBrown,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _display(proposed),
              style: const TextStyle(
                fontSize: 11,
                color: orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _correctionCard(
    Map<String, dynamic> correction,
  ) {
    final location =
        correction['_current_location'] as Map<String, dynamic>?;

    final status = correction['status']?.toString() ?? 'pending';
    final busy = _processing.contains(correction['id'].toString());
    final isFarm = location?['type'] == 'farm';

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFarm ? Icons.agriculture : Icons.storefront,
                color: orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  location == null
                      ? 'Location unavailable'
                      : _display(location['name']),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: darkBrown,
                  ),
                ),
              ),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            'Submitted: ${_formatDate(correction['created_at'])}',
            style: const TextStyle(
              fontSize: 11,
              color: muted,
            ),
          ),
          const Divider(height: 28),
          if (status == 'pending') ...[
            const Text(
              'CURRENT INFORMATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: muted,
              ),
            ),
            const SizedBox(height: 9),
            const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Field',
                    style: TextStyle(
                      fontSize: 10,
                      color: muted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Current',
                    style: TextStyle(
                      fontSize: 10,
                      color: muted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Proposed',
                    style: TextStyle(
                      fontSize: 10,
                      color: orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 15),
            _comparisonRow(
              'Barangay',
              location?['barangay'],
              correction['barangay'],
            ),
            _comparisonRow(
              'Address',
              location?['address'],
              correction['address'],
            ),
            _comparisonRow(
              'Contact',
              location?['contact_number'],
              correction['contact_number'],
            ),
            _comparisonRow(
              'Latitude',
              location?['latitude'],
              correction['latitude'],
            ),
            _comparisonRow(
              'Longitude',
              location?['longitude'],
              correction['longitude'],
            ),
          ] else ...[
            const Text(
              'PROPOSED CORRECTION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: muted,
              ),
            ),
            const SizedBox(height: 12),
            _infoRow('Barangay', correction['barangay']),
            _infoRow('Address', correction['address']),
            _infoRow('Contact Number', correction['contact_number']),
            _infoRow('Latitude', correction['latitude']),
            _infoRow('Longitude', correction['longitude']),
            _infoRow('Reviewed', _formatDate(correction['reviewed_at'])),
            if (status == 'rejected')
              _infoRow(
                'Rejection Reason',
                correction['rejection_reason'],
              ),
          ],
          if (status == 'pending') ...[
            const Divider(height: 28),
            if (location == null)
              const Text(
                'The current location could not be loaded. '
                'This correction cannot be reviewed.',
                style: TextStyle(
                  color: Color(0xFFC34D4D),
                  fontSize: 12,
                ),
              )
            else if (busy)
              const Center(
                child: CircularProgressIndicator(color: orange),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _reviewCorrection(correction, false),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject Correction'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC34D4D),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _reviewCorrection(correction, true),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve Correction'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCorrections() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _correctionsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('CORRECTIONS ERROR: ${snapshot.error}');

          return _errorState(
            'Unable to load location corrections.',
            onRetry: _refreshCorrections,
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: orange),
          );
        }

        final allCorrections = snapshot.data!;

        final pending = allCorrections
        .where((item) => item['status'] == 'pending')
        .length;

        final approved = allCorrections
            .where((item) => item['status'] == 'approved')
            .length;

        final rejected = allCorrections
            .where((item) => item['status'] == 'rejected')
            .length;

        final corrections = allCorrections
            .where((item) => item['status'] == _correctionFilter)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              children: [
                _filterButton(
                  label: 'Pending',
                  value: 'pending',
                  selected: _correctionFilter,
                  count: pending,
                  onTap: () => _selectCorrectionFilter('pending'),
                ),
                _filterButton(
                  label: 'Approved',
                  value: 'approved',
                  selected: _correctionFilter,
                  count: approved,
                  onTap: () => _selectCorrectionFilter('approved'),
                ),
                _filterButton(
                  label: 'Rejected',
                  value: 'rejected',
                  selected: _correctionFilter,
                  count: rejected,
                  onTap: () => _selectCorrectionFilter('rejected'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${corrections.length} correction request(s)',
              style: const TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            if (corrections.isEmpty)
              _emptyState(
                'No $_correctionFilter location corrections.',
              )
            else
              ...corrections.map(_correctionCard),
          ],
        );
      },
    );
  }

  Widget _emptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 45,
            color: muted,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(
    String message, {
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: muted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: muted,
                fontSize: 13,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Location Management',
            'Review location applications and proposed location corrections.',
          ),
          const SizedBox(height: 25),
          _sectionSelector(),
          const SizedBox(height: 20),
          if (_section == 'applications')
            _buildApplications()
          else
            _buildCorrections(),
        ],
      ),
    );
  }
}
