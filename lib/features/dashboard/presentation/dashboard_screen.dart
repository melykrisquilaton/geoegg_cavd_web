import 'package:flutter/material.dart';
import 'package:geoegg_cavd_web/core/supabase/cavd_order_summary.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onViewLocations;
  final ValueChanged<String>? onViewUsers;
  final VoidCallback? onViewProducers;
  final VoidCallback? onViewEggListings;
  final ValueChanged<String>? onViewOrders;

  const DashboardScreen({
    super.key,
    this.onViewLocations,
    this.onViewUsers,
    this.onViewProducers,
    this.onViewEggListings,
    this.onViewOrders,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabase = Supabase.instance.client;

  static const peach = Color(0xFFFBE3D5);
  static const orange = Color(0xFFE96B32);
  static const darkBrown = Color(0xFF3D3029);
  static const muted = Color(0xFF887A72);

  late final Stream<List<Map<String, dynamic>>> _profiles =
      _supabase.from('profiles').stream(primaryKey: ['id']);

  late final Stream<List<Map<String, dynamic>>> _listings =
      _supabase.from('egg_listings').stream(primaryKey: ['id']);

  late final Future<CavdOrderSummary> _orderSummary = CavdOrderSummary.load();
  late final Stream<List<Map<String, dynamic>>> _locations =
      _supabase.from('locations').stream(primaryKey: ['id']);

  late final Stream<int> _userCount = _countRows(_profiles);

  late final Stream<int> _buyerCount =
      _countRows(_profiles, (row) => row['role'] == 'buyer');

  late final Stream<int> _sellerCount =
      _countRows(_profiles, (row) => row['role'] == 'seller');

  late final Stream<int> _listingCount = _countRows(_listings);

  late final Stream<int> _orderCount =
      _orderSummary.then((summary) => summary.total).asStream();
  late final Stream<int> _pendingOrderCount =
      _orderSummary.then((summary) => summary.byStatus['pending'] ?? 0).asStream();
  late final Stream<int> _pendingLocationCount =
      _countRows(_locations, (row) => row['status'] == 'pending');

  Stream<int> _countRows(
    Stream<List<Map<String, dynamic>>> rows, [
    bool Function(Map<String, dynamic>)? where,
  ]) {
    return rows.map(
      (list) => where == null
          ? list.length
          : list.where(where).length,
    );
  }

  Widget _liveCount(Stream<int> stream, {double size = 30}) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        return Text(
          snapshot.hasData ? '${snapshot.data}' : '—',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.bold,
            color: darkBrown,
          ),
        );
      },
    );
  }

  Widget _statCard({
    required String title,
    required String description,
    required IconData icon,
    required Stream<int> stream,
    required Color iconBackground,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0E5DE)),
          ),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: orange, size: 23),
              ),
              const Spacer(),
              const Icon(
                Icons.trending_up,
                color: Color(0xFFB9A69B),
                size: 19,
              ),
            ],
          ),
          const SizedBox(height: 22),
          _liveCount(stream),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: darkBrown,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: muted,
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _pendingLocationCard() {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: widget.onViewLocations,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: peach,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFF1D1BF),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.location_on_outlined,
                color: orange,
                size: 27,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location applications',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: darkBrown,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Location requests waiting for administrator review.',
                    style: TextStyle(
                      fontSize: 13,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<int>(
                    stream: _pendingLocationCount,
                    builder: (context, snapshot) {
                      final count = snapshot.data;

                      return Text(
                        count == null
                            ? 'Loading applications...'
                            : '$count waiting for review',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: orange,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 17,
              color: orange,
            ),
          ],
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100 ? 3 : 2;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Marketplace overview',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: darkBrown,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Monitor GeoEgg marketplace activities and statistics.',
                style: TextStyle(
                  fontSize: 14,
                  color: muted,
                ),
              ),
              const SizedBox(height: 28),
              _pendingLocationCard(),
              const SizedBox(height: 25),
              const Text(
                'Platform Statistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkBrown,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: columns,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 215,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _statCard(
                    title: 'Total Users',
                    description: 'All registered users',
                    icon: Icons.people_outline,
                    stream: _userCount,
                    iconBackground: peach,
                    onTap: () => widget.onViewUsers?.call('all'),
                  ),
                  _statCard(
                    title: 'Buyers',
                    description: 'Registered buyers',
                    icon: Icons.shopping_bag_outlined,
                    stream: _buyerCount,
                    iconBackground: const Color(0xFFFFF1DC),
                    onTap: () => widget.onViewUsers?.call('buyer'),
                  ),
                  _statCard(
                    title: 'Producers',
                    description: 'Registered sellers',
                    icon: Icons.agriculture_outlined,
                    stream: _sellerCount,
                    iconBackground: peach,
                    onTap: widget.onViewProducers,
                  ),
                  _statCard(
                    title: 'Egg Listings',
                    description: 'All marketplace listings',
                    icon: Icons.egg_outlined,
                    stream: _listingCount,
                    iconBackground: const Color(0xFFFFF1DC),
                    onTap: widget.onViewEggListings,
                  ),
                  _statCard(
                    title: 'Total Orders',
                    description: 'Marketplace count when dashboard opened',
                    icon: Icons.receipt_long_outlined,
                    stream: _orderCount,
                    iconBackground: peach,
                    onTap: () => widget.onViewOrders?.call('all'),
                  ),
                  _statCard(
                    title: 'Pending Orders',
                    description: 'Pending count when dashboard opened',
                    icon: Icons.pending_actions_outlined,
                    stream: _pendingOrderCount,
                    iconBackground: const Color(0xFFFFF1DC),
                    onTap: () => widget.onViewOrders?.call('pending'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
