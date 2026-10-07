import 'package:flutter/material.dart';

import 'features/activity_log/presentation/activity_log_routes.dart';
import 'app_bottom_navigation.dart';
import 'auth_api.dart';
import 'app_design_system.dart';
import 'app_preferences.dart';
import 'app_settings_page.dart';
import 'profile_image_preview.dart';
import 'core/booking_status.dart';

Color get _profileInk => AppColors.ink;
Color get _profileMuted => AppColors.muted;
Color get _profileLine => AppColors.border;

enum _MerchantProfileSetting {
  editProfile,
  activityLog,
  appPreferences,
  logOut,
}

class MerchantProfileDashboardPage extends StatefulWidget {
  const MerchantProfileDashboardPage({
    super.key,
    required this.owner,
    required this.profileImage,
    required this.venueCount,
    this.bookings = const [],
    required this.onLogout,
    required this.onEditProfile,
    this.api,
    this.onNavigate,
  });

  final Map<String, dynamic> owner;
  final ImageProvider<Object>? profileImage;
  final int venueCount;
  final List<Map<String, dynamic>> bookings;
  final Future<void> Function(BuildContext context) onLogout;
  final Future<Map<String, dynamic>?> Function() onEditProfile;
  final AuthApi? api;
  final ValueChanged<int>? onNavigate;

  @override
  State<MerchantProfileDashboardPage> createState() =>
      _MerchantProfileDashboardPageState();
}

class _MerchantProfileDashboardPageState
    extends State<MerchantProfileDashboardPage> {
  late Map<String, dynamic> _owner;
  late ImageProvider<Object>? _profileImage;

  @override
  void initState() {
    super.initState();
    _owner = widget.owner;
    _profileImage = widget.profileImage;
  }

  bool _isConfirmedBooking(Map<String, dynamic> booking) =>
      BookingStatusParser.isConfirmed(booking['status']);

  bool _isPendingBooking(Map<String, dynamic> booking) =>
      BookingStatusParser.isPending(booking['status']);

  List<Map<String, dynamic>> get _todayBookings {
    final now = DateTime.now();
    return widget.bookings.where((booking) {
      if (BookingStatusParser.isCancelled(booking['status'])) {
        return false;
      }
      final value = booking['date'] ?? booking['bookingDate'];
      final date = value is DateTime ? value : DateTime.tryParse('$value');
      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();
  }

  double get _todayRevenue => _todayBookings
      .where(_isConfirmedBooking)
      .fold(0, (total, booking) => total + _number(booking['total']));

  int get _todayPendingBookings =>
      _todayBookings.where(_isPendingBooking).length;

  int get _todayParticipants => _todayBookings.fold(
    0,
    (total, booking) => total + _count(booking['players']),
  );

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  int _count(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  @override
  Widget build(BuildContext context) {
    final owner = _owner;
    final name = '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'
        .trim();
    final email = owner['email'] as String? ?? 'Account email';
    final phone = owner['phone'] as String? ?? 'Phone not provided';

    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        toolbarHeight: 56,
        titleSpacing: 16,
        leadingWidth: 56,
        titleTextStyle: AppTypography.pageTitle,
        title: Row(
          children: [
            Flexible(
              child: AppText(
                appLanguageText('Merchant Profile', 'Profile ng Merchant'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.pageTitle,
              ),
            ),
            IconButton(
              key: const ValueKey('merchant-profile-info'),
              tooltip: appLanguageText(
                'About merchant profile',
                'About merchant profile',
              ),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const AppText('Merchant Profile', localize: true),
                  content: const AppText(
                    'Manage your account and keep track of your venues.',
                    localize: true,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const AppText('Got it', localize: true),
                    ),
                  ],
                ),
              ),
              icon: Icon(
                Icons.info_outline_rounded,
                color: _profileMuted,
                size: 19,
              ),
              visualDensity: VisualDensity.compact,
              padding: AppSpacing.buttonPadding,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            ),
          ],
        ),
        backgroundColor: AppColors.page,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _profileInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            key: const ValueKey('merchant-profile-settings'),
            tooltip: appLanguageText('Settings', 'Settings'),
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          const SizedBox(height: 6),
          _profileCard(name, email, phone),
          const SizedBox(height: 6),
          _performanceCard(),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        merchantMode: true,
        selectedIndex: 4,
        onDestinationSelected: (index) {
          if (index == 4) return;
          widget.onNavigate?.call(index);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _openSettings() async {
    final setting = await showGeneralDialog<_MerchantProfileSetting>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close settings',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Theme.of(dialogContext).colorScheme.surface,
          elevation: 12,
          child: SizedBox(
            width: MediaQuery.sizeOf(dialogContext).width * .82,
            height: double.infinity,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.settings_outlined,
                          color: Color(0xFFFF8200),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: AppText(
                            appLanguageText('Settings', 'Mga Setting'),
                            style: Theme.of(dialogContext).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: appLanguageText(
                            'Close settings',
                            'Close settings',
                          ),
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: _profileLine),
                  const SizedBox(height: 6),
                  ListTile(
                    key: const ValueKey('merchant-settings-appearance'),
                    leading: const Icon(Icons.palette_outlined),
                    title: AppText(
                      appLanguageText(
                        'Appearance & language',
                        'Hitsura at wika',
                      ),
                    ),
                    onTap: () => Navigator.pop(
                      dialogContext,
                      _MerchantProfileSetting.appPreferences,
                    ),
                  ),
                  ListTile(
                    key: const ValueKey('merchant-settings-edit-profile'),
                    leading: const Icon(Icons.edit_outlined),
                    title: AppText(
                      appLanguageText('Edit profile', 'I-edit ang profile'),
                    ),
                    onTap: () => Navigator.pop(
                      dialogContext,
                      _MerchantProfileSetting.editProfile,
                    ),
                  ),
                  ListTile(
                    key: const ValueKey('merchant-settings-activity-log'),
                    leading: const Icon(Icons.history_rounded),
                    title: AppText(
                      appLanguageText('Activity log', 'Tala ng aktibidad'),
                    ),
                    onTap: () => Navigator.pop(
                      dialogContext,
                      _MerchantProfileSetting.activityLog,
                    ),
                  ),
                  const Spacer(),
                  Divider(height: 1, color: _profileLine),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AppText(
                        appLanguageText('ACCOUNT', 'ACCOUNT'),
                        style: TextStyle(
                          color: _profileMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    key: const ValueKey('merchant-settings-logout'),
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: Colors.red,
                    ),
                    title: AppText(
                      appLanguageText('Log out', 'Mag-log out'),
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () => Navigator.pop(
                      dialogContext,
                      _MerchantProfileSetting.logOut,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
    );
    if (!mounted || setting == null) return;
    await _handleSetting(setting);
  }

  Future<void> _handleSetting(_MerchantProfileSetting setting) async {
    switch (setting) {
      case _MerchantProfileSetting.editProfile:
        final updated = await widget.onEditProfile();
        if (!mounted || updated == null) return;
        setState(() {
          _owner = Map<String, dynamic>.from(updated['owner'] as Map);
          _profileImage = updated['profileImage'] as ImageProvider<Object>?;
        });
        return;
      case _MerchantProfileSetting.activityLog:
        await Navigator.of(context)
            .push(ActivityLogRoutes.open(api: widget.api, isMerchant: true));
        return;
      case _MerchantProfileSetting.appPreferences:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AppSettingsPage()),
        );
        return;
      case _MerchantProfileSetting.logOut:
        await widget.onLogout(context);
        return;
    }
  }

  Widget _profileCard(String name, String email, String phone) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _profileLine),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D192B50),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        TappableProfileAvatar(
          radius: 34,
          backgroundColor: AppColors.softOrange,
          image: _profileImage,
          fallback: AppText(
            _initials(name),
            style: TextStyle(
              color: _profileInk,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                name.isEmpty ? 'Merchant account owner' : name,
                style: TextStyle(
                  color: _profileInk,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              AppText(
                email,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _profileMuted),
              ),
              AppText(
                phone,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _profileMuted),
              ),
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.verified_rounded, size: 15, color: Colors.green),
                  SizedBox(width: 6),
                  AppText(
                    'Verified Host',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    localize: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _performanceCard() {
    final today = DateTime.now();
    final bookings = _todayBookings;
    final hasBookings = bookings.isNotEmpty;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _profileLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D192B50),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: const BoxDecoration(gradient: AppGradients.navyBrand),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: AppText(
                        "Today's performance",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        localize: true,
                      ),
                    ),
                    const Icon(
                      Icons.today_rounded,
                      color: Color(0xFFFFC27A),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    AppText(
                      '${_monthName(today.month)} ${today.day}',
                      style: const TextStyle(
                        color: Color(0xFFD8E1F1),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      localize: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const AppText(
                  'CONFIRMED REVENUE',
                  style: TextStyle(
                    color: Color(0xFFD8E1F1),
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                  localize: true,
                ),
                const SizedBox(height: 6),
                AppText(
                  '₱${_todayRevenue.toStringAsFixed(2)}',
                  key: const ValueKey('merchant-profile-today-revenue'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                  localize: true,
                ),
                const SizedBox(height: 6),
                AppText(
                  hasBookings
                      ? '${bookings.length} booking${bookings.length == 1 ? '' : 's'} scheduled today'
                      : 'No bookings scheduled today',
                  style: const TextStyle(
                    color: Color(0xFFD8E1F1),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _metric(
                        Icons.event_available_rounded,
                        "Today's bookings",
                        '${bookings.length}',
                        const Color(0xFF1C69C9),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _metric(
                        Icons.pending_actions_rounded,
                        'Awaiting approval',
                        '$_todayPendingBookings',
                        const Color(0xFFE28A16),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _metric(
                        Icons.groups_rounded,
                        'Players today',
                        '$_todayParticipants',
                        const Color(0xFF168B69),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _metric(
                        Icons.location_city_rounded,
                        'Active venues',
                        '${widget.venueCount}',
                        const Color(0xFF7655C5),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String label, String value, Color color) =>
      Container(
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.page,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _profileLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: AppText(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _profileMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AppText(
              value,
              key: ValueKey('merchant-profile-metric-$label'),
              style: TextStyle(
                color: _profileInk,
                fontSize: 19,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );

  String _monthName(int month) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];

  String _initials(String value) {
    final parts = value.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'M';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
