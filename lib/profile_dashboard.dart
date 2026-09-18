import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app_session.dart';
import 'event_dashboard.dart';
import 'fitness_dashboard.dart';
import 'sports.dart';
import 'saved_dashboard.dart';

const _profileNavy = Color(0xFF192B50);
const _profileInk = Color(0xFF101B33);
const _profileOrange = Color(0xFFFF8200);
const _profilePage = Color(0xFFF7F9FC);
const _profileMuted = Color(0xFF68748A);
const _profileLine = Color(0xFFE6EAF0);

class ProfileDashboardPage extends StatelessWidget {
  const ProfileDashboardPage({super.key, this.onLogout});

  final Future<void> Function(BuildContext context)? onLogout;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : 'Player';
    final email = user?.email ?? 'Player account';
    final initials = _initials(name);

    return Scaffold(
      backgroundColor: _profilePage,
      appBar: AppBar(
        backgroundColor: _profilePage,
        foregroundColor: _profileInk,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        title: const Text(
          'Player Profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'QR code',
            onPressed: () => _message(context, 'Your QR code is ready soon.'),
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
          IconButton(
            tooltip: 'Accessibility',
            onPressed: () =>
                _message(context, 'Accessibility settings are coming soon.'),
            icon: const Icon(Icons.accessibility_new_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await FirebaseAuth.instance.currentUser?.reload();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
            _profileHeader(name: name, email: email, initials: initials),
            const SizedBox(height: 12),
            _statsCard(),
            const SizedBox(height: 12),
            _fastPassCard(context),
            const SizedBox(height: 12),
            _balanceCard(context),
            const SizedBox(height: 12),
            _nextMatchCard(context),
            const SizedBox(height: 12),
            _settingsCard(context),
            const SizedBox(height: 12),
            _ownerCard(context),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () =>
                      _message(context, 'Help center coming soon.'),
                  child: const Text('Help Center'),
                ),
                const Text('•', style: TextStyle(color: _profileMuted)),
                TextButton(
                  onPressed: () =>
                      _message(context, 'Court rules coming soon.'),
                  child: const Text('Court Rules'),
                ),
                const Text('•', style: TextStyle(color: _profileMuted)),
                TextButton(
                  onPressed: () => _logout(context),
                  child: const Text('Log Out'),
                ),
              ],
            ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFFE8D2),
        onDestinationSelected: (index) {
          if (index == 0) {
            _openExplore(context);
            return;
          }
          if (index == 3) return;
          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SavedDashboardPage(onLogout: onLogout),
              ),
            );
            return;
          }
          _message(context, switch (index) {
            1 => 'Saved venues will appear here.',
            _ => 'Booking history will appear here.',
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on_rounded),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today_rounded),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Future<void> _openExplore(BuildContext context) async {
    final session = await AppSession.load();
    if (!context.mounted) return;

    final page = switch (session.lastBookingType) {
      'Sports' => SportsDashboardPage(onLogout: onLogout),
      'Event' => EventDashboardPage(onLogout: onLogout),
      'Fitness & Wellness' => FitnessDashboardPage(onLogout: onLogout),
      _ => null,
    };

    if (page == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    await Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  Widget _profileHeader({
    required String name,
    required String email,
    required String initials,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 31,
              backgroundColor: const Color(0xFFFFF1E4),
              child: Text(
                initials,
                style: const TextStyle(
                  color: _profileOrange,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: _profileInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _profileMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 5,
                    children: const [
                      _ProfileTag('Tennis · NTRP 3.5'),
                      _ProfileTag('Pickleball · DURS 3.8'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsCard() => Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          _Stat(value: '28', label: 'Matches'),
          _Stat(value: '14', label: 'Venues Visited'),
          _Stat(value: '4.9 ★', label: 'Rating'),
        ],
      ),
    ),
  );

  Widget _fastPassCard(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _profileNavy,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PLAYER FAST PASS',
                style: TextStyle(
                  color: _profileOrange,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Court Express Check-in',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'ID: #SLT-8824',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
              SizedBox(height: 14),
              Text(
                'Valid at 55 · Cebu Courts',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.qr_code_2_rounded, size: 40),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () =>
                  _message(context, 'Scan a venue QR code to check in.'),
              style: FilledButton.styleFrom(
                backgroundColor: _profileOrange,
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text(
                'Scan at Venue',
                style: TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _balanceCard(BuildContext context) => _whiteCard(
    children: [
      Row(
        children: [
          const _RoundIcon(icon: Icons.account_balance_wallet_outlined),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Balance',
                  style: TextStyle(color: _profileMuted, fontSize: 10),
                ),
                Text(
                  '₱1,850.00',
                  style: TextStyle(
                    color: _profileInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: null,
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(_profileOrange),
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
            child: Text('＋ Top Up', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
      const Divider(height: 20),
      const Row(
        children: [
          Icon(Icons.local_offer_outlined, color: _profileOrange, size: 15),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              'Promo Court Credits',
              style: TextStyle(color: _profileMuted, fontSize: 10),
            ),
          ),
          Text(
            '₱350.00',
            style: TextStyle(
              color: _profileOrange,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _nextMatchCard(BuildContext context) => _whiteCard(
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              '● NEXT COURT MATCH',
              style: TextStyle(
                color: _profileOrange,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _smallPill('Tonight'),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1E4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'OCT\n24',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _profileOrange,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SLT Court · Court 1 (Outdoor)',
                  style: TextStyle(
                    color: _profileInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '7:00 PM - 8:30 PM · 1.5 hrs',
                  style: TextStyle(color: _profileMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: _profileMuted,
            size: 14,
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Minglanilla, Cebu',
              style: TextStyle(color: _profileMuted, fontSize: 10),
            ),
          ),
          TextButton(
            onPressed: () =>
                _message(context, 'Your ticket details are ready.'),
            child: const Text(
              'View Ticket →',
              style: TextStyle(color: _profileOrange, fontSize: 10),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _settingsCard(BuildContext context) => _whiteCard(
    children: [
      _settingRow(
        context,
        Icons.groups_outlined,
        'Buddy List & Match Preferences',
        '5 regular buddies · Indoor & Covered',
      ),
      _settingRow(
        context,
        Icons.credit_card_outlined,
        'Payment & Split Pay',
        'GCash linked · Maya · Saved cards',
      ),
      _settingRow(
        context,
        Icons.notifications_none_rounded,
        'Match Alerts & Notification',
        '1 hour before slot · Rain warnings',
      ),
    ],
  );

  Widget _ownerCard(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _profileOrange,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COURT OWNERS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Switch to Host Portal',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'List your court, manage slots & payouts',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: () => _message(context, 'Host portal is opening soon.'),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _profileOrange,
            side: BorderSide.none,
          ),
          child: const Text('Switch', style: TextStyle(fontSize: 10)),
        ),
      ],
    ),
  );

  Widget _settingRow(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) => InkWell(
    onTap: () => _message(context, '$title settings are opening soon.'),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _RoundIcon(icon: icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _profileInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: _profileMuted, fontSize: 9),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: _profileMuted,
            size: 18,
          ),
        ],
      ),
    ),
  );

  Widget _whiteCard({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _profileLine),
    ),
    child: Column(children: children),
  );

  Widget _smallPill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F4F8),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: const TextStyle(color: _profileNavy, fontSize: 9)),
  );

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn.instance.signOut();
    await (await AppSession.load()).clear();
    if (!context.mounted) return;
    if (onLogout != null) {
      await onLogout!(context);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _initials(String name) {
    final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final values = parts.toList();
    if (values.length == 1) return values.first.substring(0, 1).toUpperCase();
    return '${values.first[0]}${values.last[0]}'.toUpperCase();
  }
}

class _ProfileTag extends StatelessWidget {
  const _ProfileTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1E4),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(color: _profileOrange, fontSize: 8),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: _profileInk,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: _profileMuted, fontSize: 9)),
      ],
    ),
  );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    decoration: const BoxDecoration(
      color: Color(0xFFFFF7F0),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: _profileOrange, size: 16),
  );
}
