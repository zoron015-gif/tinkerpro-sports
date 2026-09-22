import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_session.dart';
import 'auth_api.dart';
import 'event_dashboard.dart';
import 'fitness_dashboard.dart';
import 'profile_dashboard.dart';
import 'saved_items.dart';
import 'sports.dart';
import 'messages_dashboard.dart';
import 'customer_bookings_page.dart';

class SavedDashboardPage extends StatefulWidget {
  const SavedDashboardPage({super.key, this.onLogout, this.itemType});

  final Future<void> Function(BuildContext context)? onLogout;
  final String? itemType;

  @override
  State<SavedDashboardPage> createState() => _SavedDashboardPageState();
}

class _SavedDashboardPageState extends State<SavedDashboardPage> {
  static const _ink = Color(0xFF101B33);
  static const _navy = Color(0xFF192B50);
  static const _orange = Color(0xFFFF8200);
  static const _muted = Color(0xFF68748A);
  static const _line = Color(0xFFE2E7EF);

  late Future<List<Map<String, dynamic>>> _items;
  final Set<String> _optimisticallyRemoved = <String>{};
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _items = _loadSavedItems();
  }

  Future<List<Map<String, dynamic>>> _loadSavedItems() async {
    final saved = await SavedItemStore.list();
    final businesses = await AuthApi().customerBusinesses();
    return saved.map((item) {
      final key = item['itemKey'];
      final savedType = _savedBusinessType(item['itemType']);
      final business = businesses.cast<Map<String, dynamic>?>().firstWhere(
        (candidate) =>
            _businessType(candidate) == savedType &&
            (candidate?['id']?.toString() == key ||
                candidate?['name']?.toString() == key ||
                candidate?['name']?.toString() == item['title']?.toString()),
        orElse: () => null,
      );
      return {
        ...item,
        ...?business == null ? null : {'business': business},
      };
    }).toList();
  }

  String _savedBusinessType(dynamic value) {
    switch ('$value'.trim().toLowerCase()) {
      case 'sports':
        return 'sports';
      case 'event':
        return 'event';
      case 'fitness':
      case 'fitness & wellness':
        return 'fitness';
      default:
        return '';
    }
  }

  String _businessType(Map<String, dynamic>? business) => _savedBusinessType(
    business?['businessType'] ?? business?['business_type'],
  );

  Future<void> _refreshItems() async {
    setState(() => _items = _loadSavedItems());
    await _items;
    if (mounted) setState(_optimisticallyRemoved.clear);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Saved',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xFFF7F9FC),
        foregroundColor: const Color(0xFF101B33),
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load saved items: ${snapshot.error}'),
            );
          }
          final savedItems = (snapshot.data ?? [])
              .where(
                (item) =>
                    widget.itemType == null ||
                    item['itemType'] == widget.itemType,
              )
              .where(
                (item) => !_optimisticallyRemoved.contains(
                  _savedItemId(
                    item['itemType'] as String?,
                    item['itemKey'] as String?,
                  ),
                ),
              )
              .toList();
          final items = savedItems.where(_matchesSearch).toList();
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshItems,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _savedSearchBar(),
                  const SizedBox(height: 180),
                  Center(
                    child: Text(
                      savedItems.isEmpty
                          ? _emptyStateText
                          : 'No saved places match "$_searchQuery".',
                    ),
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              _savedSearchBar(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshItems,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _savedCard(context, item);
                    },
                  ),
                ),
              ),
            ],
          );
        },
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
                color: selected
                    ? const Color(0xFFFF8200)
                    : const Color(0xFF68748A),
                size: 24,
              );
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                color: selected
                    ? const Color(0xFF101B33)
                    : const Color(0xFF68748A),
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
          selectedIndex: 1,
          onDestinationSelected: (index) {
            if (index == 1) return;
            if (index == 0) {
              _openExplore(context);
              return;
            }
            if (index == 2) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MessagesDashboardPage()),
              );
              return;
            }
            if (index == 3) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CustomerBookingsPage(
                    onLogout: widget.onLogout,
                  ),
                ),
              );
              return;
            }

            if (index == 4) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ProfileDashboardPage(onLogout: widget.onLogout),
                ),
              );
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  index == 2
                      ? 'Messages will appear here.'
                      : 'Booking history will appear here.',
                ),
              ),
            );
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

  Widget _savedSearchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value.trim()),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search saved venues, areas, or sports...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: const Icon(Icons.clear_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: _navy, width: 1.4),
        ),
      ),
    ),
  );

  bool _matchesSearch(Map<String, dynamic> item) {
    if (_searchQuery.isEmpty) return true;
    final business = item['business'] is Map
        ? Map<String, dynamic>.from(item['business'] as Map)
        : const <String, dynamic>{};
    final searchable = [
      item['title'],
      item['subtitle'],
      item['itemKey'],
      item['itemType'],
      ...business.values,
    ].whereType<Object>().join(' ').toLowerCase();
    return searchable.contains(_searchQuery.toLowerCase());
  }

  Widget _savedCard(BuildContext context, Map<String, dynamic> item) {
    final type = _savedBusinessType(item['itemType']);
    if (type == 'sports') return _savedSportsCard(context, item);
    if (type == 'fitness') return _savedFitnessCard(context, item);
    if (type == 'event') return _savedEventCard(context, item);
    final title = item['title'] as String? ?? 'Untitled saved place';
    final savedDetails = item['subtitle'] as String? ?? 'No location provided';
    final details = _parseSavedDetails(savedDetails);
    final subtitle = details.$2;
    final key = item['itemKey'] as String? ?? title;
    final business = item['business'] is Map
        ? Map<String, dynamic>.from(item['business'] as Map)
        : const <String, dynamic>{};
    final address = business['address']?.toString() ?? subtitle;
    final category = business['category']?.toString() ?? details.$1;
    final facility = business['facilityType']?.toString();
    final hours = business['hours']?.toString();
    final availability = business['availability']?.toString();
    final price =
        (business['eventFee'] ??
                business['event_fee'] ??
                business['pricePerHour'])
            ?.toString();
    final tags = business['tags'] is List
        ? (business['tags'] as List).whereType<String>().toList()
        : <String>[];
    final savedImage = item['imageUrl'] as String?;
    final unavailable = _isUnavailable(item);
    final images = _savedImages(business, savedImage, type);

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 116,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => _showSavedGallery(images, type),
                  child: PageView.builder(
                    itemCount: images.length > 1 ? 10000 : 1,
                    itemBuilder: (_, index) => Image(
                      image: _savedImageProvider(
                        images[index % images.length],
                        type,
                      ),
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stackTrace) =>
                          Image.asset(_imageForType(type), fit: BoxFit.cover),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: .62),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 12,
                  child: _typeBadge(type, details.$1),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 17,
                      color: _muted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, height: 1.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _detailLine(Icons.category_outlined, 'Category: $category'),
                if (facility != null && facility.isNotEmpty)
                  _detailLine(Icons.business_outlined, 'Facility: $facility'),
                if (hours != null && hours.isNotEmpty)
                  _detailLine(Icons.access_time, 'Hours: $hours'),
                if (availability != null && availability.isNotEmpty)
                  _detailLine(
                    Icons.check_circle_outline,
                    'Availability: $availability',
                  ),
                if (business['details']?.toString().isNotEmpty == true)
                  _detailLine(
                    Icons.info_outline,
                    business['details'].toString(),
                  ),
                if (price != null && price.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 5),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFBFD),
                      border: Border.all(color: _line),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            type == 'event'
                                ? 'Event package'
                                : type == 'fitness'
                                ? 'Session price'
                                : 'Price / hour',
                            style: TextStyle(color: _muted, fontSize: 11),
                          ),
                        ),
                        Text(
                          type == 'event'
                              ? 'PHP $price / event'
                              : type == 'fitness'
                              ? 'PHP $price / session'
                              : 'PHP $price / hr',
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [for (final tag in tags) _tag(tag)],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Saved ${_typeLabel(type)} • ${key == title ? 'Saved card' : key}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: 11),
                if (unavailable) _unavailableNotice(),
                Row(
                  children: [
                    Expanded(
                      child: unavailable
                          ? OutlinedButton.icon(
                              onPressed: () =>
                                  _contactOwner(context, item, title),
                              icon: const Icon(
                                Icons.contact_mail_outlined,
                                size: 16,
                              ),
                              label: const Text('Contact owner'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _navy,
                                side: const BorderSide(color: _navy),
                                minimumSize: const Size(0, 38),
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: () => _message(
                                context,
                                'Opening $title for booking.',
                              ),
                              icon: const Icon(Icons.calendar_month, size: 16),
                              label: const Text('Book now'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _navy,
                                side: const BorderSide(color: _line),
                                minimumSize: const Size(0, 38),
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _removeSaved(context, type, key),
                        icon: const Icon(Icons.favorite_rounded, size: 16),
                        label: const Text('Unsave'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _orange,
                          minimumSize: const Size(0, 38),
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
  }

  Widget _savedFitnessCard(BuildContext context, Map<String, dynamic> item) {
    final title = item['title'] as String? ?? 'Saved fitness class';
    final key = item['itemKey'] as String? ?? title;
    final savedDetails = item['subtitle'] as String? ?? '';
    final savedCategory = RegExp(
      r'^Class:\s*(.*)$',
      multiLine: true,
    ).firstMatch(savedDetails)?.group(1)?.trim();
    final business = item['business'] is Map
        ? Map<String, dynamic>.from(item['business'] as Map)
        : const <String, dynamic>{};
    final address =
        business['address']?.toString() ?? savedDetails.split('\n').last.trim();
    final category =
        business['category']?.toString() ??
        savedCategory ??
        'Fitness & Wellness';
    final facility =
        business['facilityType']?.toString() ??
        business['facility_type']?.toString() ??
        '';
    final sessions =
        business['sessions']?.toString() ??
        business['session']?.toString() ??
        '';
    final hours =
        business['hours']?.toString() ??
        business['opening_hours']?.toString() ??
        'Open hours';
    final availability = business['availability']?.toString() ?? '';
    final details = business['details']?.toString() ?? '';
    final price =
        business['pricePerHour']?.toString() ??
        business['price_per_hour']?.toString() ??
        business['price']?.toString() ??
        business['hourlyRate']?.toString() ??
        '0';
    final tags = _savedTags(
      business['tags'] ?? business['amenities'] ?? business['amenities_json'],
    );
    final images = _savedImages(
      business,
      item['imageUrl'] as String?,
      'fitness',
    );
    final unavailable = _isUnavailable(item);

    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 235,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => _showSavedGallery(images, 'fitness'),
                  child: PageView.builder(
                    itemCount: images.length > 1 ? 10000 : 1,
                    itemBuilder: (_, index) => Image(
                      image: _savedImageProvider(
                        images[index % images.length],
                        'fitness',
                      ),
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stackTrace) => Image.asset(
                        _imageForType('fitness'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    onPressed: () => _removeSaved(context, 'fitness', key),
                    style: IconButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.favorite_rounded),
                  ),
                ),
                if (images.length > 1)
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
                          '${images.length} photos',
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
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                _detailLine(Icons.location_on_outlined, address),
                _detailLine(Icons.fitness_center, 'Class: $category'),
                if (facility.isNotEmpty)
                  _detailLine(Icons.business_outlined, 'Facility: $facility'),
                if (sessions.isNotEmpty)
                  _detailLine(Icons.event_available_outlined, sessions),
                _detailLine(Icons.access_time, 'Hours: $hours'),
                if (availability.isNotEmpty)
                  _detailLine(
                    Icons.check_circle_outline,
                    'Availability: $availability',
                  ),
                if (details.isNotEmpty)
                  _detailLine(Icons.info_outline, details),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFBFD),
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Session price',
                          style: TextStyle(color: _muted, fontSize: 11),
                        ),
                      ),
                      Text(
                        'PHP $price / session',
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unavailable) _unavailableNotice(),
                const SizedBox(height: 6),
                if (tags.isNotEmpty)
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [for (final tag in tags) _tag(tag)],
                  ),
                const SizedBox(height: 8),
                Text(
                  'Saved Fitness & Wellness • ${key == title ? 'Saved card' : key}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openVisit(
                          context,
                          '${business['visitUrl'] ?? business['visit_url'] ?? ''}',
                          title,
                        ),
                        icon: const Icon(Icons.language, size: 15),
                        label: const Text('Visit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _navy,
                          side: const BorderSide(color: _navy),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: unavailable
                          ? OutlinedButton.icon(
                              onPressed: () =>
                                  _contactOwner(context, item, title),
                              icon: const Icon(
                                Icons.contact_mail_outlined,
                                size: 15,
                              ),
                              label: const Text('Contact owner'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _navy,
                                side: const BorderSide(color: _navy),
                                minimumSize: const Size(0, 36),
                              ),
                            )
                          : FilledButton.icon(
                              onPressed: () =>
                                  _message(context, 'Booking $title is ready.'),
                              icon: const Icon(Icons.calendar_month, size: 15),
                              label: const Text('Book now'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _orange,
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
  }

  Widget _savedEventCard(BuildContext context, Map<String, dynamic> item) {
    final title = item['title'] as String? ?? 'Saved event venue';
    final key = item['itemKey'] as String? ?? title;
    final savedDetails = item['subtitle'] as String? ?? '';
    final savedType = RegExp(
      r'^Venue:\s*(.*)$',
      multiLine: true,
    ).firstMatch(savedDetails)?.group(1)?.trim();
    final business = item['business'] is Map
        ? Map<String, dynamic>.from(item['business'] as Map)
        : const <String, dynamic>{};
    final address =
        business['address']?.toString() ?? savedDetails.split('\n').last.trim();
    final category =
        business['category']?.toString() ?? savedType ?? 'Event venue';
    final facility =
        business['facilityType']?.toString() ??
        business['facility_type']?.toString() ??
        'Event venue';
    final hours =
        business['hours']?.toString() ??
        business['opening_hours']?.toString() ??
        'Open hours';
    final availability =
        business['availability']?.toString() ??
        business['availability_status']?.toString() ??
        '';
    final details = business['details']?.toString() ?? 'Event venue';
    final price =
        business['eventFee']?.toString() ??
        business['event_fee']?.toString() ??
        business['pricePerHour']?.toString() ??
        business['price_per_hour']?.toString() ??
        '0';
    final tags = _savedTags(business['tags']);
    final images = _savedImages(business, item['imageUrl'] as String?, 'event');
    final unavailable = _isUnavailable(item);

    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 235,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => _showSavedGallery(images, 'event'),
                  child: PageView.builder(
                    itemCount: images.length > 1 ? 10000 : 1,
                    itemBuilder: (_, index) => Image(
                      image: _savedImageProvider(
                        images[index % images.length],
                        'event',
                      ),
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stackTrace) => Image.asset(
                        _imageForType('event'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    onPressed: () => _removeSaved(context, 'event', key),
                    style: IconButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.favorite_rounded),
                  ),
                ),
                if (images.length > 1)
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
                          '${images.length} photos',
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
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                _detailLine(Icons.location_on_outlined, address),
                _detailLine(Icons.category_outlined, 'Category: $category'),
                _detailLine(Icons.business_outlined, 'Facility: $facility'),
                _detailLine(Icons.access_time, 'Hours: $hours'),
                if (availability.isNotEmpty)
                  _detailLine(
                    Icons.check_circle_outline,
                    'Availability: $availability',
                  ),
                for (final line in _savedDetailLines(details))
                  _detailLine(Icons.info_outline, line),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFBFD),
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Event package',
                          style: TextStyle(color: _muted, fontSize: 11),
                        ),
                      ),
                      Text(
                        'PHP $price / event',
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unavailable) _unavailableNotice(),
                const SizedBox(height: 6),
                if (tags.isNotEmpty)
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [for (final tag in tags) _tag(tag)],
                  ),
                const SizedBox(height: 8),
                Text(
                  'Saved Events • ${key == title ? 'Saved card' : key}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openVisit(
                          context,
                          '${business['visitUrl'] ?? business['visit_url'] ?? ''}',
                          title,
                        ),
                        icon: const Icon(Icons.language, size: 15),
                        label: const Text('Visit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _navy,
                          side: const BorderSide(color: _navy),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: unavailable
                          ? OutlinedButton.icon(
                              onPressed: () =>
                                  _contactOwner(context, item, title),
                              icon: const Icon(
                                Icons.contact_mail_outlined,
                                size: 15,
                              ),
                              label: const Text('Contact owner'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _navy,
                                side: const BorderSide(color: _navy),
                                minimumSize: const Size(0, 36),
                              ),
                            )
                          : FilledButton.icon(
                              onPressed: () =>
                                  _message(context, 'Booking $title is ready.'),
                              icon: const Icon(Icons.calendar_month, size: 15),
                              label: const Text('Book now'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _orange,
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
  }

  Widget _savedSportsCard(BuildContext context, Map<String, dynamic> item) {
    final title = item['title'] as String? ?? 'Saved sports venue';
    final key = item['itemKey'] as String? ?? title;
    final savedDetails = item['subtitle'] as String? ?? '';
    final savedType = RegExp(
      r'^Sport:\s*(.*)$',
      multiLine: true,
    ).firstMatch(savedDetails)?.group(1)?.trim();
    final business = item['business'] is Map
        ? Map<String, dynamic>.from(item['business'] as Map)
        : const <String, dynamic>{};
    final address =
        business['address']?.toString() ?? savedDetails.split('\n').last.trim();
    final sport = business['category']?.toString() ?? savedType ?? 'Sports';
    final facility =
        business['facilityType']?.toString() ??
        business['facility_type']?.toString() ??
        'Facility';
    final details = business['details']?.toString() ?? 'Sports facility';
    final hours =
        business['hours']?.toString() ??
        business['opening_hours']?.toString() ??
        'Open hours';
    final availability = business['availability']?.toString() ?? '';
    final price =
        business['pricePerHour']?.toString() ??
        business['price_per_hour']?.toString() ??
        '0';
    final pricePeriods = _savedPricePeriods(business);
    final tags = _savedTags(business['tags']);
    final images = _savedImages(
      business,
      item['imageUrl'] as String?,
      'sports',
    );
    final unavailable = _isUnavailable(item);

    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 235,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => _showSavedGallery(images, 'sports'),
                  child: PageView.builder(
                    itemCount: images.length > 1 ? 10000 : 1,
                    itemBuilder: (_, index) => Image(
                      image: _savedImageProvider(
                        images[index % images.length],
                        'sports',
                      ),
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stackTrace) => Image.asset(
                        'assets/court/pickle-court.jpg',
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
                        onPressed: () => _removeSaved(context, 'sports', key),
                        style: IconButton.styleFrom(
                          backgroundColor: _orange,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.favorite_rounded),
                      ),
                    ],
                  ),
                ),
                if (images.length > 1)
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
                          '${images.length} photos',
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
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                _detailLine(Icons.location_on_outlined, address),
                _detailLine(Icons.sports_rounded, 'Sport: $sport'),
                _detailLine(Icons.business_center_outlined, 'Type: $facility'),
                _detailLine(Icons.grid_3x3, 'Courts: $details'),
                _detailLine(Icons.access_time, 'Hours: $hours'),
                if (availability.isNotEmpty)
                  _detailLine(
                    Icons.check_circle_outline,
                    'Availability: $availability',
                  ),
                const SizedBox(height: 6),
                _savedPriceBox(price, pricePeriods),
                if (unavailable) _unavailableNotice(),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [for (final tag in tags) _tag(tag)],
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openVisit(
                          context,
                          '${business['visitUrl'] ?? business['visit_url'] ?? ''}',
                          title,
                        ),
                        icon: const Icon(Icons.language, size: 15),
                        label: const Text('Visit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _navy,
                          side: const BorderSide(color: _navy),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: unavailable
                          ? OutlinedButton.icon(
                              onPressed: () =>
                                  _contactOwner(context, item, title),
                              icon: const Icon(
                                Icons.contact_mail_outlined,
                                size: 15,
                              ),
                              label: const Text('Contact owner'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _navy,
                                side: const BorderSide(color: _navy),
                                minimumSize: const Size(0, 36),
                              ),
                            )
                          : FilledButton.icon(
                              onPressed: () =>
                                  _message(context, 'Booking $title is ready.'),
                              icon: const Icon(Icons.calendar_month, size: 15),
                              label: const Text('Book now'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _orange,
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
  }

  Widget _savedPriceBox(String price, List<String> periods) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xFFFAFBFD),
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🏷 Price',
          style: TextStyle(
            color: _ink,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (periods.isEmpty)
          _savedPriceLine(
            'Booking rate',
            'PHP ${double.tryParse(price)?.toStringAsFixed(0) ?? price} / hr',
          )
        else
          for (final period in periods)
            _savedPriceLine(
              period.split('|').first,
              period.contains('|') ? period.split('|').skip(1).join('|') : '',
            ),
      ],
    ),
  );

  Widget _savedPriceLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _ink,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  List<String> _savedTags(dynamic rawTags) {
    if (rawTags is List) {
      return rawTags
          .whereType<String>()
          .where((tag) => tag.isNotEmpty)
          .toList();
    }
    if (rawTags is String && rawTags.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTags);
        if (decoded is List) {
          return decoded
              .whereType<String>()
              .where((tag) => tag.isNotEmpty)
              .toList();
        }
      } on FormatException {
        return <String>[];
      }
    }

    return <String>[];
  }

  List<String> _savedPricePeriods(Map<String, dynamic> business) {
    final raw = business['ratePeriods'] ?? business['rate_periods'];
    if (raw is! List) return <String>[];
    return raw.whereType<Map>().map((period) {
      final start = period['start'] ?? period['start_time'] ?? '';
      final end = period['end'] ?? period['end_time'] ?? '';
      final amount = period['pricePerHour'] ?? period['price_per_hour'];
      final parsed = double.tryParse('$amount');
      return '$start - $end|PHP ${parsed?.toStringAsFixed(0) ?? amount} / hr';
    }).toList();
  }

  List<String> _savedImages(
    Map<String, dynamic> business,
    String? savedImage,
    String type,
  ) {
    final images = <String>[];
    final raw = business['imageUrls'] ?? business['image_urls'];
    if (raw is List) {
      images.addAll(raw.whereType<String>().where((image) => image.isNotEmpty));
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          images.addAll(
            decoded.whereType<String>().where((image) => image.isNotEmpty),
          );
        }
      } on FormatException {
        images.add(raw);
      }
    }
    final legacy = business['imageUrl']?.toString();
    if (images.isEmpty && legacy != null && legacy.isNotEmpty) {
      try {
        final decoded = jsonDecode(legacy);
        if (decoded is List) {
          images.addAll(
            decoded.whereType<String>().where((image) => image.isNotEmpty),
          );
        }
      } on FormatException {
        images.add(legacy);
      }
      if (images.isEmpty) images.add(legacy);
    }
    if (images.isEmpty && savedImage != null && savedImage.isNotEmpty) {
      images.add(savedImage);
    }
    if (images.isEmpty) images.add(_imageForType(type));
    return images;
  }

  Future<void> _showSavedGallery(List<String> images, String type) async {
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
                      image: _savedImageProvider(
                        images[page % images.length],
                        type,
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

  Widget _detailLine(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _muted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  List<String> _savedDetailLines(String details) => details
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('Event types:'))
      .toList();

  Widget _tag(String text) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1E4),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Text(text, style: const TextStyle(color: _ink, fontSize: 11)),
    ),
  );

  void _message(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _contactOwner(
    BuildContext context,
    Map<String, dynamic> item,
    String title,
  ) async {
    final key = item['itemKey'] as String? ?? title;
    try {
      final session = await AppSession.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Your session has expired.', 401);
      }
      final response = await AuthApi().messageOwner(
        token: token,
        businessKey: key,
      );
      final owner = response['owner'] as Map<String, dynamic>?;
      if (!context.mounted || owner == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MessagesDashboardPage(
            owner: owner,
            businessTitle: title,
          ),
        ),
      );
    } on Exception catch (error) {
      if (context.mounted) _message(context, 'Could not contact owner: $error');
    }
  }

  Future<void> _openVisit(
    BuildContext context,
    String rawUrl,
    String name,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      _message(context, '$name does not have a visit link yet.');
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not open the visit link for $name.')),
      );
    }
  }

  bool _isUnavailable(Map<String, dynamic> item) {
    final business = item['business'];
    if (business is! Map) return true;
    final enabled = business['enabled'];
    return enabled == false ||
        enabled == 0 ||
        enabled == '0' ||
        enabled == 'false' ||
        enabled == 'FALSE';
  }

  Widget _unavailableNotice() => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1E4),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: _orange.withValues(alpha: .35)),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, size: 18, color: _orange),
        const SizedBox(width: 7),
        const Expanded(
          child: Text(
            'This venue is currently unavailable. Booking is disabled.',
            style: TextStyle(color: _ink, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  String _savedItemId(String? type, String? key) => '${type ?? ''}:$key';

  String get _emptyStateText => widget.itemType == null
      ? 'You have no saved places yet.'
      : 'You have no saved ${_typeLabel(widget.itemType!)} yet.';

  Widget _typeBadge(String type, String? specificType) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForType(type), size: 15, color: _navy),
          const SizedBox(width: 5),
          Text(
            specificType ?? _typeLabel(type),
            style: const TextStyle(
              color: _navy,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );

  (String?, String) _parseSavedDetails(String value) {
    final lines = value.split('\n');
    if (lines.length < 2) return (null, value);
    final firstLine = lines.first.trim();
    final separator = firstLine.indexOf(':');
    if (separator < 0) return (null, value);
    final label = firstLine.substring(0, separator).trim().toLowerCase();
    final isSpecificType =
        label == 'sport' || label == 'class' || label == 'venue';
    if (!isSpecificType) return (null, value);
    return (
      firstLine.substring(separator + 1).trim(),
      lines.skip(1).join('\n').trim(),
    );
  }

  String _typeLabel(String type) => switch (type.toLowerCase()) {
    'fitness' => 'Fitness & Wellness',
    'sports' => 'Sports',
    'event' => 'Events',
    _ => type.isEmpty ? 'Saved place' : type,
  };

  IconData _iconForType(String type) => switch (type.toLowerCase()) {
    'fitness' => Icons.fitness_center_rounded,
    'sports' => Icons.sports_tennis_rounded,
    'event' => Icons.celebration_rounded,
    _ => Icons.place_rounded,
  };

  String _imageForType(String type) => switch (type.toLowerCase()) {
    'fitness' => 'assets/book-type/fitness.jpg',
    'sports' => 'assets/book-type/sports.jpg',
    'event' => 'assets/book-type/event.jpg',
    _ => 'assets/book-type/fitness.jpg',
  };

  ImageProvider _savedImageProvider(String? imageUrl, String type) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return AssetImage(_imageForType(type));
    }
    if (imageUrl.startsWith('data:image/')) {
      final comma = imageUrl.indexOf(',');
      if (comma >= 0) {
        try {
          final encoded = imageUrl
              .substring(comma + 1)
              .replaceAll(RegExp(r'\s'), '');
          if (encoded.isNotEmpty && encoded.length % 4 == 0) {
            return MemoryImage(base64Decode(encoded));
          }
        } on FormatException {
          // Fall back to the venue placeholder for malformed saved images.
        }
        return AssetImage(_imageForType(type));
      }
    }
    if (imageUrl.startsWith('http')) return NetworkImage(imageUrl);
    return AssetImage(imageUrl);
  }

  Future<void> _removeSaved(
    BuildContext context,
    String type,
    String key,
  ) async {
    final itemId = _savedItemId(type, key);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _optimisticallyRemoved.add(itemId));
    try {
      await SavedItemStore.remove(type, key);
    } on Exception catch (error) {
      setState(() => _optimisticallyRemoved.remove(itemId));
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not remove item: $error')),
      );
    }
  }

  Future<void> _openExplore(BuildContext context) async {
    final navigator = Navigator.of(context);
    final session = await AppSession.load();

    final page = switch (session.lastBookingType) {
      'Sports' => SportsDashboardPage(onLogout: widget.onLogout),
      'Event' => EventDashboardPage(onLogout: widget.onLogout),
      'Fitness & Wellness' => FitnessDashboardPage(onLogout: widget.onLogout),
      _ => null,
    };

    if (page == null) {
      navigator.popUntil((route) => route.isFirst);
      return;
    }

    await navigator.pushReplacement(MaterialPageRoute(builder: (_) => page));
  }
}
