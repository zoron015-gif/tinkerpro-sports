import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'auth_api.dart';
import 'core/business_type.dart';
import 'news_feed.dart';

class SavedDashboardPage extends StatelessWidget {
  const SavedDashboardPage({
    super.key,
    this.onLogout,
    this.itemType,
    this.initialUserPosition,
    this.api,
  });

  final Future<void> Function(BuildContext context)? onLogout;
  final String? itemType;
  final Position? initialUserPosition;
  final AuthApi? api;

  static String itemTypeForBusinessType(Object? businessType) =>
      switch (BusinessTypeParser.parse(businessType)) {
        BusinessType.fitness => 'fitness',
        BusinessType.event => 'event',
        _ => 'sports',
      };

  @override
  Widget build(BuildContext context) {
    final resolvedItemType = (itemType ?? 'sports').trim().toLowerCase();
    final isFitness = resolvedItemType == 'fitness';
    final isEvent = resolvedItemType == 'event';
    final businessType = isFitness
        ? 'Fitness'
        : isEvent
        ? 'Event'
        : 'Sports';
    final categoryNoun = isFitness
        ? 'fitness types'
        : isEvent
        ? 'event types'
        : 'sports';
    final venueNoun = isFitness
        ? 'venues'
        : isEvent
        ? 'event venues'
        : 'courts';

    return NewsFeedPage(
      onLogout: onLogout,
      api: api,
      savedOnly: true,
      initialUserPosition: initialUserPosition,
      businessType: businessType,
      pageTitle: isFitness
          ? 'Fitness & Wellness'
          : isEvent
          ? 'Event Venues'
          : 'Sports Courts',
      savedItemType: resolvedItemType,
      categoryNoun: categoryNoun,
      venueNoun: venueNoun,
      searchHint: isFitness
          ? 'Search venues, fitness types, or areas...'
          : isEvent
          ? 'Search venues, event types, or areas...'
          : 'Search venues, categories, or news...',
      highestRatedSectionTitle: 'Highest rated',
      allVenuesHeading: isFitness
          ? 'All venues'
          : isEvent
          ? 'All listed event venues'
          : 'All listed courts',
      categoryFilterLabel: isFitness
          ? 'Fitness type'
          : isEvent
          ? 'Event type'
          : 'Sport type',
      facilityFilterLabel: isFitness
          ? 'Facility type'
          : isEvent
          ? 'Venue type'
          : 'Court type',
    );
  }
}
