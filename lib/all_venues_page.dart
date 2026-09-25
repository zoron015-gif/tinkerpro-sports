import 'package:flutter/material.dart';

const _venuesMuted = Color(0xFF68748A);

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visiblePosts {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.posts;
    return widget.posts.where((post) {
      final searchable = [
        post['businessName'],
        post['category'],
        post['address'],
        post['title'],
        post['body'],
      ].map((value) => '$value').join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
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
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title == 'Most popular'
                    ? 'Popular courts near you'
                    : 'Courts with the highest ratings',
                style: const TextStyle(
                  color: Color(0xFF101B33),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Browse every venue in this collection.',
                style: TextStyle(color: _venuesMuted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search venues, sports, or areas...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFFFF8200),
                  ),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFE2E7EF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFE2E7EF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFFF8200)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _visiblePosts.isEmpty
              ? const Center(
                  child: Text(
                    'No venues match your search.',
                    style: TextStyle(color: _venuesMuted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  itemCount: _visiblePosts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, index) =>
                      widget.cardBuilder(_visiblePosts[index]),
                ),
        ),
      ],
    ),
  );
}
