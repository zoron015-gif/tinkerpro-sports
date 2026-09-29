import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'news_feed.dart';

class SavedDashboardPage extends StatelessWidget {
  const SavedDashboardPage({
    super.key,
    this.onLogout,
    this.itemType,
    this.initialUserPosition,
  });

  final Future<void> Function(BuildContext context)? onLogout;
  final String? itemType;
  final Position? initialUserPosition;

  @override
  Widget build(BuildContext context) => NewsFeedPage(
    onLogout: onLogout,
    savedOnly: true,
    initialUserPosition: initialUserPosition,
  );
}
