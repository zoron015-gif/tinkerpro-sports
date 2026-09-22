import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_api.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'profile_dashboard.dart';
import 'reserve_dashboard.dart';
import 'saved_dashboard.dart';
import 'saved_items.dart';
import 'messages_dashboard.dart';
import 'customer_bookings_page.dart';

typedef EventVenue = ({
  String name,
  String type,
  String address,
  String facility,
  String hours,
  String availability,
  String price,
  String details,
  String image,
  List<String> images,
  List<String> tags,
  double latitude,
  double longitude,
  String visitUrl,
});

const _eventNavy = Color(0xFF192B50);
const _eventInk = Color(0xFF101B33);
const _eventOrange = Color(0xFFFF8200);
const _eventLine = Color(0xFFE2E7EF);
const _eventMuted = Color(0xFF68748A);
const _eventPage = Color(0xFFF7F9FC);
const _eventSoftOrange = Color(0xFFFFF1E4);

class EventDashboardPage extends StatefulWidget {
  const EventDashboardPage({super.key, this.onLogout});

  final Future<void> Function(BuildContext context)? onLogout;
  @override
  State<EventDashboardPage> createState() => _EventDashboardPageState();
}

class _EventDashboardPageState extends State<EventDashboardPage> {
  final _searchController = TextEditingController();
  final List<EventVenue> _merchantVenues = [];
  List<EventVenue> get _allVenues => _merchantVenues;

  String _area = 'All areas';
  String _type = 'All venues';
  final bool _filtersOpen = true;
  bool _locationLoading = false;
  Position? _position;
  final Set<String> _savedKeys = <String>{};
  final Map<String, int> _saveCounts = <String, int>{};
  String _sortBy = 'Featured';

  List<dynamic> get _filteredVenues {
    final query = _searchController.text.trim().toLowerCase();
    final venues = _allVenues.where((venue) {
      final search =
          query.isEmpty ||
          venue.name.toLowerCase().contains(query) ||
          venue.address.toLowerCase().contains(query);
      final area =
          _area == 'All areas' ||
          venue.address.toLowerCase().contains(_area.toLowerCase());
      final type = _type == 'All venues' || venue.type == _type;
      return search && area && type;
    }).toList();
    venues.sort((a, b) {
      switch (_sortBy) {
        case 'Name A-Z':
          return a.name.compareTo(b.name);
        case 'Price: low to high':
          return _eventPrice(a.price).compareTo(_eventPrice(b.price));
        case 'Price: high to low':
          return _eventPrice(b.price).compareTo(_eventPrice(a.price));
        case 'Nearest':
          if (_position == null) return 0;
          return _distanceSquared(
            _position!.latitude,
            _position!.longitude,
            a.latitude,
            a.longitude,
          ).compareTo(
            _distanceSquared(
              _position!.latitude,
              _position!.longitude,
              b.latitude,
              b.longitude,
            ),
          );
        default:
          return 0;
      }
    });
    return venues;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
    _loadSavedState();
    _loadMerchantBusinesses();
  }

  Future<void> _loadMerchantBusinesses() async {
    try {
      final rows = await AuthApi().customerBusinesses();
      if (!mounted) return;
      setState(
        () => _merchantVenues
          ..clear()
          ..addAll(
            rows
                .where(
                  (b) =>
                      '${b['businessType'] ?? b['business_type'] ?? ''}'
                          .trim()
                          .toLowerCase() ==
                      'event',
                )
                .map(_eventVenue),
          ),
      );
    } on Exception {
      // Ignore load failures and keep the dashboard empty until the next refresh.
    }
  }

  EventVenue _eventVenue(Map<String, dynamic> b) {
    final details = b['details'] as String? ?? '';
    final fee = _eventFee(b);
    final eventTypes = RegExp(
      r'^Event types:\s*(.*)$',
      multiLine: true,
    ).firstMatch(details)?.group(1)?.trim();
    return (
      name: b['name'] as String? ?? 'Business',
      type: eventTypes?.isNotEmpty == true
          ? eventTypes!
          : b['category'] as String? ?? 'Event',
      address: b['address'] as String? ?? '',
      facility:
          b['facilityType']?.toString() ??
          b['facility_type']?.toString() ??
          'Event venue',
      hours:
          b['hours']?.toString() ??
          b['opening_hours']?.toString() ??
          'Open hours',
      availability:
          b['availability']?.toString() ??
          b['availability_status']?.toString() ??
          '',
      price: 'PHP ${fee.toStringAsFixed(0)} / event',
      details: details.isNotEmpty
          ? details
          : b['facilityType'] as String? ?? 'Event venue',
      image: _merchantImage(b),
      images: _merchantImages(b),
      tags: _eventTags(b['tags']),
      latitude: 10.3157,
      longitude: 123.8854,
      visitUrl: '${b['visitUrl'] ?? b['visit_url'] ?? ''}',
    );
  }

  List<String> _eventTags(dynamic rawTags) {
    if (rawTags is List) {
      return rawTags
          .whereType<String>()
          .where((tag) => tag.isNotEmpty)
          .toList();
    }
    if (rawTags is String && rawTags.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTags);
        if (decoded is List) {
          return decoded
              .whereType<String>()
              .where((tag) => tag.isNotEmpty)
              .toList();
        }
      } on FormatException {
        return <String>[];
      }
    }
    return <String>[];
  }

  double _eventFee(Map<String, dynamic> business) {
    final value =
        business['eventFee'] ??
        business['event_fee'] ??
        business['pricePerHour'] ??
        business['price_per_hour'];
    if (value is num) return value.toDouble();
    return double.tryParse('$value'.replaceAll(',', '').trim()) ?? 0;
  }

  String _merchantImage(Map<String, dynamic> business) {
    return _merchantImages(business).first;
  }

  List<String> _merchantImages(Map<String, dynamic> business) {
    final images = <String>[];
    final raw = business['imageUrls'] ?? business['image_urls'];
    if (raw is List && raw.whereType<String>().isNotEmpty) {
      images.addAll(raw.whereType<String>().where((image) => image.isNotEmpty));
    }
    if (images.isEmpty && raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List && decoded.whereType<String>().isNotEmpty) {
          images.addAll(
            decoded.whereType<String>().where((image) => image.isNotEmpty),
          );
        }
      } on FormatException {
        images.add(raw);
      }
    }
    if (images.isEmpty) {
      final legacy = business['imageUrl'] as String?;
      if (legacy != null && legacy.isNotEmpty) {
        images.add(legacy);
      }
    }
    if (images.isEmpty) images.add('assets/book-type/event.jpg');
    return images;
  }

  ImageProvider _eventImageProvider(String image) {
    if (image.startsWith('data:image/')) {
      final comma = image.indexOf(',');
      if (comma >= 0) {
        return MemoryImage(base64Decode(image.substring(comma + 1)));
      }
    }
    if (image.startsWith('http')) return NetworkImage(image);
    return AssetImage(image);
  }

  Future<void> _loadSavedState() async {
    try {
      final saved = await SavedItemStore.list();
      final counts = await SavedItemStore.counts('event');
      if (!mounted) return;
      setState(() {
        _savedKeys
          ..clear()
          ..addAll(
            saved
                .where((item) => item['itemType'] == 'event')
                .map((item) => item['itemKey'] as String),
          );
        _saveCounts
          ..clear()
          ..addAll(counts);
      });
    } on Exception {
      // The card remains usable even when saved-state refresh is unavailable.
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _eventPage,
      appBar: AppBar(
        backgroundColor: _eventPage,
        foregroundColor: _eventInk,
        elevation: 0,
        leading: IconButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) =>
                      ReserveDashboardPage(onLogout: widget.onLogout),
                ),
                (_) => false,
              ),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          color: _eventNavy,
        ),
        title: const Text(
          'Event Venues',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'View map',
            onPressed: _openMap,
            icon: const Icon(Icons.map_outlined),
          ),
          IconButton(
            tooltip: 'Filters',
            onPressed: _openFilterDrawer,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _mainSearchBar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (wide && _filtersOpen)
                      SizedBox(width: 270, child: _filterPanel()),
                    Expanded(child: _results(wide)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shadowColor: Colors.transparent,
            indicatorColor: _eventSoftOrange,
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                color: selected
                    ? const Color(0xFFFF8200)
                    : const Color(0xFF68748A),
                size: 24,
              );
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                color: selected
                    ? const Color(0xFF101B33)
                    : const Color(0xFF68748A),
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: 0,
          onDestinationSelected: (index) {
            if (index == 0) return;
            if (index == 4) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ProfileDashboardPage(onLogout: widget.onLogout),
                ),
              );
              return;
            }
            if (index == 1) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SavedDashboardPage(
                    onLogout: widget.onLogout,
                    itemType: 'event',
                  ),
                ),
              );
              return;
            }
            if (index == 2) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MessagesDashboardPage()),
              );
              return;
            }
            if (index == 3) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) =>
                      CustomerBookingsPage(onLogout: widget.onLogout),
                ),
              );
              return;
            }
            _message(switch (index) {
              1 => 'Saved venues will appear here.',
              2 => 'Messages will appear here.',
              3 => 'Booking history will appear here.',
              _ => 'Profile will appear here.',
            });
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

  Widget _results(bool wide) {
    final venues = _filteredVenues;
    return RefreshIndicator(
      onRefresh: _loadSavedState,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(wide ? 22 : 16, 14, wide ? 28 : 16, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${venues.length} of ${_allVenues.length} venues',
                      style: const TextStyle(
                        color: _eventMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Text('Sort by ', style: TextStyle(color: _eventMuted)),
                  DropdownButton<String>(
                    value: _sortBy,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: 'Featured',
                        child: Text('Featured'),
                      ),
                      DropdownMenuItem(
                        value: 'Nearest',
                        child: Text('Nearest'),
                      ),
                      DropdownMenuItem(
                        value: 'Name A-Z',
                        child: Text('Name A-Z'),
                      ),
                      DropdownMenuItem(
                        value: 'Price: low to high',
                        child: Text('Price: low to high'),
                      ),
                      DropdownMenuItem(
                        value: 'Price: high to low',
                        child: Text('Price: high to low'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _sortBy = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          if (venues.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('No event venues match these filters.'),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                wide ? 22 : 16,
                4,
                wide ? 28 : 16,
                28,
              ),
              sliver: SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = wide ? 2 : 1;
                    const spacing = 16.0;
                    final itemWidth =
                        (constraints.maxWidth - spacing * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final venue in venues)
                          SizedBox(
                            width: itemWidth,
                            child: _venueCard(venue),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mainSearchBar() => Container(
    color: _eventPage,
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search venues, areas, or event types...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: _searchController.clear,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: _eventLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: _eventLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: _eventOrange, width: 1.5),
        ),
      ),
    ),
  );

  Widget _filterPanel() {
    final mobile = MediaQuery.sizeOf(context).width < 900;
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom;
    return SizedBox(
      height: mobile ? availableHeight * .68 : availableHeight - 96,
      child: Container(
        margin: EdgeInsets.fromLTRB(16, 14, mobile ? 16 : 0, 16),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _eventLine),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filters',
                      style: TextStyle(
                        color: _eventInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(onPressed: _reset, child: const Text('Reset')),
                ],
              ),
              const Divider(),
              _label('SEARCH'),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Name, area, keyword...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: _eventLine),
                  ),
                ),
              ),
              _gap(),
              _label('DISTANCE'),
              OutlinedButton.icon(
                onPressed: _useLocation,
                icon: _locationLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.location_on, size: 16),
                label: Text(
                  _position == null ? 'Use my location' : 'Location enabled',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _eventNavy,
                  side: const BorderSide(color: _eventNavy),
                  minimumSize: const Size(double.infinity, 38),
                ),
              ),
              _gap(),
              _label('AREA / CITY'),
              _dropdown(_area, const [
                'All areas',
                'Cebu City',
                'Mandaue City',
                'Talisay',
              ], (value) => setState(() => _area = value)),
              _gap(),
              _label('VENUE TYPE'),
              _chips(
                const [
                  'All venues',
                  'Ballroom',
                  'Terrace',
                  'Private Dining',
                  'Garden',
                ],
                _type,
                (value) => setState(() => _type = value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFilterDrawer() {
    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Filters',
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, dialogSetState) => Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.white,
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width < 600
                    ? MediaQuery.sizeOf(context).width * .86
                    : 370,
                height: double.infinity,
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Filters',
                                style: TextStyle(
                                  color: _eventInk,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                _reset();
                                dialogSetState(() {});
                              },
                              child: const Text('Reset all'),
                            ),
                            IconButton(
                              tooltip: 'Close filters',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: _filterContent(dialogSetState),
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: FilledButton.styleFrom(
                                backgroundColor: _eventNavy,
                                minimumSize: const Size.fromHeight(48),
                              ),
                              child: Text(
                                'Apply Filters (${_filteredVenues.length})',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset =
            Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return SlideTransition(position: offset, child: child);
      },
    );
  }

  Widget _filterContent([StateSetter? dialogSetState]) {
    void update(VoidCallback callback) {
      setState(callback);
      dialogSetState?.call(() {});
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('SEARCH'),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Name, area, keyword...',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: _eventLine),
              ),
            ),
          ),
          _gap(),
          _label('DISTANCE'),
          OutlinedButton.icon(
            onPressed: _useLocation,
            icon: const Icon(Icons.my_location_rounded, size: 16),
            label: const Text('Use my location'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _eventNavy,
              side: const BorderSide(color: _eventNavy),
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
          _gap(),
          _label('AREA / CITY'),
          _dropdown(_area, const [
            'All areas',
            'Cebu City',
            'Mandaue City',
            'Talisay',
          ], (value) => update(() => _area = value)),
          _gap(),
          _label('VENUE TYPE'),
          _chips(
            const [
              'All venues',
              'Ballroom',
              'Terrace',
              'Private Dining',
              'Garden',
            ],
            _type,
            (value) => update(() => _type = value),
          ),
        ],
      ),
    );
  }

  Widget _venueCard(dynamic venue) => Card(
    elevation: 1,
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: () => _showEventGallery(venue.images),
                child: PageView.builder(
                  itemCount: venue.images.length > 1 ? 10000 : 1,
                  itemBuilder: (_, index) => Image(
                    image: _eventImageProvider(
                      venue.images[index % venue.images.length],
                    ),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) => Image.asset(
                      'assets/book-type/event.jpg',
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filled(
                      tooltip: _savedKeys.contains(venue.name)
                          ? 'Unsave venue'
                          : 'Save venue',
                      style: IconButton.styleFrom(
                        backgroundColor: _savedKeys.contains(venue.name)
                            ? _eventOrange
                            : Colors.white,
                        foregroundColor: _savedKeys.contains(venue.name)
                            ? Colors.white
                            : _eventNavy,
                      ),
                      onPressed: () => _toggleSaved(
                        key: venue.name,
                        title: venue.name,
                        subtitle: 'Venue: ${venue.type}\n${venue.address}',
                        imageUrl: venue.image,
                      ),
                      icon: Icon(
                        _savedKeys.contains(venue.name)
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                    ),
                    _saveCount(_saveCounts[venue.name] ?? 0),
                  ],
                ),
              ),
              if (venue.images.length > 1)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        '${venue.images.length} photos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  Text(
                    venue.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _eventInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _detail(Icons.location_on_outlined, venue.address),
                  _detail(Icons.celebration_outlined, 'Type: ${venue.type}'),
                  _detail(
                    Icons.business_outlined,
                    'Facility: ${venue.facility}',
                  ),
                  _detail(Icons.access_time, 'Hours: ${venue.hours}'),
                  if (venue.availability.isNotEmpty)
                    _detail(
                      Icons.check_circle_outline,
                      'Availability: ${venue.availability}',
                    ),
                  for (final line in _eventDetailLines(venue.details))
                    _detail(Icons.info_outline, line),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFBFD),
                      border: Border.all(color: _eventLine),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Event package',
                            style: TextStyle(color: _eventMuted, fontSize: 11),
                          ),
                        ),
                        Text(
                          venue.price,
                          style: const TextStyle(
                            color: _eventInk,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (venue.tags.isNotEmpty)
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [for (final tag in venue.tags) _tag(tag)],
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openVisit(venue.visitUrl, venue.name),
                          icon: const Icon(Icons.language, size: 15),
                          label: const Text('Visit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _eventNavy,
                            side: const BorderSide(color: _eventNavy),
                            minimumSize: const Size(0, 36),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _message(
                            'Booking ${venue.name} is ready. Fee: ${venue.price}.',
                          ),
                          icon: const Icon(Icons.calendar_month, size: 15),
                          label: const Text('Book now'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _eventOrange,
                            minimumSize: const Size(0, 36),
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

  Future<void> _toggleSaved({
    required String key,
    required String title,
    required String subtitle,
    String? imageUrl,
  }) async {
    try {
      if (_savedKeys.contains(key)) {
        await SavedItemStore.remove('event', key);
        setState(() {
          _savedKeys.remove(key);
          _saveCounts[key] = (_saveCounts[key] ?? 1) - 1;
        });
        _message('$title removed from Saved.');
      } else {
        await SavedItemStore.save(
          type: 'event',
          key: key,
          title: title,
          subtitle: subtitle,
          imageUrl: imageUrl,
        );
        setState(() {
          _savedKeys.add(key);
          _saveCounts[key] = (_saveCounts[key] ?? 0) + 1;
        });
        _message('$title saved.');
      }
    } on Exception catch (error) {
      _message('Could not update Saved: $error');
    }
  }

  Future<void> _showEventGallery(List<String> images) async {
    if (images.isEmpty) return;
    var index = 0;
    final controller = PageController(
      initialPage: images.length > 1 ? images.length * 1000 : 0,
    );
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(dialogContext).height * .78,
                child: PageView.builder(
                  controller: controller,
                  itemCount: images.length > 1 ? 10000 : 1,
                  onPageChanged: (page) =>
                      setDialogState(() => index = page % images.length),
                  itemBuilder: (_, page) => InteractiveViewer(
                    minScale: 1,
                    maxScale: 3,
                    child: Image(
                      image: _eventImageProvider(images[page % images.length]),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton.filled(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Positioned(
                bottom: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .65),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      '${index + 1} of ${images.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (images.length > 1) ...[
                Positioned(
                  left: 8,
                  child: IconButton.filled(
                    onPressed: () => controller.previousPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                ),
                Positioned(
                  right: 8,
                  child: IconButton.filled(
                    onPressed: () => controller.nextPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Widget _saveCount(int count) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      child: Text(
        '$count',
        style: const TextStyle(
          color: _eventNavy,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );

  int _eventPrice(String value) =>
      int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  Widget _tag(String text) => DecoratedBox(
    decoration: BoxDecoration(
      color: _eventSoftOrange,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Text(
        text,
        style: const TextStyle(color: _eventInk, fontSize: 10.5),
      ),
    ),
  );

  double _distanceSquared(
    double latitude,
    double longitude,
    double otherLatitude,
    double otherLongitude,
  ) {
    final latitudeDelta = latitude - otherLatitude;
    final longitudeDelta = longitude - otherLongitude;
    return latitudeDelta * latitudeDelta + longitudeDelta * longitudeDelta;
  }

  Widget _detail(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      children: [
        Icon(icon, size: 14, color: _eventInk),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _eventMuted, fontSize: 10.5),
          ),
        ),
      ],
    ),
  );

  List<String> _eventDetailLines(String details) => details
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('Event types:'))
      .toList();

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(
        color: _eventMuted,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: .4,
      ),
    ),
  );

  Widget _gap() => const SizedBox(height: 14);

  Widget _dropdown(
    String value,
    List<String> values,
    ValueChanged<String> onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: _eventLine),
      ),
    ),
    items: [
      for (final item in values)
        DropdownMenuItem(value: item, child: Text(item)),
    ],
    onChanged: (item) {
      if (item != null) onChanged(item);
    },
  );

  Widget _chips(
    List<String> values,
    String selected,
    ValueChanged<String> onChanged,
  ) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final value in values)
        FilterChip(
          label: Text(
            value,
            style: TextStyle(
              fontSize: 10,
              color: selected == value ? _eventOrange : _eventInk,
              fontWeight: selected == value ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          selected: selected == value,
          showCheckmark: false,
          selectedColor: _eventSoftOrange,
          checkmarkColor: _eventOrange,
          side: BorderSide(
            color: selected == value ? _eventOrange : _eventLine,
          ),
          onSelected: (_) => onChanged(value),
        ),
    ],
  );

  void _reset() {
    _searchController.clear();
    setState(() {
      _area = 'All areas';
      _type = 'All venues';
    });
  }

  Future<void> _useLocation() async {
    setState(() => _locationLoading = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _message('Turn on location services to find nearby event venues.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _message('Location permission is required for nearby event venues.');
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _position = position);
        _message('Showing event venues near your location.');
      }
    } catch (_) {
      _message('Could not read your location.');
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _openVisit(String rawUrl, String name) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      _message('$name does not have a visit link yet.');
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _message('Could not open the visit link for $name.');
    }
  }

  void _openMap() {
    final center = _position == null
        ? const LatLng(10.3157, 123.8854)
        : LatLng(_position!.latitude, _position!.longitude);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Event venue map'),
            backgroundColor: _eventPage,
            foregroundColor: _eventInk,
          ),
          body: FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 12),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.myapp',
              ),
              MarkerLayer(
                markers: [
                  for (final venue in _allVenues)
                    Marker(
                      point: LatLng(venue.latitude, venue.longitude),
                      width: 120,
                      height: 52,
                      child: _mapPin(venue.name),
                    ),
                  if (_position != null)
                    Marker(
                      point: LatLng(_position!.latitude, _position!.longitude),
                      width: 112,
                      height: 76,
                      child: _userLocationPin(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapPin(String label) => Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: _eventNavy,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 9),
        ),
      ),
      const Icon(Icons.location_on, color: _eventNavy),
    ],
  );

  Widget _userLocationPin() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1769E0),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x331769E0),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          'You are here',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0x331769E0),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x661769E0), width: 1),
        ),
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF1769E0),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
        ),
      ),
    ],
  );
}
