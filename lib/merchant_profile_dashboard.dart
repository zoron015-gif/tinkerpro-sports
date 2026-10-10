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
    this.businesses = const [],
    required this.onLogout,
    required this.onEditProfile,
    this.api,
    this.onNavigate,
  });

  final Map<String, dynamic> owner;
  final ImageProvider<Object>? profileImage;
  final int venueCount;
  final List<Map<String, dynamic>> bookings;
  final List<Map<String, dynamic>> businesses;
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
  String _performancePeriod = 'Today';

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

  List<Map<String, dynamic>> get _performanceBookings {
    if (_performancePeriod == 'All time') return widget.bookings;
    final now = DateTime.now();
    final days = switch (_performancePeriod) {
      '7 days' => 7,
      '30 days' => 30,
      _ => 1,
    };
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    return widget.bookings.where((booking) {
      final value = booking['date'] ?? booking['bookingDate'];
      final date = value is DateTime ? value : DateTime.tryParse('$value');
      return date != null &&
          !date.isBefore(start) &&
          !date.isAfter(DateTime(now.year, now.month, now.day));
    }).toList();
  }

  double get _performanceRevenue => _performanceBookings
      .where(_isConfirmedBooking)
      .fold(0, (total, booking) => total + _number(booking['total']));

  double get _estimatedPaidAmount => _performanceBookings.fold(
    0,
    (total, booking) => total + _bookingAmountReceived(booking),
  );

  int get _todayPendingBookings =>
      _todayBookings.where(_isPendingBooking).length;

  int get _todayParticipants => _todayBookings.fold(
    0,
    (total, booking) => total + _count(booking['players']),
  );

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  double _bookingAmountReceived(Map<String, dynamic> booking) {
    final paymentStatus = '${booking['paymentStatus'] ?? ''}'.toLowerCase();
    final paidAmount = booking['paidAmount'];
    if (paidAmount != null) {
      final amount = _number(paidAmount);
      if (amount > 0 || paymentStatus != 'paid') return amount;
    }
    if (paymentStatus == 'paid') return _number(booking['total']);
    return 0;
  }

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
          const SizedBox(height: 6),
          _quickToolsCard(),
          const SizedBox(height: 6),
          _businessOverviewCard(),
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
              if ('${_owner['businessName'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                AppText(
                  '${_owner['businessName']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _profileInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _performanceCard() {
    final bookings = _todayBookings;
    final filteredBookings = _performanceBookings;
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
                    Expanded(
                      child: AppText(
                        _performancePeriod == 'Today'
                            ? "Today's performance"
                            : '$_performancePeriod performance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        localize: true,
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const ValueKey('merchant-profile-date-filter'),
                        value: _performancePeriod,
                        dropdownColor: AppColors.navy,
                        iconEnabledColor: Colors.white,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Today',
                            child: Text('Today'),
                          ),
                          DropdownMenuItem(
                            value: '7 days',
                            child: Text('7 days'),
                          ),
                          DropdownMenuItem(
                            value: '30 days',
                            child: Text('30 days'),
                          ),
                          DropdownMenuItem(
                            value: 'All time',
                            child: Text('All time'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _performancePeriod = value);
                          }
                        },
                      ),
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
                  '₱${_performanceRevenue.toStringAsFixed(2)}',
                  key: const ValueKey('merchant-profile-performance-revenue'),
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
                  _performancePeriod == 'Today'
                      ? bookings.isEmpty
                            ? 'No bookings scheduled today'
                            : '${bookings.length} booking${bookings.length == 1 ? '' : 's'} scheduled today'
                      : '${filteredBookings.length} booking${filteredBookings.length == 1 ? '' : 's'} in selected period',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: InkWell(
              key: const ValueKey('merchant-profile-estimated-paid'),
              onTap: () => _navigateToManagement(3),
              borderRadius: BorderRadius.circular(14),
              child: _metric(
                Icons.account_balance_wallet_outlined,
                'Estimated paid amount',
                '₱${_estimatedPaidAmount.toStringAsFixed(2)}',
                const Color(0xFF237A43),
                description: 'From booking payment records; not a withdrawable balance. Tap for payment details.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(
    IconData icon,
    String label,
    String value,
    Color color, {
    String? description,
  }) => Container(
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
        if (description != null) ...[
          const SizedBox(height: 6),
          AppText(
            description,
            style: TextStyle(color: _profileMuted, fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    ),
  );

  Widget _quickToolsCard() => _sectionCard(
    title: 'Quick tools',
    children: [
      _quickTool(
        icon: Icons.calendar_month_rounded,
        title: 'Schedule',
        subtitle: 'Review booking requests and schedule',
        color: const Color(0xFF1C69C9),
        onTap: () => _navigateToManagement(3),
      ),
      _quickTool(
        icon: Icons.sell_outlined,
        title: 'Pricing / Promo',
        subtitle: 'Manage venues, pricing, and offers',
        color: const Color(0xFFE28A16),
        onTap: () => _navigateToManagement(1),
      ),
      _quickTool(
        icon: Icons.query_stats_rounded,
        title: 'Stats',
        subtitle: 'Open full performance analytics',
        color: const Color(0xFF7655C5),
        onTap: () => _navigateToManagement(0),
      ),
    ],
  );

  Widget _businessOverviewCard() {
    final businessName = '${_owner['businessName'] ?? ''}'.trim();
    final completionChecks = [
      businessName.isNotEmpty,
      '${_owner['address'] ?? ''}'.trim().isNotEmpty,
      widget.businesses.any(_businessHasImage),
      widget.businesses.isNotEmpty,
    ];
    final completed = completionChecks.where((value) => value).length;
    final ratings = widget.businesses
        .map((business) => _number(business['averageRating']))
        .where((rating) => rating > 0)
        .toList();
    final rating = ratings.isEmpty
        ? null
        : ratings.reduce((first, second) => first + second) / ratings.length;
    final openVenues = widget.businesses.where((business) {
      final availability = '${business['availability'] ?? ''}'.toLowerCase();
      return availability.contains('open') ||
          availability.contains('available');
    }).length;
    final recentBookings = [...widget.bookings]
      ..sort((first, second) {
        final firstDate = DateTime.tryParse(
          '${first['createdAt'] ?? first['date'] ?? ''}',
        );
        final secondDate = DateTime.tryParse(
          '${second['createdAt'] ?? second['date'] ?? ''}',
        );
        if (firstDate == null) return 1;
        if (secondDate == null) return -1;
        return secondDate.compareTo(firstDate);
      });

    return _sectionCard(
      title: 'Business overview',
      children: [
        Row(
          children: [
            Expanded(
              child: AppText(
                businessName.isEmpty ? 'Add your business name' : businessName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _profileInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (rating != null) ...[
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFE28A16),
                size: 18,
              ),
              AppText(
                rating.toStringAsFixed(1),
                style: TextStyle(
                  color: _profileInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              openVenues > 0 ? Icons.circle : Icons.circle_outlined,
              size: 10,
              color: openVenues > 0 ? const Color(0xFF168B69) : _profileMuted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AppText(
                widget.businesses.isEmpty
                    ? 'No venues added yet'
                    : '$openVenues of ${widget.businesses.length} venues marked open or available',
                style: TextStyle(color: _profileMuted, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AppText(
          'Profile completion · $completed/${completionChecks.length}',
          style: TextStyle(
            color: _profileInk,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: completed / completionChecks.length,
          minHeight: 6,
          borderRadius: BorderRadius.circular(6),
          backgroundColor: AppColors.surfaceVariant,
          color: const Color(0xFF1C69C9),
        ),
        if (recentBookings.isNotEmpty) ...[
          const SizedBox(height: 6),
          InkWell(
            key: const ValueKey('merchant-profile-recent-activity'),
            onTap: () => _navigateToManagement(3),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: Color(0xFF7655C5),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: AppText(
                      'Latest booking · ${recentBookings.first['customerName'] ?? 'Customer'} · ${recentBookings.first['status'] ?? 'updated'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _profileMuted, fontSize: 12),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: _profileMuted),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) => Container(
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          title,
          style: TextStyle(
            color: _profileInk,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        ...children,
      ],
    ),
  );

  Widget _quickTool({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) => Material(
    type: MaterialType.transparency,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .12),
        child: Icon(icon, color: color, size: 20),
      ),
      title: AppText(
        title,
        style: TextStyle(color: _profileInk, fontWeight: FontWeight.w800),
      ),
      subtitle: AppText(
        subtitle,
        style: TextStyle(color: _profileMuted, fontSize: 11),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: _profileMuted),
      onTap: onTap,
    ),
  );

  bool _businessHasImage(Map<String, dynamic> business) {
    final image = '${business['imageUrl'] ?? business['image_url'] ?? ''}'
        .trim();
    final images = business['imageUrls'] ?? business['image_urls'];
    return image.isNotEmpty ||
        (images is List &&
            images.whereType<String>().any((value) => value.trim().isNotEmpty));
  }

  void _navigateToManagement(int index) {
    widget.onNavigate?.call(index);
    Navigator.of(context).pop();
  }

  String _initials(String value) {
    final parts = value.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'M';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
