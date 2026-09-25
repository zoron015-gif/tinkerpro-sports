import 'package:flutter/material.dart';

import 'news_feed.dart';

class SavedDashboardPage extends StatelessWidget {
  const SavedDashboardPage({super.key, this.onLogout, this.itemType});

  final Future<void> Function(BuildContext context)? onLogout;
  final String? itemType;

  @override
  Widget build(BuildContext context) =>
      NewsFeedPage(onLogout: onLogout, savedOnly: true);
}
