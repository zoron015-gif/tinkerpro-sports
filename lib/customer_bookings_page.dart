import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_session.dart';
import 'auth_api.dart';
import 'messages_dashboard.dart';
import 'profile_dashboard.dart';
import 'saved_dashboard.dart';
import 'news_feed.dart';
import 'models/booking.dart';

class CustomerBookingsPage extends StatefulWidget {
  const CustomerBookingsPage({super.key, this.onLogout});

  final Future<void> Function(BuildContext context)? onLogout;

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
        height: 170,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: multiple ? 10000 : 1,
              onPageChanged: (page) {
                setState(() => _index = page % widget.images.length);
              },
              itemBuilder: (_, page) => InteractiveViewer(
                minScale: 1,
                maxScale: 3,
                child: Image(
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
            ),
            if (multiple) ...[
              Positioned(
                left: 6,
                child: _galleryButton(
                  Icons.chevron_left,
                  () => _controller.previousPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  ),
                ),
              ),
              Positioned(
                right: 6,
                child: _galleryButton(
                  Icons.chevron_right,
                  () => _controller.nextPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .65),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      '${_index + 1} of ${widget.images.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _galleryButton(IconData icon, VoidCallback onPressed) {
    return IconButton.filled(
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: .58),
        foregroundColor: Colors.white,
      ),
      onPressed: onPressed,
      icon: Icon(icon),
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
  late Future<List<Booking>> _bookings;
  int _unreadBookingCount = 0;
  int _unreadMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _bookings = _loadBookings();
  }

  Future<List<Booking>> _loadBookings() async {
    final token = (await AppSession.load()).apiToken;
    if (token == null || token.isEmpty) return [];
    final bookings = await AuthApi().customerBookingModels(token);
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
      final conversations = await AuthApi().conversations(token);
      _unreadMessageCount = conversations.fold<int>(
        0,
        (total, conversation) =>
            total + ((conversation['unreadCount'] as num?)?.toInt() ?? 0),
      );
    } on Exception {
      _unreadMessageCount = 0;
    }
    return bookings;
  }

  Future<void> _refresh() async {
    setState(() => _bookings = _loadBookings());
    await _bookings;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Bookings'),
        backgroundColor: const Color(0xFFF7F9FC),
      ),
      body: FutureBuilder<List<Booking>>(
        future: _bookings,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load bookings: ${snapshot.error}'),
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
                if (approved.isNotEmpty || completed.isNotEmpty)
                  _bookingStatusBanner(approved, completed),
                Material(
                  color: Colors.white,
                  child: TabBar(
                    labelColor: const Color(0xFF192B50),
                    unselectedLabelColor: const Color(0xFF68748A),
                    indicatorColor: const Color(0xFFFF8200),
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
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFFFE8D2),
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        child: NavigationBar(
          height: 72,
          elevation: 0,
          selectedIndex: 3,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            if (index == 3) return;
            if (index == 0) {
              _openExplore();
              return;
            }
            if (index == 1) {
              _replaceWith(
                MaterialPageRoute(
                  builder: (_) => SavedDashboardPage(onLogout: widget.onLogout),
                ),
              );
              return;
            }
            if (index == 2) {
              _replaceWith(
                MaterialPageRoute(
                  builder: (_) => const MessagesDashboardPage(),
                ),
              );
              return;
            }
            _replaceWith(
              MaterialPageRoute(
                builder: (_) => ProfileDashboardPage(onLogout: widget.onLogout),
              ),
            );
          },
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.location_on_outlined, size: 24),
              selectedIcon: Icon(Icons.location_on_rounded, size: 24),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border_rounded, size: 24),
              selectedIcon: Icon(Icons.favorite_rounded, size: 24),
              label: 'Saved',
            ),
            NavigationDestination(
              icon: _notificationIcon(Icons.send_outlined, _unreadMessageCount),
              selectedIcon: _notificationIcon(
                Icons.send_rounded,
                _unreadMessageCount,
              ),
              label: 'Messages',
            ),
            NavigationDestination(
              icon: _notificationIcon(
                Icons.calendar_today_outlined,
                _unreadBookingCount,
              ),
              selectedIcon: _notificationIcon(
                Icons.calendar_today_rounded,
                _unreadBookingCount,
              ),
              label: 'Bookings',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, size: 24),
              selectedIcon: Icon(Icons.person_rounded, size: 24),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  String _bookingStatus(Booking booking) => booking.status;

  Widget _bookingStatusBanner(List<Booking> approved, List<Booking> completed) {
    final booking = completed.isNotEmpty ? completed.first : approved.first;
    final status = _bookingStatus(booking);
    final finished = {
      'finished',
      'done',
      'completed',
      'expired',
      'cancelled',
    }.contains(status);
    return MaterialBanner(
      backgroundColor: finished
          ? const Color(0xFFE7F6EC)
          : const Color(0xFFFFF1E3),
      leading: Icon(
        finished ? Icons.check_circle_rounded : Icons.event_available_rounded,
        color: finished ? Colors.green.shade700 : const Color(0xFFFF8200),
      ),
      content: Text(
        finished
            ? 'Booking at ${booking['venueName'] ?? 'your venue'} is $status.'
            : 'Booking at ${booking['venueName'] ?? 'your venue'} was approved '
                  'for ${booking['date']} at ${_formatTime(booking['startTime'])}.',
        style: const TextStyle(
          color: Color(0xFF101B33),
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [TextButton(onPressed: _refresh, child: const Text('Refresh'))],
    );
  }

  Widget _notificationIcon(IconData icon, int count) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: Icon(icon, size: 24),
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
                Center(child: Text(emptyMessage)),
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
        builder: (_) => NewsFeedPage(onLogout: widget.onLogout),
      ),
    );
  }

  Widget _bookingCard(Booking booking) {
    final status = '${booking['status'] ?? 'pending'}';
    final total = _amount(booking['total']);
    final downpayment = _amount(booking['downpayment']);
    final images = _imageUrls(booking);
    final amenities = _listValues(booking['amenities'] ?? booking['tags']);
    final type = '${booking['businessType'] ?? ''}'.trim();
    final category = '${booking['category'] ?? ''}'.trim();
    final facility = '${booking['facilityType'] ?? ''}'.trim();
    final rate = _venueRateLabel(booking);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E7EF)),
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
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: Image(
                image: _cardImageProvider(images.first),
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) => Image.asset(
                  'assets/court/pickle-court.jpg',
                  fit: BoxFit.cover,
                ),
              ),
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
                      child: Text(
                        '${booking['venueName'] ?? 'Venue'}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF101B33),
                        ),
                      ),
                    ),
                    _statusPill(status),
                  ],
                ),
                const SizedBox(height: 5),
                if (type.isNotEmpty || category.isNotEmpty)
                  Text(
                    [
                      category,
                      type,
                    ].where((value) => value.isNotEmpty).join(' · '),
                    style: const TextStyle(
                      color: Color(0xFF68748A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 12),
                _venueDetail(Icons.location_on_outlined, booking['address']),
                _venueDetail(Icons.business_outlined, facility),
                _venueDetail(Icons.access_time_rounded, booking['hours']),
                _venueDetail(
                  Icons.event_available_outlined,
                  booking['availability'],
                ),
                _venueDetail(Icons.notes_rounded, booking['details']),
                _venueDetail(
                  Icons.celebration_outlined,
                  _labelValue(
                    'Event types',
                    _listValues(booking['eventTypes']).join(', '),
                  ),
                ),
                _venueDetail(Icons.groups_outlined, _attendanceLabel(booking)),
                _venueDetail(
                  Icons.accessibility_new_outlined,
                  _labelValue(
                    'Accessibility',
                    _listValues(booking['accessibilityNeeds']).join(', '),
                  ),
                ),
                _venueDetail(
                  Icons.local_parking_outlined,
                  _labelValue(
                    'Parking',
                    _listValues(booking['parkingNeeds']).join(', '),
                  ),
                ),
                _venueDetail(
                  Icons.security_outlined,
                  _labelValue(
                    'Security',
                    _listValues(booking['securityNeeds']).join(', '),
                  ),
                ),
                if (amenities.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final amenity in amenities) _amenityChip(amenity),
                    ],
                  ),
                ],
                if (rate.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _infoPanel('Venue rate', rate),
                ],
                const SizedBox(height: 14),
                _infoPanel(
                  'Your booking',
                  '${_scheduleLabel(booking)}\n'
                      '${booking['players'] ?? 0} players · ${booking['paymentMethod'] ?? 'Payment pending'}',
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total PHP ${total.toStringAsFixed(2)}\n'
                        'Downpayment PHP ${downpayment.toStringAsFixed(2)}',
                        style: const TextStyle(
                          height: 1.55,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF101B33),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showBookingInfo(booking),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Details'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF192B50),
                        backgroundColor: const Color(0xFFF4F6FA),
                        minimumSize: const Size(102, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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

  Widget _statusPill(String status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE8D2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      status.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: .6,
        color: Color(0xFFB85C00),
      ),
    ),
  );

  Widget _amenityChip(String value) => Chip(
    label: Text(value),
    labelStyle: const TextStyle(
      color: Color(0xFFB85C00),
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
    backgroundColor: const Color(0xFFFFF3E6),
    side: BorderSide.none,
    visualDensity: VisualDensity.compact,
    padding: const EdgeInsets.symmetric(horizontal: 3),
  );

  Widget _infoPanel(String label, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xFFE7EBF1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF68748A),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF101B33),
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  List<String> _listValues(dynamic value) {
    if (value is List) {
      return value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty && item != 'null')
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return _listValues(decoded);
      } on FormatException {
        return value
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }

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

  String _attendanceLabel(Booking booking) {
    final min = booking['attendanceMin'];
    final max = booking['attendanceMax'];
    if (min == null && max == null) return '';
    return 'Estimated attendance: ${min ?? '?'} - ${max ?? '?'} guests';
  }

  ImageProvider _cardImageProvider(String image) {
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

  double _amount(dynamic value) {
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }

  Future<void> _showBookingInfo(Booking booking) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${booking['venueName'] ?? 'Venue'}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF101B33),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF20293A)),
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFF7F9FC),
                      ),
                      child: Text(
                        '${booking['status'] ?? 'pending'}'.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Color(0xFF101B33),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: _bookingDetailsCard(booking),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bookingDetailsCard(Booking booking) {
    final status = '${booking['status'] ?? 'pending'}';
    final total = _amount(booking['total']);
    final downpayment = _amount(booking['downpayment']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
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
                child: Text(
                  '${booking['venueName'] ?? 'Venue'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF101B33),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF20293A)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Color(0xFF101B33),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _scheduleLabel(booking),
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF101B33),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${booking['players']} players · ${booking['paymentMethod']}',
            style: const TextStyle(fontSize: 14, color: Color(0xFF4C5B72)),
          ),
          const SizedBox(height: 10),
          Text(
            'Total: PHP ${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF101B33),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Downpayment: PHP ${downpayment.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF101B33),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          const Text(
            'Venue information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF101B33),
            ),
          ),
          const SizedBox(height: 8),
          _venueDetail(
            Icons.person_outline_rounded,
            _labelValue('Venue owner', booking['ownerName']),
          ),
          _venueDetail(Icons.location_on_outlined, booking['address']),
          _venueDetail(
            Icons.sports_rounded,
            _labelValue('Sport', booking['category']),
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
          const Text(
            'Booking information you entered',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF101B33),
            ),
          ),
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
          Icon(icon, size: 16, color: const Color(0xFF68748A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF4C5B72)),
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
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF68748A)),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF101B33),
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
