import 'package:flutter/material.dart';

class MerchantNewsCardsSection extends StatelessWidget {
  const MerchantNewsCardsSection({
    super.key,
    required this.businesses,
    required this.posts,
    required this.loading,
    required this.onComplete,
    required this.onEdit,
    required this.onDelete,
    required this.onPublish,
  });

  final List<Map<String, dynamic>> businesses;
  final List<Map<String, dynamic>> posts;
  final bool loading;
  final ValueChanged<Map<String, dynamic>> onComplete;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;
  final ValueChanged<Map<String, dynamic>> onPublish;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final postsByBusiness = <int, Map<String, dynamic>>{};
    for (final post in posts) {
      final businessId = _postBusinessId(post);
      if (businessId != null) {
        final existing = postsByBusiness[businessId];
        final published = '${post['status'] ?? ''}'.toLowerCase() == 'published';
        final existingPublished =
            '${existing?['status'] ?? ''}'.toLowerCase() == 'published';
        if (existing == null || (published && !existingPublished)) {
          postsByBusiness[businessId] = post;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (businesses.isEmpty)
          const Text(
            'Add a business first to create its News Card.',
            style: TextStyle(color: Color(0xFF68748A)),
          )
        else
          for (final business in businesses) ...[
            if (!_isCompletePost(postsByBusiness[_businessId(business)], business))
              _incompleteCard(business),
            if (_isCompletePost(
              postsByBusiness[_businessId(business)],
              business,
            ))
              _newsCard(postsByBusiness[_businessId(business)]!, business),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _incompleteCard(Map<String, dynamic> business) {
    final type = _businessType(business);
    return Card(
      color: const Color(0xFFFFF8F0),
      child: ListTile(
        leading: const Icon(Icons.edit_note_rounded, color: Color(0xFFFF8200)),
        title: Text('${business['name'] ?? 'Business'}'),
        subtitle: Text(
          '${_businessLabel(type, business['category'])}\n'
          'News Card incomplete — add a short venue update.',
        ),
        isThreeLine: true,
        trailing: FilledButton(
          onPressed: () => onComplete(business),
          child: const Text('Complete'),
        ),
      ),
    );
  }

  Widget _newsCard(Map<String, dynamic> post, Map<String, dynamic> business) {
    final published = '${post['status'] ?? 'draft'}'.toLowerCase() == 'published';
    final type = _businessType(business);
    return Card(
      child: ListTile(
        leading: Icon(
          published ? Icons.check_circle_rounded : Icons.pending_outlined,
          color: published ? const Color(0xFF15803D) : const Color(0xFFFF8200),
        ),
        title: Text('${post['title'] ?? 'News post'}'),
        subtitle: Text(
          '${_businessLabel(type, business['category'])}\n'
          '${published
              ? 'PUBLISHED · BOOKING CARD AVAILABLE'
              : 'DRAFT · Publish to show this Booking Card'}\n'
          '${post['body'] ?? ''}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!published)
              FilledButton(
                onPressed: () => onPublish(post),
                child: const Text('Publish'),
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit(post);
                if (value == 'delete') onDelete(post);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _businessType(Map<String, dynamic> business) =>
      '${business['businessType'] ?? business['business_type'] ?? 'Business'}';

  String _businessLabel(String type, Object? category) {
    final categoryName = '${category ?? ''}'.trim();
    return categoryName.isEmpty ? type : '$type · $categoryName';
  }

  int? _businessId(Map<String, dynamic> value) {
    final id = value['id'] ?? value['businessId'];
    return _toInt(id);
  }

  int? _postBusinessId(Map<String, dynamic> post) {
    final id = post['businessId'] ?? post['business_id'];
    return _toInt(id);
  }

  bool _isCompletePost(
    Map<String, dynamic>? post,
    Map<String, dynamic> business,
  ) {
    if (post == null) return false;
    final imageUrl =
        post['imageUrl'] ??
        post['image_url'] ??
        post['businessImageUrl'] ??
        business['imageUrl'] ??
        business['image_url'];
    return '${post['title'] ?? ''}'.trim().isNotEmpty &&
        '${post['body'] ?? ''}'.trim().isNotEmpty &&
        '$imageUrl'.trim().isNotEmpty &&
        '$imageUrl' != 'null';
  }

  int? _toInt(Object? id) {
    if (id is num) return id.toInt();
    if (id is String) return int.tryParse(id);
    return null;
  }
}
