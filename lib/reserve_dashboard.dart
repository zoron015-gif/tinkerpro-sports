import 'package:flutter/material.dart';

const _background = Color(0xFFF7F9FC);
const _navy = Color(0xFF192B50);
const _surface = Colors.white;
const _surfaceLight = Color(0xFFEFF2F7);
const _text = Color(0xFF101B33);
const _muted = Color(0xFF68748A);
const _mint = Color(0xFFFF8200);
const _mintDark = Color(0xFF192B50);
const _gold = Color(0xFFFFA63D);

class ReserveDashboardPage extends StatefulWidget {
  const ReserveDashboardPage({super.key});

  @override
  State<ReserveDashboardPage> createState() => _ReserveDashboardPageState();
}

class _ReserveDashboardPageState extends State<ReserveDashboardPage> {
  String _selected = 'Sports';

  void _continue() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Finding $_selected reservations near you...'),
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
        child: LayoutBuilder(
          builder: (context, _) => Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ReserveHeader(),
                const SizedBox(height: 10),
                const _StepPill(),
                const SizedBox(height: 8),
                const Text(
                  'Choose Your Booking Type',
                  style: TextStyle(
                    color: _text,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select an experience to view availability and reservations.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.25),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _ExperienceCard(
                          imagePath: 'assets/book-type/sports.jpg',
                          badge: '18 Courts Open',
                          title: 'Sports',
                          description:
                              'Courts, Arenas, Tournaments & Equipment Rental',
                          tags: const [
                            'Tennis',
                            'Basketball',
                            'Football',
                            'Training',
                            'Volleyball',
                            'Badminton',
                            'Pickleball',
                            'Yoga',
                          ],
                          icon: Icons.sports_tennis_rounded,
                          accent: _mint,
                          selected: _selected == 'Sports',
                          onTap: () => setState(() => _selected = 'Sports'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _ExperienceCard(
                          imagePath: 'assets/book-type/event.jpg',
                          badge: 'VIP Banquets & Lounges',
                          title: 'Event',
                          description: 'Hotel Venues, Banquets, Private Celebrations & Galas',
                          tags: const [
                            'Banquet',
                            'Private Dining',
                            'Terrace',
                            'Celebrations',
                            'Wedding',
                            'Birthday',
                            'Corporate',
                            'Conference',
                          ],
                          icon: Icons.auto_awesome_rounded,
                          accent: _gold,
                          selected: _selected == 'Event',
                          onTap: () => setState(() => _selected = 'Event'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _ExperienceCard(
                          imagePath: 'assets/book-type/fitness.jpg',
                          badge: 'Fitness Classes Open',
                          title: 'Fitness & Wellness',
                          description:
                              'Gyms, Martial Arts, Dance Classes & Personal Training',
                          tags: const [
                            'Martial Arts',
                            'Gym',
                            'Zumba',
                            'Boxing',
                            'Pilates',
                            'CrossFit',
                          ],
                          icon: Icons.fitness_center_rounded,
                          accent: _mint,
                          selected: _selected == 'Fitness & Wellness',
                          onTap: () => setState(
                            () => _selected = 'Fitness & Wellness',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
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
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 56,
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RESERVE',
                  style: TextStyle(
                    color: _mint,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
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

class _StepPill extends StatelessWidget {
  const _StepPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: _surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _mintDark),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: _mint, size: 10),
          SizedBox(width: 9),
          Text(
            'STEP 1 OF 3 • CHOOSE CATEGORY',
            style: TextStyle(
              color: _mint,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
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
          height: double.infinity,
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
                width: 88,
                height: double.infinity,
                child: Image.asset(imagePath, fit: BoxFit.cover),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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
                        style: const TextStyle(
                          color: _text,
                          fontSize: 17,
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
                      Text(
                        tags.join('  •  '),
                        maxLines: 3,
                        softWrap: true,
                        overflow: TextOverflow.visible,
                        style: const TextStyle(
                          color: _text,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
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
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        decoration: BoxDecoration(
          color: _surface.withValues(alpha: .7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .16)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 21),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _text,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
