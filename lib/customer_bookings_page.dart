import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'app_session.dart';
import 'app_design_system.dart';
import 'auth_api.dart';
import 'core/business_type.dart';
import 'event_dashboard.dart';
import 'fitness_dashboard.dart';
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
    final unreadBookings = bookings.where((booking) {
      final status = _bookingStatus(booking);
      return status == 'approved' ||
          status == 'finished' ||
          status == 'done' ||
          status == 'completed' ||
          status == 'expired' ||
          status == 'cancelled';
    }).toList();
    _unreadBookingCount = unreadBookings
        .where((booking) {
          return !session.bookingStatusBannerDismissed(
            _bookingStatusKey(booking),
          );
        })
        .length;
    for (final booking in unreadBookings) {
      await session.dismissBookingStatusBanner(_bookingStatusKey(booking));
    }
    _unreadBookingCount = 0;
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
                        const SkeletonBlock(height: 148, borderRadius: 12),
                        const SizedBox(height: 6),
                        const SkeletonBlock(width: 180, height: 18),
                        const SizedBox(height: 6),
                        const SkeletonBlock(width: 125, height: 13),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Expanded(
                              child: SkeletonBlock(
                                height: 38,
                                borderRadius: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: SkeletonBlock(
                                height: 38,
                                borderRadius: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (index < 2) const SizedBox(height: 6),
                ],
              ],
            );
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: AppText(
                    'Could not load bookings: ${snapshot.error}',
                    localize: true,
                  ),
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
                      style: TextStyle(color: AppColors.ink),
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
                      Tab(
                        child: AppText(
                          'Pending (${pending.length})',
                          localize: true,
                        ),
                      ),
                      Tab(
                        child: AppText(
                          'Approved (${approved.length})',
                          localize: true,
                        ),
                      ),
                      Tab(
                        child: AppText(
                          'Completed (${completed.length})',
                          localize: true,
                        ),
                      ),
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
            : AppColors.accentForeground,
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
                      '${_statusLabel(status)}.'
                : 'Booking at ${booking['venueName'] ?? 'your venue'} was approved '
                      'for ${booking['date']} at ${_formatTime(booking['startTime'])}.',
            localize: true,
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _refresh,
          child: const AppText('Refresh', localize: true),
        ),
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
                Center(child: AppText(emptyMessage, localize: true)),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, index) => const SizedBox(height: 6),
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
        builder: (_) => switch (BusinessTypeParser.parse(widget.businessType)) {
          BusinessType.event => EventDashboardPage(
            onLogout: widget.onLogout,
            api: widget.api,
            initialUserPosition: widget.initialUserPosition,
          ),
          BusinessType.fitness => FitnessDashboardPage(
            onLogout: widget.onLogout,
            api: widget.api,
            initialUserPosition: widget.initialUserPosition,
          ),
          _ => NewsFeedPage(
            onLogout: widget.onLogout,
            initialUserPosition: widget.initialUserPosition,
            businessType: widget.businessType ?? 'Sports',
          ),
        },
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
                      AppColors.onAccent,
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
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                        localize: true,
                      ),
                    ),
                    _statusPill(status),
                  ],
                ),
                const SizedBox(height: 6),
                AppText(
                  _statusGuidance(status),
                  localize: true,
                  key: ValueKey('booking-status-guidance-$status'),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                if (status.toLowerCase() == 'cancelled' &&
                    booking.paymentRefundStatus != 'not_requested') ...[
                  const SizedBox(height: 6),
                  AppText(
                    _paymentRefundGuidance(booking.paymentRefundStatus),
                    localize: true,
                    style: TextStyle(
                      color: booking.paymentRefundStatus == 'failed'
                          ? AppColors.errorText
                          : AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                _venueDetail(Icons.location_on_outlined, booking['address']),
                _venueDetail(Icons.access_time_rounded, booking['hours']),
                if (rate.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _infoPanel('Venue rate', rate),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (status.toLowerCase() == 'pending' ||
                        status.toLowerCase() == 'approved') ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          key: ValueKey(
                            'customer-booking-cancel-${booking.id}',
                          ),
                          onPressed: booking.id == null
                              ? null
                              : () => _cancelCustomerBooking(booking),
                          icon: const Icon(Icons.event_busy_outlined, size: 16),
                          label: const AppText('Cancel', localize: true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.errorText,
                            side: BorderSide(color: AppColors.errorText),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        key: ValueKey(
                          'customer-booking-details-${booking.id}',
                        ),
                        onPressed: () => _showBookingInfo(booking),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const AppText('Details', localize: true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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

  String _localizedStatusLabel(String status) {
    final label = _statusLabel(status);
    return appLanguageText(
      label,
      label,
      languageCode: Localizations.localeOf(context).languageCode,
    );
  }

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
        _localizedStatusLabel(status),
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
            localize: true,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );

  Widget _ratingAction(
    Booking booking, {
    bool closeDetailsOnSubmit = false,
  }) {
    final existingRating = booking.reviewRating;
    final button = OutlinedButton.icon(
        onPressed: existingRating == null
            ? () => _showRatingDialog(
                booking,
                closeDetailsOnSubmit: closeDetailsOnSubmit,
              )
            : null,
        icon: Icon(
          existingRating == null
              ? Icons.star_outline_rounded
              : Icons.star_rounded,
          size: 16,
        ),
        label: AppText(
          existingRating == null ? 'Review' : 'Reviewed',
          localize: true,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentForeground,
          side: BorderSide(
            color: AppColors.accentForeground.withValues(alpha: .55),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
    );
    return existingRating == null
        ? button
        : Tooltip(
            message: 'You rated this $existingRating/5',
            child: button,
          );
  }

  Future<void> _showRatingDialog(
    Booking booking, {
    bool closeDetailsOnSubmit = false,
  }) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => _BookingRatingDialog(booking: booking, api: _api),
    );
    if (!mounted || submitted != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: AppText('Your rating was submitted.', localize: true),
      ),
    );
    await _refresh();
    if (closeDetailsOnSubmit && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteCompletedBooking(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Delete completed booking?', localize: true),
        content: const AppText(
          'This permanently deletes the booking and its attendance and review '
          'records. This action cannot be undone.',
          localize: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Keep booking', localize: true),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Delete permanently', localize: true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = (await AppSession.load()).apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException(
          'Please sign in again to delete this booking.',
          401,
        );
      }
      final bookingId = booking.id;
      if (bookingId == null) {
        throw const AuthApiException(
          'This booking cannot be deleted right now.',
          400,
        );
      }
      await _api.deleteCustomerCompletedBooking(
        token: token,
        bookingId: bookingId,
      );
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            'Completed booking permanently deleted.',
            localize: true,
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            'Could not delete completed booking: $error',
            localize: true,
          ),
        ),
      );
    }
  }

  Future<void> _cancelCustomerBooking(Booking booking) async {
    final paymentWarning = _cancellationPaymentWarning(booking);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Cancel this booking?', localize: true),
        content: AppText(
          'You can cancel this booking at any time before it is completed. '
          '$paymentWarning',
          localize: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Keep booking', localize: true),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Cancel booking', localize: true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = (await AppSession.load()).apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException(
          'Please sign in again to cancel this booking.',
          401,
        );
      }
      final bookingId = booking.id;
      if (bookingId == null) {
        throw const AuthApiException(
          'This booking cannot be cancelled right now.',
          400,
        );
      }
      final result = await _api.cancelCustomerBooking(
        token: token,
        bookingId: bookingId,
      );
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            '${result['message'] ?? 'Booking cancelled.'}',
            localize: true,
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText('Could not cancel booking: $error', localize: true),
        ),
      );
    }
  }

  String _cancellationPaymentWarning(Booking booking) {
    if (booking.paymentMethod == 'cash_on_arrival' && booking.paidAmount > 0) {
      return 'Cash already collected cannot be voided by the app; it must be '
          'returned manually.';
    }
    if (booking.paymentMethod == 'cash_on_arrival') {
      return 'Any cash already collected must be returned manually; the app '
          'cannot void cash payments.';
    }
    if (booking.paymentStatus.toLowerCase() != 'paid' ||
        booking.paymentMethod != 'online') {
      return 'Any online payment completed after cancellation will be handled '
          'under the same cancellation policy.';
    }
    final start = _bookingStartDateTime(booking);
    if (start == null) {
      return 'The payment refund eligibility will be checked using the '
          'booking start time.';
    }
    final timeUntilStart = start.difference(DateTime.now());
    if (timeUntilStart >= const Duration(hours: 6)) {
      return 'The booking is at least 6 hours away, so the online payment '
          'refund will be requested.';
    }
    return 'Because the booking starts in less than 6 hours or has already '
        'started, the online payment cannot be voided or refunded.';
  }

  DateTime? _bookingStartDateTime(Booking booking) {
    final time = booking.startTime.length >= 5
        ? booking.startTime.substring(0, 5)
        : booking.startTime;
    return DateTime.tryParse('${booking.date}T$time');
  }

  String _paymentRefundGuidance(String status) => switch (status) {
    'pending' => 'Online payment refund is being processed.',
    'succeeded' => 'Online payment refund completed.',
    'failed' =>
      'Online payment refund could not be confirmed. Please contact support.',
    'not_eligible' => 'Payment was not refunded because the booking starts within 6 hours or has started.',
    'manual_cash_return' => 'Cash already collected must be returned manually; it cannot be voided by the app.',
    _ => '',
  };

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
          appLanguageText(
            label,
            label,
            languageCode: Localizations.localeOf(context).languageCode,
          ).toUpperCase(),
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 6),
        AppText(
          value,
          localize: true,
          style: TextStyle(
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
        return '$start - $end · \u{20B1} ${price.toStringAsFixed(2)} / hr';
      }).toList();
      if (labels.isNotEmpty) return labels.join('\n');
    }

    final value = _amount(booking['venuePricePerHour']);
    if (value > 0) return '\u{20B1} ${value.toStringAsFixed(2)} / hr';
    final fee = _amount(booking['eventFee']);
    return fee > 0 ? '\u{20B1} ${fee.toStringAsFixed(2)} per booking' : '';
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
              localize: true,
            ),
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
    final paidAmount = booking.paidAmount;
    final paymentStatus = booking.paymentStatus.toLowerCase();
    final isCashOnArrival = booking.paymentMethod == 'cash_on_arrival';
    final remainingBalance = (total - paidAmount).clamp(0, total).toDouble();
    final fitnessPlanType = '${booking['fitnessPlanType'] ?? ''}';
    final coachName = '${booking['fitnessCoachName'] ?? ''}';
    final coachDurationMonths = int.tryParse(
      '${booking['fitnessCoachDurationMonths'] ?? ''}',
    );
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
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: AppText(
                  '${booking['venueName'] ?? 'Venue'}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                  localize: true,
                ),
              ),
              const SizedBox(width: 6),
              _statusPill(status),
            ],
          ),
          const SizedBox(height: 6),
          AppText(
            _statusGuidance(status),
            localize: true,
            style: TextStyle(
              color: _statusColor(status),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          AppText(
            _scheduleLabel(booking),
            localize: true,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          AppText(
            '${fitnessPlanType.isNotEmpty
                ? 'First visit'
                : isEvent
                ? '${booking['players']} guests'
                : '${booking['players']} players'} · '
            '${booking['paymentMethod']}',
            style: TextStyle(fontSize: 14, color: AppColors.muted),
            localize: true,
          ),
          if (isEvent && eventType.isNotEmpty) ...[
            const SizedBox(height: 6),
            AppText(
              'Event: $eventType',
              localize: true,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
          ],
          if (fitnessPlanType.isNotEmpty) ...[
            const SizedBox(height: 6),
            AppText(
              '${booking['fitnessCategory']} · ${booking['fitnessPlanType']}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
              localize: true,
            ),
            AppText(
              'Plan duration: ${_fitnessPlanDuration(fitnessPlanType)}',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
              localize: true,
            ),
            AppText(
              coachName.isEmpty
                  ? 'Plan: \u{20B1} ${_amount(booking['fitnessPlanPrice']).toStringAsFixed(2)}'
                  : 'Plan: \u{20B1} ${_amount(booking['fitnessPlanPrice']).toStringAsFixed(2)}\n'
                        'Coach: $coachName'
                        '${coachDurationMonths == null ? '' : ' · ${coachDurationMonths == 1 ? '1 month' : '$coachDurationMonths months'}'}'
                        ' · \u{20B1} ${_amount(booking['fitnessCoachPrice']).toStringAsFixed(2)}',
              localize: true,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 6),
          AppText(
            'Total: \u{20B1} ${total.toStringAsFixed(2)}',
            localize: true,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          if (_amount(booking['extraPlayerCharge']) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AppText(
                'Includes extra-player fee: ? '
                '${_amount(booking['extraPlayerCharge']).toStringAsFixed(2)}',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
                localize: true,
              ),
            ),
          const SizedBox(height: 6),
          AppText(
            isCashOnArrival && paymentStatus == 'partial'
                ? 'Cash downpayment received: \u{20B1} ${paidAmount.toStringAsFixed(2)}'
                : isCashOnArrival && paymentStatus != 'paid'
                ? 'Cash downpayment due at venue: \u{20B1} ${downpayment.toStringAsFixed(2)}'
                : paymentStatus == 'paid'
                ? 'Amount paid: \u{20B1} ${paidAmount.toStringAsFixed(2)}'
                : '${fitnessPlanType.isNotEmpty ? 'One-time plan total' : 'Amount due'}: ? '
                      '${total.toStringAsFixed(2)}',
            localize: true,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          if (isCashOnArrival && paymentStatus != 'paid')
            AppText(
              paymentStatus == 'partial'
                  ? 'Remaining cash balance due on arrival: \u{20B1} ${remainingBalance.toStringAsFixed(2)}'
                  : 'Remaining cash balance after downpayment: ? '
                        '${(total - downpayment).clamp(0, total).toStringAsFixed(2)}',
              localize: true,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          const SizedBox(height: 6),
          const Divider(height: 1),
          const SizedBox(height: 6),
          AppText(
            'Venue information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
            localize: true,
          ),
          const SizedBox(height: 6),
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
          const SizedBox(height: 6),
          _bookingField(
            'Rate',
            '\u{20B1} ${_amount(booking['pricePerHour'] ?? booking['venuePricePerHour']).toStringAsFixed(2)} / hr',
          ),
          const SizedBox(height: 6),
          AppText(
            'Booking information you entered',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
            localize: true,
          ),
          const SizedBox(height: 6),
          _bookingField('Date', booking['date']),
          _bookingField('Start time', _formatTime(booking['startTime'])),
          _bookingField(
            fitnessPlanType.isNotEmpty ? 'First visit session' : 'Duration',
            '${_amount(booking['durationHours']).toStringAsFixed(0)} hour(s)',
          ),
          if (fitnessPlanType.isNotEmpty)
            _bookingField(
              'Plan duration',
              _fitnessPlanDuration(fitnessPlanType),
            ),
          _bookingField('Players', booking['players']),
          _bookingField('Payment method', booking['paymentMethod']),
          if (booking.checkedInAt case final checkedInAt?)
            _bookingField('Venue arrival', 'Checked in · $checkedInAt')
          else if (status.toLowerCase() == 'approved')
            _bookingField('Venue arrival', 'Not checked in yet'),
          if (const {
            'finished',
            'done',
            'completed',
          }.contains(status.toLowerCase())) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                if (booking.id != null) ...[
                  Expanded(
                    child: _ratingAction(
                      booking,
                      closeDetailsOnSubmit: true,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    key: ValueKey('customer-booking-delete-${booking.id}'),
                    onPressed: () => _deleteCompletedBooking(booking),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const AppText('Delete', localize: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.errorText,
                      side: BorderSide(color: AppColors.errorText),
                      padding: AppSpacing.buttonPadding,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
          const SizedBox(width: 6),
          Expanded(
            child: AppText(
              text,
              localize: true,
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
              localize: true,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: AppText(
              text,
              localize: true,
              style: TextStyle(
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
    final fitnessPlanType = '${booking['fitnessPlanType'] ?? ''}';
    final sessionLabel = fitnessPlanType.isNotEmpty
        ? 'First visit session'
        : 'Duration';
    if (end == null) {
      return '$date · $start · $sessionLabel: '
          '${duration.toStringAsFixed(0)} hour(s)';
    }
    return '$date · $start - $end · $sessionLabel: '
        '${duration.toStringAsFixed(0)} hour(s)';
  }

  String _fitnessPlanDuration(String planType) => switch (planType) {
    'monthly' => '1 month',
    'yearly' => '1 year',
    'session' => '1 session',
    _ => planType,
  };

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
          localize: true,
        ),
        if (_rating == 0) ...[
          const SizedBox(height: 4),
          AppText(
            'Choose a star rating to continue.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
            localize: true,
          ),
        ],
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                tooltip: appLanguageText(
                  '$star stars',
                  '$star stars',
                  languageCode: Localizations.localeOf(context).languageCode,
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
          decoration: InputDecoration(
            labelText: appLanguageText(
              'Comment (optional)',
              'Comment (optional)',
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
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
