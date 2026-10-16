import 'package:flutter/material.dart';

import 'app_design_system.dart';
import 'app_preferences.dart';
import 'message_unread_count.dart';
import 'saved_icons.dart';

Color get _navigationInk => AppColors.ink;
Color get _navigationOrange => AppColors.accent;
Color get _navigationMuted => AppColors.muted;

class AppBottomNavigation extends StatefulWidget {
  const AppBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.onDestinationReselected,
    this.unreadMessageCount = 0,
    this.unreadBookingCount = 0,
    this.merchantRequestCount = 0,
    this.merchantMode = false,
    this.hideMerchantVenues = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onDestinationReselected;
  final int unreadMessageCount;
  final int unreadBookingCount;
  final int merchantRequestCount;
  final bool merchantMode;
  final bool hideMerchantVenues;

  @override
  State<AppBottomNavigation> createState() => _AppBottomNavigationState();
}

class _AppBottomNavigationState extends State<AppBottomNavigation> {
  static const _reselectWindow = Duration(milliseconds: 450);
  int? _lastDestination;
  DateTime? _lastTapAt;

  void _onDestinationSelected(int index) {
    final now = DateTime.now();
    final isQuickReselect =
        index == widget.selectedIndex &&
        index == _lastDestination &&
        _lastTapAt != null &&
        now.difference(_lastTapAt!) <= _reselectWindow;

    _lastDestination = index;
    _lastTapAt = now;
    if (isQuickReselect) {
      _lastTapAt = null;
      widget.onDestinationReselected?.call();
      return;
    }
    widget.onDestinationSelected(index);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final languageCode = AppPreferences.instance.languageCode;
      String label(String english, String filipino) =>
          appLanguageText(english, filipino, languageCode: languageCode);
      final width = constraints.maxWidth;
      final compact = AppResponsive.isCompact(width);
      final veryNarrow = width < AppResponsive.narrowPhone;
      final unreadMessageCount =
          MessageUnreadCountScope.countOf(context) ?? widget.unreadMessageCount;
      final barHeight = compact ? 68.0 : 72.0;
      final labelSize = veryNarrow
          ? 9.0
          : compact
          ? 10.0
          : 12.0;
      return Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: AppColors.surface,
            surfaceTintColor: AppColors.surface,
            shadowColor: Colors.transparent,
            elevation: 0,
            height: barHeight,
            indicatorColor: AppColors.softOrange,
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                color: selected ? _navigationOrange : _navigationMuted,
                size: compact ? 22 : 24,
              );
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                color: selected ? _navigationInk : _navigationMuted,
                fontSize: labelSize,
                fontWeight: FontWeight.w700,
              );
            }),
          ),
        ),
        child: NavigationBar(
          height: barHeight,
          elevation: 0,
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          selectedIndex: widget.selectedIndex,
          labelBehavior: veryNarrow
              ? NavigationDestinationLabelBehavior.onlyShowSelected
              : NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: _onDestinationSelected,
          destinations: widget.merchantMode
              ? [
                  NavigationDestination(
                    key: ValueKey('merchant-dashboard-nav-dashboard'),
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded),
                    label: label('Dashboard', 'Dashboard'),
                  ),
                  NavigationDestination(
                    key: ValueKey('merchant-dashboard-nav-add'),
                    icon: Icon(Icons.add_circle_outline),
                    selectedIcon: Icon(Icons.add_circle),
                    label: label('Add', 'Magdagdag'),
                  ),
                  NavigationDestination(
                    key: ValueKey('merchant-dashboard-nav-messages'),
                    icon: _countBadge(messagesSquareIcon, unreadMessageCount),
                    selectedIcon: _countBadge(
                      messagesSquareIcon,
                      unreadMessageCount,
                    ),
                    label: label('Messages', 'Mga mensahe'),
                  ),
                  NavigationDestination(
                    key: ValueKey('merchant-dashboard-nav-payouts'),
                    icon: _countBadge(
                      Icons.pending_actions_outlined,
                      widget.merchantRequestCount,
                    ),
                    selectedIcon: _countBadge(
                      Icons.pending_actions_rounded,
                      widget.merchantRequestCount,
                    ),
                    label: label('Manage', 'Pamahalaan'),
                  ),
                  NavigationDestination(
                    key: ValueKey('merchant-dashboard-nav-profile'),
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: label('Profile', 'Profile'),
                  ),
                ]
              : [
                  NavigationDestination(
                    key: const ValueKey('news-feed-nav-explore'),
                    icon: const Icon(Icons.search_rounded),
                    selectedIcon: const Icon(Icons.search_rounded),
                    label: label('Explore', 'Mag-explore'),
                  ),
                  NavigationDestination(
                    key: const ValueKey('news-feed-nav-saved'),
                    icon: const Icon(savedItemIcon),
                    selectedIcon: const Icon(savedItemSelectedIcon),
                    label: label('Saved', 'Naka-save'),
                  ),
                  NavigationDestination(
                    key: const ValueKey('news-feed-nav-messages'),
                    icon: _countBadge(messagesSquareIcon, unreadMessageCount),
                    selectedIcon: _countBadge(
                      messagesSquareIcon,
                      unreadMessageCount,
                    ),
                    label: label('Messages', 'Mga mensahe'),
                  ),
                  NavigationDestination(
                    key: const ValueKey('news-feed-nav-bookings'),
                    icon: _calendarClockBadge(widget.unreadBookingCount),
                    selectedIcon: _calendarClockBadge(
                      widget.unreadBookingCount,
                    ),
                    label: label('Bookings', 'Mga booking'),
                  ),
                  NavigationDestination(
                    key: const ValueKey('news-feed-nav-profile'),
                    icon: const Icon(Icons.person_outline_rounded),
                    selectedIcon: const Icon(Icons.person_rounded),
                    label: label('Profile', 'Profile'),
                  ),
                ],
        ),
      );
    },
  );

  Widget _countBadge(IconData icon, int count) => Badge(
    isLabelVisible: count > 0,
    label: AppText(count > 99 ? '99+' : '$count'),
    child: Icon(icon, size: 24),
  );

  Widget _calendarClockBadge(int count) => Badge(
    isLabelVisible: count > 0,
    label: AppText(count > 99 ? '99+' : '$count'),
    child: SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Icon(Icons.calendar_month_outlined, size: 22),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.access_time_rounded, size: 12),
            ),
          ),
        ],
      ),
    ),
  );
}
