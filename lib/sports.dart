import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'profile_dashboard.dart';
import 'reserve_dashboard.dart';
import 'saved_dashboard.dart';
import 'saved_items.dart';

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
  final _searchController = TextEditingController();
  final _venues = const [
    (
      name: 'SLT Court',
      sport: 'Tennis',
      address: 'Village, Tugas Street, Kingswood, Minglanilla, Cebu',
      type: 'Outdoor',
      courts: '1 court',
      hours: '6:00 AM - 12:00 AM',
      image: 'assets/court/pickle-court.jpg',
      priceDay: '₱300 / hr',
      priceNight: '₱350 / hr',
      maxPrice: 350,
      tags: ['Parking · 4 cars', 'Pet-friendly', 'Restroom'],
      latitude: 10.245,
      longitude: 123.796,
    ),
    (
      name: 'Pickaboo Pickleball Cebu',
      sport: 'Pickleball',
      address: '(At the back of Gaisano Tabunok) Zafra Compound, Talisay City',
      type: 'Indoor',
      courts: '3 courts',
      hours: 'Open 24 hours',
      image: 'assets/court/pickle-court.jpg',
      priceDay: '₱400 / hr',
      priceNight: '₱500 / hr',
      maxPrice: 500,
      tags: ['Parking · 30 cars', 'Pet-friendly', 'Restroom', 'Store'],
      latitude: 10.244,
      longitude: 123.833,
    ),
    (
      name: 'River Pickleball Club',
      sport: 'Volleyball',
      address: 'South Road Properties, Cebu City',
      type: 'Covered',
      courts: '4 courts',
      hours: '7:00 AM - 11:00 PM',
      image: 'assets/court/volley-court.jpg',
      priceDay: '₱350 / hr',
      priceNight: '₱450 / hr',
      maxPrice: 450,
      tags: ['Parking', 'Restroom', 'Store'],
      latitude: 10.285,
      longitude: 123.885,
    ),
    (
      name: 'Cebu Sports Hub',
      sport: 'Basketball',
      address: 'Mandaue City, Cebu',
      type: 'Indoor',
      courts: '6 courts',
      hours: 'Open 24 hours',
      image: 'assets/court/basket-court.jpg',
      priceDay: '₱450 / hr',
      priceNight: '₱550 / hr',
      maxPrice: 550,
      tags: ['Parking', 'Shower', 'Restroom'],
      latitude: 10.323,
      longitude: 123.943,
    ),
  ];

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

  List<dynamic> get _filteredVenues {
    final query = _searchController.text.trim().toLowerCase();
    final venues = _venues.where((venue) {
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
          onPressed: () => Navigator.of(
            context,
            rootNavigator: true,
          ).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => ReserveDashboardPage(
                onLogout: widget.onLogout,
              ),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        backgroundColor: _sportsSurface,
        indicatorColor: _sportsSoftOrange,
        onDestinationSelected: (index) {
          if (index == 0) return;
          if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileDashboardPage(onLogout: widget.onLogout),
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
          _showMessage(
            switch (index) {
              1 => 'Saved venues will appear here.',
              2 => 'Booking history will appear here.',
              _ => 'Profile will appear here.',
            },
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on_rounded),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today_rounded),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
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
                    '${venues.length == _venues.length ? 55 : venues.length} of 55 courts',
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
                    DropdownMenuItem(value: 'Nearest', child: Text('Nearest')),
                    DropdownMenuItem(value: 'Name A-Z', child: Text('Name A-Z')),
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
            child: Center(child: Text('No sports courts match these filters.')),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(wide ? 22 : 16, 4, wide ? 28 : 16, 28),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: wide ? 2 : 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: wide ? .77 : .70,
              ),
              itemCount: venues.length,
              itemBuilder: (context, index) => _courtCard(venues[index]),
            ),
          ),
        ],
      ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 8,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(venue.image, fit: BoxFit.cover),
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
              Positioned(
                right: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '♧ 3',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 12,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
            child: Column(
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
                const SizedBox(height: 6),
                _priceBox(venue),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [for (final tag in venue.tags) _tag(tag)],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showMessage('Opening ${venue.name}'),
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
                        onPressed: () =>
                            _showMessage('Booking ${venue.name} is ready.'),
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
        ),
      ],
    ),
  );

  Future<void> _toggleSaved({
    required String type,
    required String key,
    required String title,
    required String subtitle,
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
        _priceLine('Daily · 6:00 AM–4:00 PM', venue.priceDay),
        _priceLine('Daily · 4:00 PM–12:00 AM', venue.priceNight),
      ],
    ),
  );

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
          label: Text(value, style: const TextStyle(fontSize: 10)),
          selected: selected == value,
          showCheckmark: false,
          side: BorderSide(
            color: selected == value ? _sportsOrange : _sportsLine,
          ),
          selectedColor: _sportsSoftOrange,
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
              label: Text(value, style: const TextStyle(fontSize: 10)),
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
                  for (final venue in _venues)
                    Marker(
                      point: LatLng(venue.latitude, venue.longitude),
                      width: 100,
                      height: 50,
                      child: _mapPin(venue.name),
                    ),
                  if (_position != null)
                    Marker(
                      point: LatLng(
                        _position!.latitude,
                        _position!.longitude,
                      ),
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
}
