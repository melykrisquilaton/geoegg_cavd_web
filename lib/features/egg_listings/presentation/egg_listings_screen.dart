import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EggListingsScreen extends StatefulWidget {
  const EggListingsScreen({super.key});

  @override
  State<EggListingsScreen> createState() => _EggListingsScreenState();
}

class _EggListingsScreenState extends State<EggListingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  static const Color cream = Color(0xFFFFF8F4);
  static const Color peach = Color(0xFFFBE3D5);
  static const Color orange = Color(0xFFE96B32);
  static const Color darkBrown = Color(0xFF3D3029);
  static const Color muted = Color(0xFF887A72);
  static const Color borderColor = Color(0xFFF0DED4);
  static const Color success = Color(0xFF43A047);
  static const Color danger = Color(0xFFE53935);

  String _selectedStatus = 'all';

  String _normalizeSearchText(dynamic value) {
    return (value ?? '')
        .toString()
        .toLowerCase()
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  late final Stream<List<Map<String, dynamic>>> _listingsStream = _supabase
      .from('egg_listings')
      .stream(primaryKey: ['id']);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _value(dynamic value, [String fallback = 'Not provided']) {
    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }
    return value.toString();
  }

  String _priceText(Map<String, dynamic> data) {
    final piece = data['price_per_piece_centavos'];
    final tray = data['price_per_tray_centavos'];

    final parts = <String>[
      if (piece is num && piece > 0)
        '₱${(piece / 100).toStringAsFixed(2)} / piece',
      if (tray is num && tray > 0) '₱${(tray / 100).toStringAsFixed(2)} / tray',
    ];

    return parts.isEmpty ? 'Price not set' : parts.join(' · ');
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return success;
      case 'unavailable':
        return danger;
      default:
        return muted;
    }
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    final label = status.isEmpty
        ? 'Available'
        : '${status[0].toUpperCase()}${status.substring(1)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
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

  List<Map<String, dynamic>> _filterListings(
    List<Map<String, dynamic>> listings,
  ) {
    final search = _normalizeSearchText(_searchController.text);

    return listings.where((data) {
      final name = _normalizeSearchText(data['name']);
      final eggType = _normalizeSearchText(data['egg_type']);
      final sellerId = _normalizeSearchText(data['seller_id']);
      final location = _normalizeSearchText(data['location_name']);

      final status = _normalizeSearchText(data['status'] ?? 'available');

      final matchesSearch =
          search.isEmpty ||
          name.contains(search) ||
          eggType.contains(search) ||
          location.contains(search) ||
          sellerId.contains(search);

      final matchesStatus =
          _selectedStatus == 'all' || status == _selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Widget _filterButton(String value, String label) {
    final selected = _selectedStatus == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _selectedStatus = value);
      },
      selectedColor: peach,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? orange : borderColor),
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? orange : muted,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Future<Map<String, dynamic>?> _loadSellerDetails(String sellerId) async {
    return _supabase
        .from('profiles')
        .select('name, email')
        .eq('id', sellerId)
        .maybeSingle();
  }

  void _showListingDetails(BuildContext context, Map<String, dynamic> data) {
    final name = _value(data['name'], 'Unnamed Eggs');
    final eggType = _value(data['egg_type'], 'Unknown type');
    final sellerId = data['seller_id']?.toString();
    final sellerDetails = sellerId == null || sellerId.trim().isEmpty
        ? Future<Map<String, dynamic>?>.value(null)
        : _loadSellerDetails(sellerId);
    final description = _value(data['description'], 'No description provided.');
    final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
    final status = _value(data['status'], 'available').toLowerCase();

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
                            Icons.egg_alt_outlined,
                            color: orange,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: darkBrown,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Center(child: _statusChip(status)),
                    const Divider(height: 32),
                    _detailRow('Egg Type', eggType),
                    _detailRow('Price', _priceText(data)),
                    _detailRow(
                      'Location',
                      _value(data['location_name'], 'No location assigned'),
                    ),
                    _detailRow('Stock', '$quantity pieces'),
                    FutureBuilder<Map<String, dynamic>?>(
                      future: sellerDetails,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          debugPrint(
                            'EGG LISTING SELLER DETAILS ERROR: '
                            '${snapshot.error}',
                          );
                          return _detailRow(
                            'Seller',
                            'Seller profile relationship unavailable.',
                          );
                        }

                        if (snapshot.connectionState != ConnectionState.done) {
                          return _detailRow(
                            'Seller',
                            'Loading seller details...',
                          );
                        }

                        final seller = snapshot.data;
                        if (seller == null) {
                          return _detailRow(
                            'Seller',
                            'Seller profile relationship unavailable.',
                          );
                        }

                        final sellerName = _value(
                          seller['name'],
                          'Name unavailable',
                        );
                        final sellerEmail = _value(
                          seller['email'],
                          'Email unavailable',
                        );
                        return _detailRow(
                          'Seller',
                          '$sellerName\n$sellerEmail',
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkBrown,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(description, style: const TextStyle(color: muted)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: muted),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: darkBrown,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listingTable(
    BuildContext context,
    List<Map<String, dynamic>> listings,
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tableWidth = constraints.maxWidth < 1040
                ? 1040.0
                : constraints.maxWidth;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(cream),
                  headingTextStyle: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  dataTextStyle: const TextStyle(
                    color: darkBrown,
                    fontSize: 13,
                  ),
                  horizontalMargin: 20,
                  columnSpacing: 18,
                  headingRowHeight: 54,
                  dataRowMinHeight: 72,
                  dataRowMaxHeight: 85,
                  columns: const [
                    DataColumn(
                      columnWidth: FlexColumnWidth(2.1),
                      label: Text('EGG LISTING'),
                    ),
                    DataColumn(
                      columnWidth: FlexColumnWidth(1.15),
                      label: Text('PRICE'),
                    ),
                    DataColumn(
                      columnWidth: FlexColumnWidth(0.85),
                      label: Text('STOCK'),
                    ),
                    DataColumn(
                      columnWidth: FlexColumnWidth(1.7),
                      label: Text('LOCATION'),
                    ),
                    DataColumn(
                      columnWidth: FlexColumnWidth(1),
                      label: Text('STATUS'),
                    ),
                    DataColumn(
                      columnWidth: FlexColumnWidth(1.35),
                      label: Text('ACTION'),
                    ),
                  ],
                  rows: listings.map((data) {
                    final name = _value(data['name'], 'Unnamed Eggs');
                    final eggType = _value(data['egg_type'], 'Unknown type');
                    final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
                    final status = _value(
                      data['status'],
                      'available',
                    ).toLowerCase();

                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 190,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: peach,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.egg_alt_outlined,
                                    color: orange,
                                    size: 23,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        eggType,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: muted,
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
                          SizedBox(width: 160, child: Text(_priceText(data))),
                        ),
                        DataCell(Text('$quantity pieces')),
                        DataCell(
                          SizedBox(
                            width: 150,
                            child: Text(
                              _value(
                                data['location_name'],
                                'No location assigned',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(_statusChip(status)),
                        DataCell(
                          TextButton.icon(
                            onPressed: () => _showListingDetails(context, data),
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
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _listingsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: orange));
        }

        if (snapshot.hasError) {
          debugPrint('EGG LISTINGS STREAM ERROR: ${snapshot.error}');

          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Unable to load egg listings. '
                'Please check your connection and permissions.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final allListings = snapshot.data ?? <Map<String, dynamic>>[];

        final filteredListings = _filterListings(allListings);

        final availableCount = allListings.where((data) {
          return _value(data['status'], 'available').toLowerCase() ==
              'available';
        }).length;

        final unavailableCount = allListings.where((data) {
          return _value(data['status'], 'available').toLowerCase() ==
              'unavailable';
        }).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Egg Listings Management',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: darkBrown,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Monitor marketplace egg listings, prices, stock, and availability.',
                style: TextStyle(fontSize: 14, color: muted),
              ),
              const SizedBox(height: 26),

              Wrap(
                spacing: 15,
                runSpacing: 12,
                children: [
                  _summaryCard(
                    'Total Listings',
                    allListings.length.toString(),
                    Icons.egg_alt_outlined,
                    orange,
                  ),
                  _summaryCard(
                    'Available',
                    availableCount.toString(),
                    Icons.check_circle_outline,
                    success,
                  ),
                  _summaryCard(
                    'Unavailable',
                    unavailableCount.toString(),
                    Icons.block_outlined,
                    danger,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by name, egg type, seller, or location...',
                  prefixIcon: const Icon(Icons.search, color: muted),
                  suffixIcon: _searchController.text.isNotEmpty
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
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: orange),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _filterButton('all', 'All Listings'),
                  _filterButton('available', 'Available'),
                  _filterButton('unavailable', 'Unavailable'),
                ],
              ),
              const SizedBox(height: 22),

              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: orange),
                  const SizedBox(width: 9),
                  Text(
                    '${filteredListings.length} listing'
                    '${filteredListings.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: darkBrown,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (filteredListings.isEmpty)
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
                        Icons.egg_alt_outlined,
                        size: 55,
                        color: muted.withValues(alpha: 0.55),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No matching listings.',
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
                        style: TextStyle(color: muted),
                      ),
                    ],
                  ),
                )
              else
                _listingTable(context, filteredListings),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: darkBrown,
                  ),
                ),
                const SizedBox(height: 3),
                Text(label, style: const TextStyle(fontSize: 12, color: muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
