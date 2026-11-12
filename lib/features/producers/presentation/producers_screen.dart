
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProducersScreen extends StatefulWidget {
  const ProducersScreen({super.key});

  @override
  State<ProducersScreen> createState() => _ProducersScreenState();
}

class _ProducersScreenState extends State<ProducersScreen> {
  // GeoEgg web theme colors
  static const Color cream = Color(0xFFFFF8F4);
  static const Color peach = Color(0xFFFBE3D5);
  static const Color orange = Color(0xFFE96B32);
  static const Color darkBrown = Color(0xFF3D3029);
  static const Color mutedBrown = Color(0xFF8D7C72);
  static const Color borderColor = Color(0xFFF0DED4);
  static const Color success = Color(0xFF43A047);
  static const Color danger = Color(0xFFE53935);

  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController =
      TextEditingController();

  String _statusFilter = 'all';

  late Stream<List<Map<String, dynamic>>> _producers =
      _producerStream();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fetch seller profiles and combine them with farm information.
  Stream<List<Map<String, dynamic>>> _producerStream() {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('role', 'seller')
        .asyncMap(_withFarmDetails);
  }

  Future<List<Map<String, dynamic>>> _withFarmDetails(
    List<Map<String, dynamic>> sellers,
  ) async {
    final farms = await _supabase
        .from('producer_profiles')
        .select();

    final farmBySeller = {
      for (final farm in farms)
        farm['user_id'].toString(): farm,
    };

    return [
      for (final seller in sellers)
        _producerView(
          seller,
          farmBySeller[seller['id'].toString()],
        ),
    ];
  }

  Map<String, dynamic> _producerView(
    Map<String, dynamic> seller,
    Map<String, dynamic>? farm,
  ) {
    return {
      'id': seller['id'],
      'name': seller['name'],
      'email': seller['email'],
      'sellerStatus': seller['seller_status'],
      'contactNumber': seller['contact_number'],
      'barangay': seller['barangay'],
      'city': seller['city'],
      'location': seller['location'],
      'farmName': farm?['farm_name'],
      'ownerName': farm?['owner_name'],
      'dailyProductionCapacity':
          farm?['daily_production_capacity'],
      'farmLatitude': farm?['farm_latitude'],
      'farmLongitude': farm?['farm_longitude'],
    };
  }

  String _value(dynamic value, [String fallback = 'Not provided']) {
    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }
    return value.toString();
  }

  String _getStatus(Map<String, dynamic> data) {
    return _value(data['sellerStatus'], 'pending');
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    final search = _searchController.text.trim().toLowerCase();

    if (search.isEmpty) return true;

    final values = [
      data['name'],
      data['ownerName'],
      data['farmName'],
      data['barangay'],
      data['city'],
      data['contactNumber'],
    ];

    return values.any(
      (value) =>
          value?.toString().toLowerCase().contains(search) ?? false,
    );
  }

  bool _matchesStatus(Map<String, dynamic> data) {
    if (_statusFilter == 'all') return true;

    return _getStatus(data).toLowerCase() == _statusFilter;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return success;
      case 'rejected':
        return danger;
      default:
        return orange;
    }
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
        status.isEmpty
            ? 'Pending'
            : '${status[0].toUpperCase()}${status.substring(1)}',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _filterButton(String value, String label) {
    final selected = _statusFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _statusFilter = value);
      },
      selectedColor: peach,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? orange : borderColor,
      ),
      labelStyle: TextStyle(
        color: selected ? orange : mutedBrown,
        fontWeight:
            selected ? FontWeight.w600 : FontWeight.normal,
      ),
      showCheckmark: false,
    );
  }

  void _showProducerDetails(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final farmName = _value(
      data['farmName'],
      'Farm name not provided',
    );

    final ownerName = _value(
      data['ownerName'],
      _value(data['name'], 'No owner name'),
    );

    final capacity = data['dailyProductionCapacity'];
    final status = _getStatus(data);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: peach,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.agriculture_outlined,
                            color: orange,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            farmName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: darkBrown,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Center(child: _statusChip(status)),
                    const Divider(height: 32),
                    _detailRow(
                      Icons.person_outline,
                      'Owner / Producer',
                      ownerName,
                    ),
                    _detailRow(
                      Icons.email_outlined,
                      'Email',
                      _value(data['email']),
                    ),
                    _detailRow(
                      Icons.phone_outlined,
                      'Contact Number',
                      _value(data['contactNumber']),
                    ),
                    _detailRow(
                      Icons.location_on_outlined,
                      'Barangay',
                      _value(data['barangay']),
                    ),
                    _detailRow(
                      Icons.location_city_outlined,
                      'City / Municipality',
                      _value(data['city']),
                    ),
                    _detailRow(
                      Icons.map_outlined,
                      'Full Location',
                      _value(data['location']),
                    ),
                    _detailRow(
                      Icons.egg_alt_outlined,
                      'Daily Production Capacity',
                      capacity == null
                          ? 'Not provided'
                          : '$capacity eggs/day',
                    ),
                    _detailRow(
                      Icons.pin_drop_outlined,
                      'Farm Latitude',
                      _value(data['farmLatitude']),
                    ),
                    _detailRow(
                      Icons.pin_drop_outlined,
                      'Farm Longitude',
                      _value(data['farmLongitude']),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            Navigator.pop(dialogContext),
                        child: const Text(
                          'Close',
                          style: TextStyle(color: orange),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: orange, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: mutedBrown,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: darkBrown,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _producerTable(
    List<Map<String, dynamic>> producers,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(cream),
            headingTextStyle: const TextStyle(
              color: mutedBrown,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            dataTextStyle: const TextStyle(
              color: darkBrown,
              fontSize: 13,
            ),
            horizontalMargin: 24,
            columnSpacing: 35,
            headingRowHeight: 54,
            dataRowMinHeight: 70,
            dataRowMaxHeight: 85,
            columns: const [
              DataColumn(label: Text('FARM / PRODUCER')),
              DataColumn(label: Text('LOCATION')),
              DataColumn(label: Text('CAPACITY')),
              DataColumn(label: Text('STATUS')),
              DataColumn(label: Text('ACTION')),
            ],
            rows: producers.map((data) {
              final farmName = _value(
                data['farmName'],
                'Farm name not provided',
              );

              final ownerName = _value(
                data['ownerName'],
                _value(data['name'], 'No owner name'),
              );

              final barangay = _value(
                data['barangay'],
                'Unknown barangay',
              );

              final city = _value(
                data['city'],
                'Unknown city',
              );

              final capacity =
                  data['dailyProductionCapacity'];

              final status = _getStatus(data);

              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 210,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: peach,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.agriculture_outlined,
                              color: orange,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  farmName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: darkBrown,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ownerName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: mutedBrown,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 160,
                      child: Text(
                        '$barangay, $city',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      capacity == null
                          ? 'Not provided'
                          : '$capacity eggs/day',
                    ),
                  ),
                  DataCell(_statusChip(status)),
                  DataCell(
                    TextButton.icon(
                      onPressed: () =>
                          _showProducerDetails(context, data),
                      icon: const Icon(
                        Icons.visibility_outlined,
                        size: 17,
                      ),
                      label: const Text('View Details'),
                      style: TextButton.styleFrom(
                        foregroundColor: orange,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _producers,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: orange),
          );
        }

        if (snapshot.hasError) {
          debugPrint(
            'PRODUCERS STREAM ERROR: ${snapshot.error}',
          );

          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Unable to load producer information. '
                'Please check your connection and permissions.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final documents =
            snapshot.data ?? <Map<String, dynamic>>[];

        final filteredProducers = documents.where((data) {
          return _matchesSearch(data) && _matchesStatus(data);
        }).toList();

        final pendingCount = documents.where((data) {
          return _getStatus(data).toLowerCase() == 'pending';
        }).length;

        return RefreshIndicator(
          color: orange,
          onRefresh: () async {
            setState(() {
              _producers = _producerStream();
            });
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Producer Management',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: darkBrown,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Monitor registered egg producers and their farm information.',
                  style: TextStyle(
                    fontSize: 14,
                    color: mutedBrown,
                  ),
                ),
                const SizedBox(height: 28),

                if (pendingCount > 0) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: peach,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: orange.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.pending_actions_outlined,
                          color: orange,
                          size: 30,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            '$pendingCount producer application'
                            '${pendingCount == 1 ? '' : 's'} '
                            'pending approval.',
                            style: const TextStyle(
                              color: darkBrown,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText:
                              'Search farm, producer, barangay...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: mutedBrown,
                          ),
                          suffixIcon:
                              _searchController.text.isNotEmpty
                                  ? IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.clear),
                                    )
                                  : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: borderColor,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: borderColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: orange,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    IconButton(
                      tooltip: 'Refresh producers',
                      onPressed: () {
                        setState(() {
                          _producers = _producerStream();
                        });
                      },
                      icon: const Icon(
                        Icons.refresh,
                        color: orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _filterButton('all', 'All'),
                    _filterButton('pending', 'Pending'),
                    _filterButton('approved', 'Approved'),
                    _filterButton('rejected', 'Rejected'),
                  ],
                ),
                const SizedBox(height: 22),

                Row(
                  children: [
                    const Icon(
                      Icons.agriculture_outlined,
                      color: orange,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      '${filteredProducers.length} '
                      'producer${filteredProducers.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: darkBrown,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (filteredProducers.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.agriculture_outlined,
                          size: 52,
                          color: mutedBrown.withValues(alpha: 0.55),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No producers found.',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: darkBrown,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Try changing your search or status filter.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: mutedBrown),
                        ),
                      ],
                    ),
                  )
                else
                  _producerTable(filteredProducers),
              ],
            ),
          ),
        );
      },
    );
  }
}
