import 'package:flutter/material.dart';

import 'app_session.dart';
import 'event_dashboard.dart';
import 'fitness_dashboard.dart';
import 'profile_dashboard.dart';
import 'saved_items.dart';
import 'sports.dart';

class SavedDashboardPage extends StatefulWidget {
  const SavedDashboardPage({super.key, this.onLogout});

  final Future<void> Function(BuildContext context)? onLogout;

  @override
  State<SavedDashboardPage> createState() => _SavedDashboardPageState();
}

class _SavedDashboardPageState extends State<SavedDashboardPage> {
  late Future<List<Map<String, dynamic>>> _items;

  @override
  void initState() {
    super.initState();
    _items = SavedItemStore.list();
  }

  void _reload() => setState(() => _items = SavedItemStore.list());

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
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('You have no saved places yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.favorite)),
                  title: Text(item['title'] as String? ?? ''),
                  subtitle: Text(item['subtitle'] as String? ?? ''),
                  trailing: IconButton(
                    tooltip: 'Remove saved item',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      try {
                        await SavedItemStore.remove(
                          item['itemType'] as String,
                          item['itemKey'] as String,
                        );
                        _reload();
                      } on Exception catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not remove item: $error')),
                        );
                      }
                    },
                  ),
                ),
              );
            },
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

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}
