import 'package:flutter/material.dart';

import 'saved_icons.dart';

const _navigationNavy = Color(0xFF192B50);
const _navigationOrange = Color(0xFFFF8200);
const _navigationMuted = Color(0xFF68748A);

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.unreadMessageCount = 0,
    this.unreadBookingCount = 0,
    this.merchantMode = false,
    this.hideMerchantVenues = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int unreadMessageCount;
  final int unreadBookingCount;
  final bool merchantMode;
  final bool hideMerchantVenues;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shadowColor: const Color(0x14000000),
        elevation: 2,
        height: 72,
        indicatorColor: const Color(0xFFFFE8D2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? _navigationOrange : _navigationMuted,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? _navigationNavy : _navigationMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          );
        }),
      ),
    ),
    child: NavigationBar(
      height: 72,
      elevation: 0,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      selectedIndex: selectedIndex,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: onDestinationSelected,
      destinations: merchantMode
          ? const [
              NavigationDestination(
                key: ValueKey('merchant-dashboard-nav-dashboard'),
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Dashboard',
              ),
              NavigationDestination(
                key: ValueKey('merchant-dashboard-nav-add'),
                icon: Icon(Icons.add_circle_outline),
                selectedIcon: Icon(Icons.add_circle),
                label: 'Add',
              ),
              NavigationDestination(
                key: ValueKey('merchant-dashboard-nav-messages'),
                icon: Icon(Icons.send_outlined),
                selectedIcon: Icon(Icons.send_rounded),
                label: 'Messages',
              ),
              NavigationDestination(
                key: ValueKey('merchant-dashboard-nav-payouts'),
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments_rounded),
                label: 'Payouts',
              ),
              NavigationDestination(
                key: ValueKey('merchant-dashboard-nav-profile'),
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ]
          : [
              NavigationDestination(
          key: const ValueKey('news-feed-nav-explore'),
          icon: Icon(
            Icons.location_on_outlined,
            ),
          selectedIcon: Icon(
            Icons.location_on_rounded,
          ),
          label: 'Explore',
        ),
        NavigationDestination(
          key: const ValueKey('news-feed-nav-saved'),
          icon: const Icon(savedItemIcon),
          selectedIcon: const Icon(savedItemSelectedIcon),
          label: 'Saved',
        ),
        NavigationDestination(
          key: const ValueKey('news-feed-nav-messages'),
          icon: _countBadge(Icons.send_outlined, unreadMessageCount),
          selectedIcon: _countBadge(Icons.send_rounded, unreadMessageCount),
          label: 'Messages',
        ),
        NavigationDestination(
          key: const ValueKey('news-feed-nav-bookings'),
          icon: _countBadge(Icons.calendar_today_outlined, unreadBookingCount),
          selectedIcon: _countBadge(Icons.calendar_today_rounded, unreadBookingCount),
          label: 'Bookings',
        ),
        NavigationDestination(
          key: const ValueKey('news-feed-nav-profile'),
          icon: const Icon(Icons.person_outline_rounded),
          selectedIcon: const Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    ),
  );

  Widget _countBadge(IconData icon, int count) => Badge(
    isLabelVisible: count > 0,
    label: Text(count > 99 ? '99+' : '$count'),
    child: Icon(icon, size: 24),
  );
}
