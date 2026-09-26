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
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
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
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      color: Color(0xFF101B33),
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Browse every venue in this collection.',
                style: TextStyle(
                  color: _venuesMuted,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search venues, sports, or areas...',
                  hintStyle: const TextStyle(fontSize: 15),
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
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
                    style: TextStyle(color: _venuesMuted, fontSize: 16),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                  itemCount: _visiblePosts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 18),
                  itemBuilder: (_, index) =>
                      widget.cardBuilder(_visiblePosts[index]),
                ),
        ),
      ],
    ),
  );
}
