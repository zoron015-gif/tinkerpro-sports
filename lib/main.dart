import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _navy = Color(0xFF192B50);
const _ink = Color(0xFF101B33);
const _orange = Color(0xFFFF8200);
const _page = Color(0xFFF7F9FC);
const _muted = Color(0xFF68748A);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TinkerPro Sports',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _orange),
        scaffoldBackgroundColor: _page,
        useMaterial3: true,
        textTheme: GoogleFonts.montserratTextTheme(),
      ),
      home: const OverviewPage(),
    );
  }
}

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _navy,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                onLogin: () => _showMessage(context, 'Sign in is coming soon.'),
              ),
            ),
            SliverToBoxAdapter(
              child: _Hero(
                onExplore: () =>
                    _showMessage(context, 'Court discovery is coming soon.'),
              ),
            ),
            SliverToBoxAdapter(child: _HowItWorks()),
            SliverToBoxAdapter(child: _Features()),
            SliverToBoxAdapter(
              child: _BottomCallout(
                onTap: () =>
                    _showMessage(context, 'Welcome to TinkerPro Sports!'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/tinker_logo.png',
                width: 52,
                height: 44,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Tinker',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.5,
                      ),
                    ),
                    TextSpan(
                      text: 'Pro',
                      style: TextStyle(
                        color: _orange,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: onLogin,
            style: TextButton.styleFrom(foregroundColor: _navy),
            child: const Text(
              'LOG IN',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .6),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x25192B50),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -18,
            child: _Orb(size: 140, color: _orange.withValues(alpha: .18)),
          ),
          Positioned(
            right: 45,
            bottom: -50,
            child: _Orb(size: 110, color: Colors.white.withValues(alpha: .06)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'PLAY MORE. PLAN LESS.',
                  style: TextStyle(
                    color: _orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Your game.\nYour court.\nYour time.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 35,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'TinkerPro Sports makes it simple to discover facilities, book courts, and keep every game moving.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .75),
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onExplore,
                icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                label: const Text('Explore courts'),
                style: FilledButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class _HowItWorks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Everything in one place',
            style: TextStyle(
              color: _ink,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'A smarter way to manage every match, session, and facility.',
            style: TextStyle(color: _muted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: const [
              _Step(
                number: '01',
                icon: Icons.search_rounded,
                title: 'Discover',
                text: 'Find the right sport and facility.',
              ),
              SizedBox(width: 10),
              _Step(
                number: '02',
                icon: Icons.calendar_month_rounded,
                title: 'Book',
                text: 'Choose a time that works for you.',
              ),
              SizedBox(width: 10),
              _Step(
                number: '03',
                icon: Icons.sports_score_rounded,
                title: 'Play',
                text: 'Show up and enjoy the game.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.icon,
    required this.title,
    required this.text,
  });

  final String number;
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 154,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFE7EBF2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: _orange, size: 22),
                Text(
                  number,
                  style: const TextStyle(
                    color: Color(0xFFB9C2D1),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              text,
              style: const TextStyle(color: _muted, fontSize: 11, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _Features extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const features = [
      (
        Icons.sports_tennis_rounded,
        'Multi-sport booking',
        'One simple system for every court and activity.',
      ),
      (
        Icons.schedule_rounded,
        'Live availability',
        'See open slots and avoid double bookings.',
      ),
      (
        Icons.groups_rounded,
        'Built for teams',
        'Keep players, coaches, and staff aligned.',
      ),
      (
        Icons.insights_rounded,
        'Clear operations',
        'Make better decisions with a view of your facility.',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Made for the way you play',
            style: TextStyle(
              color: _ink,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1E4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(feature.$1, color: _orange),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature.$2,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            feature.$3,
                            style: const TextStyle(color: _muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFB8C0CD),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomCallout extends StatelessWidget {
  const _BottomCallout({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEE0),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ready to get in the game?',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Start your next booking with TinkerPro.',
                  style: TextStyle(
                    color: _navy.withValues(alpha: .7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onTap,
            style: IconButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }
}
