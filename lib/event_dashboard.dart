import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'profile_dashboard.dart';
import 'reserve_dashboard.dart';
import 'saved_dashboard.dart';
import 'saved_items.dart';

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
  final _venues = const [
    (
      'Grand Ballroom',
      'Ballroom',
      'Cebu City, Cebu',
      '₱25,000 / event',
      'Banquet · 250 guests',
      10.3157,
      123.8854,
    ),
    (
      'Skyline Terrace',
      'Terrace',
      'Mandaue City, Cebu',
      '₱18,000 / event',
      'Cocktail · 120 guests',
      10.323,
      123.943,
    ),
    (
      'Private Dining Hall',
      'Private Dining',
      'Cebu City, Cebu',
      '₱12,000 / event',
      'Dining · 40 guests',
      10.285,
      123.885,
    ),
    (
      'Garden Celebration Venue',
      'Garden',
      'Talisay City, Cebu',
      '₱20,000 / event',
      'Outdoor · 180 guests',
      10.245,
      123.796,
    ),
  ];

  String _area = 'All areas';
  String _type = 'All venues';
  bool _filtersOpen = true;
  bool _locationLoading = false;
  Position? _position;
  final Set<String> _savedKeys = <String>{};
  final Map<String, int> _saveCounts = <String, int>{};
  String _sortBy = 'Featured';

  List<dynamic> get _filteredVenues {
    final query = _searchController.text.trim().toLowerCase();
    final venues = _venues.where((venue) {
      final search =
          query.isEmpty ||
          venue.$1.toLowerCase().contains(query) ||
          venue.$3.toLowerCase().contains(query);
      final area =
          _area == 'All areas' ||
          venue.$3.toLowerCase().contains(_area.toLowerCase());
      final type = _type == 'All venues' || venue.$2 == _type;
      return search && area && type;
    }).toList();
    venues.sort((a, b) {
      switch (_sortBy) {
        case 'Name A-Z':
          return a.$1.compareTo(b.$1);
        case 'Price: low to high':
          return _eventPrice(a.$4).compareTo(_eventPrice(b.$4));
        case 'Price: high to low':
          return _eventPrice(b.$4).compareTo(_eventPrice(a.$4));
        case 'Nearest':
          if (_position == null) return 0;
          return _distanceSquared(
            _position!.latitude,
            _position!.longitude,
            a.$6,
            a.$7,
          ).compareTo(
            _distanceSquared(
              _position!.latitude,
              _position!.longitude,
              b.$6,
              b.$7,
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
          onPressed: () => Navigator.of(
            context,
            rootNavigator: true,
          ).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => ReserveDashboardPage(onLogout: widget.onLogout),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        backgroundColor: Colors.white,
        indicatorColor: _eventSoftOrange,
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
                  itemType: 'event',
                ),
              ),
            );
            return;
          }
          _message(switch (index) {
            1 => 'Saved venues will appear here.',
            2 => 'Booking history will appear here.',
            _ => 'Profile will appear here.',
          });
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
                      '${venues.length} of ${_venues.length} venues',
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
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: wide ? 2 : 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: wide ? .77 : .78,
                ),
                itemCount: venues.length,
                itemBuilder: (_, index) => _venueCard(venues[index]),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 8,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/book-type/event.jpg',
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filled(
                      tooltip: _savedKeys.contains(venue.$1)
                          ? 'Unsave venue'
                          : 'Save venue',
                      style: IconButton.styleFrom(
                        backgroundColor: _savedKeys.contains(venue.$1)
                            ? _eventOrange
                            : Colors.white,
                        foregroundColor: _savedKeys.contains(venue.$1)
                            ? Colors.white
                            : _eventNavy,
                      ),
                      onPressed: () => _toggleSaved(
                        key: venue.$1,
                        title: venue.$1,
                        subtitle: 'Venue: ${venue.$2}\n${venue.$3}',
                      ),
                      icon: Icon(
                        _savedKeys.contains(venue.$1)
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                    ),
                    _saveCount(_saveCounts[venue.$1] ?? 0),
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
                  venue.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _eventInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                _detail(Icons.location_on_outlined, venue.$3),
                _detail(Icons.celebration_outlined, 'Type: ${venue.$2}'),
                _detail(Icons.groups_outlined, venue.$5),
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
                        venue.$4,
                        style: const TextStyle(
                          color: _eventInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _message('Booking ${venue.$1} is ready.'),
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
          ),
        ),
      ],
    ),
  );

  Future<void> _toggleSaved({
    required String key,
    required String title,
    required String subtitle,
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
          label: Text(value, style: const TextStyle(fontSize: 10)),
          selected: selected == value,
          showCheckmark: false,
          selectedColor: _eventSoftOrange,
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
                  for (final venue in _venues)
                    Marker(
                      point: LatLng(venue.$6, venue.$7),
                      width: 120,
                      height: 52,
                      child: _mapPin(venue.$1),
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
