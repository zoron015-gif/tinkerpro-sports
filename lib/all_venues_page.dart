import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

const _venuesMuted = Color(0xFF68748A);
const _venuesOrange = Color(0xFFFF8200);
const _venuesInk = Color(0xFF101B33);

class AllVenuesPage extends StatefulWidget {
  const AllVenuesPage({
    super.key,
    required this.title,
    required this.posts,
    required this.cardBuilder,
  });

  final String title;
  final List<Map<String, dynamic>> posts;
  final Widget Function(Map<String, dynamic> post) cardBuilder;

  @override
  State<AllVenuesPage> createState() => _AllVenuesPageState();
}

class _AllVenuesPageState extends State<AllVenuesPage> {
  final _searchController = TextEditingController();
  String _area = 'All areas';
  String _sport = 'All sports';
  String _courtType = 'All';
  String _availability = 'Any';
  String _priceSort = 'Recommended';
  double _maxPrice = 700;
  Position? _userPosition;
  bool _locationLoading = false;
  final Set<String> _amenities = <String>{};
  var _headerVisible = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visiblePosts {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.posts.where((post) {
      final address = '${post['address'] ?? ''}'.toLowerCase();
      final category = '${post['category'] ?? ''}'.toLowerCase();
      final facility = '${post['facilityType'] ?? ''}'.toLowerCase();
      final hours = '${post['hours'] ?? post['opening_hours'] ?? ''}'
          .toLowerCase();
      final availability = '${post['availability'] ?? ''}'.toLowerCase();
      final price = _venuePrice(post);
      final rawAmenities = '${post['tags'] ?? post['amenities'] ?? ''}'
          .toLowerCase();
      final searchable = [
        post['businessName'],
        post['businessType'],
        post['category'],
        post['address'],
        post['title'],
        post['body'],
      ].map((value) => '$value').join(' ').toLowerCase();
      return (_area == 'All areas' || address.contains(_area.toLowerCase())) &&
          (_sport == 'All sports' || category == _sport.toLowerCase()) &&
          (_courtType == 'All' || facility == _courtType.toLowerCase()) &&
          (_availability == 'Any' ||
              hours.contains('open 24 hours') ||
              availability.contains('open 24 hours')) &&
          price <= _maxPrice &&
          _amenities.every(
            (amenity) => rawAmenities.contains(amenity.toLowerCase()),
          ) &&
          (query.isEmpty || searchable.contains(query));
    }).toList();
    if (_priceSort == 'Lowest to highest') {
      filtered.sort((a, b) => _venuePrice(a).compareTo(_venuePrice(b)));
    } else if (_priceSort == 'Highest to lowest') {
      filtered.sort((a, b) => _venuePrice(b).compareTo(_venuePrice(a)));
    } else if (_userPosition case final position?) {
      filtered.sort(
        (a, b) =>
            _distanceFrom(position, a).compareTo(_distanceFrom(position, b)),
      );
    }
    return filtered;
  }

  double _venuePrice(Map<String, dynamic> post) =>
      double.tryParse(
        '${post['pricePerHour'] ?? post['price_per_hour'] ?? post['eventFee'] ?? post['event_fee'] ?? 0}',
      ) ??
      0;

  double _distanceFrom(Position position, Map<String, dynamic> post) {
    final latitude = double.tryParse(
      '${post['latitude'] ?? post['lat'] ?? ''}',
    );
    final longitude = double.tryParse(
      '${post['longitude'] ?? post['lng'] ?? ''}',
    );
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return double.infinity;
    }
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      latitude,
      longitude,
    );
  }

  List<String> _options(
    String Function(Map<String, dynamic>) selector,
    String allLabel,
  ) {
    final values =
        widget.posts
            .map(selector)
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return [allLabel, ...values];
  }

  void _resetFilters(StateSetter setSheetState) {
    setState(() {
      _area = 'All areas';
      _sport = 'All sports';
      _courtType = 'All';
      _availability = 'Any';
      _priceSort = 'Recommended';
      _maxPrice = 700;
      _userPosition = null;
      _amenities.clear();
    });
    setSheetState(() {});
  }

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .78,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Filter venues',
                          style: TextStyle(
                            color: _venuesInk,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('all-venues-filter-reset'),
                        onPressed: () => _resetFilters(setSheetState),
                        child: const Text('Reset'),
                      ),
                      IconButton(
                        tooltip: 'Close filters',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    children: [
                      _filterLabel('Sport type'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final value in _options(
                            (post) => '${post['category'] ?? ''}',
                            'All sports',
                          ))
                            ChoiceChip(
                              key: ValueKey('all-venues-filter-sport-$value'),
                              label: Text(value),
                              selected: _sport == value,
                              selectedColor: _venuesOrange,
                              onSelected: (_) {
                                setState(() => _sport = value);
                                setSheetState(() {});
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _filterLabel('Area / city'),
                      OutlinedButton.icon(
                        key: const ValueKey('all-venues-use-my-location'),
                        onPressed: _locationLoading
                            ? null
                            : () => _useMyLocation(
                                refreshSheet: () {
                                  if (sheetContext.mounted) {
                                    setSheetState(() {});
                                  }
                                },
                              ),
                        icon: _locationLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _userPosition == null
                                    ? Icons.my_location_rounded
                                    : Icons.location_on_rounded,
                              ),
                        label: Text(
                          _locationLoading
                              ? 'Getting your location...'
                              : _userPosition == null
                              ? 'Use my location'
                              : 'Using my location · nearest first',
                        ),
                      ),
                      _dropdown(
                        value: _area,
                        options: _options(
                          (post) => '${post['address'] ?? ''}',
                          'All areas',
                        ),
                        onChanged: (value) {
                          setState(() => _area = value);
                          setSheetState(() {});
                        },
                      ),
                      const SizedBox(height: 14),
                      _filterLabel('Court type'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final value in [
                            'All',
                            ..._options(
                              (post) => '${post['facilityType'] ?? ''}',
                              '',
                            ).where((value) => value.isNotEmpty),
                          ])
                            ChoiceChip(
                              key: ValueKey('all-venues-filter-court-$value'),
                              label: Text(value),
                              selected: _courtType == value,
                              selectedColor: _venuesOrange,
                              onSelected: (_) {
                                setState(() => _courtType = value);
                                setSheetState(() {});
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _filterLabel('Amenities'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final value in const [
                            'Parking',
                            'Pet-friendly',
                            'Restroom',
                            'Shower',
                            'Store',
                          ])
                            FilterChip(
                              key: ValueKey('all-venues-filter-amenity-$value'),
                              label: Text(value),
                              selected: _amenities.contains(value),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _amenities.add(value);
                                  } else {
                                    _amenities.remove(value);
                                  }
                                });
                                setSheetState(() {});
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _filterLabel('Availability'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final value in const ['Any', 'Open 24 hours'])
                            ChoiceChip(
                              key: ValueKey(
                                'all-venues-filter-availability-$value',
                              ),
                              label: Text(value),
                              selected: _availability == value,
                              selectedColor: _venuesOrange,
                              onSelected: (_) {
                                setState(() => _availability = value);
                                setSheetState(() {});
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _filterLabel('Price (PHP / hour)'),
                      Slider(
                        key: const ValueKey('all-venues-filter-price'),
                        value: _maxPrice,
                        min: 0,
                        max: 700,
                        divisions: 14,
                        label: _maxPrice >= 700
                            ? '700+'
                            : _maxPrice.round().toString(),
                        onChanged: (value) {
                          setState(() => _maxPrice = value);
                          setSheetState(() {});
                        },
                      ),
                      const SizedBox(height: 8),
                      _filterLabel('Sort price'),
                      _dropdown(
                        value: _priceSort,
                        options: const [
                          'Recommended',
                          'Lowest to highest',
                          'Highest to lowest',
                        ],
                        onChanged: (value) {
                          setState(() => _priceSort = value);
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('all-venues-filter-apply'),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: _venuesInk,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text('Show ${_visiblePosts.length} venues'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _useMyLocation({required VoidCallback refreshSheet}) async {
    setState(() => _locationLoading = true);
    refreshSheet();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showLocationMessage(
          'Location services are off. Turn them on to find nearby venues.',
          actionLabel: 'Location settings',
          onAction: Geolocator.openLocationSettings,
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _showLocationMessage(
          'Location permission was denied. Allow access to sort venues by distance.',
        );
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _showLocationMessage(
          'Location permission is blocked. Enable it in app settings.',
          actionLabel: 'App settings',
          onAction: Geolocator.openAppSettings,
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() => _userPosition = position);
      refreshSheet();
      _showLocationMessage('Venues are now ordered nearest to your location.');
    } on Exception catch (error) {
      _showLocationMessage('Could not get your location: $error');
    } finally {
      if (mounted) {
        setState(() => _locationLoading = false);
        refreshSheet();
      }
    }
  }

  void _showLocationMessage(
    String message, {
    String? actionLabel,
    Future<bool> Function()? onAction,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: () => onAction()),
        ),
      );
  }

  Widget _filterLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: _venuesMuted,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: .8,
      ),
    ),
  );

  Widget _dropdown({
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: options.contains(value) ? value : options.first,
    items: [
      for (final option in options)
        DropdownMenuItem(value: option, child: Text(option)),
    ],
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
    decoration: const InputDecoration(
      filled: true,
      fillColor: Color(0xFFF8FAFC),
      border: OutlineInputBorder(),
    ),
  );

  bool _handleListScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final visible = notification.metrics.pixels <= 0;
    if (_headerVisible != visible) {
      setState(() => _headerVisible = visible);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F9FC),
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF101B33),
      title: Text(
        widget.title,
        style: const TextStyle(
          color: Color(0xFF101B33),
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      actions: [
        IconButton(
          key: const ValueKey('all-venues-open-filters'),
          tooltip: 'Filter venues',
          onPressed: _openFilters,
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    ),
    body: Column(
      children: [
        Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.topCenter,
              curve: Curves.easeInOut,
              child: _headerVisible
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.title == 'Most popular'
                                    ? 'Popular courts near you'
                                    : 'Courts with the highest ratings',
                                key: const ValueKey('all-venues-header-title'),
                                maxLines: 1,
                                softWrap: false,
                                style: const TextStyle(
                                  color: Color(0xFF101B33),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Browse every venue in this collection.',
                            style: TextStyle(
                              color: _venuesMuted,
                              fontSize: 13,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    )
                  : const SizedBox(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: TextField(
                key: const ValueKey('all-venues-search'),
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search venues, sports, or areas...',
                  hintStyle: const TextStyle(fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: _venuesOrange),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFE2E7EF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFE2E7EF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: _venuesOrange,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleListScroll,
            child: _visiblePosts.isEmpty
                ? const Center(
                    child: Text(
                      'No venues match your filters or search.',
                      style: TextStyle(color: _venuesMuted, fontSize: 16),
                    ),
                  )
                : ListView.separated(
                    key: const ValueKey('all-venues-list'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    itemCount: _visiblePosts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, index) =>
                        widget.cardBuilder(_visiblePosts[index]),
                  ),
          ),
        ),
      ],
    ),
  );
}
