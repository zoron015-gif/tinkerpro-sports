import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'app_session.dart';
import 'app_design_system.dart';
import 'auth_api.dart';
import 'messages_dashboard.dart';
import 'profile_dashboard.dart';
import 'app_bottom_navigation.dart';
import 'saved_dashboard.dart';
import 'news_feed.dart';
import 'models/booking.dart';
import 'skeleton_loader.dart';
import 'app_preferences.dart';

class CustomerBookingsPage extends StatefulWidget {
  const CustomerBookingsPage({
    super.key,
    this.onLogout,
    this.api,
    this.initialUserPosition,
    this.businessType,
  });

  final Future<void> Function(BuildContext context)? onLogout;
  final AuthApi? api;
  final Position? initialUserPosition;
  final String? businessType;

  @override
  State<CustomerBookingsPage> createState() => _CustomerBookingsPageState();
}

class _BookingGallery extends StatefulWidget {
  const _BookingGallery({required this.images});

  final List<String> images;

  @override
  State<_BookingGallery> createState() => _BookingGalleryState();
}

class _BookingGalleryState extends State<_BookingGallery> {
  late final PageController _controller;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: widget.images.length > 1 ? widget.images.length * 1000 : 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiple = widget.images.length > 1;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: double.infinity,
        height: 190,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: multiple ? 10000 : 1,
              onPageChanged: (page) {
                setState(() => _index = page % widget.images.length);
              },
              itemBuilder: (_, page) => Image(
                image: _imageProvider(
                  widget.images[page % widget.images.length],
                ),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, error, stackTrace) => Image.asset(
                  'assets/court/pickle-court.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (multiple)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var dot = 0; dot < widget.images.length; dot++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: dot == _index ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: dot == _index
                              ? Colors.white
                              : Colors.white.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  ImageProvider _imageProvider(String image) {
    if (image.startsWith('data:image/')) {
      final comma = image.indexOf(',');
      if (comma >= 0) {
        try {
          return MemoryImage(base64Decode(image.substring(comma + 1)));
        } on FormatException {
          return const AssetImage('assets/court/pickle-court.jpg');
        }
      }
    }
    if (image.startsWith('http')) return NetworkImage(image);
    return AssetImage(image);
  }
}

class _CustomerBookingsPageState extends State<CustomerBookingsPage> {
  late final AuthApi _api;
  late Future<List<Booking>> _bookings;
  int _unreadBookingCount = 0;
  int _unreadMessageCount = 0;
  String? _messageCountError;
  String? _bookingStatusBannerKey;
  var _showBookingStatusBanner = true;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? AuthApi();
    _bookings = _loadBookings();
  }

  Future<List<Booking>> _loadBookings() async {
    final session = await AppSession.load();
    final token = session.apiToken;
    if (token == null || token.isEmpty) return [];
    final bookings = await _api.customerBookingModels(
      token,
      businessType: widget.businessType,
    );
    final bannerBooking = _bookingStatusBannerBooking(bookings);
    _bookingStatusBannerKey = bannerBooking == null
        ? null
        : _bookingStatusKey(bannerBooking);
    _showBookingStatusBanner =
        bannerBooking == null ||
        !session.bookingStatusBannerDismissed(_bookingStatusBannerKey!);
    _unreadBookingCount = bookings.where((booking) {
      final status = _bookingStatus(booking);
      return status == 'approved' ||
          status == 'finished' ||
          status == 'done' ||
          status == 'completed' ||
          status == 'expired' ||
          status == 'cancelled';
    }).length;
    try {
      final conversations = await _api.conversations(
        token,
        businessType: widget.businessType,
      );
      _unreadMessageCount = conversations.fold<int>(
        0,
        (total, conversation) =>
            total + ((conversation['unreadCount'] as num?)?.toInt() ?? 0),
      );
      _messageCountError = null;
    } on Exception catch (error) {
      _messageCountError = 'Unread message count could not be updated: $error';
    }
    return bookings;
  }

  Future<void> _refresh() async {
    await _dismissBookingStatusBanner();
    if (!mounted) return;
    setState(() {
      _bookings = _loadBookings();
    });
    await _bookings;
  }

  Future<void> _dismissBookingStatusBanner() async {
    if (!_showBookingStatusBanner) return;
    final bannerKey = _bookingStatusBannerKey;
    setState(() => _showBookingStatusBanner = false);
    if (bannerKey == null) return;
    final session = await AppSession.load();
    await session.dismissBookingStatusBanner(bannerKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        title: const AppText('Bookings', localize: true),
        backgroundColor: AppColors.page,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: FutureBuilder<List<Booking>>(
        future: _bookings,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              key: const ValueKey('customer-bookings-loading-skeleton'),
              padding: const EdgeInsets.all(16),
              children: [
                for (var index = 0; index < 3; index++) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.surfaceVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SkeletonBlock(
                          height: 148,
                          borderRadius: 12,
                        ),
                        const SizedBox(height: 14),
                        const SkeletonBlock(width: 180, height: 18),
                        const SizedBox(height: 8),
                        const SkeletonBlock(width: 125, height: 13),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Expanded(
                              child: SkeletonBlock(height: 38, borderRadius: 12),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: SkeletonBlock(height: 38, borderRadius: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (index < 2) const SizedBox(height: 14),
                ],
              ],
            );
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: AppText('Could not load bookings: ${snapshot.error}', localize: true),
                ),
              ],
            );
          }
          final bookings = snapshot.data ?? const <Booking>[];
          final pending = bookings
              .where((booking) => _bookingStatus(booking) == 'pending')
              .toList();
          final approved = bookings
              .where((booking) => _bookingStatus(booking) == 'approved')
              .toList();
          final completed = bookings
              .where(
                (booking) => const {
                  'finished',
                  'done',
                  'completed',
                  'expired',
                  'cancelled',
                }.contains(_bookingStatus(booking)),
              )
              .toList();

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                if (_messageCountError != null)
                  MaterialBanner(
                    backgroundColor: AppColors.softStatus,
                    leading: const Icon(
                      Icons.sync_problem_rounded,
                      color: Color(0xFFB85C00),
                    ),
                    content: AppText(
                      _messageCountError!,
                      style:  TextStyle(color: AppColors.ink),
                    ),
                    actions: [
                      TextButton(
                        onPressed: _refresh,
                        child: const AppText('Retry', localize: true),
                      ),
                    ],
                  ),
                if (approved.isNotEmpty || completed.isNotEmpty)
                  AnimatedSize(
                    alignment: Alignment.topCenter,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    child: _showBookingStatusBanner
                        ? _bookingStatusBanner(approved, completed)
                        : const SizedBox.shrink(),
                  ),
                Material(
                  color: AppColors.surface,
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    labelColor: AppColors.ink,
                    unselectedLabelColor: AppColors.muted,
                    indicatorColor: AppColors.accent,
                    indicatorWeight: 3,
                    tabs: [
                      Tab(text: 'Pending (${pending.length})'),
                      Tab(text: 'Approved (${approved.length})'),
                      Tab(text: 'Completed (${completed.length})'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _bookingTab(
                        pending,
                        emptyMessage: 'No pending bookings.',
                      ),
                      _bookingTab(
                        approved,
                        emptyMessage: 'No approved bookings.',
                      ),
                      _bookingTab(
                        completed,
                        emptyMessage: 'No completed bookings.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: 3,
        unreadMessageCount: _unreadMessageCount,
        unreadBookingCount: _unreadBookingCount,
        onDestinationSelected: (index) {
          if (index == 3) return;
          if (index == 0) {
            _openExplore();
            return;
          }
          if (index == 1) {
            _replaceWith(
              MaterialPageRoute(
                builder: (_) => SavedDashboardPage(
                  onLogout: widget.onLogout,
                  itemType: SavedDashboardPage.itemTypeForBusinessType(
                    widget.businessType,
                  ),
                  initialUserPosition: widget.initialUserPosition,
                ),
              ),
            );
            return;
          }
          if (index == 2) {
            _replaceWith(
              MaterialPageRoute(
                builder: (_) => MessagesDashboardPage(
                  initialUserPosition: widget.initialUserPosition,
                  businessType: widget.businessType,
                ),
              ),
            );
            return;
          }
          _replaceWith(
            MaterialPageRoute(
              builder: (_) => ProfileDashboardPage(
                onLogout: widget.onLogout,
                initialUserPosition: widget.initialUserPosition,
                businessType: widget.businessType,
              ),
            ),
          );
        },
      ),
    );
  }

  String _bookingStatus(Booking booking) => booking.status;

  Booking? _bookingStatusBannerBooking(List<Booking> bookings) {
    final completed = bookings.where((booking) {
      return const {
        'finished',
        'done',
        'completed',
        'expired',
        'cancelled',
      }.contains(_bookingStatus(booking));
    });
    if (completed.isNotEmpty) return completed.first;
    final approved = bookings.where(
      (booking) => _bookingStatus(booking) == 'approved',
    );
    return approved.isEmpty ? null : approved.first;
  }

  String _bookingStatusKey(Booking booking) {
    final identity =
        booking.id?.toString() ??
        '${booking.venue.id ?? booking.venue.name}_${booking.date}_${booking.startTime}';
    return '${identity}_${booking.status}';
  }

  Widget _bookingStatusBanner(List<Booking> approved, List<Booking> completed) {
    final booking = completed.isNotEmpty ? completed.first : approved.first;
    final status = _bookingStatus(booking);
    final isCompleted = {'finished', 'done', 'completed'}.contains(status);
    final isInactive = {'expired', 'cancelled'}.contains(status);
    return MaterialBanner(
      backgroundColor: isCompleted
          ? const Color(0xFFE7F6EC)
          : isInactive
          ? const Color(0xFFFEE4E2)
          : AppColors.softStatus,
      leading: Icon(
        isCompleted
            ? Icons.check_circle_rounded
            : isInactive
            ? Icons.event_busy_rounded
            : Icons.event_available_rounded,
        color: isCompleted
            ? AppColors.success
            : isInactive
            ? AppColors.errorText
            : AppColors.accent,
      ),
      content: InkWell(
        key: const ValueKey('booking-status-banner-content'),
        onTap: _dismissBookingStatusBanner,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AppText(
            isCompleted || isInactive
                ? 'Booking at ${booking['venueName'] ?? 'your venue'} is '
                      '${_statusLabel(status).toLowerCase()}.'
                : 'Booking at ${booking['venueName'] ?? 'your venue'} was approved '
                      'for ${booking['date']} at ${_formatTime(booking['startTime'])}.',
            style:  TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _refresh, child: const AppText('Refresh', localize: true)),
        TextButton(
          key: const ValueKey('booking-status-banner-dismiss'),
          onPressed: _dismissBookingStatusBanner,
          child: const AppText('Dismiss', localize: true),
        ),
      ],
    );
  }

  Widget _bookingTab(List<Booking> bookings, {required String emptyMessage}) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: bookings.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 180),
                Center(child: AppText(emptyMessage)),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _bookingCard(bookings[index]),
            ),
    );
  }

  void _replaceWith(Route<void> route) {
    Navigator.of(context).pushReplacement(route);
  }

  Future<void> _openExplore() async {
    if (!mounted) return;
    _replaceWith(
      MaterialPageRoute(
        builder: (_) => NewsFeedPage(
          onLogout: widget.onLogout,
          initialUserPosition: widget.initialUserPosition,
          businessType: widget.businessType ?? 'Sports',
        ),
      ),
    );
  }

  Widget _bookingCard(Booking booking) {
    final status = '${booking['status'] ?? 'pending'}';
    final images = _imageUrls(booking);
    final type = '${booking['businessType'] ?? ''}'.trim();
    final category = '${booking['category'] ?? ''}'.trim();
    final rate = _venueRateLabel(booking);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D192B50),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
            child: Stack(
              children: [
                _BookingGallery(images: images),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _imageBadge(
                    type.isEmpty ? 'Booking' : type,
                    AppColors.surface.withValues(alpha: .94),
                    AppColors.ink,
                  ),
                ),
                if (category.isNotEmpty)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _imageBadge(
                      category,
                      AppColors.accent,
                      Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppText(
                        '${booking['venueName'] ?? 'Venue'}',
                        style:  TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                       localize: true,),
                    ),
                    _statusPill(status),
                  ],
                ),
                const SizedBox(height: 6),
                AppText(
                  _statusGuidance(status),
                  key: ValueKey('booking-status-guidance-$status'),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                _venueDetail(Icons.location_on_outlined, booking['address']),
                _venueDetail(Icons.access_time_rounded, booking['hours']),
                if (rate.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _infoPanel('Venue rate', rate),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showBookingInfo(booking),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const AppText('View booking details', localize: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side:  BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (status == 'finished' && booking.id != null) ...[
                  const SizedBox(height: 12),
                  _ratingAction(booking),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) => switch (status.toLowerCase()) {
    'pending' => 'Awaiting approval',
    'approved' => 'Confirmed',
    'finished' || 'done' || 'completed' => 'Completed',
    'expired' => 'Expired',
    'cancelled' => 'Cancelled',
    _ =>
      status
          .split(RegExp(r'[_\s]+'))
          .where((part) => part.isNotEmpty)
          .map(
            (part) =>
                '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
          )
          .join(' '),
  };

  Color _statusColor(String status) => switch (status.toLowerCase()) {
    'pending' => const Color(0xFFB85C00),
    'approved' ||
    'finished' ||
    'done' ||
    'completed' => const Color(0xFF18794E),
    'expired' || 'cancelled' => const Color(0xFFB42318),
    _ => const Color(0xFF475467),
  };

  String _statusGuidance(String status) => switch (status.toLowerCase()) {
    'pending' =>
      'Waiting for the venue to approve your request. Not confirmed yet.',
    'approved' => 'Confirmed by the venue. Your booking is ready.',
    'finished' || 'done' || 'completed' => 'This booking has been completed.',
    'expired' => 'This request expired before it was confirmed.',
    'cancelled' => 'This booking was cancelled and is no longer reserved.',
    _ => 'Check the booking details or contact the venue for an update.',
  };

  Widget _statusPill(String status) {
    final color = _statusColor(status);
    return Container(
      key: ValueKey('booking-status-pill-${status.toLowerCase()}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: AppText(
        _statusLabel(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _imageBadge(String text, Color background, Color foreground) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: AppText(
            text,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );

  Widget _ratingAction(Booking booking) {
    final existingRating = booking.reviewRating;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: existingRating == null
            ? () => _showRatingDialog(booking)
            : null,
        icon: Icon(
          existingRating == null
              ? Icons.star_outline_rounded
              : Icons.star_rounded,
        ),
        label: AppText(
          existingRating == null
              ? 'Rate this booking'
              : 'You rated this $existingRating/5',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: BorderSide(color: AppColors.accent.withValues(alpha: .55)),
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _showRatingDialog(Booking booking) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => _BookingRatingDialog(booking: booking, api: _api),
    );
    if (!mounted || submitted != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: AppText('Your rating was submitted.', localize: true)));
    await _refresh();
  }

  Widget _infoPanel(String label, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.page,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xFFE7EBF1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label.toUpperCase(),
          style:  TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 3),
        AppText(
          value,
          style:  TextStyle(
            color: AppColors.ink,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  String _venueRateLabel(Booking booking) {
    final periods = booking['ratePeriods'];
    if (periods is List && periods.isNotEmpty) {
      final labels = periods.whereType<Map>().map((period) {
        final start = period['start'] ?? '';
        final end = period['end'] ?? '';
        final price = _amount(period['pricePerHour']);
        return '$start - $end · PHP ${price.toStringAsFixed(2)} / hr';
      }).toList();
      if (labels.isNotEmpty) return labels.join('\n');
    }

    final value = _amount(booking['venuePricePerHour']);
    if (value > 0) return 'PHP ${value.toStringAsFixed(2)} / hr';
    final fee = _amount(booking['eventFee']);
    return fee > 0 ? 'PHP ${fee.toStringAsFixed(2)} per booking' : '';
  }

  double _amount(dynamic value) {
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }

  Future<void> _showBookingInfo(Booking booking) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.page,
          appBar: AppBar(
            title: const AppText(
              'Booking details',
              style: TextStyle(fontWeight: FontWeight.w900),
             localize: true,),
            backgroundColor: AppColors.page,
            foregroundColor: AppColors.ink,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: _bookingDetailsCard(booking),
          ),
        ),
      ),
    );
  }

  Widget _bookingDetailsCard(Booking booking) {
    final status = '${booking['status'] ?? 'pending'}';
    final total = _amount(booking['total']);
    final downpayment = _amount(booking['downpayment']);
    final fitnessPlanType = '${booking['fitnessPlanType'] ?? ''}';
    final isEvent = '${booking['businessType']}'.toLowerCase() == 'event';
    final eventType = '${booking['eventType'] ?? ''}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BookingGallery(images: _imageUrls(booking)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppText(
                  '${booking['venueName'] ?? 'Venue'}',
                  style:  TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                 localize: true,),
              ),
              const SizedBox(width: 8),
              _statusPill(status),
            ],
          ),
          const SizedBox(height: 6),
          AppText(
            _statusGuidance(status),
            style: TextStyle(
              color: _statusColor(status),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          AppText(
            _scheduleLabel(booking),
            style:  TextStyle(
              fontSize: 15,
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          AppText(
            '${fitnessPlanType.isNotEmpty
                ? 'First visit'
                : isEvent
                ? '${booking['players']} guests'
                : '${booking['players']} players'} · '
            '${booking['paymentMethod']}',
            style: TextStyle(fontSize: 14, color: AppColors.muted),
           localize: true,),
          if (isEvent && eventType.isNotEmpty) ...[
            const SizedBox(height: 6),
            AppText(
              'Event: $eventType',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
             localize: true,),
          ],
          if (fitnessPlanType.isNotEmpty) ...[
            const SizedBox(height: 6),
            AppText(
              '${booking['fitnessCategory']} · '
                      '${booking['fitnessPlanType']}'
                  .toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
             localize: true,),
            AppText(
              'Plan: PHP ${_amount(booking['fitnessPlanPrice']).toStringAsFixed(2)}'
              '${'${booking['fitnessCoachName'] ?? ''}'.isEmpty ? '' : '\nCoach: ${booking['fitnessCoachName']} · PHP ${_amount(booking['fitnessCoachPrice']).toStringAsFixed(2)}'}',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
             localize: true,),
          ],
          const SizedBox(height: 10),
          AppText(
            'Total: PHP ${total.toStringAsFixed(2)}',
            style:  TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
           localize: true,),
          if (_amount(booking['extraPlayerCharge']) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AppText(
                'Includes extra-player fee: PHP '
                '${_amount(booking['extraPlayerCharge']).toStringAsFixed(2)}',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
               localize: true,),
            ),
          const SizedBox(height: 2),
          AppText(
            '${fitnessPlanType.isNotEmpty ? 'One-time plan total' : 'Downpayment'}: PHP '
            '${fitnessPlanType.isNotEmpty ? total.toStringAsFixed(2) : downpayment.toStringAsFixed(2)}',
            style:  TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
           localize: true,),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
           AppText(
            'Venue information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
           localize: true,),
          const SizedBox(height: 8),
          _venueDetail(
            Icons.person_outline_rounded,
            _labelValue('Venue owner', booking['ownerName']),
          ),
          _venueDetail(Icons.location_on_outlined, booking['address']),
          _venueDetail(
            Icons.sports_rounded,
            _labelValue(
              fitnessPlanType.isNotEmpty ? 'Fitness category' : 'Sport',
              booking['sportType'] ?? booking['category'],
            ),
          ),
          if (fitnessPlanType.isEmpty)
            _venueDetail(
              Icons.grid_view_rounded,
              _labelValue(
                'Booked area',
                booking['occupiesFullStudio'] == true
                    ? 'Whole studio'
                    : 'Slot ${booking['slotNumber'] ?? '—'}',
              ),
            ),
          _venueDetail(
            Icons.business_center_outlined,
            _labelValue('Type', booking['facilityType']),
          ),
          _venueDetail(
            Icons.grid_3x3,
            _labelValue('Details', booking['details']),
          ),
          _venueDetail(
            Icons.access_time,
            _labelValue('Hours', booking['hours']),
          ),
          _venueDetail(
            Icons.check_circle_outline,
            _labelValue('Availability', booking['availability']),
          ),
          const SizedBox(height: 10),
          _bookingField(
            'Rate',
            'PHP ${_amount(booking['pricePerHour'] ?? booking['venuePricePerHour']).toStringAsFixed(2)} / hr',
          ),
          const SizedBox(height: 12),
           AppText(
            'Booking information you entered',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
           localize: true,),
          const SizedBox(height: 8),
          _bookingField('Date', booking['date']),
          _bookingField('Start time', _formatTime(booking['startTime'])),
          _bookingField(
            'Duration',
            '${_amount(booking['durationHours']).toStringAsFixed(0)} hour(s)',
          ),
          _bookingField('Players', booking['players']),
          _bookingField('Payment method', booking['paymentMethod']),
        ],
      ),
    );
  }

  List<String> _imageUrls(Booking booking) {
    final images = <String>[];
    final raw = booking['imageUrls'];
    if (raw is List) {
      images.addAll(raw.map((value) => '$value').where(_validImage));
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          images.addAll(decoded.map((value) => '$value').where(_validImage));
        }
      } on FormatException {
        if (_validImage(raw)) images.add(raw.trim());
      }
    }

    final direct = '${booking['imageUrl'] ?? ''}'.trim();
    if (images.isEmpty && _validImage(direct)) {
      try {
        final decoded = jsonDecode(direct);
        if (decoded is List) {
          images.addAll(decoded.map((value) => '$value').where(_validImage));
        } else {
          images.add(direct);
        }
      } on FormatException {
        images.add(direct);
      }
    }
    return images.isEmpty ? ['assets/court/pickle-court.jpg'] : images;
  }

  bool _validImage(String value) {
    final image = value.trim();
    return image.isNotEmpty && image != 'null';
  }

  Widget _venueDetail(IconData icon, dynamic value) {
    final text = '$value'.trim();
    if (value == null || text.isEmpty || text == 'null') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: AppText(
              text,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  String _labelValue(String label, dynamic value) {
    final text = '$value'.trim();
    return value == null || text.isEmpty || text == 'null'
        ? ''
        : '$label: $text';
  }

  Widget _bookingField(String label, dynamic value) {
    final text = '$value'.trim();
    if (value == null || text.isEmpty || text == 'null') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: AppText(
              label,
              style:  TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: AppText(
              text,
              style:  TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _scheduleLabel(Booking booking) {
    final date = '${booking['date'] ?? ''}';
    final start = _formatTime(booking['startTime']);
    final duration = _amount(booking['durationHours']);
    final end = _endTime(booking['startTime'], duration);
    if (end == null) {
      return '$date · $start · ${duration.toStringAsFixed(0)} hour(s)';
    }
    return '$date · $start - $end · '
        '${duration.toStringAsFixed(0)} hour(s)';
  }

  String _formatTime(dynamic value) {
    final raw = '$value'.trim();
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return raw;
    return _clockLabel(hour, minute);
  }

  String? _endTime(dynamic value, double duration) {
    final parts = '$value'.trim().split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || duration <= 0) return null;
    final end = DateTime(
      2024,
      1,
      1,
      hour,
      minute,
    ).add(Duration(minutes: (duration * 60).round()));
    return _clockLabel(end.hour % 24, end.minute);
  }

  String _clockLabel(int hour, int minute) {
    final normalizedHour = hour % 24;
    final period = normalizedHour >= 12 ? 'PM' : 'AM';
    final displayHour = normalizedHour % 12 == 0 ? 12 : normalizedHour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }
}

class _BookingRatingDialog extends StatefulWidget {
  const _BookingRatingDialog({required this.booking, required this.api});

  final Booking booking;
  final AuthApi api;

  @override
  State<_BookingRatingDialog> createState() => _BookingRatingDialogState();
}

class _BookingRatingDialogState extends State<_BookingRatingDialog> {
  final _comment = TextEditingController();
  var _rating = 0;
  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final token = (await AppSession.load()).apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException(
          'Please sign in to rate this booking.',
          401,
        );
      }
      final bookingId = widget.booking.id;
      if (bookingId == null) {
        throw const AuthApiException(
          'This booking cannot be rated because its ID is missing.',
          400,
        );
      }
      await widget.api.submitCustomerReview(
        token: token,
        bookingId: bookingId,
        rating: _rating,
        comment: _comment.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: AppText('Rate ${widget.booking.venue.name}', localize: true),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
         AppText(
          'How was your completed booking?',
          style: TextStyle(color: AppColors.muted),
         localize: true,),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                tooltip: appLanguageText(
                  'Rate $star out of 5 stars',
                  'Rate $star out of 5 stars',
                ),
                onPressed: _submitting
                    ? null
                    : () => setState(() => _rating = star),
                icon: Icon(
                  star <= _rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 34,
                ),
              ),
          ],
        ),
        TextField(
          controller: _comment,
          maxLines: 3,
          decoration: InputDecoration(labelText: appLanguageText('Comment (optional)', 'Comment (optional)')),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          AppText(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        child: const AppText('Cancel', localize: true),
      ),
      FilledButton(
        onPressed: _rating == 0 || _submitting ? null : _submit,
        child: const AppText('Submit rating', localize: true),
      ),
    ],
  );
}
