import 'package:flutter/material.dart';

class MerchantNewsCardsSection extends StatelessWidget {
  const MerchantNewsCardsSection({
    super.key,
    required this.businesses,
    required this.posts,
    required this.loading,
    required this.onCreate,
    required this.onComplete,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> businesses;
  final List<Map<String, dynamic>> posts;
  final bool loading;
  final VoidCallback onCreate;
  final ValueChanged<Map<String, dynamic>> onComplete;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final postsByBusiness = <int, Map<String, dynamic>>{
      for (final post in posts)
        if (_postBusinessId(post) != null) _postBusinessId(post)!: post,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.post_add_rounded),
          label: const Text('Create news card'),
        ),
        const SizedBox(height: 12),
        if (businesses.isEmpty)
          const Text(
            'Add a business first to create its News Card.',
            style: TextStyle(color: Color(0xFF68748A)),
          )
        else
          for (final business in businesses) ...[
            if (postsByBusiness[_businessId(business)] == null)
              _incompleteCard(business),
            if (postsByBusiness[_businessId(business)] != null)
              _publishedCard(postsByBusiness[_businessId(business)]!),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _incompleteCard(Map<String, dynamic> business) => Card(
    color: const Color(0xFFFFF8F0),
    child: ListTile(
      leading: const Icon(Icons.edit_note_rounded, color: Color(0xFFFF8200)),
      title: Text('${business['name'] ?? 'Business'}'),
      subtitle: const Text('News Card incomplete — add a short venue update.'),
      trailing: FilledButton(
        onPressed: () => onComplete(business),
        child: const Text('Complete'),
      ),
    ),
  );

  Widget _publishedCard(Map<String, dynamic> post) => Card(
    child: ListTile(
      title: Text('${post['title'] ?? 'News post'}'),
      subtitle: Text(
        '${post['body'] ?? ''}\nView info is available on the Booking Card.',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') onEdit(post);
          if (value == 'delete') onDelete(post);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    ),
  );

  int? _businessId(Map<String, dynamic> value) {
    final id = value['id'] ?? value['businessId'];
    return _toInt(id);
  }

  int? _postBusinessId(Map<String, dynamic> post) {
    final id = post['businessId'] ?? post['business_id'];
    return _toInt(id);
  }

  int? _toInt(Object? id) {
    if (id is num) return id.toInt();
    if (id is String) return int.tryParse(id);
    return null;
  }
}
