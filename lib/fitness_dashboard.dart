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

typedef FitnessClass = ({
  String name,
  String category,
  String address,
  String sessions,
  String facility,
  String hours,
  String availability,
  String specialRates,
  String details,
  String image,
  List<String> images,
  String price,
  List<String> tags,
  double latitude,
  double longitude,
  String visitUrl,
});

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
  final List<FitnessClass> _merchantClasses = [];
  List<FitnessClass> get _allClasses => _merchantClasses;

  String _area = 'All areas';
  String _classType = 'All classes';
  String _availability = 'Any';
  final bool _filtersOpen = true;
  bool _locationLoading = false;
  Position? _position;
  final Set<String> _savedKeys = <String>{};
  final Map<String, int> _saveCounts = <String, int>{};
  final Set<String> _selectedAmenities = <String>{};
  String _sortBy = 'Featured';

  List<dynamic> get _filteredClasses {
    final query = _searchController.text.trim().toLowerCase();
    final classes = _allClasses.where((item) {
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
    classes.sort((a, b) {
      switch (_sortBy) {
        case 'Name A-Z':
          return a.name.compareTo(b.name);
        case 'Price: low to high':
          return _fitnessPrice(a.price).compareTo(_fitnessPrice(b.price));
        case 'Price: high to low':
          return _fitnessPrice(b.price).compareTo(_fitnessPrice(a.price));
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
    return classes;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
    _loadSavedState();
    _loadMerchantBusinesses();
  }

  String _normalizedBusinessType(Map<String, dynamic> business) {
    final candidates = [
      business['businessType'],
      business['business_type'],
      business['bookingType'],
      business['type'],
      business['category'],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        final value = candidate.trim();
        final normalized = value.toLowerCase();
        if (normalized == 'fitness' ||
            normalized == 'wellness' ||
            normalized.contains('fitness') ||
            normalized.contains('wellness')) {
          return 'Fitness & Wellness';
        }
        return value;
      }
    }
    return 'Fitness & Wellness';
  }

  Future<void> _loadMerchantBusinesses() async {
    try {
      final rows = await AuthApi().customerBusinesses();
      if (!mounted) return;
      setState(
        () => _merchantClasses
          ..clear()
          ..addAll(
            rows
                .where((b) {
                  final type = _normalizedBusinessType(b);
                  return type == 'Fitness & Wellness' ||
                      type == 'Fitness' ||
                      type == 'Wellness';
                })
                .map(_fitnessClass),
          ),
      );
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Could not load fitness businesses: $error'),
            ),
          );
      }
    }
  }

  FitnessClass _fitnessClass(Map<String, dynamic> b) {
    final businessType = _normalizedBusinessType(b);
    final rawTags = b['tags'] ?? b['amenities'] ?? b['amenities_json'];
    final tags = rawTags is List
        ? rawTags.whereType<String>().toList()
        : rawTags is String
        ? _decodeStringList(rawTags)
        : <String>[];
    final priceValue =
        b['pricePerHour'] ??
        b['price_per_hour'] ??
        b['price'] ??
        b['hourlyRate'];
    final parsedPrice = double.tryParse('$priceValue');
    final ratePeriods = _decodeRatePeriods(
      b['ratePeriods'] ?? b['rate_periods'],
    );
    final images = _merchantImages(b);
    return (
      name: '${b['name'] ?? 'Business'}',
      category: '${b['category'] ?? businessType}',
      address: '${b['address'] ?? ''}',
      sessions: '${b['sessions'] ?? b['session'] ?? ''}',
      facility: '${b['facilityType'] ?? b['facility_type'] ?? ''}',
      hours: '${b['hours'] ?? b['opening_hours'] ?? 'Open hours'}',
      availability: '${b['availability'] ?? ''}',
      specialRates: _formatRatePeriods(ratePeriods),
      details: '${b['details'] ?? ''}',
      image: _merchantImage(b),
      images: images,
      price: parsedPrice == null
          ? ''
          : 'PHP ${parsedPrice.toStringAsFixed(0)} / session',
      tags: tags,
      latitude: 10.3157,
      longitude: 123.8854,
      visitUrl: '${b['visitUrl'] ?? b['visit_url'] ?? ''}',
    );
  }

  List<Map<String, dynamic>> _decodeRatePeriods(dynamic value) {
    dynamic decoded = value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(value);
      } on FormatException {
        return const [];
      }
    }
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((period) => Map<String, dynamic>.from(period))
        .where(
          (period) =>
              '${period['start'] ?? period['start_time'] ?? ''}'
                  .trim()
                  .isNotEmpty &&
              '${period['end'] ?? period['end_time'] ?? ''}'.trim().isNotEmpty,
        )
        .toList();
  }

  String _formatRatePeriods(List<Map<String, dynamic>> periods) => periods
      .map((period) {
        final start = period['start'] ?? period['start_time'];
        final end = period['end'] ?? period['end_time'];
        final value = period['pricePerHour'] ?? period['price_per_hour'];
        final price = double.tryParse('$value');
        final formattedPrice = price == null
            ? ''
            : ' (PHP ${price.toStringAsFixed(0)} / hr)';
        return '$start - $end$formattedPrice';
      })
      .join(', ');

  List<String> _decodeStringList(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } on FormatException {
      return value.trim().isEmpty ? <String>[] : [value.trim()];
    }
    return value.trim().isEmpty ? <String>[] : [value.trim()];
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
    if (images.isEmpty) {
      images.add('assets/book-type/fitness.jpg');
    }
    return images;
  }

  ImageProvider _fitnessImageProvider(String image) {
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
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
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
          color: _fitnessNavy,
        ),
        title: const Text(
          'Fitness & Wellness',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
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
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.black,
            shadowColor: Colors.transparent,
            indicatorColor: _fitnessSoftOrange,
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                color: selected ? const Color(0xFFFF8200) : Colors.white,
                size: 24,
              );
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                color: selected ? Colors.white : Colors.white,
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
                    itemType: 'fitness',
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
    final classes = _filteredClasses;
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadMerchantBusinesses(), _loadSavedState()]);
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
                      '${classes.length} of ${_allClasses.length} classes',
                      style: const TextStyle(
                        color: _fitnessMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Text('Sort by', style: TextStyle(color: _fitnessMuted)),
                  const SizedBox(width: 5),
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
          if (classes.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('No fitness classes match these filters.'),
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
                        for (final item in classes)
                          SizedBox(width: itemWidth, child: _classCard(item)),
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
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: () => _showFitnessGallery(item.images),
                child: PageView.builder(
                  itemCount: item.images.length > 1 ? 10000 : 1,
                  itemBuilder: (_, index) => Image(
                    image: _fitnessImageProvider(
                      item.images[index % item.images.length],
                    ),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) => Image.asset(
                      'assets/book-type/fitness.jpg',
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
                        subtitle: 'Class: ${item.category}\n${item.address}',
                        imageUrl: item.image,
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
              if (item.images.length > 1)
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
                        '${item.images.length} photos',
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
              if (item.facility.isNotEmpty)
                _detail(Icons.business_outlined, 'Facility: ${item.facility}'),
              if (item.sessions.isNotEmpty)
                _detail(Icons.event_available_outlined, item.sessions),
              _detail(Icons.access_time, 'Hours: ${item.hours}'),
              if (item.availability.isNotEmpty)
                _detail(
                  Icons.check_circle_outline,
                  'Availability: ${item.availability}',
                ),
              if (item.specialRates.isNotEmpty)
                _detail(
                  Icons.payments_outlined,
                  'Special rates: ${item.specialRates}',
                ),
              if (item.details.isNotEmpty)
                _detail(Icons.info_outline, item.details),
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
                      item.specialRates.isNotEmpty
                          ? 'See special rates above'
                          : item.price.isEmpty
                          ? 'Price not set'
                          : item.price,
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
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openVisit(item.visitUrl, item.name),
                      icon: const Icon(Icons.language, size: 15),
                      label: const Text('Visit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _fitnessNavy,
                        side: const BorderSide(color: _fitnessNavy),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          _message('Booking ${item.name} is ready.'),
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

  Future<void> _showFitnessGallery(List<String> images) async {
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
                      image: _fitnessImageProvider(
                        images[page % images.length],
                      ),
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
          color: _fitnessNavy,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );

  int _fitnessPrice(String value) =>
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
          label: Text(
            value,
            style: TextStyle(
              fontSize: 10,
              color: selected == value ? _fitnessOrange : _fitnessInk,
              fontWeight: selected == value ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          selected: selected == value,
          showCheckmark: false,
          selectedColor: _fitnessSoftOrange,
          checkmarkColor: _fitnessOrange,
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
          label: Text(
            value,
            style: TextStyle(
              fontSize: 10,
              color: _selectedAmenities.contains(value)
                  ? _fitnessOrange
                  : _fitnessInk,
              fontWeight: _selectedAmenities.contains(value)
                  ? FontWeight.w800
                  : FontWeight.w600,
            ),
          ),
          selected: _selectedAmenities.contains(value),
          showCheckmark: false,
          selectedColor: _fitnessSoftOrange,
          checkmarkColor: _fitnessOrange,
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
                  for (final item in _allClasses)
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
