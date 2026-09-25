import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_api.dart';
import 'app_session.dart';
import 'sports.dart';
import 'event_dashboard.dart';
import 'fitness_dashboard.dart';
import 'saved_items.dart';
import 'messages_dashboard.dart';
import 'customer_bookings_page.dart';
import 'profile_dashboard.dart';
import 'reserve_dashboard.dart';
import 'reviews.dart';
import 'all_venues_page.dart';

const _newsInk = Color(0xFF101B33);
const _newsMuted = Color(0xFF68748A);
const _newsOrange = Color(0xFFFF8200);
const _newsPage = Color(0xFFF7F9FC);

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
      height: 190,
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
  const NewsFeedPage({super.key, this.onLogout, this.savedOnly = false});

  final Future<void> Function(BuildContext context)? onLogout;
  final bool savedOnly;

  @override
  State<NewsFeedPage> createState() => _NewsFeedPageState();
}

class _NewsFeedPageState extends State<NewsFeedPage> {
  final _api = AuthApi();
  final _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _posts;
  final Set<String> _savedKeys = <String>{};
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
    final posts = await _api.newsFeed(token);
    if (!widget.savedOnly) return posts;
    final saved = await SavedItemStore.list();
    final savedKeys = saved
        .where((item) => '${item['itemType'] ?? ''}'.toLowerCase() == 'sports')
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

  Future<void> _reload() async {
    final refreshed = _loadFeed();
    setState(() => _posts = refreshed);
    await refreshed;
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
                      '${item['itemType'] ?? ''}'.toLowerCase() == 'sports',
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
                initialSelection: 'Sports',
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
        widget.savedOnly ? 'Saved venues' : 'Sports Courts',
        style: const TextStyle(color: _newsInk, fontWeight: FontWeight.w900),
      ),
      actions: [
        if (!widget.savedOnly)
          IconButton(
            key: const ValueKey('news-feed-open-filters'),
            tooltip: 'Open filters',
            onPressed: _openSportsFilters,
            icon: const Icon(Icons.tune_rounded),
            style: IconButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor: const Color(0xFFF7F9FC),
              foregroundColor: _newsInk,
            ),
          ),
      ],
    ),
    body: Column(
      children: [
        if (!widget.savedOnly) ...[_feedIntro(), _mainSearchBar()],
        if (widget.savedOnly) _mainSearchBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
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
                final posts = _filteredPosts(snapshot.data ?? const []);
                if (posts.isEmpty) {
                  return _message(
                    widget.savedOnly
                        ? 'You have no saved venues yet.'
                        : snapshot.data?.isEmpty == true
                        ? 'No venue news has been posted yet.'
                        : 'No courts match your search.',
                  );
                }
                return widget.savedOnly
                    ? _savedCardList(posts)
                    : _feedContent(posts);
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
          shadowColor: const Color(0x14000000),
          elevation: 2,
          height: 72,
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
        selectedIndex: widget.savedOnly ? 1 : 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: _onNavigationSelected,
        destinations: const [
          NavigationDestination(
            key: ValueKey('news-feed-nav-explore'),
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on_rounded),
            label: 'Explore',
          ),
          NavigationDestination(
            key: ValueKey('news-feed-nav-saved'),
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Saved',
          ),
          NavigationDestination(
            key: ValueKey('news-feed-nav-messages'),
            icon: Icon(Icons.send_outlined),
            selectedIcon: Icon(Icons.send_rounded),
            label: 'Messages',
          ),
          NavigationDestination(
            key: ValueKey('news-feed-nav-bookings'),
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today_rounded),
            label: 'Bookings',
          ),
          NavigationDestination(
            key: ValueKey('news-feed-nav-profile'),
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                            key: const ValueKey('news-feed-filter-reset'),
                            onPressed: () {
                              setState(() {
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
                            key: const ValueKey('news-feed-filter-close'),
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
                          _filterLabel('Sport type'),
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
                          const SizedBox(height: 20),
                          _filterLabel('Area / city'),
                          _feedDropdown(
                            identifier: 'area',
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
                                  (post) => '${post['facilityType'] ?? ''}',
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
                                  key: ValueKey(
                                    'news-feed-filter-amenity-$value',
                                  ),
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
                            key: const ValueKey('news-feed-filter-price'),
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
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const ValueKey('news-feed-filter-apply'),
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
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 6),
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
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.5,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Fresh updates, offers, and stories from local venues.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _newsMuted,
                      fontSize: 13,
                      height: 1.35,
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

  Widget _mainSearchBar() => Container(
    color: _newsPage,
    padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
    child: TextField(
      key: const ValueKey('news-feed-search'),
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Search venues, categories, or news...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                key: const ValueKey('news-feed-search-clear'),
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
        prefixIconColor: _newsOrange,
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: _newsOrange, width: 1.4),
        ),
      ),
    ),
  );

  Widget _feedContent(List<Map<String, dynamic>> posts) {
    final popular = [...posts]
      ..sort(
        (a, b) =>
            _number(b['reviewCount']).compareTo(_number(a['reviewCount'])),
      );
    final highestRated = [...posts]
      ..sort(
        (a, b) =>
            _number(b['averageRating']).compareTo(_number(a['averageRating'])),
      );
    final featured = popular.take(6).toList();
    final rated = highestRated.take(6).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _quickSportChips(posts),
        const SizedBox(height: 10),
        _sectionHeader('Most popular', 'Highest review activity', featured),
        _horizontalVenues(featured, identifier: 'most-popular'),
        const SizedBox(height: 22),
        _sectionHeader('Highest rate', 'Top average ratings', rated),
        _horizontalVenues(rated, identifier: 'highest-rate'),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'All listed courts',
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
      MaterialPageRoute(
        builder: (_) => AllVenuesPage(
          title: title,
          posts: sectionPosts,
          cardBuilder: _postCard,
        ),
      ),
    );
  }

  Widget _quickSportChips(List<Map<String, dynamic>> posts) {
    final sports = _feedOptions(
      posts,
      (post) => '${post['category'] ?? ''}',
      '',
    ).where((value) => value.isNotEmpty).toList();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sports.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final selected = index == 0
              ? _feedSport == 'All sports'
              : _feedSport.toLowerCase() == sports[index - 1].toLowerCase();
          final label = index == 0 ? 'All courts' : sports[index - 1];
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) =>
                setState(() => _feedSport = index == 0 ? 'All sports' : label),
            selectedColor: _newsOrange,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? _newsOrange : const Color(0xFFE1E6ED),
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : _newsInk,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          );
        },
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

  Widget _miniVenueCard(Map<String, dynamic> post) {
    final image = '${post['imageUrl'] ?? ''}';
    final name = '${post['businessName'] ?? 'Venue'}';
    final category = '${post['category'] ?? ''}';
    final rating = _number(post['averageRating']);
    final price = _number(post['pricePerHour']);
    final availability = '${post['availability'] ?? ''}'.toLowerCase();
    final isOpen =
        availability.contains('open') || availability.contains('available');
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openBookingType(post),
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
                      image.isEmpty ? _miniImageFallback() : _miniImage(image),
                      if (isOpen)
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
                          child: _miniBadge(category, const Color(0xCC101B33)),
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
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 15,
                        ),
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
                    if (price > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        'PHP ${price.toStringAsFixed(0)} / hr',
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

  List<Map<String, dynamic>> _filteredPosts(List<Map<String, dynamic>> posts) {
    final query = _searchController.text.trim().toLowerCase();
    return posts.where((post) {
      final address = '${post['address'] ?? ''}'.toLowerCase();
      final category = '${post['category'] ?? ''}'.toLowerCase();
      final matchesArea =
          _feedArea == 'All areas' || address.contains(_feedArea.toLowerCase());
      final matchesSport =
          _feedSport == 'All sports' || category == _feedSport.toLowerCase();
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
          _feedCourtType == 'All' ||
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
  }

  void _onNavigationSelected(int index) {
    if (index == 0) {
      if (widget.savedOnly) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => NewsFeedPage(onLogout: widget.onLogout),
          ),
        );
      }
      return;
    }
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              NewsFeedPage(onLogout: widget.onLogout, savedOnly: true),
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
    final type = '${post['businessType'] ?? ''}';
    final category = '${post['category'] ?? ''}';
    final address = '${post['address'] ?? ''}';
    final body = '${post['body'] ?? ''}';
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
              images.isNotEmpty
                  ? _NewsImageCarousel(
                      images: images,
                      imageProvider: _imageProvider,
                    )
                  : image != null && image.isNotEmpty
                  ? _image(image)
                  : _imageFallback(),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
                        style: const TextStyle(
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
                        isSaved
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                    ),
                  ],
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
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: _newsOrange,
                          size: 19,
                        ),
                        SizedBox(width: 8),
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
                          : '$reviews ${reviews == 1 ? 'review' : 'reviews'} · '
                                '$ratedUsers rated',
                      style: const TextStyle(color: _newsMuted, fontSize: 12),
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
                const SizedBox(height: 8),
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
    final business = post['business'];
    final nestedBusiness = business is Map
        ? business
        : const <String, dynamic>{};
    final value = post.containsKey('enabled')
        ? post['enabled']
        : post.containsKey('businessEnabled')
        ? post['businessEnabled']
        : nestedBusiness.containsKey('enabled')
        ? nestedBusiness['enabled']
        : null;
    if (value == null) return false;
    if (value is bool) return value == false;
    if (value is num) return value == 0;
    final normalized = '$value'.trim().toLowerCase();
    return normalized == '0' ||
        normalized == 'false' ||
        normalized == 'disabled' ||
        normalized == 'inactive' ||
        normalized == 'off';
  }

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
        await SavedItemStore.remove('sports', key);
      } else {
        await SavedItemStore.save(
          type: 'sports',
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
      if (_isMerchantDisabled(post)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This court is currently unavailable and cannot be booked.',
              ),
            ),
          );
        }
        return;
      }
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

  // Retained for compatibility with older venue-post payloads.
  // ignore: unused_element
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
