import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'auth_api.dart';
import 'news_feed.dart';

class FitnessDashboardPage extends StatelessWidget {
  const FitnessDashboardPage({
    super.key,
    this.onLogout,
    this.api,
    this.initialUserPosition,
    this.savedOnly = false,
  });

  final Future<void> Function(BuildContext context)? onLogout;
  final AuthApi? api;
  final Position? initialUserPosition;
  final bool savedOnly;

  @override
  Widget build(BuildContext context) => NewsFeedPage(
    onLogout: onLogout,
    api: api,
    initialUserPosition: initialUserPosition,
    savedOnly: savedOnly,
    businessType: 'Fitness',
    pageTitle: 'Fitness & Wellness',
    savedItemType: 'fitness',
    categoryNoun: 'fitness types',
    venueNoun: 'venues',
    searchHint: 'Search venues, fitness types, or areas...',
    highestRatedSectionTitle: 'Highest rated',
    allVenuesHeading: 'All venues',
    categoryFilterLabel: 'Fitness type',
    facilityFilterLabel: 'Facility type',
  );
}
