// The booking-type picker remains in this file for the customer reservation flow.
// ignore_for_file: unused_element

import 'package:flutter/material.dart';

import 'event_dashboard.dart';
import 'fitness_dashboard.dart';
import 'app_session.dart';
import 'news_feed.dart';
import 'app_design_system.dart';

import 'dart:async';

const _background = AppColors.page;
const _navy = AppColors.navy;
const _surface = Colors.white;
const _surfaceLight = AppColors.softSurface;
const _text = AppColors.ink;
const _muted = AppColors.muted;
const _mint = AppColors.orange;
const _gold = Color(0xFFFFA63D);
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
          content: Text('$_selected dashboard is not available yet.'),
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
                  const Center(
                    child: Text(
                      'Choose your booking type',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _text,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Explore live availability and find the right experience.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
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
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          decoration: BoxDecoration(
            color: _surface,
            border: const Border(top: BorderSide(color: Color(0xFFE5EAF1))),
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
              const Row(
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
                    color: _navy,
                    detail: 'Easy rescheduling',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _continue,
                  style: FilledButton.styleFrom(
                    backgroundColor: _mint,
                    foregroundColor: Colors.white,
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
                        child: Text(
                          'Continue to $_selected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Instant confirmation · No upfront payment required',
                style: TextStyle(
                  color: Color(0xFF237C63),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
    return const Text(
      'Reserve experience',
      textAlign: TextAlign.center,
      style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w900),
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
    return Semantics(
      button: true,
      selected: selected,
      label: '$title booking option',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_reserveCardRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: textScale > 1.2 ? 176 : 160,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_reserveCardRadius),
            border: Border.all(
              color: selected ? accent : Colors.white.withValues(alpha: .16),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: .16),
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
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0x00000000),
                                Color(0x1F000000),
                                Color(0x00000000),
                              ],
                              stops: [0, .55, 1],
                            ),
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
                            child: _Badge(text: badge, color: accent),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            selected ? Icons.check_circle_rounded : icon,
                            color: accent,
                            size: 22,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(
                          color: _text,
                          fontSize: title.length > 10 ? 17 : 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
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
        color: _surface.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
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
      child: Text(
        label,
        style: const TextStyle(
          color: _navy,
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
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _text,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 9, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
