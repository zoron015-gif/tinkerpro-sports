import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_dashboard.dart';
import 'reserve_dashboard.dart';

import 'dart:async';

const _navy = Color(0xFF192B50);
const _ink = Color(0xFF101B33);
const _orange = Color(0xFFFF8200);
const _page = Color(0xFFF7F9FC);
const _muted = Color(0xFF68748A);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    const MyApp(),
  ); // Replace MyApp with your root widget name if different
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TinkerPro',
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

  Future<void> _openBookings(BuildContext context) async {
    final authenticated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AuthDashboardPage()),
    );
    if (!context.mounted || authenticated != true) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReserveDashboardPage()),
    );
  }

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
              child: const _Header(),
            ),
            SliverToBoxAdapter(
              child: _Hero(
                onExplore: () => _openBookings(context),
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
  const _Header();

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
        ],
      ),
    );
  }
}

enum _AuthMode { login, register }

enum _AccountRole { customer, merchant }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  _AuthMode _mode = _AuthMode.login;
  _AccountRole _role = _AccountRole.customer;
  bool _obscurePassword = true;

  void _showComingSoon(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$provider sign in will be connected soon.'),
        backgroundColor: _navy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == _AuthMode.login;
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                color: _navy,
              ),
              const SizedBox(height: 18),
              Center(
                child: Image.asset(
                  'assets/tinker_logo.png',
                  width: 76,
                  height: 58,
                ),
              ),
              const SizedBox(height: 15),
              Center(
                child: Text(
                  isLogin ? 'Welcome back' : 'Create your account',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Center(
                child: Text(
                  isLogin
                      ? 'Sign in to continue your game.'
                      : 'Join TinkerPro and get in the game.',
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ),
              const SizedBox(height: 26),
              _AuthModeToggle(
                mode: _mode,
                onChanged: (mode) => setState(() => _mode = mode),
              ),
              const SizedBox(height: 24),
              if (!isLogin) ...[
                const Text(
                  'I am joining as',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.person_rounded,
                        title: 'Player',
                        subtitle: 'Book and play',
                        selected: _role == _AccountRole.customer,
                        onTap: () =>
                            setState(() => _role = _AccountRole.customer),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.storefront_rounded,
                        title: 'Merchant',
                        subtitle: 'Manage facilities',
                        selected: _role == _AccountRole.merchant,
                        onTap: () =>
                            setState(() => _role = _AccountRole.merchant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              _AuthField(
                label: 'Email address',
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              _AuthField(
                label: 'Password',
                hint: 'Enter your password',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              if (!isLogin) ...[
                const SizedBox(height: 14),
                const _AuthField(
                  label: 'Confirm password',
                  hint: 'Repeat your password',
                  icon: Icons.verified_user_outlined,
                  obscureText: true,
                ),
              ],
              if (isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _showComingSoon('Password recovery'),
                    child: const Text('Forgot password?'),
                  ),
                )
              else
                const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _showComingSoon(
                    isLogin
                        ? 'Email login'
                        : '${_role == _AccountRole.merchant ? 'Merchant' : 'Customer'} registration',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(53),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  child: Text(isLogin ? 'Sign in' : 'Create account'),
                ),
              ),
              const SizedBox(height: 22),
              const _OrDivider(),
              const SizedBox(height: 18),
              _SocialButton(
                label: 'Continue with Google',
                mark: 'G',
                onTap: () => _showComingSoon('Google'),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text.rich(
                  TextSpan(
                    text: isLogin
                        ? 'New to TinkerPro? '
                        : 'Already have an account? ',
                    style: const TextStyle(color: _muted, fontSize: 13),
                    children: [
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () => setState(
                            () => _mode = isLogin
                                ? _AuthMode.register
                                : _AuthMode.login,
                          ),
                          child: Text(
                            isLogin ? 'Register' : 'Sign in',
                            style: const TextStyle(
                              color: _orange,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
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

class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({required this.mode, required this.onChanged});

  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDF4),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          _ToggleOption(
            label: 'Sign in',
            selected: mode == _AuthMode.login,
            onTap: () => onChanged(_AuthMode.login),
          ),
          _ToggleOption(
            label: 'Register',
            selected: mode == _AuthMode.register,
            onTap: () => onChanged(_AuthMode.register),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x16000000),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _navy : _muted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ),
  );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(15),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: selected ? _navy : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected ? _orange : const Color(0xFFE4E8EF),
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: selected ? _orange : _muted, size: 24),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: selected ? Colors.white : _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: selected
                        ? Colors.white.withValues(alpha: .65)
                        : _muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: _ink,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: _muted, size: 20),
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.white,
          hintStyle: const TextStyle(color: Color(0xFF9CA6B5), fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E7EF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E7EF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _orange, width: 1.5),
          ),
        ),
      ),
    ],
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider(color: Color(0xFFDDE2EA))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'OR CONTINUE WITH',
          style: TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
      ),
      const Expanded(child: Divider(color: Color(0xFFDDE2EA))),
    ],
  );
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.mark,
    required this.onTap,
  });

  final String label;
  final String mark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(51),
      backgroundColor: Colors.white,
      foregroundColor: _ink,
      side: const BorderSide(color: Color(0xFFE1E6EE)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          mark,
          style: TextStyle(
            color: _navy,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
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
                'Your sport.\nYour event.\nYour place.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 35,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'TinkerPro brings sports and events together in one marketplace. Discover local businesses, compare what they offer, and book in a few taps.',
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
                label: const Text('Explore bookings'),
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

class SportsSelectionPage extends StatefulWidget {
  const SportsSelectionPage({super.key});

  @override
  State<SportsSelectionPage> createState() => _SportsSelectionPageState();
}

class _SportsSelectionPageState extends State<SportsSelectionPage> {
  String? _selectedBooking;
  bool _showEvents = false;

  static const _sports = [
    (
      'assets/court/basket-court.jpg',
      Icons.sports_basketball_rounded,
      'Basketball',
      'Indoor courts',
    ),
    (
      'assets/court/volley-court.jpg',
      Icons.sports_volleyball_rounded,
      'Volleyball',
      'Team courts',
    ),
    (
      'assets/court/badminton-court.jpg',
      Icons.sports_tennis_rounded,
      'Badminton',
      'Fast-paced play',
    ),
    (
      'assets/court/pickle-court.jpg',
      Icons.sports_tennis_rounded,
      'Pickleball',
      'Social court play',
    ),
  ];

  static const _events = [
    (
      'assets/court/basket-court.jpg',
      Icons.celebration_rounded,
      'Community events',
      'Local activities',
    ),
    (
      'assets/court/volley-court.jpg',
      Icons.groups_rounded,
      'Group experiences',
      'Gather and connect',
    ),
    (
      'assets/court/badminton-court.jpg',
      Icons.event_rounded,
      'Hosted events',
      'Book an event',
    ),
    (
      'assets/court/pickle-court.jpg',
      Icons.local_activity_rounded,
      'Special occasions',
      'Plan your day',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: _navy,
                    ),
                    const Spacer(),
                    const Text(
                      'STEP 1 OF 3',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _SelectionHero()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Sports'),
                      icon: Icon(Icons.sports_score_rounded),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Events'),
                      icon: Icon(Icons.event_rounded),
                    ),
                  ],
                  selected: {_showEvents},
                  onSelectionChanged: (selection) => setState(() {
                    _showEvents = selection.first;
                    _selectedBooking = null;
                  }),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        _showEvents ? 'Choose an event' : 'Choose a sport',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${(_showEvents ? _events : _sports).length} available',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final booking = (_showEvents ? _events : _sports)[index];
                  final selected = _selectedBooking == booking.$3;
                  return _SportCard(
                    imagePath: booking.$1,
                    icon: booking.$2,
                    title: booking.$3,
                    subtitle: booking.$4,
                    selected: selected,
                    onTap: () => setState(() => _selectedBooking = booking.$3),
                  );
                }, childCount: (_showEvents ? _events : _sports).length),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: .96,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: FilledButton(
                  onPressed: _selectedBooking == null
                      ? null
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Great choice! Let’s find $_selectedBooking listings.',
                            ),
                            backgroundColor: _navy,
                          ),
                        ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(55),
                    backgroundColor: _orange,
                    disabledBackgroundColor: const Color(0xFFE0E4EB),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: _muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(
                    _selectedBooking == null
                        ? (_showEvents
                            ? 'Select an event to continue'
                            : 'Select a sport to continue')
                        : 'Find $_selectedBooking',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionHero extends StatefulWidget {
  @override
  State<_SelectionHero> createState() => _SelectionHeroState();
}

class _SelectionHeroState extends State<_SelectionHero> {
  static const _heroImages = [
    'assets/court/basket-court.jpg',
    'assets/court/volley-court.jpg',
    'assets/court/badminton-court.jpg',
    'assets/court/pickle-court.jpg',
  ];

  late final PageController _pageController;
  Timer? _carouselTimer;
  int _activePage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      _activePage = (_activePage + 1) % _heroImages.length;
      _pageController.animateToPage(
        _activePage,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 224,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30192B50),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _heroImages.length,
            onPageChanged: (page) => setState(() => _activePage = page),
            itemBuilder: (context, index) =>
                Image.asset(_heroImages[index], fit: BoxFit.cover),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _navy.withValues(alpha: .68),
                  _navy.withValues(alpha: .94),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'FOOTBALL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'COMING SOON',
                      style: TextStyle(
                        color: Color(0xE6FFFFFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Find your next game',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Choose a sport or event and we’ll take care of the rest.',
                  style: TextStyle(
                    color: Color(0xD9FFFFFF),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: List.generate(
                    _heroImages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.only(right: 5),
                      width: index == _activePage ? 22 : 6,
                      height: 5,
                      decoration: BoxDecoration(
                        color: index == _activePage
                            ? _orange
                            : Colors.white.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
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

class _SportCard extends StatelessWidget {
  const _SportCard({
    required this.imagePath,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String imagePath;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _orange : const Color(0xFFE6EAF1),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x28192B50),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              imagePath,
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: .16),
              colorBlendMode: BlendMode.darken,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, _navy.withValues(alpha: .92)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .9),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(icon, color: _orange, size: 23),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: _orange,
                          size: 23,
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xD9FFFFFF),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            'A simple marketplace for clients to book and merchants to grow.',
            style: TextStyle(color: _muted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: const [
              _Step(
                number: '01',
                icon: Icons.search_rounded,
                title: 'Discover',
                text: 'Find sports, events, and local businesses.',
              ),
              SizedBox(width: 10),
              _Step(
                number: '02',
                icon: Icons.calendar_month_rounded,
                title: 'Book',
                text: 'Choose a service, slot, or event.',
              ),
              SizedBox(width: 10),
              _Step(
                number: '03',
                icon: Icons.sports_score_rounded,
                title: 'Enjoy',
                text: 'Arrive ready and let your plans happen.',
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
        'Sports and events',
        'Book courts, activities, venues, and experiences in one place.',
      ),
      (
        Icons.schedule_rounded,
        'Merchant marketplace',
        'Businesses can showcase their services, spaces, and schedules.',
      ),
      (
        Icons.groups_rounded,
        'Easy discovery',
        'Compare listings, details, and availability before you book.',
      ),
      (
        Icons.insights_rounded,
        'Simple bookings',
        'Keep every sports or event reservation organized in one app.',
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
                  'Ready to make a plan?',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Book a sport or event from a local business today.',
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
