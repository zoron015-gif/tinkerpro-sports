import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

const _sportsNavy = Color(0xFF192B50);
const _sportsInk = Color(0xFF101B33);
const _sportsOrange = Color(0xFFFF8200);
const _sportsLine = Color(0xFFE2E7EF);
const _sportsMuted = Color(0xFF68748A);
const _sportsPage = Color(0xFFF7F9FC);
const _sportsSurface = Colors.white;
const _sportsSoftOrange = Color(0xFFFFF1E4);

class SportsDashboardPage extends StatefulWidget {
  const SportsDashboardPage({super.key});

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
  bool _filtersOpen = true;
  bool _locationLoading = false;
  Position? _position;

  List<dynamic> get _filteredVenues {
    final query = _searchController.text.trim().toLowerCase();
    return _venues.where((venue) {
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
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
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
          onPressed: () => Navigator.of(context).pop(),
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
          if (MediaQuery.sizeOf(context).width < 900)
            IconButton(
              tooltip: 'Filters',
              onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
              icon: Icon(
                _filtersOpen
                    ? Icons.filter_list_off_rounded
                    : Icons.filter_list_rounded,
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wide) SizedBox(width: 270, child: _filterPanel()),
              Expanded(
                child: Column(
                  children: [
                    if (!wide && _filtersOpen) _filterPanel(),
                    Expanded(child: _results(wide)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        backgroundColor: _sportsSurface,
        indicatorColor: _sportsSoftOrange,
        onDestinationSelected: (index) {
          if (index == 0) return;
          _showMessage(
            index == 1
                ? 'Booking history will appear here.'
                : 'Profile will appear here.',
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
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
    return CustomScrollView(
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
                  value: 'Featured',
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: 'Featured',
                      child: Text('Featured'),
                    ),
                    DropdownMenuItem(value: 'Nearest', child: Text('Nearest')),
                  ],
                  onChanged: (_) {},
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
    );
  }

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
              _label('SEARCH'),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Name, area, keyword...',
                  hintStyle: const TextStyle(fontSize: 12, color: _sportsMuted),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: _sportsLine),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: _sportsLine),
                  ),
                ),
              ),
              _sectionGap(),
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

  Widget _amenityChips(List<String> values) => Wrap(
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
