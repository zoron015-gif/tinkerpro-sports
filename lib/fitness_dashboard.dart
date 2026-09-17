import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

const _fitnessNavy = Color(0xFF192B50);
const _fitnessInk = Color(0xFF101B33);
const _fitnessOrange = Color(0xFFFF8200);
const _fitnessLine = Color(0xFFE2E7EF);
const _fitnessMuted = Color(0xFF68748A);
const _fitnessPage = Color(0xFFF7F9FC);
const _fitnessSoftOrange = Color(0xFFFFF1E4);

class FitnessDashboardPage extends StatefulWidget {
  const FitnessDashboardPage({super.key});

  @override
  State<FitnessDashboardPage> createState() => _FitnessDashboardPageState();
}

class _FitnessDashboardPageState extends State<FitnessDashboardPage> {
  final _searchController = TextEditingController();
  final _classes = const [
    (
      name: 'Apex Pulse Fitness',
      category: 'CrossFit',
      address: 'Cebu City, Cebu',
      sessions: '12 classes today',
      hours: '5:00 AM - 10:00 PM',
      image: 'assets/book-type/fitness.jpg',
      price: '₱500 / session',
      tags: ['Showers', 'Coach', 'Parking'],
      latitude: 10.3157,
      longitude: 123.8854,
    ),
    (
      name: 'Zen Pilates Studio',
      category: 'Pilates',
      address: 'Mandaue City, Cebu',
      sessions: '8 classes today',
      hours: '6:00 AM - 9:00 PM',
      image: 'assets/book-type/fitness.jpg',
      price: '₱450 / session',
      tags: ['Beginner-friendly', 'Mats', 'Locker room'],
      latitude: 10.323,
      longitude: 123.943,
    ),
    (
      name: 'Boxing Conditioning Club',
      category: 'Boxing',
      address: 'Cebu City, Cebu',
      sessions: '10 classes today',
      hours: '7:00 AM - 11:00 PM',
      image: 'assets/book-type/fitness.jpg',
      price: '₱600 / session',
      tags: ['Equipment', 'Coach', 'Parking'],
      latitude: 10.285,
      longitude: 123.885,
    ),
    (
      name: 'Flow Yoga Wellness',
      category: 'Yoga',
      address: 'Talisay City, Cebu',
      sessions: '6 classes today',
      hours: '6:00 AM - 8:00 PM',
      image: 'assets/book-type/fitness.jpg',
      price: '₱400 / session',
      tags: ['Mats', 'Beginner-friendly', 'Shower'],
      latitude: 10.245,
      longitude: 123.796,
    ),
  ];

  String _area = 'All areas';
  String _classType = 'All classes';
  String _availability = 'Any';
  bool _filtersOpen = true;
  bool _locationLoading = false;
  Position? _position;
  final Set<String> _selectedAmenities = <String>{};

  List<dynamic> get _filteredClasses {
    final query = _searchController.text.trim().toLowerCase();
    return _classes.where((item) {
      final matchesSearch =
          query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.address.toLowerCase().contains(query);
      final matchesArea =
          _area == 'All areas' ||
          item.address.toLowerCase().contains(_area.toLowerCase());
      final matchesType =
          _classType == 'All classes' || item.category == _classType;
      final matchesAvailability =
          _availability == 'Any' ||
          (_availability == 'Open now' && item.sessions.isNotEmpty);
      final matchesAmenities = _selectedAmenities.every(
        (amenity) => item.tags.any(
          (tag) => tag.toLowerCase().startsWith(amenity.toLowerCase()),
        ),
      );
      return matchesSearch &&
          matchesArea &&
          matchesType &&
          matchesAvailability &&
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
      backgroundColor: _fitnessPage,
      appBar: AppBar(
        backgroundColor: _fitnessPage,
        foregroundColor: _fitnessInk,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          color: _fitnessNavy,
        ),
        title: const Text(
          'Fitness & Wellness',
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
              if (wide && _filtersOpen)
                SizedBox(width: 270, child: _filterPanel()),
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
        backgroundColor: Colors.white,
        indicatorColor: _fitnessSoftOrange,
        onDestinationSelected: (index) {
          if (index == 0) return;
          _message(
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
    final classes = _filteredClasses;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(wide ? 22 : 16, 14, wide ? 28 : 16, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${classes.length} of ${_classes.length} classes',
                    style: const TextStyle(
                      color: _fitnessMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Text('Sort by', style: TextStyle(color: _fitnessMuted)),
                const SizedBox(width: 5),
                const Text(
                  'Featured ▾',
                  style: TextStyle(
                    color: _fitnessInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (classes.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text('No fitness classes match these filters.'),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(wide ? 22 : 16, 4, wide ? 28 : 16, 28),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: wide ? 2 : 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: wide ? .77 : .78,
              ),
              itemCount: classes.length,
              itemBuilder: (_, index) => _classCard(classes[index]),
            ),
          ),
      ],
    );
  }

  Widget _filterPanel() {
    final mobile = MediaQuery.sizeOf(context).width < 900;
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom;
    final height = mobile ? availableHeight * .68 : availableHeight - 96;
    return SizedBox(
      height: height,
      child: Container(
        margin: EdgeInsets.fromLTRB(16, 14, mobile ? 16 : 0, 16),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _fitnessLine),
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
                        color: _fitnessInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Reset'),
                  ),
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
                    borderSide: const BorderSide(color: _fitnessLine),
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
                  foregroundColor: _fitnessNavy,
                  side: const BorderSide(color: _fitnessNavy),
                  minimumSize: const Size(double.infinity, 38),
                ),
              ),
              _gap(),
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
              _gap(),
              _label('CLASS TYPE'),
              _chips(
                const ['All classes', 'CrossFit', 'Pilates', 'Boxing', 'Yoga'],
                _classType,
                (value) => setState(() => _classType = value),
              ),
              _gap(),
              _label('AMENITIES'),
              _amenityChips(const [
                'Showers',
                'Coach',
                'Parking',
                'Mats',
                'Locker room',
                'Equipment',
              ]),
              _gap(),
              _label('AVAILABILITY'),
              _chips(
                const ['Any', 'Open now'],
                _availability,
                (value) => setState(() => _availability = value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _classCard(dynamic item) => Card(
    elevation: 1,
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 8,
          child: Image.asset(
            item.image,
            width: double.infinity,
            fit: BoxFit.cover,
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
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _fitnessInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                _detail(Icons.location_on_outlined, item.address),
                _detail(Icons.fitness_center, 'Class: ${item.category}'),
                _detail(Icons.event_available_outlined, item.sessions),
                _detail(Icons.access_time, 'Hours: ${item.hours}'),
                const SizedBox(height: 7),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFBFD),
                    border: Border.all(color: _fitnessLine),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Session price',
                          style: TextStyle(color: _fitnessMuted, fontSize: 11),
                        ),
                      ),
                      Text(
                        item.price,
                        style: const TextStyle(
                          color: _fitnessInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [for (final tag in item.tags) _tag(tag)],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _message('Booking ${item.name} is ready.'),
                    icon: const Icon(Icons.calendar_month, size: 15),
                    label: const Text('Book now'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _fitnessOrange,
                      minimumSize: const Size(0, 36),
                    ),
                  ),
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
      children: [
        Icon(icon, size: 14, color: _fitnessInk),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _fitnessMuted, fontSize: 10.5),
          ),
        ),
      ],
    ),
  );

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: _fitnessSoftOrange,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: _fitnessInk,
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
        color: _fitnessMuted,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: .4,
      ),
    ),
  );

  Widget _gap() => const SizedBox(height: 14);

  Widget _dropdown({
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: _fitnessLine),
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
          label: Text(value, style: const TextStyle(fontSize: 10)),
          selected: selected == value,
          showCheckmark: false,
          selectedColor: _fitnessSoftOrange,
          side: BorderSide(
            color: selected == value ? _fitnessOrange : _fitnessLine,
          ),
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
          selectedColor: _fitnessSoftOrange,
          side: BorderSide(
            color: _selectedAmenities.contains(value)
                ? _fitnessOrange
                : _fitnessLine,
          ),
          onSelected: (selected) => setState(() {
            if (selected) {
              _selectedAmenities.add(value);
            } else {
              _selectedAmenities.remove(value);
            }
          }),
        ),
    ],
  );

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _area = 'All areas';
      _classType = 'All classes';
      _availability = 'Any';
      _selectedAmenities.clear();
    });
  }

  Future<void> _useLocation() async {
    setState(() => _locationLoading = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _message('Turn on location services to find nearby fitness classes.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _message('Location permission is required for nearby classes.');
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _position = position);
        _message('Showing fitness classes near your location.');
      }
    } catch (_) {
      _message('Could not read your location.');
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openMap() {
    final center = _position == null
        ? const LatLng(10.3157, 123.8854)
        : LatLng(_position!.latitude, _position!.longitude);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Fitness class map'),
            backgroundColor: _fitnessPage,
            foregroundColor: _fitnessInk,
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
                  for (final item in _classes)
                    Marker(
                      point: LatLng(item.latitude, item.longitude),
                      width: 120,
                      height: 52,
                      child: _mapPin(item.name),
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
          color: _fitnessNavy,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 9),
        ),
      ),
      const Icon(Icons.location_on, color: _fitnessNavy),
    ],
  );
}
