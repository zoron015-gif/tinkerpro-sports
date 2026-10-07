import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'auth_api.dart';
import 'news_feed.dart';

class EventDashboardPage extends StatelessWidget {
  const EventDashboardPage({
    super.key,
    this.onLogout,
    this.api,
    this.initialUserPosition,
  });

  final Future<void> Function(BuildContext context)? onLogout;
  final AuthApi? api;
  final Position? initialUserPosition;

  @override
  Widget build(BuildContext context) => NewsFeedPage(
    api: api,
    onLogout: onLogout,
    initialUserPosition: initialUserPosition,
    businessType: 'Event',
    pageTitle: 'Event Venues',
    savedItemType: 'event',
    categoryNoun: 'event types',
    venueNoun: 'event venues',
    searchHint: 'Search venues, event types, or areas...',
    highestRatedSectionTitle: 'Highest rated',
    allVenuesHeading: 'All listed event venues',
    categoryFilterLabel: 'Event type',
    facilityFilterLabel: 'Venue type',
  );
}
