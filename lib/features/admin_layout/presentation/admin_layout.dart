import '../../producers/presentation/producers_screen.dart';
import 'package:flutter/material.dart';
import '../../egg_listings/presentation/egg_listings_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../users/presentation/users_screen.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../locations/presentation/locations_screen.dart';
import '../../admin_profile/presentation/admin_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/presentation/login_screen.dart';

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _selectedIndex = 0;
  String _usersInitialFilter = 'all';
  String _ordersInitialFilter = 'all';

  static const cream = Color(0xFFFFF8F4);
  static const peach = Color(0xFFFBE3D5);
  static const orange = Color(0xFFE96B32);
  static const darkBrown = Color(0xFF3D3029);
  static const muted = Color(0xFF887A72);

  final List<String> _menuLabels = [
    'Dashboard',
    'Users',
    'Producers',
    'Egg Listings',
    'Order Summary',
    'Locations',
    'Admin Profile',
  ];

  final List<IconData> _menuIcons = [
    Icons.dashboard_outlined,
    Icons.people_outline,
    Icons.agriculture_outlined,
    Icons.egg_outlined,
    Icons.receipt_long_outlined,
    Icons.location_on_outlined,
    Icons.account_circle_outlined,
  ];

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return DashboardScreen(
          onViewLocations: () {
            setState(() {
              _selectedIndex = 5;
            });
          },
          onViewUsers: (filter) {
            setState(() {
              _selectedIndex = 1;
              _usersInitialFilter = filter;
            });
          },
          onViewProducers: () {
            setState(() {
              _selectedIndex = 2;
            });
          },
          onViewEggListings: () {
            setState(() {
              _selectedIndex = 3;
            });
          },
          onViewOrders: (filter) {
            setState(() {
              _selectedIndex = 4;
              _ordersInitialFilter = filter;
            });
          },
        );

      case 1:
        return UsersScreen(
          key: ValueKey(_usersInitialFilter),
          initialFilter: _usersInitialFilter,
        );

      case 2:
        return const ProducersScreen();

      case 3:
        return const EggListingsScreen();

      case 4:
        return OrdersScreen(
          key: ValueKey(_ordersInitialFilter),
          initialFilter: _ordersInitialFilter,
        );

      case 5:
        return const LocationsScreen();

      case 6:
        return const AdminProfileScreen();

      default:
        return _comingSoonScreen(
          _menuLabels[_selectedIndex],
        );
    }
  }

  Widget _comingSoonScreen(String title) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.construction_outlined,
            size: 55,
            color: orange,
          ),
          const SizedBox(height: 15),
          Text(
            '$title module',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: darkBrown,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This module will be implemented next.',
            style: TextStyle(color: muted),
          ),
        ],
      ),
    );
  }

  Widget _sidebar() {
    return Container(
      width: 245,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.egg_alt_outlined,
                color: orange,
                size: 37,
              ),
              const SizedBox(width: 10),
              const Text(
                'GeoEgg',
                style: TextStyle(
                  color: darkBrown,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Padding(
            padding: EdgeInsets.only(left: 47),
            child: Text(
              'CAVD ADMINISTRATION',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1,
                color: orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 42),
          const Padding(
            padding: EdgeInsets.only(left: 12, bottom: 13),
            child: Text(
              'MAIN MENU',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: muted,
              ),
            ),
          ),
          ...List.generate(_menuLabels.length, (index) {
            return _sidebarItem(index);
          }),
          const Spacer(),
          const Divider(color: Color(0xFFF0E5DE)),
          _sidebarItem(
            7,
            label: 'Log Out',
            icon: Icons.logout,
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(
    int index, {
    String? label,
    IconData? icon,
  }) {
    final selected = _selectedIndex == index;
    final itemLabel = label ?? _menuLabels[index];
    final itemIcon = icon ?? _menuIcons[index];

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: selected ? peach : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            if (index == 7) {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: const Text('Log Out'),
                    content: const Text(
                      'Are you sure you want to log out?',
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
                        child: const Text('Log Out'),
                      ),
                    ],
                  );
                },
              );

              if (shouldLogout == true && mounted) {
                try {
                  await Supabase.instance.client.auth.signOut();

                  if (!mounted) return;

                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Logout failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }

              return;
            }

            setState(() {
              _selectedIndex = index;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 13,
            ),
            child: Row(
              children: [
                Icon(
                  itemIcon,
                  size: 20,
                  color: selected ? orange : muted,
                ),
                const SizedBox(width: 13),
                Text(
                  itemLabel,
                  style: TextStyle(
                    color: selected ? darkBrown : muted,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: Row(
        children: [
          _sidebar(),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 76,
                  padding: const EdgeInsets.symmetric(horizontal: 35),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFFF0E5DE),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _menuLabels[_selectedIndex],
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: darkBrown,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.account_circle_outlined,
                        color: orange,
                        size: 29,
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CAVD Administrator',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: darkBrown,
                            ),
                          ),
                          Text(
                            'Administrator',
                            style: TextStyle(
                              fontSize: 11,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _getSelectedScreen(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
