// The booking-type picker remains in this file for the customer reservation flow.
// ignore_for_file: unused_element

import 'package:flutter/material.dart';

import 'event_dashboard.dart';
import 'fitness_dashboard.dart';
import 'app_session.dart';
import 'news_feed.dart';
import 'app_design_system.dart';

import 'dart:async';

import 'app_preferences.dart';

Color get _background => AppColors.page;
Color get _surface => AppColors.surface;
Color get _surfaceLight => AppColors.softSurface;
Color get _text => AppColors.ink;
Color get _muted => AppColors.muted;
Color get _mint => AppColors.accentForeground;
Color get _gold => AppColors.accentForeground;
const _reserveCardRadius = 17.0;

class ReserveDashboardPage extends StatefulWidget {
  const ReserveDashboardPage({super.key, this.initialSelection, this.onLogout});

  final String? initialSelection;
  final Future<void> Function(BuildContext context)? onLogout;

  @override
  State<ReserveDashboardPage> createState() => _ReserveDashboardPageState();
}

class _ReserveDashboardPageState extends State<ReserveDashboardPage> {
  String _selected = 'Fitness & Wellness';

  @override
  void initState() {
    super.initState();
    const choices = {'Sports', 'Event', 'Fitness & Wellness'};
    if (choices.contains(widget.initialSelection)) {
      _selected = widget.initialSelection!;
    }
  }

  void _continue() {
    unawaited(
      AppSession.load().then((session) {
        return session.setLastBookingType(_selected);
      }),
    );
    if (_selected == 'Sports') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NewsFeedPage(onLogout: widget.onLogout),
        ),
      );
      return;
    }
    if (_selected == 'Event') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventDashboardPage(onLogout: widget.onLogout),
        ),
      );
      return;
    }
    if (_selected == 'Fitness & Wellness') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FitnessDashboardPage(onLogout: widget.onLogout),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: AppText(
            '$_selected dashboard is not available yet.',
            localize: true,
          ),
          backgroundColor: _surfaceLight,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: RefreshIndicator(
        onRefresh: () async {},
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              centerTitle: true,
              title: const _ReserveHeader(),
              backgroundColor: _background,
              foregroundColor: _text,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Center(
                    child: AppText(
                      'Choose your booking type',
                      textAlign: TextAlign.center,
                      style: AppTypography.sectionTitle.copyWith(
                        color: _text,
                        height: 1.25,
                      ),
                      localize: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: AppText(
                      'Explore live availability and find the right experience.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      localize: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ExperienceCard(
                    key: const ValueKey('reserve-option-sports'),
                    imagePath: 'assets/book-type/sports.jpg',
                    badge: '18 Courts Open',
                    title: 'Sports',
                    description: 'Courts, arenas, tournaments and more',
                    tags: const [
                      'Tennis',
                      'Padel',
                      'Basketball',
                      'Volleyball',
                      'Badminton',
                      'Pickleball',
                    ],
                    icon: Icons.sports_tennis_rounded,
                    accent: _mint,
                    selected: _selected == 'Sports',
                    onTap: () => setState(() => _selected = 'Sports'),
                  ),
                  const SizedBox(height: 6),
                  _ExperienceCard(
                    key: const ValueKey('reserve-option-event'),
                    imagePath: 'assets/book-type/event.jpg',
                    badge: 'VIP Banquets & Lounges',
                    title: 'Event',
                    description: 'Hotel venues, private dining and more',
                    tags: const ['Ballroom', 'Terrace', 'Private Dining'],
                    icon: Icons.auto_awesome_rounded,
                    accent: _gold,
                    selected: _selected == 'Event',
                    onTap: () => setState(() => _selected = 'Event'),
                  ),
                  const SizedBox(height: 6),
                  _ExperienceCard(
                    key: const ValueKey('reserve-option-fitness'),
                    imagePath: 'assets/book-type/fitness.jpg',
                    badge: 'Fitness Classes Open',
                    title: 'Fitness & Wellness',
                    description:
                        'Gyms, martial arts, yoga and personal training',
                    tags: const ['CrossFit', 'Pilates', 'Zumba', 'Boxing'],
                    icon: Icons.fitness_center_rounded,
                    accent: _mint,
                    selected: _selected == 'Fitness & Wellness',
                    onTap: () =>
                        setState(() => _selected = 'Fitness & Wellness'),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          key: const ValueKey('reserve-footer'),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          decoration: BoxDecoration(
            color: _surface,
            border: Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .08),
                blurRadius: 14,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _Benefit(
                    icon: Icons.verified_rounded,
                    label: 'Guaranteed slot',
                    color: _mint,
                    detail: '100% reserved',
                  ),
                  _Benefit(
                    icon: Icons.room_service_rounded,
                    label: 'VIP concierge',
                    color: _gold,
                    detail: 'Personal host',
                  ),
                  _Benefit(
                    icon: Icons.schedule_rounded,
                    label: 'Flexible changes',
                    color: _text,
                    detail: 'Easy rescheduling',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _continue,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: AppText(
                          'Continue to $_selected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          localize: true,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              AppText(
                'Instant confirmation · No upfront payment required',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                localize: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReserveHeader extends StatelessWidget {
  const _ReserveHeader();

  @override
  Widget build(BuildContext context) {
    return AppText(
      'Reserve experience',
      textAlign: TextAlign.center,
      style: AppTypography.pageTitle.copyWith(color: _text),
      localize: true,
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({
    required this.imagePath,
    required this.badge,
    required this.title,
    required this.description,
    required this.tags,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String imagePath;
  final String badge;
  final String title;
  final String description;
  final List<String> tags;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final accentForeground = AppColors.accentForeground;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title booking option',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_reserveCardRadius),
        child: AnimatedContainer(
          key: ValueKey('reserve-option-surface-$title'),
          duration: const Duration(milliseconds: 180),
          height: textScale > 1.2 ? 178 : 162,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(_reserveCardRadius),
            border: Border.all(
              color: selected ? accentForeground : AppColors.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accentForeground.withValues(alpha: .16),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 112,
                height: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: Image.asset(imagePath, fit: BoxFit.cover),
                      ),
                    ),
                    const Positioned(
                      top: 10,
                      right: 5,
                      bottom: 10,
                      width: 18,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppGradients.horizontalEdgeShade,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _Badge(
                              text: badge,
                              color: accentForeground,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            selected ? Icons.check_circle_rounded : icon,
                            color: accentForeground,
                            size: 22,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      AppText(
                        title,
                        style: TextStyle(
                          color: _text,
                          fontSize: title.length > 10 ? 17 : 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppText(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var index = 0; index < tags.length; index++)
                              Padding(
                                padding: EdgeInsets.only(
                                  right: index == tags.length - 1 ? 0 : 6,
                                ),
                                child: _OptionChip(label: tags[index]),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: AppText(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: .1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: AppText(
        label,
        style: TextStyle(
          color: _text,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.label,
    required this.color,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            AppText(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _text,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 6),
            AppText(
              detail,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _muted, fontSize: 9, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
