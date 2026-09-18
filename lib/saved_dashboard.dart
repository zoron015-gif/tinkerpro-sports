import 'package:flutter/material.dart';

import 'app_session.dart';
import 'event_dashboard.dart';
import 'fitness_dashboard.dart';
import 'profile_dashboard.dart';
import 'saved_items.dart';
import 'sports.dart';

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

  @override
  void initState() {
    super.initState();
    _items = SavedItemStore.list();
  }

  Future<void> _refreshItems() async {
    setState(() => _items = SavedItemStore.list());
    await _items;
    if (mounted) setState(_optimisticallyRemoved.clear);
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
          final items = (snapshot.data ?? [])
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
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshItems,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 220),
                  Center(child: Text(_emptyStateText)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refreshItems,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return _savedCard(context, item);
              },
            ),
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFFE8D2),
        onDestinationSelected: (index) {
          if (index == 1) return;
          if (index == 0) {
            _openExplore(context);
            return;
          }
          if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileDashboardPage(onLogout: widget.onLogout),
              ),
            );
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking history will appear here.')),
          );
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

  Widget _savedCard(BuildContext context, Map<String, dynamic> item) {
    final type = item['itemType'] as String? ?? '';
    final title = item['title'] as String? ?? 'Untitled saved place';
    final savedDetails = item['subtitle'] as String? ?? 'No location provided';
    final details = _parseSavedDetails(savedDetails);
    final subtitle = details.$2;
    final key = item['itemKey'] as String? ?? title;

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
                Image.asset(_imageForType(type), fit: BoxFit.cover),
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
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, height: 1.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Saved ${_typeLabel(type)} • ${key == title ? 'Saved card' : key}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openType(context, type),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Explore'),
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

  Future<void> _removeSaved(
    BuildContext context,
    String type,
    String key,
  ) async {
    final itemId = _savedItemId(type, key);
    setState(() => _optimisticallyRemoved.add(itemId));
    try {
      await SavedItemStore.remove(type, key);
    } on Exception catch (error) {
      if (!context.mounted) return;
      setState(() => _optimisticallyRemoved.remove(itemId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not remove item: $error')));
    }
  }

  Future<void> _openType(BuildContext context, String type) async {
    final page = switch (type.toLowerCase()) {
      'sports' => SportsDashboardPage(onLogout: widget.onLogout),
      'event' => EventDashboardPage(onLogout: widget.onLogout),
      'fitness' => FitnessDashboardPage(onLogout: widget.onLogout),
      _ => null,
    };
    if (page == null || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _openExplore(BuildContext context) async {
    final session = await AppSession.load();
    if (!context.mounted) return;

    final page = switch (session.lastBookingType) {
      'Sports' => SportsDashboardPage(onLogout: widget.onLogout),
      'Event' => EventDashboardPage(onLogout: widget.onLogout),
      'Fitness & Wellness' => FitnessDashboardPage(onLogout: widget.onLogout),
      _ => null,
    };

    if (page == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    await Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => page));
  }
}
