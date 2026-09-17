import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'profile_dashboard.dart';
import 'saved_dashboard.dart';
import 'saved_items.dart';

const _fitnessNavy = Color(0xFF192B50);
const _fitnessInk = Color(0xFF101B33);
const _fitnessOrange = Color(0xFFFF8200);
const _fitnessLine = Color(0xFFE2E7EF);
const _fitnessMuted = Color(0xFF68748A);
const _fitnessPage = Color(0xFFF7F9FC);
const _fitnessSoftOrange = Color(0xFFFFF1E4);

class FitnessDashboardPage extends StatefulWidget {
  const FitnessDashboardPage({super.key, this.onLogout});

  final Future<void> Function(BuildContext context)? onLogout;

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
  final Set<String> _savedKeys = <String>{};
  final Map<String, int> _saveCounts = <String, int>{};
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
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    try {
      final saved = await SavedItemStore.list();
      final counts = await SavedItemStore.counts('fitness');
      if (!mounted) return;
      setState(() {
        _savedKeys
          ..clear()
          ..addAll(
            saved
                .where((item) => item['itemType'] == 'fitness')
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
        indicatorColor: _fitnessSoftOrange,
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
                builder: (_) => SavedDashboardPage(onLogout: widget.onLogout),
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

  Widget _mainSearchBar() => Container(
    color: _fitnessPage,
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search classes, areas, or fitness types...',
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
          borderSide: const BorderSide(color: _fitnessLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: _fitnessLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: _fitnessOrange, width: 1.5),
        ),
      ),
    ),
  );

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
                                  color: _fitnessInk,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                _resetFilters();
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
                                backgroundColor: _fitnessNavy,
                                minimumSize: const Size.fromHeight(48),
                              ),
                              child: Text(
                                'Apply Filters (${_filteredClasses.length})',
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
                borderSide: const BorderSide(color: _fitnessLine),
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
              foregroundColor: _fitnessNavy,
              side: const BorderSide(color: _fitnessNavy),
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
          _gap(),
          _label('AREA / CITY'),
          _dropdown(
            value: _area,
            values: const ['All areas', 'Cebu City', 'Mandaue City', 'Talisay'],
            onChanged: (value) => update(() => _area = value),
          ),
          _gap(),
          _label('CLASS TYPE'),
          _chips(
            const ['All classes', 'CrossFit', 'Pilates', 'Boxing', 'Yoga'],
            _classType,
            (value) => update(() => _classType = value),
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
            (value) => update(() => _availability = value),
          ),
        ],
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                item.image,
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
                      tooltip: _savedKeys.contains(item.name)
                          ? 'Unsave class'
                          : 'Save class',
                      style: IconButton.styleFrom(
                        backgroundColor: _savedKeys.contains(item.name)
                            ? _fitnessOrange
                            : Colors.white,
                        foregroundColor: _savedKeys.contains(item.name)
                            ? Colors.white
                            : _fitnessNavy,
                      ),
                      onPressed: () => _toggleSaved(
                        key: item.name,
                        title: item.name,
                        subtitle: item.address,
                      ),
                      icon: Icon(
                        _savedKeys.contains(item.name)
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                    ),
                    _saveCount(_saveCounts[item.name] ?? 0),
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

  Future<void> _toggleSaved({
    required String key,
    required String title,
    required String subtitle,
  }) async {
    try {
      if (_savedKeys.contains(key)) {
        await SavedItemStore.remove('fitness', key);
        setState(() {
          _savedKeys.remove(key);
          _saveCounts[key] = (_saveCounts[key] ?? 1) - 1;
        });
        _message('$title removed from Saved.');
      } else {
        await SavedItemStore.save(
          type: 'fitness',
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
          color: _fitnessNavy,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
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
