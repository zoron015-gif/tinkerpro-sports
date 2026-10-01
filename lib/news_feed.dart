import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_api.dart';
import 'app_session.dart';
import 'sports.dart';
import 'saved_items.dart';
import 'saved_icons.dart';
import 'messages_dashboard.dart';
import 'customer_bookings_page.dart';
import 'profile_dashboard.dart';
import 'reserve_dashboard.dart';
import 'reviews.dart';
import 'fitness_booking_page.dart';
import 'all_venues_page.dart';
import 'merchant_business_status.dart';
import 'app_card_styles.dart';
import 'app_bottom_navigation.dart';
import 'filter_panel_style.dart';
import 'sports_slot_configurations.dart';
import 'app_design_system.dart';

const _newsInk = AppColors.ink;
const _newsMuted = AppColors.muted;
const _newsOrange = AppColors.orange;
const _newsPage = AppColors.page;
const _newsCardImageHeight = 160.0;

class _NewsImageCarousel extends StatefulWidget {
  const _NewsImageCarousel({required this.images, required this.imageProvider});

  final List<String> images;
  final ImageProvider<Object>? Function(String value) imageProvider;

  @override
  State<_NewsImageCarousel> createState() => _NewsImageCarouselState();
}

class _NewsImageCarouselState extends State<_NewsImageCarousel> {
  late final PageController _controller;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: widget.images.length > 1 ? widget.images.length * 1000 : 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiple = widget.images.length > 1;
    return SizedBox(
      height: _newsCardImageHeight,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: multiple ? 100000 : 1,
            onPageChanged: (page) {
              setState(() => _index = page % widget.images.length);
            },
            itemBuilder: (_, page) {
              final provider = widget.imageProvider(
                widget.images[page % widget.images.length],
              );
              return Image(
                image:
                    provider ??
                    const AssetImage('assets/court/pickle-court.jpg'),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFFFFE8D2),
                  child: Center(
                    child: Icon(
                      Icons.storefront_rounded,
                      color: _newsOrange,
                      size: 52,
                    ),
                  ),
                ),
              );
            },
          ),
          if (multiple)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var dot = 0; dot < widget.images.length; dot++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: dot == _index ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: dot == _index
                            ? Colors.white
                            : Colors.white.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class NewsFeedPage extends StatefulWidget {
  const NewsFeedPage({
    super.key,
    this.onLogout,
    this.savedOnly = false,
    this.api,
    this.initialUserPosition,
    this.businessType = 'Sports',
    this.pageTitle = 'Sports Courts',
    this.savedItemType = 'sports',
    this.categoryNoun = 'sports',
    this.venueNoun = 'courts',
    this.searchHint = 'Search venues, categories, or news...',
    this.highestRatedSectionTitle = 'Highest rate',
    this.allVenuesHeading = 'All listed courts',
    this.categoryFilterLabel = 'Sport type',
    this.facilityFilterLabel = 'Court type',
  });

  final Future<void> Function(BuildContext context)? onLogout;
  final bool savedOnly;
  final AuthApi? api;
  final Position? initialUserPosition;
  final String businessType;
  final String pageTitle;
  final String savedItemType;
  final String categoryNoun;
  final String venueNoun;
  final String searchHint;
  final String highestRatedSectionTitle;
  final String allVenuesHeading;
  final String categoryFilterLabel;
  final String facilityFilterLabel;

  @override
  State<NewsFeedPage> createState() => _NewsFeedPageState();
}

class _NewsFeedPageState extends State<NewsFeedPage> {
  late final AuthApi _api;
  final _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _posts;
  final Set<String> _savedKeys = <String>{};
  final Set<String> _heartedVenueKeys = <String>{};
  final Set<String> _heartUpdatesInProgress = <String>{};
  final Map<String, int> _heartCounts = <String, int>{};
  final MapController _courtMapController = MapController();
  late Future<List<Map<String, dynamic>>> _businesses;
  var _courtMapExpanded = false;
  var _feedIntroVisible = true;
  Position? _userPosition;
  var _locationLoading = false;
  String _feedArea = 'All areas';
  late String _feedSport;
  String _feedCourtType = 'All';
  String _feedAvailability = 'Any';
  String _feedPriceSort = 'Recommended';
  double _feedMaxPrice = 700;
  final Set<String> _feedAmenities = <String>{};

  String get _categoryAllLabel => widget.businessType.toLowerCase() == 'sports'
      ? 'All sports'
      : 'All types';

  String get _facilityAllLabel => 'All';

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? AuthApi();
    _userPosition = widget.initialUserPosition;
    _feedSport = _categoryAllLabel;
    _businesses = _api.customerBusinesses();
    _posts = _loadFeed();
    _loadSavedKeys();
  }

  Future<List<Map<String, dynamic>>> _loadFeed() async {
    final session = await AppSession.load();
    final token = session.apiToken;
    if (token == null || token.isEmpty) {
      throw const AuthApiException(
        'Please sign in to view the customer News Feed.',
        401,
      );
    }
    final isEventFeed = widget.businessType.trim().toLowerCase() == 'event';
    final feedPosts = isEventFeed
        ? <Map<String, dynamic>>[]
        : await _api.newsFeed(token);
    for (final post in feedPosts) {
      final key = _postHeartKey(post);
      if (key.isEmpty) continue;
      _heartCounts[key] = _number(post['heartCount']).toInt();
      if (post['heartedByMe'] == true ||
          post['heartedByMe'] == 1 ||
          post['heartedByMe'] == '1') {
        _heartedVenueKeys.add(key);
      } else {
        _heartedVenueKeys.remove(key);
      }
    }
    final businesses = await _businesses;
    final enabledBusinessIds = businesses
        .where((business) => !_isMerchantDisabled(business))
        .map((business) => int.tryParse('${business['id'] ?? ''}'))
        .whereType<int>()
        .toSet();
    final posts = feedPosts
        .map((post) {
          final businessId = int.tryParse('${post['businessId'] ?? ''}');
          final enabled =
              businessId != null &&
              enabledBusinessIds.contains(businessId) &&
              !_isMerchantDisabled(post);
          final eventTypes = _stringList(post['eventTypes']);
          final isEvent =
              '${post['businessType'] ?? ''}'.trim().toLowerCase() == 'event';
          return {
            ...post,
            if (isEvent && eventTypes.isNotEmpty)
              'category': eventTypes.join(', '),
            'eventTypes': eventTypes,
            'enabled': enabled,
            'businessEnabled': enabled,
          };
        })
        .where((post) => _matchesBusinessType(post['businessType']))
        .toList();
    if (widget.businessType.trim().toLowerCase() == 'event') {
      final listedBusinessIds = posts
          .map((post) => int.tryParse('${post['businessId'] ?? ''}'))
          .whereType<int>()
          .toSet();
      for (final business in businesses) {
        if ('${business['businessType'] ?? ''}'.trim().toLowerCase() !=
            'event') {
          continue;
        }
        final businessId = int.tryParse('${business['id'] ?? ''}');
        if (businessId == null || listedBusinessIds.contains(businessId)) {
          continue;
        }
        final eventTypes = _stringList(business['eventTypes']);
        final name = '${business['name'] ?? 'Event venue'}';
        posts.add({
          ...business,
          'id': businessId,
          'businessId': businessId,
          'businessName': name,
          'businessType': 'Event',
          'category': eventTypes.isEmpty
              ? '${business['category'] ?? 'Event'}'
              : eventTypes.join(', '),
          'eventTypes': eventTypes,
          'address': business['address'] ?? '',
          'imageUrl': business['imageUrl'],
          'imageUrls': business['imageUrls'],
          'title': name,
          'body': '${business['details'] ?? ''}',
          'averageRating': business['averageRating'] ?? 0,
          'reviewCount': business['reviewCount'] ?? 0,
          'ratingUserCount': business['ratingUserCount'] ?? 0,
          'heartCount': business['heartCount'] ?? 0,
          'enabled':
              business['enabled'] != false &&
              business['enabled'] != 0 &&
              business['enabled'] != '0' &&
              business['enabled'] != 'false' &&
              business['enabled'] != 'FALSE',
          'businessEnabled':
              business['enabled'] != false &&
              business['enabled'] != 0 &&
              business['enabled'] != '0' &&
              business['enabled'] != 'false' &&
              business['enabled'] != 'FALSE',
        });
        final heartKey = _postHeartKey(posts.last);
        if (heartKey.isNotEmpty) {
          _heartCounts[heartKey] = _number(business['heartCount']).toInt();
          if (business['heartedByMe'] == true ||
              business['heartedByMe'] == 1 ||
              business['heartedByMe'] == '1') {
            _heartedVenueKeys.add(heartKey);
          } else {
            _heartedVenueKeys.remove(heartKey);
          }
        }
        listedBusinessIds.add(businessId);
      }
    }
    if (!widget.savedOnly) return posts;
    final saved = await SavedItemStore.list();
    final savedKeys = saved
        .where(
          (item) =>
              '${item['itemType'] ?? ''}'.toLowerCase() ==
              widget.savedItemType.toLowerCase(),
        )
        .map((item) => '${item['itemKey'] ?? ''}')
        .toSet();
    return posts
        .where(
          (post) =>
              savedKeys.contains('${post['businessId'] ?? ''}') ||
              savedKeys.contains('${post['businessName'] ?? ''}'),
        )
        .toList();
  }

  bool _matchesBusinessType(Object? value) {
    final type = '$value'.trim().toLowerCase();
    if (widget.businessType.toLowerCase() == 'sports') {
      return type == 'sports';
    }
    if (widget.businessType.toLowerCase() == 'fitness') {
      return type == 'fitness' ||
          type == 'wellness' ||
          type.contains('fitness') ||
          type.contains('wellness');
    }
    return type == widget.businessType.trim().toLowerCase();
  }

  Future<void> _reload() async {
    _businesses = _api.customerBusinesses();
    final refreshed = _loadFeed();
    setState(() {
      _posts = refreshed;
    });
    await refreshed;
  }

  bool _handleFeedScroll(ScrollNotification notification) {
    if (widget.savedOnly ||
        notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final visible = notification.metrics.pixels <= 0;
    if (_feedIntroVisible != visible) {
      setState(() => _feedIntroVisible = visible);
    }
    return false;
  }

  Future<void> _loadSavedKeys() async {
    try {
      final saved = await SavedItemStore.list();
      if (!mounted) return;
      setState(() {
        _savedKeys
          ..clear()
          ..addAll(
            saved
                .where(
                  (item) =>
                      '${item['itemType'] ?? ''}'.toLowerCase() ==
                      widget.savedItemType.toLowerCase(),
                )
                .map((item) => '${item['itemKey'] ?? ''}'),
          );
      });
    } on Exception {
      // The feed remains usable when saved items cannot be loaded.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _newsPage,
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: _newsInk,
      leading: IconButton(
        key: const ValueKey('news-feed-back'),
        tooltip: 'Back to reservations',
        onPressed: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ReserveDashboardPage(
                initialSelection: widget.businessType.toLowerCase() == 'fitness'
                    ? 'Fitness & Wellness'
                    : widget.businessType,
                onLogout: widget.onLogout,
              ),
            ),
          );
        },
        icon: const Icon(Icons.arrow_back_rounded),
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: const Color(0xFFF7F9FC),
          foregroundColor: _newsInk,
        ),
      ),
      title: Text(
        widget.savedOnly ? 'Saved venues' : widget.pageTitle,
        style: const TextStyle(color: _newsInk, fontWeight: FontWeight.w900),
      ),
      actions: [
        if (!widget.savedOnly) _courtMapHeaderControl(),
        FilterPanelButton(
          key: const ValueKey('news-feed-open-filters'),
          activeCount: _activeFeedFilterCount,
          onPressed: _openSportsFilters,
        ),
      ],
    ),
    body: _courtMapExpanded && !widget.savedOnly
        ? _courtLocationsMap()
        : Column(
            children: [
              if (!widget.savedOnly)
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.topCenter,
                  curve: Curves.easeInOut,
                  child: _feedIntroVisible ? _feedIntro() : const SizedBox(),
                ),
              if (!widget.savedOnly) _mainSearchBar(),
              if (widget.savedOnly) _mainSearchBar(),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleFeedScroll,
                  child: RefreshIndicator(
                    onRefresh: _reload,
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _posts,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return _message(
                            'Could not load the news feed: ${snapshot.error}',
                          );
                        }
                        final posts = _filteredPosts(snapshot.data ?? const []);
                        if (posts.isEmpty) {
                          return _message(
                            widget.savedOnly
                                ? snapshot.data?.isEmpty == true
                                      ? 'You have no saved venues yet.'
                                      : 'No saved venues match your filters or search.'
                                : snapshot.data?.isEmpty == true
                                ? 'No venue news has been posted yet.'
                                : 'No ${widget.venueNoun} match your search.',
                          );
                        }
                        return widget.savedOnly
                            ? _savedCardList(posts)
                            : _feedContent(posts);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
    bottomNavigationBar: _courtMapExpanded && !widget.savedOnly
        ? null
        : AppBottomNavigation(
            selectedIndex: widget.savedOnly ? 1 : 0,
            onDestinationSelected: _onNavigationSelected,
          ),
  );

  Widget _savedCardList(List<Map<String, dynamic>> posts) => ListView.separated(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
    itemCount: posts.length,
    separatorBuilder: (_, _) => const SizedBox(height: 14),
    itemBuilder: (_, index) => _postCard(posts[index]),
  );

  void _openSportsFilters() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close venue filters',
      barrierColor: Colors.black54,
      transitionDuration: filterPanelTransitionDuration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _posts,
            builder: (context, snapshot) {
              final posts = snapshot.data ?? const <Map<String, dynamic>>[];
              final areas = _feedOptions(
                posts,
                (post) => '${post['address'] ?? ''}',
                'All areas',
              );
              final sports = _categoryOptions(posts);
              return Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  key: const ValueKey('filter-panel-surface'),
                  width: filterPanelWidth(context),
                  height: double.infinity,
                  child: Material(
                    color: Colors.white,
                    elevation: 24,
                    child: StatefulBuilder(
                      builder: (context, setSheetState) => SafeArea(
                        child: Column(
                          children: [
                            Padding(
                              padding: filterPanelHeaderPadding,
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Filter venues',
                                      style: filterPanelTitleStyle,
                                    ),
                                  ),
                                  TextButton(
                                    key: const ValueKey(
                                      'news-feed-filter-reset',
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _feedArea = 'All areas';
                                        _feedSport = _categoryAllLabel;
                                        _feedCourtType = _facilityAllLabel;
                                        _feedAvailability = 'Any';
                                        _feedPriceSort = 'Recommended';
                                        _feedMaxPrice = 700;
                                        _feedAmenities.clear();
                                        _userPosition = null;
                                      });
                                      setSheetState(() {});
                                    },
                                    child: const Text('Reset'),
                                  ),
                                  IconButton(
                                    key: const ValueKey(
                                      'news-feed-filter-close',
                                    ),
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
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
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final value in sports)
                                        ChoiceChip(
                                          key: ValueKey(
                                            'news-feed-filter-sport-$value',
                                          ),
                                          label: Text(value),
                                          selected: _feedSport == value,
                                          onSelected: (_) {
                                            setState(() => _feedSport = value);
                                            setSheetState(() {});
                                          },
                                          selectedColor: _newsOrange,
                                          labelStyle: TextStyle(
                                            color: _feedSport == value
                                                ? Colors.white
                                                : _newsInk,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: filterPanelSectionSpacing,
                                  ),
                                  _filterLabel('Area / city'),
                                  OutlinedButton.icon(
                                    key: const ValueKey(
                                      'news-feed-use-my-location',
                                    ),
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
                                    label: Text(
                                      _locationLoading
                                          ? 'Getting your location...'
                                          : _userPosition == null
                                          ? 'Use my location'
                                          : 'Using my location · nearest first',
                                    ),
                                  ),
                                  _feedDropdown(
                                    identifier: 'area',
                                    value: _feedArea,
                                    values: areas,
                                    onChanged: (value) {
                                      setState(() => _feedArea = value);
                                      setSheetState(() {});
                                    },
                                  ),
                                  const SizedBox(
                                    height: filterPanelSectionSpacing,
                                  ),
                                  _filterLabel(widget.facilityFilterLabel),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      for (final value in [
                                        _facilityAllLabel,
                                        ..._feedOptions(
                                          posts,
                                          (post) =>
                                              '${post['facilityType'] ?? ''}',
                                          '',
                                        ).where((value) => value.isNotEmpty),
                                      ])
                                        ChoiceChip(
                                          key: ValueKey(
                                            'news-feed-filter-court-$value',
                                          ),
                                          label: Text(value),
                                          selected: _feedCourtType == value,
                                          onSelected: (_) {
                                            setState(
                                              () => _feedCourtType = value,
                                            );
                                            setSheetState(() {});
                                          },
                                          selectedColor: _newsOrange,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: filterPanelSectionSpacing,
                                  ),
                                  _filterLabel('Amenities'),
                                  Wrap(
                                    spacing: 8,
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
                                            'news-feed-filter-amenity-$value',
                                          ),
                                          label: Text(value),
                                          selected: _feedAmenities.contains(
                                            value,
                                          ),
                                          onSelected: (selected) {
                                            setState(() {
                                              if (selected) {
                                                _feedAmenities.add(value);
                                              } else {
                                                _feedAmenities.remove(value);
                                              }
                                            });
                                            setSheetState(() {});
                                          },
                                        ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: filterPanelSectionSpacing,
                                  ),
                                  _filterLabel('Availability'),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      for (final value in const [
                                        'Any',
                                        'Open 24 hours',
                                      ])
                                        ChoiceChip(
                                          key: ValueKey(
                                            'news-feed-filter-availability-$value',
                                          ),
                                          label: Text(value),
                                          selected: _feedAvailability == value,
                                          onSelected: (_) {
                                            setState(
                                              () => _feedAvailability = value,
                                            );
                                            setSheetState(() {});
                                          },
                                          selectedColor: _newsOrange,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: filterPanelSectionSpacing,
                                  ),
                                  _filterLabel('Price (PHP / hour)'),
                                  Slider(
                                    key: const ValueKey(
                                      'news-feed-filter-price',
                                    ),
                                    value: _feedMaxPrice,
                                    min: 0,
                                    max: 700,
                                    divisions: 14,
                                    label: _feedMaxPrice >= 700
                                        ? '700+'
                                        : _feedMaxPrice.round().toString(),
                                    onChanged: (value) {
                                      setState(() => _feedMaxPrice = value);
                                      setSheetState(() {});
                                    },
                                  ),
                                  const SizedBox(
                                    height: filterPanelSectionSpacing,
                                  ),
                                  _filterLabel('Sort price'),
                                  _feedDropdown(
                                    identifier: 'price-sort',
                                    value: _feedPriceSort,
                                    values: const [
                                      'Recommended',
                                      'Lowest to highest',
                                      'Highest to lowest',
                                    ],
                                    onChanged: (value) {
                                      setState(() => _feedPriceSort = value);
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
                                  key: const ValueKey('news-feed-filter-apply'),
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  style: filterPanelApplyButtonStyle,
                                  child: Text(
                                    'Show ${_filteredPosts(posts).length} venues',
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

  int get _activeFeedFilterCount =>
      (_feedArea == 'All areas' ? 0 : 1) +
      (_feedSport == _categoryAllLabel ? 0 : 1) +
      (_feedCourtType == _facilityAllLabel ? 0 : 1) +
      (_feedAvailability == 'Any' ? 0 : 1) +
      (_feedPriceSort == 'Recommended' ? 0 : 1) +
      (_feedMaxPrice >= 700 ? 0 : 1) +
      _feedAmenities.length +
      (_userPosition == null ? 0 : 1);

  List<String> _feedOptions(
    List<Map<String, dynamic>> posts,
    String Function(Map<String, dynamic>) selector,
    String allLabel,
  ) {
    final values =
        posts
            .map(selector)
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return [allLabel, ...values];
  }

  List<String> _categoryFilterOptions(Map<String, dynamic> post) {
    final eventTypes = _stringList(post['eventTypes']);
    if ('${post['businessType'] ?? ''}'.trim().toLowerCase() == 'event' &&
        eventTypes.isNotEmpty) {
      return eventTypes;
    }
    final category = '${post['category'] ?? ''}'.trim();
    return category.isEmpty ? const [] : [category];
  }

  List<String> _categoryOptions(List<Map<String, dynamic>> posts) {
    final values =
        posts
            .expand(_categoryFilterOptions)
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return [_categoryAllLabel, ...values];
  }

  List<String> _stringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((item) => '$item'.trim())
              .where((item) => item.isNotEmpty)
              .toList();
        }
      } on FormatException {
        return [value.trim()];
      }
      return [value.trim()];
    }
    return const [];
  }

  Widget _filterLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text.toUpperCase(), style: filterPanelSectionLabelStyle),
  );

  Widget _feedDropdown({
    required String identifier,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    key: ValueKey('news-feed-filter-$identifier'),
    initialValue: values.contains(value) ? value : values.first,
    items: values
        .map((item) => DropdownMenuItem(value: item, child: Text(item)))
        .toList(),
    onChanged: (item) {
      if (item != null) onChanged(item);
    },
    decoration: InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE1E6ED)),
      ),
    ),
  );

  Widget _feedIntro() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover what’s new',
                    style: TextStyle(
                      color: _newsInk,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.5,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Fresh updates, offers, and stories from local venues.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _newsMuted,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _courtMapHeaderControl() => IconButton(
    key: const ValueKey('news-feed-toggle-court-map'),
    tooltip: _courtMapExpanded
        ? 'Hide ${widget.venueNoun == 'courts' ? 'court' : 'venue'} map'
        : 'Show ${widget.venueNoun} on map',
    onPressed: () => setState(() => _courtMapExpanded = !_courtMapExpanded),
    icon: AnimatedRotation(
      turns: _courtMapExpanded ? .5 : 0,
      duration: const Duration(milliseconds: 180),
      child: const Icon(Icons.map_outlined),
    ),
    style: IconButton.styleFrom(
      shape: const CircleBorder(),
      backgroundColor: const Color(0xFFF7F9FC),
      foregroundColor: _courtMapExpanded ? _newsOrange : _newsInk,
    ),
  );

  Widget _courtLocationsMap() => FutureBuilder<List<Map<String, dynamic>>>(
    future: _businesses,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Could not load ${widget.venueNoun == 'courts' ? 'court' : 'venue'} locations: ${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _newsMuted, fontSize: 12),
            ),
          ),
        );
      }

      final courts = (snapshot.data ?? const <Map<String, dynamic>>[])
          .where(
            (business) => _matchesBusinessType(
              business['businessType'] ?? business['business_type'],
            ),
          )
          .toList();
      final pinnedCourts = <({Map<String, dynamic> business, LatLng point})>[];
      final courtsWithoutPin = <Map<String, dynamic>>[];
      for (final court in courts) {
        final latitude = _mapCoordinate(court['latitude'] ?? court['lat']);
        final longitude = _mapCoordinate(court['longitude'] ?? court['lng']);
        if (latitude != null &&
            longitude != null &&
            latitude >= -90 &&
            latitude <= 90 &&
            longitude >= -180 &&
            longitude <= 180) {
          pinnedCourts.add((
            business: court,
            point: LatLng(latitude, longitude),
          ));
        } else {
          courtsWithoutPin.add(court);
        }
      }

      final uniquePoints = pinnedCourts.map((court) => court.point).toSet();
      final center = uniquePoints.isEmpty
          ? _userPosition == null
                ? const LatLng(10.3157, 123.8854)
                : LatLng(_userPosition!.latitude, _userPosition!.longitude)
          : LatLng(
              uniquePoints
                      .map((point) => point.latitude)
                      .reduce((a, b) => a + b) /
                  uniquePoints.length,
              uniquePoints
                      .map((point) => point.longitude)
                      .reduce((a, b) => a + b) /
                  uniquePoints.length,
            );
      final uniquePointsList = uniquePoints.toList();

      return Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _courtMapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: uniquePointsList.length > 1 ? 5 : 13,
              onMapReady: () {
                if (uniquePointsList.length > 1) {
                  _courtMapController.fitCamera(
                    CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(uniquePointsList),
                      padding: const EdgeInsets.all(48),
                    ),
                  );
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.myapp',
              ),
              MarkerLayer(markers: pinnedCourts.map(_courtMapMarker).toList()),
              if (_userPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        _userPosition!.latitude,
                        _userPosition!.longitude,
                      ),
                      width: 42,
                      height: 42,
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                child: Text(
                  '${pinnedCourts.length} ${widget.venueNoun} on map'
                  '${courtsWithoutPin.isEmpty ? '' : ' · ${courtsWithoutPin.length} need pins'}',
                  style: const TextStyle(
                    color: _newsInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  double? _mapCoordinate(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  Marker _courtMapMarker(
    ({Map<String, dynamic> business, LatLng point}) court,
  ) => Marker(
    point: court.point,
    width: 40,
    height: 42,
    child: GestureDetector(
      onTap: () => _openCourtMapLocation(
        '${court.business['name'] ?? 'Court'}',
        court.point,
      ),
      child: const Icon(Icons.location_on, color: _newsOrange, size: 34),
    ),
  );

  Future<void> _openCourtMapLocation(String name, LatLng point) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${point.latitude},${point.longitude}',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open map directions for $name.')),
      );
    }
  }

  Future<void> _useMyLocation({required VoidCallback refreshSheet}) async {
    setState(() => _locationLoading = true);
    refreshSheet();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showLocationMessage(
          'Location services are off. Turn them on to find nearby ${widget.venueNoun}.',
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
          'Location permission was denied. Allow location access to sort ${widget.venueNoun} by distance.',
        );
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _showLocationMessage(
          'Location permission is blocked. Enable it in app settings to find nearby ${widget.venueNoun}.',
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
      _showLocationMessage(
        '${widget.venueNoun[0].toUpperCase()}${widget.venueNoun.substring(1)} are now ordered nearest to your location.',
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                onPressed: () async {
                  final opened = await onAction();
                  if (!opened && mounted) {
                    _showLocationMessage('Could not open $actionLabel.');
                  }
                },
              ),
      ),
    );
  }

  Widget _mainSearchBar() => Container(
    color: _newsPage,
    padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
    child: TextField(
      key: const ValueKey('news-feed-search'),
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: widget.searchHint,
        hintStyle: const TextStyle(fontSize: 13),
        prefixIcon: const Icon(Icons.search, size: 17),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                key: const ValueKey('news-feed-search-clear'),
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded, size: 17),
              ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        prefixIconColor: _newsOrange,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFFE1E6ED)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFFE1E6ED)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: _newsOrange, width: 1.4),
        ),
      ),
    ),
  );

  Widget _feedContent(List<Map<String, dynamic>> posts) {
    final popular = [...posts]
      ..sort((a, b) {
        final byHearts = _postHeartCount(b).compareTo(_postHeartCount(a));
        return byHearts != 0
            ? byHearts
            : '${a['businessName']}'.compareTo('${b['businessName']}');
      });
    final highestRated =
        posts.where((post) => _number(post['reviewCount']) > 0).toList()
          ..sort((a, b) {
            final byRating = _number(b['averageRating'])
                .compareTo(_number(a['averageRating']));
            return byRating != 0
                ? byRating
                : '${a['businessName']}'.compareTo('${b['businessName']}');
          });
    final featured = popular.take(6).toList();
    final rated = highestRated.take(6).toList();

    return ListView(
      key: const ValueKey('news-feed-content-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _sectionHeader('Most popular', 'Most hearts from users', popular),
        if (featured.isEmpty)
          const Padding(
            key: ValueKey('news-feed-most-popular-empty'),
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No popular venues available yet.',
              style: TextStyle(
                color: _newsMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          _horizontalVenues(featured, identifier: 'most-popular'),
        const SizedBox(height: 22),
        _sectionHeader(
          widget.highestRatedSectionTitle,
          'Highest average review rating',
          highestRated,
        ),
        if (rated.isEmpty)
          const Padding(
            key: ValueKey('news-feed-highest-rated-empty'),
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No highest-rated venues available yet.',
              style: TextStyle(
                color: _newsMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          _horizontalVenues(
            rated,
            identifier: widget.highestRatedSectionTitle
                .toLowerCase()
                .replaceAll(' ', '-'),
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                widget.allVenuesHeading,
                style: TextStyle(
                  color: _newsInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${posts.length} venues',
              style: const TextStyle(
                color: _newsMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final post in posts) ...[
          _postCard(post),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _sectionHeader(
    String title,
    String subtitle,
    List<Map<String, dynamic>> sectionPosts,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _newsInk,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: _newsMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      TextButton.icon(
        key: ValueKey(
          'news-feed-see-all-${title.toLowerCase().replaceAll(' ', '-')}',
        ),
        onPressed: () => _openAllVenues(title, sectionPosts),
        icon: const Icon(Icons.chevron_right_rounded, size: 17),
        label: Text('See all (${sectionPosts.length})'),
        style: TextButton.styleFrom(
          foregroundColor: _newsOrange,
          padding: EdgeInsets.zero,
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );

  void _openAllVenues(String title, List<Map<String, dynamic>> sectionPosts) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) => AllVenuesPage(
          title: title,
          posts: sectionPosts,
          cardBuilder: _postCard,
          initialUserPosition: _userPosition,
          categoryFilterLabel: widget.categoryFilterLabel,
          categoryAllLabel: _categoryAllLabel,
          facilityFilterLabel: widget.facilityFilterLabel,
          popularHeading: widget.businessType == 'Sports'
              ? 'Courts with the most hearts'
              : '${widget.pageTitle} venues with the most hearts',
          ratedHeading: widget.businessType == 'Sports'
              ? 'Courts with the highest ratings'
              : '${widget.pageTitle} venues with the highest ratings',
          searchHint: widget.businessType.toLowerCase() == 'sports'
              ? 'Search venues, sports, or areas...'
              : 'Search venues, ${widget.categoryNoun}, or areas...',
          collectionDescription: widget.businessType == 'Sports'
              ? 'Browse every venue in this collection.'
              : 'Browse all ${widget.venueNoun} in this collection.',
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOutCubic,
                    ),
                  ),
              child: child,
            ),
      ),
    );
  }

  Widget _horizontalVenues(
    List<Map<String, dynamic>> posts, {
    required String identifier,
  }) => Padding(
    key: ValueKey('news-feed-$identifier-section'),
    padding: const EdgeInsets.only(top: 10),
    child: SizedBox(
      height: 190,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth - 10) / 2;
          return ListView.separated(
            key: ValueKey('news-feed-$identifier-scroll'),
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, index) => SizedBox(
              key: ValueKey(
                'news-feed-$identifier-card-${_venueIdentifier(posts[index])}',
              ),
              width: cardWidth,
              child: _miniVenueCard(posts[index]),
            ),
          );
        },
      ),
    ),
  );

  String _venueIdentifier(Map<String, dynamic> post) {
    final businessId = int.tryParse('${post['businessId']}');
    if (businessId != null && businessId > 0) return 'business-$businessId';
    final name = '${post['businessName'] ?? ''}'
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return name.isEmpty ? 'unknown' : name;
  }

  String _postHeartKey(Map<String, dynamic> post) {
    final businessId = int.tryParse('${post['businessId']}');
    return businessId != null && businessId > 0 ? '$businessId' : '';
  }

  int _postHeartCount(Map<String, dynamic> post) =>
      _heartCounts[_postHeartKey(post)] ?? _number(post['heartCount']).toInt();

  bool _isHearted(Map<String, dynamic> post) {
    final key = _postHeartKey(post);
    return key.isNotEmpty
        ? _heartedVenueKeys.contains(key)
        : post['heartedByMe'] == true;
  }

  void _applyHeartState(Map<String, dynamic> post, bool hearted, int count) {
    final key = _postHeartKey(post);
    if (key.isEmpty) return;
    _heartCounts[key] = count;
    if (hearted) {
      _heartedVenueKeys.add(key);
    } else {
      _heartedVenueKeys.remove(key);
    }
    post['heartCount'] = count;
    post['heartedByMe'] = hearted;
  }

  Future<void> _toggleHeart(Map<String, dynamic> post) async {
    final businessId = int.tryParse('${post['businessId']}');
    if (businessId == null || businessId <= 0) return;
    final wasHearted = _isHearted(post);
    final key = '$businessId';
    if (!_heartUpdatesInProgress.add(key)) return;
    final previousCount = _postHeartCount(post);
    final nextHearted = !wasHearted;
    final nextCount = (previousCount + (nextHearted ? 1 : -1)).clamp(
      0,
      0x7fffffff,
    );
    setState(() => _applyHeartState(post, nextHearted, nextCount));
    try {
      final token = (await AppSession.load()).apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException(
          'Your session has expired. Please log in again.',
          401,
        );
      }
      final result = await _api.setBusinessHearted(
        token: token,
        businessId: businessId,
        hearted: nextHearted,
      );
      if (!mounted) return;
      final count = (result['heartCount'] as num?)?.toInt();
      setState(() => _applyHeartState(post, nextHearted, count ?? nextCount));
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _applyHeartState(post, wasHearted, previousCount));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update heart: $error')));
    } finally {
      _heartUpdatesInProgress.remove(key);
    }
  }

  Widget _miniVenueCard(Map<String, dynamic> post) {
    final image = '${post['imageUrl'] ?? ''}';
    final name = '${post['businessName'] ?? 'Venue'}';
    final category = '${post['category'] ?? ''}';
    final rating = _number(post['averageRating']);
    final hearted = _isHearted(post);
    final heartCount = _postHeartCount(post);
    final priceLabel = _priceLabel(post);
    final unavailable = _isMerchantDisabled(post);
    final availability = '${post['availability'] ?? ''}'.toLowerCase();
    final isOpen =
        availability.contains('open') || availability.contains('available');
    return Semantics(
      key: ValueKey('news-feed-mini-${_venueIdentifier(post)}'),
      button: true,
      enabled: !unavailable,
      label: unavailable
          ? '$name. Unavailable. Booking disabled.'
          : '$name. Open venue details.',
      child: AbsorbPointer(
        absorbing: unavailable,
        child: SizedBox(
          width: double.infinity,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: unavailable ? null : () => _openBookingType(post),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E7EF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A192B50),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    child: SizedBox(
                      height: 94,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          image.isEmpty
                              ? _miniImageFallback()
                              : _miniImage(image),
                          if (unavailable)
                            const ColoredBox(color: Color(0x55000000)),
                          if (unavailable)
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: _miniBadge(
                                'Unavailable',
                                const Color(0xFFD32F2F),
                              ),
                            )
                          else if (isOpen)
                            Positioned(
                              left: 8,
                              top: 8,
                              child: _miniBadge(
                                'Available',
                                const Color(0xDD15803D),
                              ),
                            ),
                          if (category.isNotEmpty)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: _miniBadge(
                                category,
                                const Color(0xCC101B33),
                              ),
                            ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Material(
                              color: Colors.white.withValues(alpha: .95),
                              borderRadius: BorderRadius.circular(18),
                              child: GestureDetector(
                                key: ValueKey(
                                  'news-feed-mini-heart-${_venueIdentifier(post)}',
                                ),
                                onTap: () => _toggleHeart(post),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .95),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        hearted
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        size: 14,
                                        color: hearted
                                            ? Colors.red
                                            : _newsMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$heartCount',
                                        key: ValueKey(
                                          'news-feed-mini-heart-count-${_venueIdentifier(post)}',
                                        ),
                                        style: const TextStyle(
                                          color: _newsInk,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _newsInk,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _ratingStars(rating, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              rating == 0 ? 'New' : rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: _newsMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '(${_number(post['reviewCount']).toInt()})',
                              style: const TextStyle(
                                color: _newsMuted,
                                fontSize: 10,
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                        if (_distanceLabel(post) case final distance?)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              distance,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _newsMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (unavailable) ...[
                          const SizedBox(height: 3),
                          const Text(
                            'UNAVAILABLE · Booking disabled',
                            style: TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ] else if (priceLabel != 'Price not listed') ...[
                          const SizedBox(height: 3),
                          Text(
                            priceLabel,
                            style: const TextStyle(
                              color: _newsInk,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniBadge(String text, Color background) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  Widget _miniImage(String value) => Image(
    image:
        _imageProvider(value) ??
        const AssetImage('assets/court/pickle-court.jpg'),
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => _miniImageFallback(),
  );

  Widget _miniImageFallback() => const ColoredBox(
    color: Color(0xFFFFE8D2),
    child: Center(
      child: Icon(Icons.storefront_rounded, color: _newsOrange, size: 30),
    ),
  );

  Widget _ratingStars(double rating, {required double size}) {
    final value = rating.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            value >= star
                ? Icons.star_rounded
                : value >= star - .5
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            color: Colors.amber,
            size: size,
          ),
      ],
    );
  }

  String? _distanceLabel(Map<String, dynamic> post) {
    final position = _userPosition;
    if (position == null) return null;
    final latitude = _mapCoordinate(post['latitude'] ?? post['lat']);
    final longitude = _mapCoordinate(post['longitude'] ?? post['lng']);
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    final distanceKm =
        Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          latitude,
          longitude,
        ) /
        1000;
    return '${distanceKm.toStringAsFixed(1)} km away';
  }

  List<Map<String, dynamic>> _filteredPosts(List<Map<String, dynamic>> posts) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = posts.where((post) {
      final address = '${post['address'] ?? ''}'.toLowerCase();
      final matchesArea =
          _feedArea == 'All areas' || address.contains(_feedArea.toLowerCase());
      final categories = _categoryFilterOptions(post)
          .map((value) => value.toLowerCase())
          .toList();
      final matchesSport =
          _feedSport == _categoryAllLabel ||
          categories.contains(_feedSport.toLowerCase());
      final facility = '${post['facilityType'] ?? ''}';
      final hours = '${post['hours'] ?? post['opening_hours'] ?? ''}';
      final availability = '${post['availability'] ?? ''}';
      final price =
          double.tryParse(
            '${post['pricePerHour'] ?? post['price_per_hour'] ?? 0}',
          ) ??
          0;
      final rawAmenities = '${post['tags'] ?? post['amenities'] ?? ''}'
          .toLowerCase();
      final matchesCourt =
          _feedCourtType == _facilityAllLabel ||
          facility.toLowerCase() == _feedCourtType.toLowerCase();
      final matchesAvailability =
          _feedAvailability == 'Any' ||
          hours.toLowerCase().contains('open 24 hours') ||
          availability.toLowerCase().contains('open 24 hours');
      final matchesPrice = price <= _feedMaxPrice;
      final matchesAmenities = _feedAmenities.every(
        (amenity) => rawAmenities.contains(amenity.toLowerCase()),
      );
      final searchable = [
        post['businessName'],
        post['businessType'],
        post['category'],
        ..._stringList(post['eventTypes']),
        post['title'],
        post['body'],
        post['address'],
      ].map((value) => '$value').join(' ').toLowerCase();
      return matchesArea &&
          matchesSport &&
          matchesCourt &&
          matchesAvailability &&
          matchesPrice &&
          matchesAmenities &&
          (query.isEmpty || searchable.contains(query));
    }).toList();
    if (_feedPriceSort == 'Lowest to highest') {
      filtered.sort((a, b) => _venuePrice(a).compareTo(_venuePrice(b)));
    } else if (_feedPriceSort == 'Highest to lowest') {
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
      _mapCoordinate(
        post['pricePerHour'] ??
            post['price_per_hour'] ??
            post['eventFee'] ??
            post['event_fee'],
      ) ??
      0;

  double _distanceFrom(Position position, Map<String, dynamic> post) {
    final latitude = _mapCoordinate(post['latitude'] ?? post['lat']);
    final longitude = _mapCoordinate(post['longitude'] ?? post['lng']);
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

  void _onNavigationSelected(int index) {
    if (index == 0) {
      if (widget.savedOnly) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => NewsFeedPage(
              onLogout: widget.onLogout,
              api: _api,
              initialUserPosition: _userPosition,
              businessType: widget.businessType,
              pageTitle: widget.pageTitle,
              savedItemType: widget.savedItemType,
              categoryNoun: widget.categoryNoun,
              venueNoun: widget.venueNoun,
              searchHint: widget.searchHint,
              highestRatedSectionTitle: widget.highestRatedSectionTitle,
              allVenuesHeading: widget.allVenuesHeading,
              categoryFilterLabel: widget.categoryFilterLabel,
              facilityFilterLabel: widget.facilityFilterLabel,
            ),
          ),
        );
      }
      return;
    }
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NewsFeedPage(
            onLogout: widget.onLogout,
            savedOnly: true,
            api: _api,
            initialUserPosition: _userPosition,
            businessType: widget.businessType,
            pageTitle: widget.pageTitle,
            savedItemType: widget.savedItemType,
            categoryNoun: widget.categoryNoun,
            venueNoun: widget.venueNoun,
            searchHint: widget.searchHint,
            highestRatedSectionTitle: widget.highestRatedSectionTitle,
            allVenuesHeading: widget.allVenuesHeading,
            categoryFilterLabel: widget.categoryFilterLabel,
            facilityFilterLabel: widget.facilityFilterLabel,
          ),
        ),
      );
    } else if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MessagesDashboardPage(
            initialUserPosition: _userPosition,
            api: _api,
            businessType: widget.businessType,
          ),
        ),
      );
    } else if (index == 3) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerBookingsPage(
            onLogout: widget.onLogout,
            initialUserPosition: _userPosition,
            businessType: widget.businessType,
          ),
        ),
      );
    } else if (index == 4) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfileDashboardPage(
            onLogout: widget.onLogout,
            initialUserPosition: _userPosition,
            businessType: widget.businessType,
          ),
        ),
      );
    }
  }

  Widget _message(String text) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(32, 72, 32, 32),
    children: [
      const Icon(Icons.explore_outlined, size: 52, color: _newsOrange),
      const SizedBox(height: 16),
      Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _newsInk,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ),
    ],
  );

  Widget _postCard(Map<String, dynamic> post) {
    final image = post['imageUrl'] as String?;
    final images = _imageListValue([
      post['imageUrls'],
      post['images'],
      post['imageUrl'],
    ]);
    final rating = _number(post['averageRating']);
    final reviews = _number(post['reviewCount']).toInt();
    final ratedUsers = _number(post['ratingUserCount']).toInt();
    final businessId = int.tryParse('${post['businessId']}');
    final businessName = '${post['businessName'] ?? ''}';
    final saveKey = '${businessId ?? businessName}';
    final isSaved = _savedKeys.contains(saveKey);
    final isHearted = _isHearted(post);
    final heartCount = _postHeartCount(post);
    final type = '${post['businessType'] ?? ''}';
    final category = '${post['category'] ?? ''}';
    final address = '${post['address'] ?? ''}';
    final body = '${post['body'] ?? ''}';
    final priceLabel = _priceLabel(post);
    final unavailable = _isMerchantDisabled(post);
    final secondaryAction = unavailable
        ? OutlinedButton.icon(
            key: ValueKey('news-feed-contact-owner-${_venueIdentifier(post)}'),
            onPressed: () => _contactOwner(post),
            icon: const Icon(Icons.message_outlined, size: 16),
            label: const Text('Contact owner'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _newsInk,
              padding: const EdgeInsets.symmetric(vertical: 11),
              side: const BorderSide(color: Color(0xFFE2E7EF)),
            ),
          )
        : OutlinedButton.icon(
            key: ValueKey('news-feed-visit-${_venueIdentifier(post)}'),
            onPressed: _visitUrl(post).isEmpty ? null : () => _visitVenue(post),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Visit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _newsInk,
              padding: const EdgeInsets.symmetric(vertical: 11),
              side: const BorderSide(color: Color(0xFFE2E7EF)),
            ),
          );
    return Card(
      key: ValueKey('news-feed-card-${_venueIdentifier(post)}'),
      clipBehavior: Clip.antiAlias,
      elevation: AppCardStyles.elevation,
      margin: EdgeInsets.zero,
      shape: AppCardStyles.marketplaceShape,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                key: ValueKey('news-feed-image-${_venueIdentifier(post)}'),
                width: double.infinity,
                height: _newsCardImageHeight,
                child: images.isNotEmpty
                    ? _NewsImageCarousel(
                        images: images,
                        imageProvider: _imageProvider,
                      )
                    : image != null && image.isNotEmpty
                    ? _image(image)
                    : _imageFallback(),
              ),
              if (type.isNotEmpty)
                Positioned(
                  top: 14,
                  left: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        type,
                        style: const TextStyle(
                          color: _newsInk,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              if (category.isNotEmpty)
                Positioned(
                  right: 14,
                  top: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _newsOrange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _newsInk,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      key: ValueKey('news-feed-save-${_venueIdentifier(post)}'),
                      onPressed: () => _toggleSaved(post),
                      tooltip: isSaved ? 'Remove from Saved' : 'Save venue',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      color: isSaved ? _newsOrange : _newsInk,
                      icon: Icon(
                        isSaved ? savedItemSelectedIcon : savedItemIcon,
                      ),
                    ),
                    IconButton(
                      key: ValueKey(
                        'news-feed-heart-${_venueIdentifier(post)}',
                      ),
                      onPressed: () => _toggleHeart(post),
                      tooltip: isHearted ? 'Remove heart' : 'Heart venue',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      color: isHearted ? Colors.red : _newsInk,
                      icon: Icon(
                        isHearted
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                    ),
                    Text(
                      '$heartCount',
                      key: ValueKey(
                        'news-feed-heart-count-${_venueIdentifier(post)}',
                      ),
                      style: const TextStyle(
                        color: _newsMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: _newsMuted,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _newsMuted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_distanceLabel(post) case final distance?) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.near_me_outlined,
                        color: _newsOrange,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        distance,
                        style: TextStyle(
                          color: _newsMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 7),
                _priceTag(priceLabel),
                const SizedBox(height: 7),
                Text(
                  '${post['title'] ?? ''}',
                  style: TextStyle(
                    color: _newsInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _newsMuted,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                if (unavailable) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1E4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _newsOrange.withValues(alpha: .35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: _newsOrange,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This court is currently unavailable. Booking cannot proceed.',
                            style: TextStyle(
                              color: _newsInk,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Row(
                  children: [
                    _ratingStars(rating, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      rating == 0 ? 'New' : rating.toStringAsFixed(1),
                      style: TextStyle(
                        color: _newsInk,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      rating == 0
                          ? 'No ratings yet'
                          : '$reviews ${reviews == 1 ? 'review' : 'reviews'} · '
                                '$ratedUsers rated',
                      style: TextStyle(color: _newsMuted, fontSize: 12),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      key: ValueKey(
                        'news-feed-reviews-${_venueIdentifier(post)}',
                      ),
                      onPressed: businessId == null
                          ? null
                          : () => _showReviews(post, businessId),
                      icon: const Icon(Icons.rate_review_outlined, size: 16),
                      label: const Text('Reviews'),
                      style: TextButton.styleFrom(
                        foregroundColor: _newsInk,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: ValueKey(
                          'news-feed-explore-${_venueIdentifier(post)}',
                        ),
                        onPressed: unavailable
                            ? null
                            : () => _openBookingType(post),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                        label: const Text('Explore venue'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _newsOrange,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: secondaryAction),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isMerchantDisabled(Map<String, dynamic> post) {
    return isMerchantBusinessDisabled(post);
  }

  String _priceLabel(Map<String, dynamic> post) {
    final business = post['business'] is Map
        ? Map<String, dynamic>.from(post['business'] as Map)
        : const <String, dynamic>{};
    final businessType =
        '${post['businessType'] ?? business['businessType'] ?? ''}'
            .toLowerCase();
    final isEvent = businessType.contains('event');

    double? parseAmount(Object? value) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final match = RegExp(r'\d[\d,]*(?:\.\d+)?').firstMatch(value);
        if (match != null) {
          return double.tryParse(match.group(0)!.replaceAll(',', ''));
        }
      }
      return null;
    }

    final price =
        [
              post['pricePerHour'],
              post['price_per_hour'],
              post['eventFee'],
              post['event_fee'],
              post['price'],
              business['pricePerHour'],
              business['price_per_hour'],
              business['eventFee'],
              business['event_fee'],
              business['price'],
            ]
            .map(parseAmount)
            .whereType<double>()
            .firstWhere((amount) => amount > 0, orElse: () => 0);
    if (price > 0) {
      return 'PHP ${price.toStringAsFixed(0)} / ${isEvent ? 'event' : 'hr'}';
    }

    final rawPeriods = post['ratePeriods'] ?? post['rate_periods'];
    if (rawPeriods is List) {
      final rates = rawPeriods
          .whereType<Map>()
          .map(
            (period) => parseAmount(
              period['pricePerHour'] ??
                  period['price_per_hour'] ??
                  period['price'],
            ),
          )
          .whereType<double>()
          .where((amount) => amount > 0)
          .toList();
      if (rates.isNotEmpty) {
        rates.sort();
        return 'From PHP ${rates.first.toStringAsFixed(0)} / hr';
      }
    }

    return 'Price not listed';
  }

  Widget _priceTag(String label) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1E4),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _newsOrange.withValues(alpha: .28)),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sell_outlined, color: _newsOrange, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: _newsInk,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _contactOwner(Map<String, dynamic> post) async {
    try {
      final session = await AppSession.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Your session has expired.', 401);
      }
      final businessKey = '${post['businessId'] ?? post['businessName'] ?? ''}';
      final response = await _api.messageOwner(
        token: token,
        businessKey: businessKey,
      );
      final owner = response['owner'] as Map<String, dynamic>?;
      if (!mounted) return;
      if (owner == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This merchant is not available for messages yet.'),
          ),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MessagesDashboardPage(
            owner: owner,
            businessTitle: '${post['businessName'] ?? 'Venue'}',
            initialUserPosition: _userPosition,
            api: _api,
            businessType: widget.businessType == 'Fitness' ? 'Fitness' : null,
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not contact the owner: $error')),
      );
    }
  }

  Future<void> _toggleSaved(Map<String, dynamic> post) async {
    final businessId = int.tryParse('${post['businessId']}');
    final businessName = '${post['businessName'] ?? ''}'.trim();
    final key = '${businessId ?? businessName}';
    if (key.isEmpty) return;
    final currentlySaved = _savedKeys.contains(key);
    setState(() {
      if (currentlySaved) {
        _savedKeys.remove(key);
        if (widget.savedOnly) {
          _posts = _posts.then(
            (posts) =>
                posts.where((item) => _postSaveKey(item) != key).toList(),
          );
        }
      } else {
        _savedKeys.add(key);
      }
    });
    try {
      if (currentlySaved) {
        await SavedItemStore.remove(widget.savedItemType, key);
      } else {
        await SavedItemStore.save(
          type: widget.savedItemType,
          key: key,
          title: businessName,
          subtitle: '${post['address'] ?? ''}',
          imageUrl: '${post['imageUrl'] ?? ''}',
        );
      }
      if (currentlySaved && widget.savedOnly && mounted) {
        _reload();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlySaved ? 'Removed from Saved.' : 'Saved to your venues.',
            ),
          ),
        );
      }
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        if (currentlySaved) {
          _savedKeys.add(key);
          if (widget.savedOnly) {
            _posts = _loadFeed();
          }
        } else {
          _savedKeys.remove(key);
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update Saved: $error')));
    }
  }

  String _postSaveKey(Map<String, dynamic> post) {
    final businessId = int.tryParse('${post['businessId']}');
    final businessName = '${post['businessName'] ?? ''}'.trim();
    return '${businessId ?? businessName}';
  }

  String _visitUrl(Map<String, dynamic> post) =>
      '${post['visitUrl'] ?? post['visit_url'] ?? ''}'.trim();

  Future<void> _visitVenue(Map<String, dynamic> post) async {
    final value = _visitUrl(post);
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasScheme ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The venue link could not be opened.')),
        );
      }
    }
  }

  Widget _imageFallback() => const SizedBox(
    height: _newsCardImageHeight,
    width: double.infinity,
    child: ColoredBox(
      color: Color(0xFFFFE8D2),
      child: Icon(Icons.storefront_rounded, size: 52, color: _newsOrange),
    ),
  );

  Widget _image(String value) {
    final provider = _imageProvider(value);
    if (provider == null) return _imageFallback();
    return Image(
      image: provider,
      height: _newsCardImageHeight,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _imageFallback(),
    );
  }

  ImageProvider<Object>? _imageProvider(String value) {
    if (value.startsWith('data:image/')) {
      final separator = value.indexOf(',');
      if (separator <= 0 || separator >= value.length - 1) return null;
      try {
        return MemoryImage(base64Decode(value.substring(separator + 1)));
      } on FormatException {
        return null;
      }
    }
    return NetworkImage(value);
  }

  Future<void> _openBookingType(Map<String, dynamic> post) async {
    try {
      final businessValue = post['business'];
      final business = businessValue is Map
          ? Map<String, dynamic>.from(businessValue)
          : const <String, dynamic>{};
      final businessId = int.tryParse(
        '${post['businessId'] ?? business['id'] ?? ''}',
      );
      final locallyDisabled = _isMerchantDisabled(post);
      final availableBusinesses = locallyDisabled || businessId == null
          ? <Map<String, dynamic>>[]
          : await _api.customerBusinesses();
      final matchingBusinesses = availableBusinesses
          .where((item) => int.tryParse('${item['id'] ?? ''}') == businessId)
          .toList();
      final publishedBusiness = matchingBusinesses.isEmpty
          ? null
          : matchingBusinesses.first;

      if (publishedBusiness == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This venue is currently unavailable and cannot be booked.',
              ),
            ),
          );
        }
        return;
      }
      final type =
          '${publishedBusiness['businessType'] ?? post['businessType'] ?? post['type'] ?? ''}';
      final venue = _toSportsVenue(
        {
          ...post,
          ...publishedBusiness,
          'businessName': publishedBusiness['name'] ?? post['businessName'],
          'includedPlayers': publishedBusiness['includedPlayers'],
          'additionalPlayerFee': publishedBusiness['additionalPlayerFee'],
          'averageRating': post['averageRating'],
          'reviewCount': post['reviewCount'],
          'ratingUserCount': post['ratingUserCount'],
          'heartCount': post['heartCount'],
          'business': publishedBusiness,
        },
        fitness:
            type.toLowerCase().contains('fitness') ||
            type.toLowerCase().contains('wellness'),
      );
      if (!mounted) return;

      if (type.toLowerCase().contains('event')) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          backgroundColor: const Color(0xFFF8F9FF),
          builder: (context) {
            final name = '${post['businessName'] ?? 'Event venue'}';
            final category =
                '${post['category'] ?? publishedBusiness['category'] ?? 'Event'}';
            final address =
                '${post['address'] ?? publishedBusiness['address'] ?? 'Address unavailable'}';
            final details =
                '${post['details'] ?? publishedBusiness['details'] ?? ''}';
            final fee =
                post['eventFee'] ??
                post['event_fee'] ??
                publishedBusiness['eventFee'] ??
                publishedBusiness['event_fee'];
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Event type: $category'),
                    const SizedBox(height: 6),
                    Text('Location: $address'),
                    if (fee != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Price: PHP ${_number(fee).toStringAsFixed(0)} / event',
                      ),
                    ],
                    if (details.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(details),
                    ],
                  ],
                ),
              ),
            );
          },
        );
        return;
      }

      if (type.toLowerCase().contains('fitness') ||
          type.toLowerCase().contains('wellness')) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SportsVenueDetailPage(
              venue: venue,
              savedItemType: 'fitness',
              amenitiesHeading: 'FITNESS AMENITIES',
              onReserve: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  backgroundColor: const Color(0xFFF8F9FF),
                  builder: (_) => FitnessBookingPage(
                    business: publishedBusiness,
                    api: _api,
                    onLogout: widget.onLogout,
                  ),
                );
              },
            ),
          ),
        );
        return;
      }

      if (!type.toLowerCase().contains('sport')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This venue has no business type.')),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SportsDashboardPage(
            onLogout: widget.onLogout,
            initialVenue: venue,
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open venue page: $error')),
      );
    }
  }

  // Retained for compatibility with older venue-post payloads.
  // ignore: unused_element
  SportsVenue _toSportsVenue(
    Map<String, dynamic> post, {
    bool fitness = false,
  }) {
    final business = post['business'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(post['business'] as Map)
        : post['business'] is Map
        ? Map<String, dynamic>.from(post['business'] as Map)
        : <String, dynamic>{};
    final businessName = _stringValue([
      post['businessName'],
      business['name'],
      business['businessName'],
    ]);
    final category = _stringValue([post['category'], business['category']]);
    final type = _stringValue([
      post['businessType'],
      business['businessType'],
      post['facilityType'],
      business['facilityType'],
    ]);
    final address = _stringValue([
      post['address'],
      business['address'],
      post['location'],
      business['location'],
    ]);
    final ownerName = _stringValue([
      post['ownerName'],
      business['ownerName'],
      post['merchantName'],
      business['merchantName'],
      post['ownerFirstName'],
      business['ownerFirstName'],
      post['ownerLastName'],
      business['ownerLastName'],
      business['merchant'],
    ]);
    final hours = _stringValue([
      post['hours'],
      post['opening_hours'],
      business['hours'],
      post['openingHours'],
      business['openingHours'],
      post['opening_hours'],
    ]);
    final availability = _stringValue([
      post['availability'],
      business['availability'],
      post['availabilityStatus'],
      business['availabilityStatus'],
    ]);
    final fitnessCategories = _stringMapList(
      business['fitnessCategories'] ?? business['fitness_categories_json'],
    );
    final fitnessCoaches = _stringMapList(
      business['fitnessCoaches'] ?? business['fitness_coaches_json'],
    );
    final fitnessRates = <String>[];
    var fitnessHeadlinePrice = 0.0;
    var fitnessHeadlineLabel = '';
    if (fitness) {
      for (final item in fitnessCategories) {
        final categoryName = _stringValue([item['category']]);
        if (categoryName.isEmpty) continue;
        for (final (plan, label, unit) in const [
          ('session', 'Session', 'session'),
          ('monthly', 'Monthly', 'month'),
          ('yearly', 'Yearly', 'year'),
        ]) {
          var amount = _number(item['${plan}Price']);
          if (plan == 'yearly') {
            final discountType = item['yearlyDiscountType'];
            final discountValue = _number(item['yearlyDiscountValue']);
            if (discountType == 'freeMonths') {
              amount = (amount - _number(item['monthlyPrice']) * discountValue)
                  .clamp(0, double.infinity);
            } else if (discountType == 'percentage') {
              amount *= (1 - discountValue / 100).clamp(0, 1);
            }
          }
          if (amount <= 0) continue;
          fitnessRates.add(
            '$categoryName · $label|PHP ${amount.toStringAsFixed(2)} / $unit',
          );
          if (fitnessHeadlinePrice == 0) {
            fitnessHeadlinePrice = amount;
            fitnessHeadlineLabel = unit;
          }
        }
      }
      for (final coach in fitnessCoaches) {
        final coachName = _stringValue([coach['name']]);
        final price = _number(coach['monthlyPrice']);
        if (coachName.isNotEmpty && price > 0) {
          fitnessRates.add(
            'Coach $coachName|PHP ${price.toStringAsFixed(2)} / month',
          );
        }
      }
    }
    final priceRaw = fitness && fitnessHeadlinePrice > 0
        ? fitnessHeadlinePrice
        : _firstNonEmpty([
            post['pricePerHour'],
            business['pricePerHour'],
            post['price_per_hour'],
            business['price_per_hour'],
            post['price'],
            business['price'],
            post['hourlyRate'],
            business['hourlyRate'],
          ]);
    final priceText = priceRaw == null || '$priceRaw'.trim().isEmpty
        ? ''
        : fitness && fitnessHeadlinePrice > 0
        ? 'PHP ${fitnessHeadlinePrice.toStringAsFixed(2)} / $fitnessHeadlineLabel'
        : (priceRaw is num
              ? 'PHP ${priceRaw.toStringAsFixed(0)} / hour'
              : priceRaw.toString().startsWith('PHP')
              ? priceRaw.toString()
              : 'PHP $priceRaw / hour');
    final image = _stringValue([
      post['imageUrl'],
      business['imageUrl'],
      post['image'],
      business['image'],
    ]);
    final images = _stringListValue([
      post['imageUrls'],
      post['businessImageUrl'],
      business['imageUrls'],
      post['images'],
      business['images'],
      post['imageUrl'],
      business['imageUrl'],
    ]);
    final tags = _stringListValue([
      post['tags'],
      post['amenities'],
      business['tags'],
      post['amenities'],
      business['amenities'],
    ]);
    final rawPeriods = post['ratePeriods'];
    final rateLabels = <String>[];
    if (rawPeriods is List) {
      for (final item in rawPeriods.whereType<Map>()) {
        final start = item['start'] ?? item['start_time'] ?? '';
        final end = item['end'] ?? item['end_time'] ?? '';
        final amount = item['pricePerHour'] ?? item['price_per_hour'];
        if ('$amount'.trim().isNotEmpty && '$amount' != 'null') {
          rateLabels.add(
            '$start - $end|PHP ${double.tryParse('$amount')?.toStringAsFixed(0) ?? amount} / hr',
          );
        }
      }
    }
    final parsedPrice = priceRaw is num
        ? priceRaw.toDouble()
        : double.tryParse('$priceRaw') ?? 0;
    final totalSlots =
        int.tryParse('${post['slotCount'] ?? business['slotCount'] ?? 1}') ?? 1;
    final rawSportsSlots =
        post['sportsSlots'] ??
        business['sportsSlots'] ??
        post['sports_slots_json'] ??
        business['sports_slots_json'];
    final sportsSlots = normalizeSportsSlotConfigurations(
      raw: rawSportsSlots,
      legacySportTypes: category,
      legacyPrice: parsedPrice,
      totalSlots: totalSlots,
      includedPlayers: _number(
        post['includedPlayers'] ??
            business['includedPlayers'] ??
            post['included_players'] ??
            business['included_players'],
      ).toInt(),
      additionalPlayerFee: _number(
        post['additionalPlayerFee'] ??
            business['additionalPlayerFee'] ??
            post['additional_player_fee'] ??
            business['additional_player_fee'],
      ),
    );
    final sportRateLabels = sportsSlots.map((sport) {
      final rate = (sport['pricePerHour'] as num).toDouble();
      final included = (sport['includedPlayers'] as num).toInt();
      final extraFee = (sport['additionalPlayerFee'] as num).toDouble();
      final playerFee = included > 0 && extraFee > 0
          ? ' · $included included · PHP ${extraFee.toStringAsFixed(2)} / extra player'
          : '';
      return '${sport['sportType']}: PHP ${rate.toStringAsFixed(2)} / hr / '
          '${sport['fullStudio'] == true ? 'whole studio' : 'per slot'}'
          '$playerFee';
    }).toList();
    final maxSportPrice = sportsSlots
        .map((sport) => (sport['pricePerHour'] as num).toDouble())
        .fold<double>(parsedPrice, (maximum, value) {
          return value > maximum ? value : maximum;
        });
    final venueId =
        int.tryParse('${post['businessId'] ?? business['id'] ?? 0}') ?? 0;

    return (
      id: venueId,
      name: businessName,
      sport: fitness
          ? fitnessCategories
                .map((item) => _stringValue([item['category']]))
                .where((item) => item.isNotEmpty)
                .join(', ')
          : sportsSlots.map((item) => item['sportType']).join(', '),
      address: address,
      ownerName: ownerName,
      type: type,
      courts: fitness
          ? _stringValue([business['facilityType'], business['facility_type']])
          : '',
      hours: hours,
      availability: availability,
      details: _stringValue([
        post['details'],
        post['business_details'],
        business['details'],
      ]),
      image: image,
      images: images,
      priceDay: priceText,
      priceNight: priceText,
      priceLines: fitness && fitnessRates.isNotEmpty
          ? fitnessRates
          : sportRateLabels.isNotEmpty
          ? sportRateLabels
          : priceText.isEmpty
          ? const <String>[]
          : <String>[priceText],
      maxPrice: fitness && fitnessHeadlinePrice > 0
          ? fitnessHeadlinePrice
          : maxSportPrice,
      averageRating: _number(post['averageRating']),
      reviewCount: _number(post['reviewCount']).toInt(),
      ratingUserCount: _number(post['ratingUserCount']).toInt(),
      includedPlayers:
          int.tryParse(
            '${post['includedPlayers'] ?? business['includedPlayers'] ?? post['included_players'] ?? business['included_players'] ?? 0}',
          ) ??
          0,
      additionalPlayerFee:
          double.tryParse(
            '${post['additionalPlayerFee'] ?? business['additionalPlayerFee'] ?? post['additional_player_fee'] ?? business['additional_player_fee'] ?? 0}',
          ) ??
          0,
      totalSlots: totalSlots,
      sportsSlots: sportsSlots,
      tags: tags,
      rateLabels: fitness && fitnessRates.isNotEmpty
          ? fitnessRates
          : sportRateLabels.isNotEmpty
          ? sportRateLabels
          : rateLabels,
      latitude: 0,
      longitude: 0,
      distanceLabel: _distanceLabel(post) ?? '',
      heartCount: _postHeartCount(post),
      visitUrl: _stringValue([
        post['visitUrl'],
        business['visitUrl'],
        post['visit_url'],
        business['visit_url'],
      ]),
      merchantEmail: _stringValue([
        post['merchantEmail'],
        business['merchantEmail'],
        post['merchant_email'],
        business['merchant_email'],
      ]),
      merchantPhone: _stringValue([
        post['merchantPhone'],
        business['merchantPhone'],
        post['merchant_phone'],
        business['merchant_phone'],
      ]),
      merchantAvatarUrl: _stringValue([
        post['merchantAvatarUrl'],
        business['merchantAvatarUrl'],
        post['merchant_avatar_url'],
        business['merchant_avatar_url'],
      ]),
    );
  }

  String _stringValue(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num || value is bool) return value.toString();
      if (value is Map) {
        final map = value;
        final candidate = _stringValue([
          map['ownerName'],
          map['merchantName'],
          map['name'],
          map['businessName'],
          map['firstName'],
          map['lastName'],
        ]);
        if (candidate.isNotEmpty) return candidate;
      }
    }
    return '';
  }

  List<Map<String, dynamic>> _stringMapList(Object? value) {
    dynamic decoded = value;
    if (decoded is String && decoded.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(decoded);
      } on FormatException {
        return const [];
      }
    }
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  dynamic _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value is num) return value;
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is Map) {
        return _firstNonEmpty([
          value['pricePerHour'],
          value['price_per_hour'],
          value['hourlyRate'],
          value['price'],
        ]);
      }
    }
    return null;
  }

  List<String> _stringListValue(List<dynamic> values) {
    final output = <String>[];
    for (final value in values) {
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          output.add(trimmed);
        }
        continue;
      }
      if (value is List) {
        for (final item in value) {
          if (item is String && item.trim().isNotEmpty) {
            output.add(item.trim());
          } else if (item is Map) {
            final nested = _stringValue([
              item['name'],
              item['label'],
              item['value'],
            ]);
            if (nested.isNotEmpty) output.add(nested);
          }
        }
      }
      if (value is Map) {
        final nested = _stringValue([
          value['name'],
          value['label'],
          value['value'],
          value['title'],
          value['tag'],
        ]);
        if (nested.isNotEmpty) output.add(nested);
      }
    }
    return output.toSet().toList();
  }

  List<String> _imageListValue(List<dynamic> values) {
    for (final value in values) {
      final parsed = <String>[];
      if (value is List) {
        parsed.addAll(
          value
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty && item != 'null'),
        );
      } else if (value is String) {
        final trimmed = value.trim();
        if (trimmed.startsWith('[')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is List) {
              parsed.addAll(
                decoded
                    .whereType<String>()
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty && item != 'null'),
              );
            }
          } on FormatException {
            continue;
          }
        } else if (trimmed.isNotEmpty && trimmed != 'null') {
          parsed.add(trimmed);
        }
      }
      if (parsed.isNotEmpty) return parsed.toSet().toList();
    }
    return const [];
  }

  Future<void> _showReviews(Map<String, dynamic> post, int businessId) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ReviewsSheet(
          api: _api,
          businessId: businessId,
          businessName: '${post['businessName'] ?? ''}',
          onSubmitted: _reload,
        ),
      );

  double _number(dynamic value) => double.tryParse('$value') ?? 0;
}
