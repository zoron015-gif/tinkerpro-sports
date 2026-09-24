import 'dart:convert';

import 'package:flutter/material.dart';

import 'auth_api.dart';
import 'app_session.dart';
import 'sports.dart';
import 'event_dashboard.dart';
import 'fitness_dashboard.dart';
import 'saved_dashboard.dart';
import 'messages_dashboard.dart';
import 'customer_bookings_page.dart';
import 'profile_dashboard.dart';

const _newsInk = Color(0xFF101B33);
const _newsMuted = Color(0xFF68748A);
const _newsOrange = Color(0xFFFF8200);
const _newsPage = Color(0xFFF7F9FC);

class NewsFeedPage extends StatefulWidget {
  const NewsFeedPage({super.key, this.onLogout});

  final Future<void> Function(BuildContext context)? onLogout;

  @override
  State<NewsFeedPage> createState() => _NewsFeedPageState();
}

class _NewsFeedPageState extends State<NewsFeedPage> {
  final _api = AuthApi();
  final _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _posts;
  String _categoryFilter = 'All';
  String _feedArea = 'All areas';
  String _feedSport = 'All sports';
  String _feedCourtType = 'All';
  String _feedAvailability = 'Any';
  double _feedMaxPrice = 700;
  final Set<String> _feedAmenities = <String>{};

  @override
  void initState() {
    super.initState();
    _posts = _loadFeed();
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
    return _api.newsFeed(token);
  }

  void _reload() => setState(() => _posts = _loadFeed());

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
      title: const Text(
        'Sports Courts',
        style: TextStyle(color: _newsInk, fontWeight: FontWeight.w900),
      ),
      actions: [
        IconButton(
          tooltip: 'View map',
          onPressed: _openSportsMap,
          icon: const Icon(Icons.map_outlined),
        ),
        IconButton(
          tooltip: 'Open filters',
          onPressed: _openSportsFilters,
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    ),
    body: Column(
      children: [
        _feedIntro(),
        _mainSearchBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _reload(),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _posts,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _message(
                    'Could not load the news feed: ${snapshot.error}',
                  );
                }
                final allPosts = snapshot.data ?? const [];
                final posts = _filteredPosts(allPosts);
                if (allPosts.isEmpty) {
                  return _message('No venue news has been posted yet.');
                }
                if (posts.isEmpty) {
                  return _message('No news matches your search.');
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: posts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => _postCard(posts[index]),
                );
              },
            ),
          ),
        ),
      ],
    ),
    bottomNavigationBar: Theme(
      data: Theme.of(context).copyWith(
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shadowColor: Colors.transparent,
          indicatorColor: const Color(0xFFFFE8D2),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? _newsOrange : _newsInk,
              size: 24,
            );
          }),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(
              color: _newsInk,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      child: NavigationBar(
        height: 72,
        selectedIndex: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: _onNavigationSelected,
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
            icon: Icon(Icons.send_outlined),
            selectedIcon: Icon(Icons.send_rounded),
            label: 'Messages',
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
    ),
  );

  void _openSportsMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SportsDashboardPage(
          onLogout: widget.onLogout,
          initialAction: SportsDashboardAction.openMap,
        ),
      ),
    );
  }

  void _openSportsFilters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _posts,
        builder: (context, snapshot) {
          final posts = snapshot.data ?? const <Map<String, dynamic>>[];
          final areas = _feedOptions(
            posts,
            (post) => '${post['address'] ?? ''}',
            'All areas',
          );
          final sports = _feedOptions(
            posts,
            (post) => '${post['category'] ?? ''}',
            'All sports',
          );
          return StatefulBuilder(
            builder: (context, setSheetState) => Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .72,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1E6ED),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Filter venues',
                              style: TextStyle(
                                color: _newsInk,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _categoryFilter = 'All';
                                _feedArea = 'All areas';
                                _feedSport = 'All sports';
                                _feedCourtType = 'All';
                                _feedAvailability = 'Any';
                                _feedMaxPrice = 700;
                                _feedAmenities.clear();
                              });
                              setSheetState(() {});
                            },
                            child: const Text('Reset'),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        children: [
                          _filterLabel('Business type'),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final value in [
                                'All',
                                'Sports',
                                'Events',
                                'Fitness',
                              ])
                                ChoiceChip(
                                  label: Text(value),
                                  selected: _categoryFilter == value,
                                  onSelected: (_) {
                                    setState(() => _categoryFilter = value);
                                    setSheetState(() {});
                                  },
                                  selectedColor: _newsOrange,
                                  labelStyle: TextStyle(
                                    color: _categoryFilter == value
                                        ? Colors.white
                                        : _newsInk,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _filterLabel('Area / city'),
                          _feedDropdown(
                            value: _feedArea,
                            values: areas,
                            onChanged: (value) {
                              setState(() => _feedArea = value);
                              setSheetState(() {});
                            },
                          ),
                          const SizedBox(height: 20),
                          _filterLabel('Court type'),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final value in [
                                'All',
                                ..._feedOptions(
                                  posts,
                                  (post) =>
                                      '${post['facilityType'] ?? ''}',
                                  '',
                                ).where((value) => value.isNotEmpty),
                              ])
                                ChoiceChip(
                                  label: Text(value),
                                  selected: _feedCourtType == value,
                                  onSelected: (_) {
                                    setState(() => _feedCourtType = value);
                                    setSheetState(() {});
                                  },
                                  selectedColor: _newsOrange,
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
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
                                  label: Text(value),
                                  selected: _feedAmenities.contains(value),
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
                          const SizedBox(height: 20),
                          _filterLabel('Availability'),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final value in const ['Any', 'Open 24 hours'])
                                ChoiceChip(
                                  label: Text(value),
                                  selected: _feedAvailability == value,
                                  onSelected: (_) {
                                    setState(() => _feedAvailability = value);
                                    setSheetState(() {});
                                  },
                                  selectedColor: _newsOrange,
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _filterLabel('Price (PHP / hour)'),
                          Slider(
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
                          const SizedBox(height: 8),
                          _filterLabel('Sport / category'),
                          _feedDropdown(
                            value: _feedSport,
                            values: sports,
                            onChanged: (value) {
                              setState(() => _feedSport = value);
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
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: _newsInk,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
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
          );
        },
      ),
    );
  }

  List<String> _feedOptions(
    List<Map<String, dynamic>> posts,
    String Function(Map<String, dynamic>) selector,
    String allLabel,
  ) {
    final values = posts
        .map(selector)
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return [allLabel, ...values];
  }

  Widget _filterLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: _newsMuted,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    ),
  );

  Widget _feedDropdown({
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
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
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 2),
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
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Fresh updates, offers, and stories from local venues.',
                    style: TextStyle(color: _newsMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh feed',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded, color: _newsInk),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final filter in ['All', 'Sports', 'Events', 'Fitness'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: _categoryFilter == filter,
                    onSelected: (_) => setState(() => _categoryFilter = filter),
                    selectedColor: _newsOrange,
                    labelStyle: TextStyle(
                      color: _categoryFilter == filter
                          ? Colors.white
                          : _newsInk,
                      fontWeight: FontWeight.w800,
                    ),
                    side: BorderSide(
                      color: _categoryFilter == filter
                          ? _newsOrange
                          : const Color(0xFFDDE3EC),
                    ),
                    backgroundColor: Colors.white,
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _mainSearchBar() => Container(
    color: _newsPage,
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Search venues, categories, or news...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
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
          borderSide: const BorderSide(color: Color(0xFFE1E6ED)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFFE1E6ED)),
        ),
      ),
    ),
  );

  List<Map<String, dynamic>> _filteredPosts(List<Map<String, dynamic>> posts) {
    final query = _searchController.text.trim().toLowerCase();
    return posts.where((post) {
      final type = '${post['businessType'] ?? ''}'.toLowerCase();
      final matchesCategory =
          _categoryFilter == 'All' ||
          (_categoryFilter == 'Sports' && type.contains('sport')) ||
          (_categoryFilter == 'Events' && type.contains('event')) ||
          (_categoryFilter == 'Fitness' &&
              (type.contains('fitness') || type.contains('wellness')));
      final address = '${post['address'] ?? ''}'.toLowerCase();
      final category = '${post['category'] ?? ''}'.toLowerCase();
      final matchesArea = _feedArea == 'All areas' ||
          address.contains(_feedArea.toLowerCase());
      final matchesSport = _feedSport == 'All sports' ||
          category == _feedSport.toLowerCase();
      final facility = '${post['facilityType'] ?? ''}';
      final hours = '${post['hours'] ?? post['opening_hours'] ?? ''}';
      final availability = '${post['availability'] ?? ''}';
      final price = double.tryParse(
            '${post['pricePerHour'] ?? post['price_per_hour'] ?? 0}',
          ) ??
          0;
      final rawAmenities = '${post['tags'] ?? post['amenities'] ?? ''}'
          .toLowerCase();
      final matchesCourt = _feedCourtType == 'All' ||
          facility.toLowerCase() == _feedCourtType.toLowerCase();
      final matchesAvailability = _feedAvailability == 'Any' ||
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
        post['title'],
        post['body'],
        post['address'],
      ].map((value) => '$value').join(' ').toLowerCase();
      return matchesCategory &&
          matchesArea &&
          matchesSport &&
          matchesCourt &&
          matchesAvailability &&
          matchesPrice &&
          matchesAmenities &&
          (query.isEmpty || searchable.contains(query));
    }).toList();
  }

  void _onNavigationSelected(int index) {
    if (index == 0) return;
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SavedDashboardPage(onLogout: widget.onLogout),
        ),
      );
    } else if (index == 2) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MessagesDashboardPage()));
    } else if (index == 3) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerBookingsPage(onLogout: widget.onLogout),
        ),
      );
    } else if (index == 4) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfileDashboardPage(onLogout: widget.onLogout),
        ),
      );
    }
  }

  Widget _message(String text) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(32),
    children: [
      const Icon(Icons.article_outlined, size: 48, color: _newsMuted),
      const SizedBox(height: 12),
      Center(child: Text(text, textAlign: TextAlign.center)),
    ],
  );

  Widget _postCard(Map<String, dynamic> post) {
    final image = post['imageUrl'] as String?;
    final rating = _number(post['averageRating']);
    final reviews = _number(post['reviewCount']).toInt();
    final businessId = int.tryParse('${post['businessId']}');
    final businessName = '${post['businessName'] ?? ''}';
    final type = '${post['businessType'] ?? ''}';
    final category = '${post['category'] ?? ''}';
    final address = '${post['address'] ?? ''}';
    final body = '${post['body'] ?? ''}';
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE5EAF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              if (image != null && image.isNotEmpty)
                _image(image)
              else
                _imageFallback(),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  style: const TextStyle(
                    color: _newsInk,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 6),
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
                          style: const TextStyle(
                            color: _newsMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  '${post['title'] ?? ''}',
                  style: const TextStyle(
                    color: _newsInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _newsMuted,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating == 0 ? 'New' : rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: _newsInk,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      rating == 0
                          ? 'No ratings yet'
                          : '$reviews ${reviews == 1 ? 'review' : 'reviews'}',
                      style: const TextStyle(color: _newsMuted, fontSize: 12),
                    ),
                    const Spacer(),
                    TextButton.icon(
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
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: businessId == null
                        ? null
                        : () => _openBookingType(post),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Explore venue'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _newsOrange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback() => const SizedBox(
    height: 190,
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
      height: 190,
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
      final type = '${post['businessType'] ?? post['type'] ?? ''}';
      final venue = _toSportsVenue(post);
      if (!mounted) return;

      if (type.toLowerCase().contains('event')) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EventDashboardPage(onLogout: null)),
        );
        return;
      }

      if (type.toLowerCase().contains('fitness') ||
          type.toLowerCase().contains('wellness')) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FitnessDashboardPage(onLogout: null),
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

  SportsVenue _toSportsVenue(Map<String, dynamic> post) {
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
    final category = _stringValue([
      post['category'],
      business['category'],
    ]);
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
    final priceRaw = _firstNonEmpty([
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
    final venueId =
        int.tryParse('${post['businessId'] ?? business['id'] ?? 0}') ?? 0;

    return (
      id: venueId,
      name: businessName,
      sport: category,
      address: address,
      ownerName: ownerName,
      type: type,
      courts: '',
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
      priceLines: priceText.isEmpty ? const [] : [priceText],
      maxPrice: parsedPrice,
      tags: tags,
      rateLabels: rateLabels,
      latitude: 0,
      longitude: 0,
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

  Future<void> _showReviews(Map<String, dynamic> post, int businessId) async {
    var reviews = await _api.newsReviews(businessId);
    if (!mounted) return;
    final comment = TextEditingController();
    var rating = 5;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${post['businessName'] ?? ''} reviews',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (reviews.isEmpty)
                  const Text(
                    'No reviews yet.',
                    style: TextStyle(color: _newsMuted),
                  )
                else
                  for (final review in reviews.take(8))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${review['reviewerName'] ?? 'Customer'}'),
                      subtitle: Text('${review['comment'] ?? ''}'),
                      trailing: Text('${review['rating'] ?? 0}/5'),
                    ),
                const Divider(height: 24),
                const Text(
                  'Leave a review after your completed booking',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                DropdownButtonFormField<int>(
                  initialValue: rating,
                  items: [
                    for (var value = 5; value >= 1; value--)
                      DropdownMenuItem(
                        value: value,
                        child: Text('$value stars'),
                      ),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => rating = value ?? 5),
                ),
                TextField(
                  controller: comment,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Comment'),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final session = await AppSession.load();
                      final token = session.apiToken;
                      if (token == null || token.isEmpty) return;
                      try {
                        await _api.createNewsReview(
                          token: token,
                          businessId: businessId,
                          rating: rating,
                          comment: comment.text.trim(),
                        );
                        reviews = await _api.newsReviews(businessId);
                        if (sheetContext.mounted) setSheetState(() {});
                        if (sheetContext.mounted && mounted) _reload();
                      } on Exception catch (error) {
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext)
                              .showSnackBar(SnackBar(content: Text('$error')));
                        }
                      }
                    },
                    child: const Text('Submit review'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    comment.dispose();
  }

  double _number(dynamic value) => double.tryParse('$value') ?? 0;
}
