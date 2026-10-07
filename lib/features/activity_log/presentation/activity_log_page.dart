import 'package:flutter/material.dart';

import 'package:myapp/auth_api.dart';
import 'package:myapp/app_design_system.dart';

import '../data/activity_log_repository.dart';
import '../domain/activity_log_entry.dart';
import 'activity_log_controller.dart';
import '../../../skeleton_loader.dart';
import 'widgets/activity_log_controls.dart';
import '../../../app_preferences.dart';

Color get _activityInk => AppColors.ink;
Color get _activityMuted => AppColors.muted;
Color get _activityOrange => AppColors.accent;
Color get _activityPage => AppColors.page;

class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({super.key, this.api, this.isMerchant = false});

  final AuthApi? api;
  final bool isMerchant;

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  late final ActivityLogController _controller;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = ActivityLogController(
      repository: ActivityLogRepository(api: widget.api ?? AuthApi()),
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Scaffold(
      backgroundColor: _activityPage,
      appBar: AppBar(
        toolbarHeight: widget.isMerchant ? 56 : null,
        titleSpacing: widget.isMerchant ? 16 : null,
        leadingWidth: widget.isMerchant ? 56 : null,
        titleTextStyle: AppTypography.pageTitle,
        backgroundColor: _activityPage,
        foregroundColor: _activityInk,
        title: const AppText('Activity log', localize: true),
        actions: [
          ActivityLogDateFilter(
            selectedDate: _controller.selectedDate,
            onSelected: _controller.selectDate,
            onClear: () => _controller.selectDate(null),
          ),
        ],
      ),
      body: _buildBody(),
    ),
  );

  Widget _buildBody() {
    if (_controller.state == ActivityLogLoadState.loading) {
      return ListView(
        key: const ValueKey('activity-log-loading-skeleton'),
        padding: const EdgeInsets.all(16),
        children: [
          const SkeletonBlock(height: 46, borderRadius: 14),
          const SizedBox(height: 6),
          for (var index = 0; index < 5; index++) ...[
            const Row(
              children: [
                SkeletonBlock(width: 42, height: 42, borderRadius: 21),
                SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBlock(width: 160, height: 15),
                      SizedBox(height: 6),
                      SkeletonBlock(height: 12),
                    ],
                  ),
                ),
              ],
            ),
            if (index < 4) const SizedBox(height: 6),
          ],
        ],
      );
    }
    if (_controller.state == ActivityLogLoadState.failed) {
      return ActivityLogMessage(
        icon: Icons.error_outline_rounded,
        message: _controller.userErrorMessage,
        supportRequestId: _controller.supportRequestId,
        actionLabel: 'Retry',
        onAction: _controller.load,
      );
    }
    final listItems = _controller.visibleGroups;
    return Column(
      children: [
        ActivityLogSearchField(
          controller: _searchController,
          isEmpty: _controller.isSearchEmpty,
          onChanged: _controller.search,
          onClear: () {
            _searchController.clear();
            _controller.search('');
          },
        ),
        Expanded(
          child: listItems.isEmpty
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: SizedBox(
                    height: 220,
                    child: ActivityLogMessage(
                      icon: Icons.history_rounded,
                      message: !_controller.hasActivities
                          ? 'Your account activity will appear here.'
                          : _controller.selectedDate != null
                          ? 'No activity found on ${_formatDate(_controller.selectedDate!)}.'
                          : 'No activity matches your search.',
                    ),
                  ),
                )
              : ListView.separated(
                  key: const ValueKey('activity-log-list'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(16),
                  itemCount: listItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final group = listItems[index];
                    return group.venueName == null
                        ? _ActivityTile(activity: group.activities.first)
                        : _VenueActivityTile(
                            key: ValueKey('activity-log-venue-${group.key}'),
                            venueName: group.venueName!,
                            sportType: group.sportType,
                            activities: group.activities,
                          );
                  },
                ),
        ),
      ],
    );
  }
}

Map<String, dynamic> _activityDetails(ActivityLogEntry activity) =>
    activity.details;

String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

String _formatExactDateTime(DateTime? value) {
  final date = value?.toLocal();
  if (date == null) return 'Time unavailable';
  return '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)} '
      '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}:${_twoDigits(date.second)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

class _VenueActivityTile extends StatelessWidget {
  const _VenueActivityTile({
    super.key,
    required this.venueName,
    required this.activities,
    this.sportType,
  });

  final String venueName;
  final String? sportType;
  final List<ActivityLogEntry> activities;

  @override
  Widget build(BuildContext context) {
    final mostRecent = activities.first.createdAt;
    return Card(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        key: const ValueKey('activity-log-venue-tile'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.softOrangeAlt,
          foregroundColor: _activityOrange,
          child: Icon(Icons.location_on_outlined),
        ),
        title: AppText(
          venueName,
          style: TextStyle(color: _activityInk, fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sportType != null && sportType!.isNotEmpty)
                AppText(sportType!, style: TextStyle(color: _activityMuted)),
              AppText(
                '${activities.length} ${activities.length == 1 ? 'activity' : 'activities'} · '
                'Last: ${_formatExactDateTime(mostRecent)}',
                style: TextStyle(color: _activityMuted, fontSize: 12),
                localize: true,
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _showVenueTimeline(context),
      ),
    );
  }

  Future<void> _showVenueTimeline(
    BuildContext context,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          venueName,
                          style: TextStyle(
                            color: _activityInk,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (sportType != null && sportType!.isNotEmpty)
                          AppText(
                            sportType!,
                            style: TextStyle(color: _activityMuted),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: appLanguageText(
                      'Close venue activity',
                      'Close venue activity',
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                itemCount: activities.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  final details = _activityDetails(activity);
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _activityPage,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          activity.title ?? 'Venue activity',
                          style: TextStyle(
                            color: _activityInk,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppText(
                          _formatExactDateTime(activity.createdAt),
                          style: TextStyle(color: _activityMuted, fontSize: 12),
                        ),
                        if (_auditContextLabel(activity).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          AppText(
                            _auditContextLabel(activity),
                            style: TextStyle(
                              color: _activityMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                        if (details['bookingDate'] != null ||
                            details['startTime'] != null) ...[
                          const SizedBox(height: 6),
                          AppText(
                            'Booking: ${details['bookingDate'] ?? 'Date unavailable'}'
                            '${details['startTime'] == null ? '' : ' at ${details['startTime']}'}',
                            style: TextStyle(color: _activityMuted),
                            localize: true,
                          ),
                        ],
                        if (details['durationHours'] != null)
                          AppText(
                            'Duration: ${details['durationHours']} hours',
                            style: TextStyle(color: _activityMuted),
                            localize: true,
                          ),
                        if (details['players'] != null)
                          AppText(
                            'Players: ${details['players']}',
                            style: TextStyle(color: _activityMuted),
                            localize: true,
                          ),
                        if (details.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: AppText(
                              activity.description ?? '',
                              style: TextStyle(color: _activityMuted),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity});

  final ActivityLogEntry activity;

  @override
  Widget build(BuildContext context) {
    final createdAt = activity.createdAt;
    final dateLabel = createdAt == null
        ? ''
        : '${_twoDigits(createdAt.toLocal().month)}/${_twoDigits(createdAt.toLocal().day)}/${createdAt.toLocal().year} · '
              '${_twoDigits(createdAt.toLocal().hour)}:${_twoDigits(createdAt.toLocal().minute)}';

    return Card(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.softOrangeAlt,
          foregroundColor: _activityOrange,
          child: Icon(_activityIcon(activity.activityType ?? '')),
        ),
        title: AppText(
          activity.title ?? 'Account activity',
          style: TextStyle(color: _activityInk, fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                activity.description ?? '',
                style: TextStyle(color: _activityMuted),
              ),
              if (dateLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                AppText(
                  dateLabel,
                  style: TextStyle(color: _activityMuted, fontSize: 11),
                ),
              ],
              if (_auditContextLabel(activity).isNotEmpty) ...[
                const SizedBox(height: 6),
                AppText(
                  _auditContextLabel(activity),
                  style: TextStyle(color: _activityMuted, fontSize: 10),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _activityIcon(String type) => switch (type) {
    'login' => Icons.login_rounded,
    'login_failed' || 'login_blocked' => Icons.gpp_bad_outlined,
    'profile_updated' => Icons.person_outline_rounded,
    'merchant_profile_updated' => Icons.storefront_outlined,
    'business_created' || 'business_updated' => Icons.business_outlined,
    'business_deleted' => Icons.business_center_outlined,
    'business_enabled' || 'business_disabled' => Icons.toggle_on_outlined,
    'news_post_created' ||
    'news_post_updated' ||
    'news_post_deleted' => Icons.article_outlined,
    'item_saved' => Icons.bookmark_add_outlined,
    'item_removed' => Icons.bookmark_remove_outlined,
    'booking_requested' => Icons.event_available_outlined,
    'booking_approved' || 'booking_finished' => Icons.check_circle_outline,
    'review_submitted' => Icons.star_outline_rounded,
    'message_sent' => Icons.chat_bubble_outline_rounded,
    'account_registration' => Icons.person_add_alt_rounded,
    'email_verified' => Icons.mark_email_read_outlined,
    'password_changed' => Icons.password_rounded,
    'venue_hearted' => Icons.favorite_rounded,
    'venue_unhearted' => Icons.heart_broken_rounded,
    _ => Icons.history_rounded,
  };
}

String _auditContextLabel(ActivityLogEntry activity) {
  final role = activity.actorRole?.trim() ?? '';
  final requestId = activity.requestId?.trim() ?? '';
  return [
    if (role.isNotEmpty) 'Performed by $role',
    if (requestId.isNotEmpty) 'Request ID: $requestId',
  ].join(' · ');
}
