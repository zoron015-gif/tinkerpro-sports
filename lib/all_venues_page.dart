import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'app_design_system.dart';
import 'filter_panel_style.dart';
import 'app_preferences.dart';

Color get _venuesMuted => AppColors.muted;
Color get _venuesOrange => AppColors.accentForeground;

class AllVenuesPage extends StatefulWidget {
  const AllVenuesPage({
    super.key,
    required this.title,
    required this.posts,
    required this.cardBuilder,
    this.initialUserPosition,
    this.categoryFilterLabel = 'Sport type',
    this.categoryAllLabel = 'All sports',
    this.facilityFilterLabel = 'Court type',
    this.popularHeading = 'Courts with the most hearts',
    this.ratedHeading = 'Courts with the highest ratings',
    this.searchHint = 'Search venues, sports, or areas...',
    this.collectionDescription = 'Browse every venue in this collection.',
    this.priceFilterLabel = 'Price (\u{20B1} / hour)',
  });

  final String title;
  final List<Map<String, dynamic>> posts;
  final Widget Function(Map<String, dynamic> post) cardBuilder;
  final Position? initialUserPosition;
  final String categoryFilterLabel;
  final String categoryAllLabel;
  final String facilityFilterLabel;
  final String popularHeading;
  final String ratedHeading;
  final String searchHint;
  final String collectionDescription;
  final String priceFilterLabel;

  @override
  State<AllVenuesPage> createState() => _AllVenuesPageState();
}

class _AllVenuesPageState extends State<AllVenuesPage> {
  final _searchController = TextEditingController();
  String _area = 'All areas';
  late String _sport;
  String _courtType = 'All';
  String _availability = 'Any';
  String _priceSort = 'Recommended';
  double _maxPrice = 700;
  Position? _userPosition;
  bool _locationLoading = false;
  final Set<String> _amenities = <String>{};
  var _headerVisible = true;

  @override
  void initState() {
    super.initState();
    _sport = widget.categoryAllLabel;
    _userPosition = widget.initialUserPosition;
    _maxPrice = _priceFilterMaximum;
  }

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
        post['facilityType'],
        post['hours'],
        post['availability'],
        post['tags'],
        post['amenities'],
      ].map((value) => '$value').join(' ').toLowerCase();
      return (_area == 'All areas' || address.contains(_area.toLowerCase())) &&
          (_sport == widget.categoryAllLabel ||
              category == _sport.toLowerCase()) &&
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

  double get _priceFilterMaximum {
    var maximum = 700.0;
    for (final post in widget.posts) {
      final price = _venuePrice(post);
      if (price > maximum) maximum = price;
    }
    return (maximum / 100).ceil() * 100.0;
  }

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
      _sport = widget.categoryAllLabel;
      _courtType = 'All';
      _availability = 'Any';
      _priceSort = 'Recommended';
      _maxPrice = _priceFilterMaximum;
      _userPosition = null;
      _amenities.clear();
    });
    setSheetState(() {});
  }

  int get _activeFilterCount =>
      (_area == 'All areas' ? 0 : 1) +
      (_sport == widget.categoryAllLabel ? 0 : 1) +
      (_courtType == 'All' ? 0 : 1) +
      (_availability == 'Any' ? 0 : 1) +
      (_priceSort == 'Recommended' ? 0 : 1) +
      (_maxPrice >= _priceFilterMaximum ? 0 : 1) +
      _amenities.length +
      (_userPosition == null ? 0 : 1);

  void _openFilters() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close venue filters',
      barrierColor: Colors.black54,
      transitionDuration: filterPanelTransitionDuration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) => Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          key: const ValueKey('filter-panel-surface'),
          width: filterPanelWidth(context),
          height: double.infinity,
          child: Material(
            color: AppColors.surface,
            elevation: 24,
            child: StatefulBuilder(
              builder: (context, setSheetState) => SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: filterPanelHeaderPadding,
                      child: Row(
                        children: [
                          Expanded(
                            child: AppText(
                              'Filter venues',
                              style: filterPanelTitleStyle,
                              localize: true,
                            ),
                          ),
                          TextButton(
                            key: const ValueKey('all-venues-filter-reset'),
                            onPressed: () => _resetFilters(setSheetState),
                            child: const AppText('Reset', localize: true),
                          ),
                          IconButton(
                            tooltip: appLanguageText(
                              'Close filters',
                              'Close filters',
                            ),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView(
                        padding: filterPanelContentPadding,
                        children: [
                          _filterLabel(widget.categoryFilterLabel),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final value in _options(
                                (post) => '${post['category'] ?? ''}',
                                widget.categoryAllLabel,
                              ))
                                ChoiceChip(
                                  key: ValueKey(
                                    'all-venues-filter-sport-$value',
                                  ),
                                  label: AppText(value),
                                  selected: _sport == value,
                                  selectedColor: AppColors.accent,
                                  onSelected: (_) {
                                    setState(() => _sport = value);
                                    setSheetState(() {});
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: filterPanelSectionSpacing),
                          _filterLabel('Area / city'),
                          OutlinedButton.icon(
                            key: const ValueKey('all-venues-use-my-location'),
                            onPressed: _locationLoading
                                ? null
                                : () => _useMyLocation(
                                    refreshSheet: () {
                                      if (dialogContext.mounted) {
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
                            label: AppText(
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
                          const SizedBox(height: filterPanelSectionSpacing),
                          _filterLabel(widget.facilityFilterLabel),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final value in [
                                'All',
                                ..._options(
                                  (post) => '${post['facilityType'] ?? ''}',
                                  '',
                                ).where((value) => value.isNotEmpty),
                              ])
                                ChoiceChip(
                                  key: ValueKey(
                                    'all-venues-filter-court-$value',
                                  ),
                                  label: AppText(value),
                                  selected: _courtType == value,
                                  selectedColor: AppColors.accent,
                                  onSelected: (_) {
                                    setState(() => _courtType = value);
                                    setSheetState(() {});
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: filterPanelSectionSpacing),
                          _filterLabel('Amenities'),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final value in const [
                                'Parking',
                                'Pet-friendly',
                                'Restroom',
                                'Shower',
                                'Store',
                              ])
                                FilterChip(
                                  key: ValueKey(
                                    'all-venues-filter-amenity-$value',
                                  ),
                                  label: AppText(value),
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
                          const SizedBox(height: filterPanelSectionSpacing),
                          _filterLabel('Availability'),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final value in const [
                                'Any',
                                'Open 24 hours',
                              ])
                                ChoiceChip(
                                  key: ValueKey(
                                    'all-venues-filter-availability-$value',
                                  ),
                                  label: AppText(value),
                                  selected: _availability == value,
                                  selectedColor: AppColors.accent,
                                  onSelected: (_) {
                                    setState(() => _availability = value);
                                    setSheetState(() {});
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: filterPanelSectionSpacing),
                          _filterLabel(widget.priceFilterLabel),
                          Slider(
                            key: const ValueKey('all-venues-filter-price'),
                            value: _maxPrice,
                            min: 0,
                            max: _priceFilterMaximum,
                            divisions: 14,
                            label: _maxPrice >= _priceFilterMaximum
                                ? '${_priceFilterMaximum.round()}+'
                                : _maxPrice.round().toString(),
                            onChanged: (value) {
                              setState(() => _maxPrice = value);
                              setSheetState(() {});
                            },
                          ),
                          const SizedBox(height: 6),
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
                      padding: filterPanelFooterPadding,
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const ValueKey('all-venues-filter-apply'),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: filterPanelApplyButtonStyle(context),
                          child: AppText(
                            'Show ${_visiblePosts.length} venues',
                            localize: true,
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
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOutCubic,
                  ),
                ),
            child: child,
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
          content: AppText(message),
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: () => onAction()),
        ),
      );
  }

  Widget _filterLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: AppText(label.toUpperCase(), style: filterPanelSectionLabelStyle),
  );

  Widget _dropdown({
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: options.contains(value) ? value : options.first,
    items: [
      for (final option in options)
        DropdownMenuItem(value: option, child: AppText(option)),
    ],
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
    decoration: InputDecoration(
      filled: true,
      fillColor: AppColors.surfaceVariant,
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

  void _showCollectionDescription() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText(
          widget.title == 'Most popular' ? 'Most popular venues' : 'Top rated',
        ),
        content: AppText(widget.collectionDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const AppText('Got it', localize: true),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.page,
    appBar: AppBar(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      title: AppText(widget.title, style: AppTypography.pageTitle),
      actions: [
        FilterPanelButton(
          key: const ValueKey('all-venues-open-filters'),
          activeCount: _activeFilterCount,
          onPressed: _openFilters,
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
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: FittedBox(
                                  alignment: Alignment.centerLeft,
                                  fit: BoxFit.scaleDown,
                                  child: AppText(
                                    widget.title == 'Most popular'
                                        ? widget.popularHeading
                                        : widget.ratedHeading,
                                    key: const ValueKey(
                                      'all-venues-header-title',
                                    ),
                                    maxLines: 1,
                                    softWrap: false,
                                    style: AppTypography.sectionTitle,
                                  ),
                                ),
                              ),
                              IconButton(
                                key: const ValueKey('all-venues-info'),
                                tooltip: appLanguageText(
                                  'About this venue list',
                                  'About this venue list',
                                ),
                                onPressed: _showCollectionDescription,
                                icon: Icon(
                                  Icons.info_outline_rounded,
                                  color: _venuesMuted,
                                  size: 19,
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: AppSpacing.buttonPadding,
                                constraints: const BoxConstraints.tightFor(
                                  width: 44,
                                  height: 44,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 3, 16, 0),
              child: TextField(
                key: const ValueKey('all-venues-search'),
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: appLanguageText(
                    widget.searchHint,
                    widget.searchHint,
                  ),
                  hintStyle: const TextStyle(fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: _venuesOrange),
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
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: _venuesOrange, width: 1.5),
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
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      SizedBox(height: 80),
                      Center(
                        child: AppText(
                          'No venues match your filters or search.',
                          style: TextStyle(color: _venuesMuted, fontSize: 16),
                          localize: true,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    key: const ValueKey('all-venues-list'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                    itemCount: _visiblePosts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, index) =>
                        widget.cardBuilder(_visiblePosts[index]),
                  ),
          ),
        ),
      ],
    ),
  );
}
