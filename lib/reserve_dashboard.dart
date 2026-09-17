import 'package:flutter/material.dart';

import 'event_dashboard.dart';
import 'fitness_dashboard.dart';
import 'sports.dart';

const _background = Color(0xFFF7F9FC);
const _navy = Color(0xFF192B50);
const _surface = Colors.white;
const _surfaceLight = Color(0xFFEFF2F7);
const _text = Color(0xFF101B33);
const _muted = Color(0xFF68748A);
const _mint = Color(0xFFFF8200);
const _gold = Color(0xFFFFA63D);

class ReserveDashboardPage extends StatefulWidget {
  const ReserveDashboardPage({super.key});

  @override
  State<ReserveDashboardPage> createState() => _ReserveDashboardPageState();
}

class _ReserveDashboardPageState extends State<ReserveDashboardPage> {
  String _selected = 'Fitness & Wellness';

  void _continue() {
    if (_selected == 'Sports') {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const SportsDashboardPage()));
      return;
    }
    if (_selected == 'Event') {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const EventDashboardPage()));
      return;
    }
    if (_selected == 'Fitness & Wellness') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FitnessDashboardPage()),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Padding(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ReserveHeader(),
                const SizedBox(height: 18),
                const SizedBox(height: 22),
                const Center(
                  child: Text(
                    'Choose Your Booking Type',
                    style: TextStyle(
                      color: _text,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Select an experience to explore real-time availability and\nluxury venue amenities.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 13, height: 1.35),
                  ),
                ),
                const SizedBox(height: 18),
                _ExperienceCard(
                  imagePath: 'assets/book-type/sports.jpg',
                  badge: '18 Courts Open',
                  title: 'Sports',
                  description: 'Courts, Arenas, Tournaments &...',
                  tags: const [
                    'Tennis',
                    'Padel',
                    'Basketball',
                    'Volleyball',
                    'badminton',
                    'pickleball',
                  ],
                  icon: Icons.sports_tennis_rounded,
                  accent: _mint,
                  selected: _selected == 'Sports',
                  onTap: () => setState(() => _selected = 'Sports'),
                ),
                const SizedBox(height: 12),
                _ExperienceCard(
                  imagePath: 'assets/book-type/event.jpg',
                  badge: 'VIP Banquets & Lounges',
                  title: 'Event',
                  description: 'Hotel Venues, Private Dinings &...',
                  tags: const ['Ballroom', 'Terrace', 'Private Dining'],
                  icon: Icons.auto_awesome_rounded,
                  accent: _gold,
                  selected: _selected == 'Event',
                  onTap: () => setState(() => _selected = 'Event'),
                ),
                const SizedBox(height: 12),
                _ExperienceCard(
                  imagePath: 'assets/book-type/fitness.jpg',
                  badge: 'Fitness Classes Open',
                  title: 'Fitness & Wellness',
                  description: 'Gyms, Martial Arts, Yoga & Personal...',
                  tags: const ['CrossFit', 'Pilates', 'Zumba', 'Boxing'],
                  icon: Icons.fitness_center_rounded,
                  accent: _mint,
                  selected: _selected == 'Fitness & Wellness',
                  onTap: () => setState(() => _selected = 'Fitness & Wellness'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: const [
                    _Benefit(
                      icon: Icons.verified_rounded,
                      label: 'Guaranteed\nSlot',
                      color: _mint,
                    ),
                    SizedBox(width: 8),
                    _Benefit(
                      icon: Icons.room_service_rounded,
                      label: 'VIP Concierge',
                      color: _gold,
                    ),
                    SizedBox(width: 8),
                    _Benefit(
                      icon: Icons.schedule_rounded,
                      label: 'Flexible\nChanges',
                      color: _navy,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: FilledButton(
                    onPressed: _continue,
                    style: FilledButton.styleFrom(
                      backgroundColor: _mint,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(36),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Continue to $_selected'),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward_rounded, size: 22),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    '●  Instant confirmation · No upfront payment required',
                    style: TextStyle(
                      color: Color(0xFF237C63),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
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
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _navy),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 4),
                Text(
                  'Reserve Experience',
                  style: TextStyle(
                    color: _text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    return Semantics(
      button: true,
      selected: selected,
      label: '$title booking option',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 190,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
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
                width: 132,
                height: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Image.asset(imagePath, fit: BoxFit.cover),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _Badge(text: badge, color: accent),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            selected ? Icons.check_circle_rounded : icon,
                            color: accent,
                            size: 21,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          color: _text,
                          fontSize: title.length > 10 ? 15 : 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 9,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: tags
                            .map((tag) => _OptionChip(label: tag))
                            .toList(),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
                fontSize: 9,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 88,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: _surface.withValues(alpha: .7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .16)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 22),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _text,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            Text(
              switch (label) {
                'Guaranteed\nSlot' => '100% Reserved',
                'VIP Concierge' => 'Personal Host',
                _ => 'Free Cancellation',
              },
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A5BD), fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }
}
