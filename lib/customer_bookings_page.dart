import 'package:flutter/material.dart';

import 'app_session.dart';
import 'auth_api.dart';
import 'messages_dashboard.dart';
import 'profile_dashboard.dart';
import 'saved_dashboard.dart';
import 'sports.dart';
import 'event_dashboard.dart';
import 'fitness_dashboard.dart';

class CustomerBookingsPage extends StatefulWidget {
  const CustomerBookingsPage({super.key, this.onLogout});

  final Future<void> Function(BuildContext context)? onLogout;

  @override
  State<CustomerBookingsPage> createState() => _CustomerBookingsPageState();
}

class _CustomerBookingsPageState extends State<CustomerBookingsPage> {
  late Future<List<Map<String, dynamic>>> _bookings;

  @override
  void initState() {
    super.initState();
    _bookings = _loadBookings();
  }

  Future<List<Map<String, dynamic>>> _loadBookings() async {
    final token = (await AppSession.load()).apiToken;
    if (token == null || token.isEmpty) return [];
    return AuthApi().customerBookings(token);
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
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
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
            final bookings = snapshot.data ?? const [];
            if (bookings.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 180),
                  Center(child: Text('No bookings yet.')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _bookingCard(bookings[index]),
            );
          },
        ),
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
          destinations: const [
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
              icon: Icon(Icons.send_outlined, size: 24),
              selectedIcon: Icon(Icons.send_rounded, size: 24),
              label: 'Messages',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined, size: 22),
              selectedIcon: Icon(Icons.calendar_today_rounded, size: 22),
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

  void _replaceWith(Route<void> route) {
    Navigator.of(context).pushReplacement(route);
  }

  Future<void> _openExplore() async {
    final session = await AppSession.load();
    if (!mounted) return;
    final page = switch (session.lastBookingType) {
      'Event' => EventDashboardPage(onLogout: widget.onLogout),
      'Fitness & Wellness' => FitnessDashboardPage(onLogout: widget.onLogout),
      _ => SportsDashboardPage(onLogout: widget.onLogout),
    };
    _replaceWith(MaterialPageRoute(builder: (_) => page));
  }

  Widget _bookingCard(Map<String, dynamic> booking) {
    final status = '${booking['status'] ?? 'pending'}';
    final total = _amount(booking['total']);
    final downpayment = _amount(booking['downpayment']);
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${booking['venueName'] ?? 'Venue'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'View booking information',
                  onPressed: () => _showBookingInfo(booking),
                  icon: const Icon(Icons.info_outline_rounded),
                ),
                Chip(label: Text(status.toUpperCase())),
              ],
            ),
            const SizedBox(height: 8),
            Text(_scheduleLabel(booking)),
            Text('${booking['players']} players · ${booking['paymentMethod']}'),
            const SizedBox(height: 8),
            Text('Total: PHP ${total.toStringAsFixed(2)}'),
            Text('Downpayment: PHP ${downpayment.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  double _amount(dynamic value) {
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }

  Future<void> _showBookingInfo(Map<String, dynamic> booking) {
    final total = _amount(booking['total']);
    final downpayment = _amount(booking['downpayment']);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${booking['venueName'] ?? 'Venue'} information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoSection('Court information', [
                _infoLine('Type', booking['businessType']),
                _infoLine('Sport/category', booking['category']),
                _infoLine('Facility', booking['facilityType']),
                _infoLine('Address', booking['address']),
                _infoLine('Venue hours', booking['hours']),
                _infoLine('Availability', booking['availability']),
                _infoLine('Details', booking['details']),
              ]),
              const Divider(height: 28),
              _infoSection('Your booking', [
                _infoLine('Status', '${booking['status'] ?? 'Pending'}'),
                _infoLine('Schedule', _scheduleLabel(booking)),
                _infoLine('Players', booking['players']),
                _infoLine('Payment method', booking['paymentMethod']),
                _infoLine('Total', 'PHP ${total.toStringAsFixed(2)}'),
                _infoLine(
                  'Downpayment',
                  'PHP ${downpayment.toStringAsFixed(2)}',
                ),
                _infoLine(
                  'Remaining balance',
                  'PHP ${(total - downpayment).toStringAsFixed(2)}',
                ),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _infoSection(String title, List<Widget> lines) {
    final visible = lines.where((line) => line is! SizedBox).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...visible,
      ],
    );
  }

  Widget _infoLine(String label, dynamic value) {
    final text = '$value'.trim();
    if (value == null || text.isEmpty || text == 'null') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Color(0xFF101B33), fontSize: 14),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }

  String _scheduleLabel(Map<String, dynamic> booking) {
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
