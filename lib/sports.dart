import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_api.dart';
import 'app_session.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'profile_dashboard.dart';
import 'reserve_dashboard.dart';
import 'saved_dashboard.dart';
import 'customer_bookings_page.dart';
import 'saved_items.dart';
import 'messages_dashboard.dart';

typedef SportsVenue = ({
  int id,
  String name,
  String sport,
  String address,
  String ownerName,
  String type,
  String courts,
  String hours,
  String availability,
  String image,
  List<String> images,
  String priceDay,
  String priceNight,
  List<String> priceLines,
  double maxPrice,
  List<String> tags,
  double latitude,
  double longitude,
  String visitUrl,
});

const _sportsNavy = Color(0xFF192B50);
const _sportsInk = Color(0xFF101B33);
const _sportsOrange = Color(0xFFFF8200);
const _sportsLine = Color(0xFFE2E7EF);
const _sportsMuted = Color(0xFF68748A);
const _sportsPage = Color(0xFFF7F9FC);
const _sportsSurface = Colors.white;
const _sportsSoftOrange = Color(0xFFFFF1E4);

class SportsDashboardPage extends StatefulWidget {
  const SportsDashboardPage({super.key, this.onLogout});

  final Future<void> Function(BuildContext context)? onLogout;

  @override
  State<SportsDashboardPage> createState() => _SportsDashboardPageState();
}

class _SportsDashboardPageState extends State<SportsDashboardPage> {
  final _api = AuthApi();
  final _searchController = TextEditingController();
  final List<SportsVenue> _merchantVenues = [];
  List<Map<String, dynamic>> _customerBookings = [];
  List<SportsVenue> get _allVenues => _merchantVenues;

  String _area = 'All areas';
  String _sport = 'All sports';
  String _courtType = 'All';
  String _availability = 'Any';
  double _maxPrice = 700;
  final Set<String> _selectedAmenities = <String>{};
  bool _locationLoading = false;
  Position? _position;
  final Set<String> _savedKeys = <String>{};
  final Map<String, int> _saveCounts = <String, int>{};
  String _sortBy = 'Featured';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadMerchantBusinesses();
  }

  List<dynamic> get _filteredVenues {
    final query = _searchController.text.trim().toLowerCase();
    final venues = _allVenues.where((venue) {
      final matchesQuery =
          query.isEmpty ||
          venue.name.toLowerCase().contains(query) ||
          venue.address.toLowerCase().contains(query);
      final matchesType = _courtType == 'All' || venue.type == _courtType;
      final matchesSport = _sport == 'All sports' || venue.sport == _sport;
      final matchesArea =
          _area == 'All areas' ||
          venue.address.toLowerCase().contains(_area.toLowerCase());
      final matchesAvailability =
          _availability == 'Any' ||
          (_availability == 'Open 24 hours' && venue.hours == 'Open 24 hours');
      final matchesPrice = venue.maxPrice <= _maxPrice;
      final matchesAmenities = _selectedAmenities.every(
        (amenity) => venue.tags.any(
          (tag) => tag.toLowerCase().startsWith(amenity.toLowerCase()),
        ),
      );
      return matchesQuery &&
          matchesType &&
          matchesSport &&
          matchesArea &&
          matchesAvailability &&
          matchesPrice &&
          matchesAmenities;
    }).toList();
    venues.sort((a, b) {
      switch (_sortBy) {
        case 'Name A-Z':
          return a.name.compareTo(b.name);
        case 'Price: low to high':
          return a.maxPrice.compareTo(b.maxPrice);
        case 'Price: high to low':
          return b.maxPrice.compareTo(a.maxPrice);
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
    _loadCustomerBookings();
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
                      'sports',
                )
                .map(_sportsVenue),
          ),
      );
    } on Exception catch (error) {
      if (mounted) {
        _showMessage('Could not load merchant Sports venues: $error');
      }
    }
  }

  Future<void> _loadCustomerBookings() async {
    try {
      final session = await AppSession.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) return;
      final bookings = await _api.customerBookings(token);
      if (mounted) setState(() => _customerBookings = bookings);
    } on Exception {
      // The venue browser remains usable if booking status is unavailable.
    }
  }

  SportsVenue _sportsVenue(Map<String, dynamic> b) {
    final rawTags = b['tags'];
    final tags = rawTags is List
        ? rawTags.whereType<String>().toList()
        : rawTags is String
        ? (() {
            try {
              final decoded = jsonDecode(rawTags);
              return decoded is List
                  ? decoded.whereType<String>().toList()
                  : <String>[];
            } on FormatException {
              return <String>[];
            }
          })()
        : <String>[];
    final price =
        double.tryParse('${b['pricePerHour'] ?? b['price_per_hour'] ?? 0}') ??
        0;
    final rawPeriods = b['ratePeriods'] ?? b['rate_periods'];
    final periods = rawPeriods is List
        ? rawPeriods.whereType<Map>().map((period) {
            final start = period['start'] ?? period['start_time'] ?? '';
            final end = period['end'] ?? period['end_time'] ?? '';
            final amount = period['pricePerHour'] ?? period['price_per_hour'];
            return '$start - $end|PHP ${double.tryParse('$amount')?.toStringAsFixed(0) ?? amount} / hr';
          }).toList()
        : <String>[];
    final images = _merchantImages(b);
    return (
      id: (b['id'] as num?)?.toInt() ?? 0,
      name: b['name'] as String? ?? 'Business',
      sport: '${b['category'] ?? 'Sports'}',
      address: '${b['address'] ?? ''}',
      ownerName: _ownerName(b),
      type: '${b['facilityType'] ?? b['facility_type'] ?? 'Facility'}',
      courts: '${b['details'] ?? 'Sports facility'}',
      hours: '${b['hours'] ?? b['opening_hours'] ?? 'Open hours'}',
      availability: '${b['availability'] ?? b['availability_status'] ?? ''}',
      image: _merchantImage(b),
      images: images,
      priceDay: 'PHP ${price.toStringAsFixed(0)} / hr',
      priceNight: 'PHP ${price.toStringAsFixed(0)} / hr',
      priceLines: periods.isEmpty
          ? ['Booking rate|PHP ${price.toStringAsFixed(0)} / hr']
          : periods,
      maxPrice: price,
      tags: tags,
      latitude: 10.3157,
      longitude: 123.8854,
      visitUrl: '${b['visitUrl'] ?? b['visit_url'] ?? ''}',
    );
  }

  String _ownerName(Map<String, dynamic> business) {
    final explicit = business['ownerName'] ?? business['owner_name'];
    if (explicit is String && explicit.trim().isNotEmpty) {
      return explicit.trim();
    }
    final first =
        business['ownerFirstName'] ?? business['owner_first_name'] ?? '';
    final last = business['ownerLastName'] ?? business['owner_last_name'] ?? '';
    final name = '$first $last'.trim();
    return name.isEmpty ? 'Venue owner' : name;
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
    final legacy = business['imageUrl'] as String?;
    if (images.isEmpty && legacy != null && legacy.isNotEmpty) {
      try {
        final decoded = jsonDecode(legacy);
        if (decoded is List && decoded.whereType<String>().isNotEmpty) {
          images.addAll(
            decoded.whereType<String>().where((image) => image.isNotEmpty),
          );
        }
      } on FormatException {
        images.add(legacy);
      }
      if (images.isEmpty) images.add(legacy);
    }
    if (images.isEmpty) images.add('assets/court/pickle-court.jpg');
    return images;
  }

  ImageProvider _sportsImageProvider(String image) {
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
      final counts = await SavedItemStore.counts('sports');
      if (!mounted) return;
      setState(() {
        _savedKeys
          ..clear()
          ..addAll(
            saved
                .where((item) => item['itemType'] == 'sports')
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
      backgroundColor: _sportsPage,
      appBar: AppBar(
        backgroundColor: _sportsPage,
        foregroundColor: _sportsInk,
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
        ),
        title: const Text(
          'Sports Courts',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'View map',
            onPressed: _openMap,
            icon: const Icon(Icons.map_outlined),
          ),
          IconButton(
            tooltip: 'Open filters sidebar',
            onPressed: _openFilterDrawer,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_customerBookings.any(
            (booking) =>
                booking['status'] == 'approved' ||
                booking['status'] == 'finished',
          ))
            _bookingStatusBanner(),
          _mainSearchBar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: _results(wide))],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: _sportsSurface,
            surfaceTintColor: _sportsSurface,
            shadowColor: Colors.transparent,
            indicatorColor: _sportsSoftOrange,
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
                    itemType: 'sports',
                  ),
                ),
              );
              return;
            }
            if (index == 2) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MessagesDashboardPage(),
                ),
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
            _showMessage(switch (index) {
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
      onRefresh: () async {
        await Future.wait([_loadSavedState(), _loadMerchantBusinesses()]);
      },
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
                      '${venues.length} of ${_allVenues.length} courts',
                      style: const TextStyle(
                        color: _sportsMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Text(
                    'Sort by',
                    style: TextStyle(color: _sportsMuted, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
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
                child: Text('No sports courts match these filters.'),
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
                          SizedBox(width: itemWidth, child: _courtCard(venue)),
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

  Widget _bookingStatusBanner() {
    final booking = _customerBookings.firstWhere(
      (item) => item['status'] == 'approved' || item['status'] == 'finished',
    );
    final finished = booking['status'] == 'finished';
    return MaterialBanner(
      backgroundColor: finished ? const Color(0xFFE7F6EC) : _sportsSoftOrange,
      leading: Icon(
        finished ? Icons.check_circle_rounded : Icons.event_available_rounded,
        color: finished ? Colors.green.shade700 : _sportsOrange,
      ),
      content: Text(
        finished
            ? 'Booking at ${booking['venueName']} is finished.'
            : 'Booking at ${booking['venueName']} was approved for '
                  '${booking['date']} at ${booking['startTime']}.',
        style: const TextStyle(color: _sportsInk, fontWeight: FontWeight.w700),
      ),
      actions: [
        TextButton(
          onPressed: _loadCustomerBookings,
          child: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _mainSearchBar() => Container(
    color: _sportsPage,
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search courts, areas, or sports...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: _searchController.clear,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
        filled: true,
        fillColor: _sportsSurface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: _sportsLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: _sportsLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: _sportsOrange, width: 1.5),
        ),
      ),
    ),
  );

  // Kept as a reusable desktop filter layout for future inline filter mode.
  // ignore: unused_element
  Widget _filterPanel() {
    final mobile = MediaQuery.sizeOf(context).width < 900;
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom;
    final panelHeight = mobile ? availableHeight * .68 : availableHeight - 96;

    return SizedBox(
      height: panelHeight,
      child: Container(
        margin: EdgeInsets.fromLTRB(16, 14, mobile ? 16 : 0, 16),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        decoration: BoxDecoration(
          color: _sportsSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _sportsLine),
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
                        color: _sportsInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Reset', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const Divider(height: 16),
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
                label: const Text('Use my location'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _sportsInk,
                  side: const BorderSide(color: _sportsNavy),
                  minimumSize: const Size(double.infinity, 38),
                ),
              ),
              _sectionGap(),
              _label('AREA / CITY'),
              _dropdown(
                value: _area,
                values: const [
                  'All areas',
                  'Cebu City',
                  'Mandaue City',
                  'Talisay',
                ],
                onChanged: (value) => setState(() => _area = value),
              ),
              _sectionGap(),
              _label('SPORT'),
              _dropdown(
                value: _sport,
                values: const [
                  'All sports',
                  'Basketball',
                  'Badminton',
                  'Tennis',
                  'Padel',
                  'Volleyball',
                  'Pickleball',
                ],
                onChanged: (value) => setState(() => _sport = value),
              ),
              _sectionGap(),
              _label('COURT TYPE'),
              _chips(
                const ['All', 'Indoor', 'Outdoor', 'Covered'],
                _courtType,
                (value) => setState(() => _courtType = value),
              ),
              _sectionGap(),
              _label('AMENITIES'),
              _amenityChips(const [
                'Parking',
                'Pet-friendly',
                'Restroom',
                'Shower',
                'Store',
              ]),
              _sectionGap(),
              _label('AVAILABILITY'),
              _chips(
                const ['Any', 'Open 24 hours'],
                _availability,
                (value) => setState(() => _availability = value),
              ),
              _sectionGap(),
              _label('PRICE (₱ / HOUR)'),
              Text(
                _maxPrice >= 700
                    ? '₱0 to ₱700+'
                    : '₱0 to ₱${_maxPrice.round()} / hour',
                style: const TextStyle(
                  color: _sportsInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Slider(
                value: _maxPrice,
                min: 0,
                max: 700,
                divisions: 14,
                activeColor: _sportsOrange,
                label: '₱${_maxPrice.round()}',
                onChanged: (value) => setState(() => _maxPrice = value),
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
              color: _sportsSurface,
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
                                  color: _sportsInk,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _resetFilters,
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
                                backgroundColor: _sportsNavy,
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
          _label('DISTANCE'),
          OutlinedButton.icon(
            onPressed: _useLocation,
            icon: const Icon(Icons.my_location_rounded, size: 16),
            label: const Text('Use my location'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _sportsNavy,
              side: const BorderSide(color: _sportsNavy),
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
          _sectionGap(),
          _label('AREA / CITY'),
          _dropdown(
            value: _area,
            values: const ['All areas', 'Cebu City', 'Mandaue City', 'Talisay'],
            onChanged: (value) => update(() => _area = value),
          ),
          _sectionGap(),
          _label('SPORT'),
          _dropdown(
            value: _sport,
            values: const [
              'All sports',
              'Basketball',
              'Badminton',
              'Tennis',
              'Padel',
              'Volleyball',
              'Pickleball',
            ],
            onChanged: (value) => update(() => _sport = value),
          ),
          _sectionGap(),
          _label('COURT TYPE'),
          _chips(
            const ['All', 'Indoor', 'Outdoor', 'Covered'],
            _courtType,
            (value) => update(() => _courtType = value),
          ),
          _sectionGap(),
          _label('AMENITIES'),
          _amenityChips(const [
            'Parking',
            'Pet-friendly',
            'Restroom',
            'Shower',
            'Store',
          ], dialogSetState),
          _sectionGap(),
          _label('AVAILABILITY'),
          _chips(
            const ['Any', 'Open 24 hours'],
            _availability,
            (value) => update(() => _availability = value),
          ),
          _sectionGap(),
          _priceFilter(dialogSetState),
        ],
      ),
    );
  }

  Widget _priceFilter([StateSetter? dialogSetState]) {
    void update(VoidCallback callback) {
      setState(callback);
      dialogSetState?.call(() {});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('PRICE (₱ / HOUR)')),
            Text(
              _maxPrice >= 700 ? '₱0 - ₱700+' : '₱0 - ₱${_maxPrice.round()}',
              style: const TextStyle(
                color: _sportsNavy,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: _sportsNavy,
            inactiveTrackColor: _sportsLine,
            thumbColor: _sportsOrange,
            overlayColor: _sportsOrange.withValues(alpha: .14),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: _maxPrice,
            min: 0,
            max: 700,
            divisions: 14,
            onChanged: (value) => update(() => _maxPrice = value),
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('₱0', style: TextStyle(color: _sportsMuted, fontSize: 11)),
            Text('₱350', style: TextStyle(color: _sportsMuted, fontSize: 11)),
            Text('₱700+', style: TextStyle(color: _sportsMuted, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _courtCard(dynamic venue) => Card(
    elevation: 1,
    shadowColor: Colors.black12,
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
                onTap: () => _showSportsGallery(venue.images),
                child: PageView.builder(
                  itemCount: venue.images.length > 1 ? 10000 : 1,
                  itemBuilder: (_, index) => Image(
                    image: _sportsImageProvider(
                      venue.images[index % venue.images.length],
                    ),
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) => Image.asset(
                      'assets/court/pickle-court.jpg',
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
                            ? _sportsOrange
                            : Colors.white,
                        foregroundColor: _savedKeys.contains(venue.name)
                            ? Colors.white
                            : _sportsNavy,
                      ),
                      onPressed: () => _toggleSaved(
                        type: 'sports',
                        key: venue.name,
                        title: venue.name,
                        subtitle: 'Sport: ${venue.sport}\n${venue.address}',
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
                  color: _sportsInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              _detail(Icons.location_on_outlined, venue.address),
              _detail(Icons.sports_rounded, 'Sport: ${venue.sport}'),
              _detail(Icons.business_center_outlined, 'Type: ${venue.type}'),
              _detail(Icons.grid_3x3, 'Courts: ${venue.courts}'),
              _detail(Icons.access_time, 'Hours: ${venue.hours}'),
              if (venue.availability.isNotEmpty)
                _detail(
                  Icons.check_circle_outline,
                  'Availability: ${venue.availability}',
                ),
              const SizedBox(height: 6),
              _priceBox(venue),
              const SizedBox(height: 6),
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: [for (final tag in venue.tags) _tag(tag)],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openVisit(venue.visitUrl, venue.name),
                      icon: const Icon(Icons.language, size: 15),
                      label: const Text('Visit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _sportsNavy,
                        side: const BorderSide(color: _sportsNavy),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openBookingModal(venue),
                      icon: const Icon(Icons.calendar_month, size: 15),
                      label: const Text('Book now'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _sportsOrange,
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

  Future<void> _openBookingModal(SportsVenue venue) async {
    final rate = venue.maxPrice;
    if (!rate.isFinite || rate <= 0) {
      _showMessage('This venue does not have a valid merchant rate.');
      return;
    }
    var hours = 1;
    var players = 1;
    var payment = 'gcash';
    DateTime bookingDate = DateTime.now();
    TimeOfDay bookingTime = TimeOfDay.now();
    var occupiedBookings = <Map<String, dynamic>>[];
    var availabilityLoading = true;
    final session = await AppSession.load();
    final token = session.apiToken;
    if (token != null && token.isNotEmpty) {
      try {
        occupiedBookings = await _api.bookingAvailability(
          token: token,
          venueId: venue.id,
          date: _bookingDateString(bookingDate),
        );
      } on Exception catch (error) {
        _showMessage('Could not load this venue\'s availability: $error');
      }
    }
    availabilityLoading = false;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _sportsPage,
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final total = rate * hours;
          final cashOnArrival = total / 2;
          final dueNow = payment == 'cash' ? cashOnArrival : total;
          final selectedSlotBooked = _bookingSlotOverlaps(
            bookingTime,
            hours,
            occupiedBookings,
          );
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Book ${venue.name}',
                      style: const TextStyle(
                        color: _sportsNavy,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Merchant rate: PHP ${rate.toStringAsFixed(2)} / hour',
                      style: const TextStyle(color: _sportsMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Owner: ${venue.ownerName}',
                      style: const TextStyle(
                        color: _sportsNavy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _bookingDetail(Icons.location_on_outlined, venue.address),
                    _bookingDetail(Icons.access_time_rounded, venue.hours),
                    _bookingDetail(Icons.sports_rounded, venue.sport),
                    const SizedBox(height: 18),
                    const Text(
                      'Choose date and time',
                      style: TextStyle(
                        color: _sportsInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: bookingDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  bookingDate = picked;
                                  availabilityLoading = true;
                                });
                                if (token != null && token.isNotEmpty) {
                                  try {
                                    final bookings = await _api
                                        .bookingAvailability(
                                          token: token,
                                          venueId: venue.id,
                                          date: _bookingDateString(picked),
                                        );
                                    if (context.mounted) {
                                      setModalState(() {
                                        occupiedBookings = bookings;
                                        availabilityLoading = false;
                                      });
                                    }
                                  } on Exception catch (error) {
                                    if (context.mounted) {
                                      setModalState(
                                        () => availabilityLoading = false,
                                      );
                                      _showMessage(
                                        'Could not refresh availability: $error',
                                      );
                                    }
                                  }
                                } else {
                                  setModalState(
                                    () => availabilityLoading = false,
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(
                              MaterialLocalizations.of(context)
                                  .formatMediumDate(bookingDate),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: bookingTime,
                              );
                              if (picked != null) {
                                setModalState(() => bookingTime = picked);
                              }
                            },
                            icon: const Icon(Icons.schedule_rounded),
                            label: Text(bookingTime.format(context)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select a time within the venue hours: ${venue.hours}.',
                      style: const TextStyle(color: _sportsMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    if (availabilityLoading)
                      const LinearProgressIndicator()
                    else if (occupiedBookings.isEmpty)
                      Text(
                        'No existing bookings for this date.',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else ...[
                      Text(
                        'Already booked on this date',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: occupiedBookings
                            .map(
                              (booking) => Chip(
                                avatar: Icon(
                                  Icons.event_busy_rounded,
                                  size: 16,
                                  color: Colors.red.shade700,
                                ),
                                label: Text(_occupiedBookingLabel(booking)),
                                backgroundColor: Colors.red.shade50,
                                side: BorderSide(color: Colors.red.shade200),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (selectedSlotBooked) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          'This time overlaps an existing booking. Please choose another time.',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Text(
                      'Booking duration',
                      style: TextStyle(
                        color: _sportsInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: hours,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.schedule_rounded),
                        labelText: 'Hours',
                      ),
                      items: [
                        for (var value = 1; value <= 8; value++)
                          DropdownMenuItem(
                            value: value,
                            child: Text('$value hour${value == 1 ? '' : 's'}'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setModalState(() => hours = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      initialValue: players,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.groups_rounded),
                        labelText: 'Number of players',
                      ),
                      items: [
                        for (var value = 1; value <= 30; value++)
                          DropdownMenuItem(
                            value: value,
                            child: Text(
                              '$value player${value == 1 ? '' : 's'}',
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => players = value);
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Payment method',
                      style: TextStyle(
                        color: _sportsInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'gcash',
                          label: Text('GCash'),
                          icon: Icon(Icons.account_balance_wallet_rounded),
                        ),
                        ButtonSegment(
                          value: 'card',
                          label: Text('Card'),
                          icon: Icon(Icons.credit_card_rounded),
                        ),
                        ButtonSegment(
                          value: 'cash',
                          label: Text('Cash on arrival'),
                          icon: Icon(Icons.payments_outlined),
                        ),
                      ],
                      selected: {payment},
                      onSelectionChanged: (selection) {
                        setModalState(() => payment = selection.first);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      payment == 'cash'
                          ? 'Pay PHP ${cashOnArrival.toStringAsFixed(2)} now and '
                                'PHP ${cashOnArrival.toStringAsFixed(2)} on arrival.'
                          : 'Pay the full PHP ${total.toStringAsFixed(2)} now by '
                                '${payment == 'gcash' ? 'GCash' : 'card'}.',
                      style: const TextStyle(color: _sportsMuted),
                    ),
                    const Divider(height: 24),
                    _bookingAmountRow('Merchant rate', rate, '/ hour'),
                    _bookingAmountRow('Duration', hours.toDouble(), ' hour(s)'),
                    _bookingAmountRow(
                      'Players',
                      players.toDouble(),
                      players == 1 ? ' player' : ' players',
                    ),
                    _bookingScheduleRow(
                      context,
                      bookingDate,
                      bookingTime,
                      hours,
                    ),
                    _bookingAmountRow('Booking total', total, ''),
                    _bookingAmountRow(
                      payment == 'cash' ? 'Pay now' : 'Amount due',
                      dueNow,
                      '',
                      strong: true,
                    ),
                    if (payment == 'cash')
                      Text(
                        'Cash on Arrival is fixed at 50% of the booking total.',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: availabilityLoading || selectedSlotBooked
                            ? null
                            : () {
                                _submitBooking(
                                  modalContext: modalContext,
                                  venue: venue,
                                  bookingDate: bookingDate,
                                  bookingTime: bookingTime,
                                  hours: hours,
                                  players: players,
                                  payment: payment,
                                );
                              },
                        icon: const Icon(Icons.lock_outline_rounded),
                        label: Text(
                          payment == 'cash'
                              ? 'Continue · PHP ${dueNow.toStringAsFixed(2)}'
                              : 'Pay · PHP ${dueNow.toStringAsFixed(2)}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _bookingDateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  bool _bookingSlotOverlaps(
    TimeOfDay selectedTime,
    int durationHours,
    List<Map<String, dynamic>> bookings,
  ) {
    final selectedStart = selectedTime.hour * 60 + selectedTime.minute;
    final selectedEnd = selectedStart + durationHours * 60;
    for (final booking in bookings) {
      final rawStart = '${booking['startTime'] ?? ''}';
      final parts = rawStart.split(':');
      if (parts.length < 2) continue;
      final startHour = int.tryParse(parts[0]);
      final startMinute = int.tryParse(parts[1]);
      final duration = double.tryParse('${booking['durationHours']}');
      if (startHour == null || startMinute == null || duration == null) {
        continue;
      }
      final bookedStart = startHour * 60 + startMinute;
      final bookedEnd = bookedStart + (duration * 60).round();
      if (selectedStart < bookedEnd && selectedEnd > bookedStart) return true;
    }
    return false;
  }

  String _occupiedBookingLabel(Map<String, dynamic> booking) {
    final rawStart = '${booking['startTime'] ?? ''}';
    final parts = rawStart.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final duration = double.tryParse('${booking['durationHours']}') ?? 0;
    if (hour == null || minute == null) return 'Unavailable';
    final start = TimeOfDay(hour: hour, minute: minute);
    final endMinutes = hour * 60 + minute + (duration * 60).round();
    final end = TimeOfDay(
      hour: (endMinutes ~/ 60) % 24,
      minute: endMinutes % 60,
    );
    return '${_formatTime(start)} - ${_formatTime(end)}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  Future<void> _submitBooking({
    required BuildContext modalContext,
    required SportsVenue venue,
    required DateTime bookingDate,
    required TimeOfDay bookingTime,
    required int hours,
    required int players,
    required String payment,
  }) async {
    final session = await AppSession.load();
    final token = session.apiToken;
    if (token == null || token.isEmpty || venue.id <= 0) {
      _showMessage('Please sign in before creating a booking.');
      return;
    }
    final date =
        '${bookingDate.year.toString().padLeft(4, '0')}-'
        '${bookingDate.month.toString().padLeft(2, '0')}-'
        '${bookingDate.day.toString().padLeft(2, '0')}';
    final startTime =
        '${bookingTime.hour.toString().padLeft(2, '0')}:'
        '${bookingTime.minute.toString().padLeft(2, '0')}:00';
    try {
      final response = await _api.createBooking(
        token: token,
        venueId: venue.id,
        date: date,
        startTime: startTime,
        durationHours: hours.toDouble(),
        players: players,
        paymentMethod: payment,
      );
      if (!mounted || !modalContext.mounted) return;
      Navigator.of(modalContext).pop();
      final booking = response['booking'] as Map<String, dynamic>? ?? {};
      final downpayment =
          booking['downpayment'] ?? (venue.maxPrice * hours / 2);
      _showMessage(
        'Booking request sent to ${venue.ownerName}. '
        'Downpayment: PHP $downpayment. Waiting for approval.',
      );
    } on Exception catch (error) {
      _showMessage('Could not submit booking: $error');
    }
  }

  Widget _bookingAmountRow(
    String label,
    double amount,
    String suffix, {
    bool strong = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: _sportsMuted,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          label == 'Duration'
              ? '${amount.toStringAsFixed(0)}$suffix'
              : 'PHP ${amount.toStringAsFixed(2)}$suffix',
          style: TextStyle(
            color: _sportsInk,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _bookingDetail(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(icon, size: 15, color: _sportsMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text.isEmpty ? 'Not provided' : text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _sportsMuted, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _bookingScheduleRow(
    BuildContext context,
    DateTime date,
    TimeOfDay time,
    int hours,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Schedule',
            style: TextStyle(color: _sportsMuted, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          '${MaterialLocalizations.of(context).formatShortDate(date)} · '
          '${time.format(context)} · $hours hr',
          style: const TextStyle(
            color: _sportsInk,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Future<void> _toggleSaved({
    required String type,
    required String key,
    required String title,
    required String subtitle,
    String? imageUrl,
  }) async {
    try {
      if (_savedKeys.contains(key)) {
        await SavedItemStore.remove(type, key);
        setState(() {
          _savedKeys.remove(key);
          _saveCounts[key] = (_saveCounts[key] ?? 1) - 1;
        });
        _showMessage('$title removed from Saved.');
      } else {
        await SavedItemStore.save(
          type: type,
          key: key,
          title: title,
          subtitle: subtitle,
          imageUrl: imageUrl,
        );
        setState(() {
          _savedKeys.add(key);
          _saveCounts[key] = (_saveCounts[key] ?? 0) + 1;
        });
        _showMessage('$title saved.');
      }
    } on Exception catch (error) {
      _showMessage('Could not update Saved: $error');
    }
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
          color: _sportsNavy,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: _sportsInk),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _sportsMuted, fontSize: 10.5),
          ),
        ),
      ],
    ),
  );

  Widget _priceBox(dynamic venue) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xFFFAFBFD),
      border: Border.all(color: _sportsLine),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🏷 Price',
          style: TextStyle(
            color: _sportsInk,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        for (final line in venue.priceLines)
          _priceLine(
            line.split('|').first,
            line.contains('|') ? line.split('|').skip(1).join('|') : '',
          ),
      ],
    ),
  );

  Future<void> _showSportsGallery(List<String> images) async {
    if (images.isEmpty) return;
    var index = 0;
    final galleryController = PageController(
      initialPage: images.length > 1 ? images.length * 1000 : 0,
    );
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * .78,
                child: PageView.builder(
                  onPageChanged: (value) =>
                      setState(() => index = value % images.length),
                  itemCount: images.length > 1 ? 10000 : 1,
                  controller: galleryController,
                  itemBuilder: (_, page) => InteractiveViewer(
                    minScale: 1,
                    maxScale: 3,
                    child: Image(
                      image: _sportsImageProvider(images[page % images.length]),
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
                    onPressed: () => galleryController.previousPage(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                ),
                Positioned(
                  right: 8,
                  child: IconButton.filled(
                    onPressed: () => galleryController.nextPage(
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
    galleryController.dispose();
  }

  Widget _priceLine(String label, String value) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: _sportsMuted, fontSize: 9.5),
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          color: _sportsInk,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: _sportsSoftOrange,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: _sportsInk,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(
        color: _sportsMuted,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: .4,
      ),
    ),
  );

  Widget _sectionGap() => const SizedBox(height: 14);

  Widget _dropdown({
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: _sportsLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: _sportsLine),
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
    String? selected,
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
              color: selected == value ? _sportsOrange : _sportsInk,
              fontWeight: selected == value ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          selected: selected == value,
          showCheckmark: false,
          side: BorderSide(
            color: selected == value ? _sportsOrange : _sportsLine,
          ),
          selectedColor: _sportsSoftOrange,
          checkmarkColor: _sportsOrange,
          onSelected: (_) => onChanged(value),
        ),
    ],
  );

  Widget _amenityChips(List<String> values, [StateSetter? dialogSetState]) =>
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final value in values)
            FilterChip(
              label: Text(
                value,
                style: TextStyle(
                  fontSize: 10,
                  color: _selectedAmenities.contains(value)
                      ? _sportsOrange
                      : _sportsInk,
                  fontWeight: _selectedAmenities.contains(value)
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
              selected: _selectedAmenities.contains(value),
              showCheckmark: false,
              side: BorderSide(
                color: _selectedAmenities.contains(value)
                    ? _sportsOrange
                    : _sportsLine,
              ),
              selectedColor: _sportsSoftOrange,
              checkmarkColor: _sportsOrange,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedAmenities.add(value);
                  } else {
                    _selectedAmenities.remove(value);
                  }
                });
                dialogSetState?.call(() {});
              },
            ),
        ],
      );

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _area = 'All areas';
      _sport = 'All sports';
      _courtType = 'All';
      _availability = 'Any';
      _maxPrice = 700;
      _selectedAmenities.clear();
    });
  }

  Future<void> _useLocation() async {
    setState(() => _locationLoading = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage('Turn on location services to find nearby sports courts.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Location permission is required for nearby courts.');
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _position = position);
        _showMessage('Showing sports courts near your location.');
      }
    } catch (_) {
      _showMessage('Could not read your location.');
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  void _openMap() {
    final center = _position == null
        ? const LatLng(10.285, 123.885)
        : LatLng(_position!.latitude, _position!.longitude);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Sports court map'),
            backgroundColor: _sportsPage,
            foregroundColor: _sportsInk,
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
                      width: 100,
                      height: 50,
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

  Widget _mapPin(String name) => Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: _sportsNavy,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 9),
        ),
      ),
      const Icon(Icons.location_on, color: _sportsNavy),
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openVisit(String rawUrl, String name) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      _showMessage('$name does not have a visit link yet.');
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage('Could not open the visit link for $name.');
    }
  }
}
