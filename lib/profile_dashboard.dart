import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'app_session.dart';
import 'event_dashboard.dart';
import 'fitness_dashboard.dart';
import 'sports.dart';
import 'saved_dashboard.dart';
import 'messages_dashboard.dart';
import 'customer_bookings_page.dart';
import 'auth_api.dart';

const _profileNavy = Color(0xFF192B50);
const _profileInk = Color(0xFF101B33);
const _profileOrange = Color(0xFFFF8200);
const _profilePage = Color(0xFFF7F9FC);
const _profileMuted = Color(0xFF68748A);
const _profileLine = Color(0xFFE6EAF0);

class ProfileDashboardPage extends StatefulWidget {
  const ProfileDashboardPage({super.key, this.onLogout});

  final Future<void> Function(BuildContext context)? onLogout;

  @override
  State<ProfileDashboardPage> createState() => _ProfileDashboardPageState();
}

class _ProfileDashboardPageState extends State<ProfileDashboardPage> {
  final _api = AuthApi();
  Timer? _bookingReminderTimer;
  final Set<String> _sentBookingReminderKeys = <String>{};
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _bookings = [];
  String _selectedHistoryTab = 'Upcoming booking';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _bookingReminderTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkBookingReminders(),
    );
  }

  @override
  void dispose() {
    _bookingReminderTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final token = (await AppSession.load()).apiToken;
      if (token != null && token.isNotEmpty) {
        final profile = await _api.me(token);
        final bookings = await _api.customerBookings(token);
        if (!mounted) return;
        setState(() {
          _user = profile['user'] as Map<String, dynamic>?;
          _bookings = bookings;
        });
        _checkBookingReminders();
      }
    } on Exception catch (error) {
      if (mounted) _message(context, 'Could not load profile: $error');
    }
  }

  String get _name {
    final apiName = '${_user?['firstName'] ?? ''} ${_user?['lastName'] ?? ''}'
        .trim();
    if (apiName.isNotEmpty) return apiName;
    final firebaseName = FirebaseAuth.instance.currentUser?.displayName?.trim();
    return firebaseName?.isNotEmpty == true ? firebaseName! : 'Player';
  }

  String get _email =>
      (_user?['email'] as String?) ??
      FirebaseAuth.instance.currentUser?.email ??
      'Player account';

  List<Map<String, dynamic>> get _upcoming => _bookings
      .where((booking) => '${booking['status']}'.toLowerCase() == 'approved')
      .toList();

  List<Map<String, dynamic>> get _completed => _bookings
      .where(
        (booking) => const {
          'finished',
          'done',
          'completed',
        }.contains('${booking['status']}'.toLowerCase()),
      )
      .toList();

  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: _name);
    final addressController = TextEditingController(
      text: '${_user?['address'] ?? ''}',
    );
    final phoneController = TextEditingController(
      text: '${_user?['phone'] ?? ''}',
    );
    final hobbyController = TextEditingController();
    final hobbies = '${_user?['hobby'] ?? ''}'
        .split(',')
        .map((hobby) => hobby.trim())
        .where((hobby) => hobby.isNotEmpty)
        .toList();
    String? profileImage = _user?['avatarUrl'] as String?;
    final value = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close edit profile',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.white,
          elevation: 12,
          child: SizedBox(
            width: MediaQuery.sizeOf(dialogContext).width * .88,
            height: double.infinity,
            child: SafeArea(
              child: StatefulBuilder(
                builder: (context, setDialogState) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            color: _profileOrange,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Edit profile',
                              style: TextStyle(
                                color: _profileInk,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: _profileLine),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final picked = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 80,
                                  maxWidth: 900,
                                );
                                if (picked == null) return;
                                final bytes = await picked.readAsBytes();
                                setDialogState(() {
                                  profileImage =
                                      'data:image/${picked.name.split('.').last};base64,'
                                      '${base64Encode(bytes)}';
                                });
                              },
                              child: CircleAvatar(
                                radius: 38,
                                backgroundColor: const Color(0xFFFFF1E4),
                                backgroundImage: _avatarImage(profileImage),
                                child: !_hasAvatar(profileImage)
                                    ? const Icon(
                                        Icons.add_a_photo_outlined,
                                        color: _profileOrange,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap photo to change',
                              style: TextStyle(
                                color: _profileMuted,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: nameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _profileInputDecoration(
                                label: 'Name',
                                icon: Icons.person_outline,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: _profileInputDecoration(
                                label: 'Contact number',
                                icon: Icons.phone_outlined,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: addressController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _profileInputDecoration(
                                label: 'Address',
                                icon: Icons.location_on_outlined,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (hobbies.isNotEmpty)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: hobbies
                                      .map(
                                        (hobby) => InputChip(
                                          label: Text(hobby),
                                          onDeleted: () => setDialogState(
                                            () => hobbies.remove(hobby),
                                          ),
                                          deleteIconColor: _profileOrange,
                                          labelStyle: const TextStyle(
                                            color: _profileOrange,
                                            fontSize: 12,
                                          ),
                                          backgroundColor: const Color(
                                            0xFFFFF1E4,
                                          ),
                                          side: BorderSide.none,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            if (hobbies.isNotEmpty) const SizedBox(height: 8),
                            TextField(
                              controller: hobbyController,
                              textCapitalization: TextCapitalization.sentences,
                              onSubmitted: (value) {
                                final hobby = value.trim();
                                if (hobby.isEmpty || hobbies.contains(hobby)) {
                                  return;
                                }

                                setDialogState(() {
                                  hobbies.add(hobby);
                                  hobbyController.clear();
                                });
                              },
                              decoration: _profileInputDecoration(
                                label: 'Add hobby',
                                icon: Icons.sports_tennis_outlined,
                                suffixIcon: const Icon(Icons.add_rounded),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Press enter after each hobby',
                                style: TextStyle(
                                  color: _profileMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Save changes'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
    );
    final name = nameController.text.trim();
    final address = addressController.text.trim();
    final pendingHobby = hobbyController.text.trim();
    if (pendingHobby.isNotEmpty && !hobbies.contains(pendingHobby)) {
      hobbies.add(pendingHobby);
    }
    final hobby = hobbies.join(', ');
    final phone = phoneController.text.trim();
    nameController.dispose();
    addressController.dispose();
    phoneController.dispose();
    hobbyController.dispose();
    if (value != true || name.isEmpty) return;
    final parts = name.split(RegExp(r'\s+'));
    final firstName = parts.first;
    final lastName = parts.skip(1).join(' ');
    try {
      final token = (await AppSession.load()).apiToken;
      if (token != null && token.isNotEmpty) {
        final response = await _api.updateCustomerProfile(
          token: token,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          address: address,
          hobby: hobby,
          avatarUrl: profileImage,
        );
        await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
        if (!mounted) return;
        setState(() => _user = response['user'] as Map<String, dynamic>?);
        _message(context, 'Profile updated.');
      }
    } on Exception catch (error) {
      if (mounted) _message(context, 'Could not update profile: $error');
    }
  }

  Future<void> _openSettings(BuildContext context) async {
    final action = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close settings',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.white,
          elevation: 12,
          child: SizedBox(
            width: MediaQuery.sizeOf(dialogContext).width * .82,
            height: double.infinity,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.settings_outlined,
                          color: _profileOrange,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Settings',
                            style: TextStyle(
                              color: _profileInk,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close settings',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: _profileLine),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit profile'),
                    onTap: () => Navigator.pop(dialogContext, 'edit'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.swap_horiz_rounded),
                    title: const Text('Switch to Host Portal'),
                    onTap: () => Navigator.pop(dialogContext, 'switch'),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Log out',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () => Navigator.pop(dialogContext, 'logout'),
                  ),
                  const Spacer(),
                  const Divider(height: 1, color: _profileLine),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'SUPPORT',
                        style: TextStyle(
                          color: _profileMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () =>
                                Navigator.pop(dialogContext, 'help'),
                            icon: const Icon(
                              Icons.help_outline_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Help Center',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 10,
                              ),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () =>
                                Navigator.pop(dialogContext, 'rules'),
                            icon: const Icon(Icons.gavel_outlined, size: 18),
                            label: const Text(
                              'Court Rules',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 10,
                              ),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        await _editProfile();
      case 'switch':
        _message(context, 'Host portal is opening soon.');
      case 'logout':
        await _logout(context);
      case 'help':
        _message(context, 'Help center coming soon.');
      case 'rules':
        _message(context, 'Court rules coming soon.');
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _name;
    final email = _email;
    final initials = _initials(name);

    return Scaffold(
      backgroundColor: _profilePage,
      appBar: AppBar(
        backgroundColor: _profilePage,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _profileInk,
        elevation: 0,
        scrolledUnderElevation: 0,
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
            tooltip: 'Settings',
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await FirebaseAuth.instance.currentUser?.reload();
            await _loadProfile();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              _profileHeader(
                name: name,
                email: email,
                initials: initials,
                avatarUrl: _user?['avatarUrl'] as String?,
                hobby: '${_user?['hobby'] ?? ''}',
                address: '${_user?['address'] ?? ''}',
              ),
              const SizedBox(height: 10),
              _statsCard(
                matches: _completed.length,
                venues: _completed
                    .map((booking) => booking['venueId'])
                    .toSet()
                    .length,
              ),
              const SizedBox(height: 10),
              _profileHistorySection(context),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shadowColor: const Color(0x14000000),
            elevation: 2,
            indicatorColor: const Color(0xFFFFE8D2),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                color: selected
                    ? const Color(0xFFFF8200)
                    : const Color(0xFF68748A),
                size: 24,
              );
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                color: selected
                    ? const Color(0xFF101B33)
                    : const Color(0xFF68748A),
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              );
            }),
          ),
        ),
        child: NavigationBar(
          height: 72,
          elevation: 0,
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: 4,
          onDestinationSelected: (index) {
            if (index == 0) {
              _openExplore(context);
              return;
            }
            if (index == 4) return;
            if (index == 1) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SavedDashboardPage(onLogout: widget.onLogout),
                ),
              );
              return;
            }
            if (index == 2) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MessagesDashboardPage(),
                ),
              );
              return;
            }
            if (index == 3) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) =>
                      CustomerBookingsPage(onLogout: widget.onLogout),
                ),
              );
              return;
            }
            _message(context, switch (index) {
              1 => 'Saved venues will appear here.',
              2 => 'Messages will appear here.',
              3 => 'Booking history will appear here.',
              _ => 'Booking history will appear here.',
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.location_on_outlined, size: 24),
              selectedIcon: Icon(Icons.location_on_rounded, size: 24),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border_rounded, size: 24),
              selectedIcon: Icon(Icons.favorite_rounded, size: 24),
              label: 'Saved',
            ),
            NavigationDestination(
              icon: Icon(Icons.send_outlined, size: 24),
              selectedIcon: Icon(Icons.send_rounded, size: 24),
              label: 'Messages',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined, size: 22),
              selectedIcon: Icon(Icons.calendar_today_rounded, size: 22),
              label: 'Bookings',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, size: 24),
              selectedIcon: Icon(Icons.person_rounded, size: 24),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExplore(BuildContext context) async {
    final session = await AppSession.load();
    if (!context.mounted) return;

    final page = switch (session.lastBookingType) {
      'Sports' => SportsDashboardPage(onLogout: widget.onLogout),
      'Event' => EventDashboardPage(onLogout: widget.onLogout),
      'Fitness & Wellness' => FitnessDashboardPage(onLogout: widget.onLogout),
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
    required String? avatarUrl,
    required String hobby,
    required String address,
  }) {
    return _whiteCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      children: [
        Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 31,
                  backgroundColor: const Color(0xFFFFF1E4),
                  backgroundImage: _avatarImage(avatarUrl),
                  child: !_hasAvatar(avatarUrl)
                      ? Text(
                          initials,
                          style: const TextStyle(
                            color: _profileOrange,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
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
                        style: const TextStyle(
                          color: _profileMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _profileHeaderDetail(
                        Icons.location_on_outlined,
                        address.isEmpty ? 'Add your address' : address,
                      ),
                      const SizedBox(height: 4),
                      _profileHeaderDetail(
                        Icons.sports_tennis_outlined,
                        hobby.isEmpty ? 'Add your hobbies' : hobby,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _statsCard({required int matches, required int venues}) => _whiteCard(
    padding: const EdgeInsets.symmetric(vertical: 14),
    children: [
      Row(
        children: [
          _Stat(value: '$matches', label: 'Matches'),
          _statDivider(),
          _Stat(value: '$venues', label: 'Venues visited'),
        ],
      ),
    ],
  );

  Widget _statDivider() => Container(height: 34, width: 1, color: _profileLine);

  Widget _profileHistorySection(BuildContext context) {
    const tabs = [
      (
        title: 'Upcoming match',
        icon: Icons.calendar_month_outlined,
        key: 'upcoming-booking',
      ),
      (
        title: 'Venues visited',
        icon: Icons.location_on_outlined,
        key: 'venues-visited',
      ),
      (
        title: 'Court match history',
        icon: Icons.sports_tennis_outlined,
        key: 'court-match-history',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _profileLine)),
          ),
          child: Row(
            children: [
              for (final tab in tabs)
                Expanded(
                  child: InkWell(
                    key: ValueKey('profile-history-tab-${tab.key}'),
                    onTap: () =>
                        setState(() => _selectedHistoryTab = tab.title),
                    child: Tooltip(
                      message: tab.title,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _selectedHistoryTab == tab.title
                                  ? _profileOrange
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Icon(
                          tab.icon,
                          size: 23,
                          color: _selectedHistoryTab == tab.title
                              ? _profileOrange
                              : _profileMuted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            _selectedHistoryTab,
            style: const TextStyle(
              color: _profileInk,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 8),
        switch (_selectedHistoryTab) {
          'Venues visited' => _visitedVenuesCard(context),
          'Court match history' => _courtMatchHistoryCard(context),
          _ => _upcomingBookingCard(context),
        },
      ],
    );
  }

  DateTime? _bookingStart(Map<String, dynamic> booking) {
    final date = '${booking['date'] ?? ''}'.trim();
    final time = '${booking['startTime'] ?? ''}'.trim();
    if (date.isEmpty || time.isEmpty) return null;
    return DateTime.tryParse('$date $time');
  }

  String _bookingCountdown(Map<String, dynamic> booking) {
    final start = _bookingStart(booking);
    if (start == null) return 'Schedule unavailable';
    final difference = start.difference(DateTime.now());
    if (difference.isNegative || difference.inSeconds == 0) {
      return 'Booking time is now';
    }
    if (difference.inDays > 0) {
      final hours = difference.inHours.remainder(24);
      return '${difference.inDays}d ${hours}h left';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes.remainder(60)}m left';
    }
    return '${difference.inMinutes.clamp(1, 59)}m left';
  }

  void _checkBookingReminders() {
    if (!mounted) return;
    for (final booking in _upcoming) {
      final start = _bookingStart(booking);
      if (start == null) continue;
      final difference = start.difference(DateTime.now());
      final bookingKey =
          '${booking['id'] ?? booking['venueId']}-${booking['date']}-${booking['startTime']}';
      if (difference.inSeconds > 0 &&
          difference <= const Duration(hours: 24) &&
          _sentBookingReminderKeys.add(bookingKey)) {
        final venue = '${booking['venueName'] ?? 'your venue'}';
        _message(
          context,
          'Reminder: your booking at $venue starts ${_bookingCountdown(booking)}.',
        );
      }
      if (difference.inSeconds <= 0) {
        _sentBookingReminderKeys.remove(bookingKey);
      }
    }
    setState(() {});
  }

  Widget _profileHeaderDetail(IconData icon, String text) => Row(
    children: [
      Icon(icon, color: _profileMuted, size: 13),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _profileMuted, fontSize: 10),
        ),
      ),
    ],
  );

  Widget _upcomingBookingCard(BuildContext context) {
    final booking = _upcoming.isEmpty ? null : _upcoming.first;
    if (booking == null) {
      return _whiteCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: const [
          Text(
            'UPCOMING BOOKING',
            style: TextStyle(
              color: _profileOrange,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'No approved bookings yet.',
            style: TextStyle(color: _profileInk, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text(
            'Your booking ticket will appear here after merchant approval.',
            style: TextStyle(color: _profileMuted, fontSize: 11),
          ),
        ],
      );
    }
    return _whiteCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'UPCOMING BOOKING',
                style: TextStyle(
                  color: _profileOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _showAllUpcomingBookings(context),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${booking['venueName'] ?? 'Venue'}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _profileInk,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${booking['date'] ?? ''} · ${_time(booking['startTime'])} · '
          '${booking['durationHours'] ?? 0} hour(s)',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _profileMuted, fontSize: 11),
        ),
        Text(
          '${booking['players'] ?? 0} players · ${booking['paymentMethod'] ?? ''}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _profileMuted, fontSize: 11),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1E4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                color: _profileOrange,
                size: 16,
              ),
              const SizedBox(width: 7),
              Text(
                _bookingCountdown(booking),
                style: const TextStyle(
                  color: _profileOrange,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.confirmation_num_outlined,
              color: _profileOrange,
              size: 16,
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Booking ticket is available in Messages.',
                style: TextStyle(color: _profileMuted, fontSize: 11),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MessagesDashboardPage(),
                ),
              ),
              child: const Text('View Ticket'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showAllUpcomingBookings(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: .78,
        minChildSize: .5,
        maxChildSize: .94,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: _profilePage,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _profileLine,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Upcoming bookings',
                        style: TextStyle(
                          color: _profileInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _smallPill('${_upcoming.length} approved'),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: _upcoming.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _upcomingBookingItem(context, _upcoming[index], index),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _upcomingBookingItem(
    BuildContext context,
    Map<String, dynamic> booking,
    int index,
  ) => _whiteCard(
    padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
    children: [
      Row(
        children: [
          _smallPill('#${index + 1}'),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'APPROVED BOOKING',
              style: TextStyle(
                color: _profileOrange,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Icon(Icons.verified_rounded, color: Colors.green, size: 18),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        '${booking['venueName'] ?? 'Venue'}',
        style: const TextStyle(
          color: _profileInk,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 5),
      _bookingDetailLine(
        Icons.calendar_today_outlined,
        '${booking['date'] ?? ''} · ${_time(booking['startTime'])}',
      ),
      _bookingDetailLine(
        Icons.schedule_outlined,
        '${booking['durationHours'] ?? 0} hour(s) · ${booking['players'] ?? 0} players',
      ),
      _bookingDetailLine(
        Icons.payment_outlined,
        '${booking['paymentMethod'] ?? 'Payment method not specified'}',
      ),
      _bookingDetailLine(
        Icons.notifications_active_outlined,
        _bookingCountdown(booking),
      ),
      const SizedBox(height: 5),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MessagesDashboardPage()),
          ),
          icon: const Icon(Icons.confirmation_num_outlined, size: 16),
          label: const Text('View ticket'),
        ),
      ),
    ],
  );

  Widget _bookingDetailLine(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Row(
      children: [
        Icon(icon, color: _profileMuted, size: 15),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: _profileMuted, fontSize: 11),
          ),
        ),
      ],
    ),
  );

  Widget _visitedVenuesCard(BuildContext context) {
    final venues = _visitedVenueEntries;
    return _whiteCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 17),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'VENUES VISITED',
                style: TextStyle(
                  color: _profileOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _showVisitedVenues(context),
              child: const Text('View all'),
            ),
          ],
        ),
        if (venues.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No completed court visits yet.',
                style: TextStyle(
                  color: _profileInk,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else ...[
          const SizedBox(height: 8),
          for (final venue in venues.take(2)) ...[
            _visitedVenueItem(venue),
            if (venue != venues.take(2).last) const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  List<({String name, List<Map<String, dynamic>> bookings})>
  get _visitedVenueEntries {
    final venues = <String, List<Map<String, dynamic>>>{};
    for (final booking in _completed) {
      final name = '${booking['venueName'] ?? 'Venue'}';
      venues.putIfAbsent(name, () => []).add(booking);
    }
    return venues.entries
        .map((entry) => (name: entry.key, bookings: entry.value))
        .toList();
  }

  Widget _visitedVenueItem(
    ({String name, List<Map<String, dynamic>> bookings}) venue, {
    String? details,
    String? badge,
    VoidCallback? onTap,
  }) {
    final latestBooking = venue.bookings.first;
    final image = _avatarImage(
      latestBooking['imageUrl'] ??
          (latestBooking['imageUrls'] is List &&
                  (latestBooking['imageUrls'] as List).isNotEmpty
              ? (latestBooking['imageUrls'] as List).first
              : null),
    );
    final price =
        latestBooking['pricePerHour'] ??
        latestBooking['venuePricePerHour'] ??
        latestBooking['venue_price_per_hour'];
    final amount = price is num ? price.toDouble() : double.tryParse('$price');
    final date = '${latestBooking['date'] ?? ''}'.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _profilePage,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _profileLine),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 68,
                  height: 58,
                  child: image == null
                      ? const ColoredBox(
                          color: Color(0xFFFFF1E4),
                          child: Icon(
                            Icons.sports_tennis_rounded,
                            color: _profileOrange,
                          ),
                        )
                      : Image(
                          image: image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFFFFF1E4),
                            child: Icon(
                              Icons.sports_tennis_rounded,
                              color: _profileOrange,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _profileInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amount == null
                          ? 'Hourly rate unavailable'
                          : 'PHP ${amount.toStringAsFixed(2)} / hour',
                      style: const TextStyle(
                        color: _profileNavy,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      date.isEmpty ? 'Visit date unavailable' : 'Visited $date',
                      style: const TextStyle(
                        color: _profileMuted,
                        fontSize: 11,
                      ),
                    ),
                    if (details != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _profileMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badge != null)
                _smallPill(badge)
              else if (venue.bookings.length > 1) ...[
                const SizedBox(width: 6),
                _smallPill('${venue.bookings.length} visits'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _courtMatchHistoryCard(BuildContext context) {
    final bookings = _completed.take(2).toList();
    return _whiteCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'COURT MATCH HISTORY',
                style: TextStyle(
                  color: _profileOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _showCourtMatchHistory(context),
              child: const Text('View all'),
            ),
          ],
        ),
        if (_completed.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Completed bookings will appear here.',
                style: TextStyle(
                  color: _profileInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
        else ...[
          const SizedBox(height: 8),
          for (final entry in bookings.asMap().entries) ...[
            _historyBookingCard(context, entry.value, entry.key),
            if (entry.key < bookings.length - 1) const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Future<void> _showCourtMatchHistory(BuildContext context) =>
      _showProfileListSheet(
        context,
        title: 'Court match history',
        countLabel: '${_completed.length} completed',
        emptyText: 'No completed bookings yet.',
        children: _completed
            .asMap()
            .entries
            .map(
              (entry) => _historyBookingCard(context, entry.value, entry.key),
            )
            .toList(),
      );

  Future<void> _showVisitedVenues(BuildContext context) {
    final venues = _visitedVenueEntries;
    return _showProfileListSheet(
      context,
      title: 'Venues visited',
      countLabel: '${venues.length} venues',
      emptyText: 'No completed court visits yet.',
      children: venues.map(_visitedVenueItem).toList(),
    );
  }

  Future<void> _showProfileListSheet(
    BuildContext context, {
    required String title,
    required String countLabel,
    required String emptyText,
    required List<Widget> children,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: .72,
        minChildSize: .45,
        maxChildSize: .94,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: _profilePage,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _profileLine,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: _profileInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _smallPill(countLabel),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: children.isEmpty
                    ? Center(
                        child: Text(
                          emptyText,
                          style: const TextStyle(color: _profileMuted),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: children.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, index) => children[index],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyBookingCard(
    BuildContext context,
    Map<String, dynamic> booking,
    int index,
  ) => _visitedVenueItem(
    (name: '${booking['venueName'] ?? 'Venue'}', bookings: [booking]),
    details:
        'Completed · ${_time(booking['startTime'])} · '
        '${booking['durationHours'] ?? 0} hour(s) · '
        '${booking['players'] ?? 0} players',
    badge: '#${index + 1}',
    onTap: () => _showCompletedMatchDetails(context, booking, index),
  );

  Future<void> _showCompletedMatchDetails(
    BuildContext context,
    Map<String, dynamic> booking,
    int index,
  ) {
    final image = _avatarImage(
      booking['imageUrl'] ??
          (booking['imageUrls'] is List &&
                  (booking['imageUrls'] as List).isNotEmpty
              ? (booking['imageUrls'] as List).first
              : null),
    );
    final hourlyRate = _bookingAmount(
      booking['pricePerHour'] ?? booking['venuePricePerHour'],
    );
    final total = _bookingAmount(booking['total']);
    final extraPlayerCharge = _bookingAmount(booking['extraPlayerCharge']);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .88,
          ),
          decoration: const BoxDecoration(
            color: _profilePage,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _profileLine,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 190,
                    child: image == null
                        ? const ColoredBox(
                            color: Color(0xFFFFF1E4),
                            child: Icon(
                              Icons.sports_tennis_rounded,
                              color: _profileOrange,
                              size: 44,
                            ),
                          )
                        : Image(
                            image: image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: Color(0xFFFFF1E4),
                              child: Icon(
                                Icons.sports_tennis_rounded,
                                color: _profileOrange,
                                size: 44,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${booking['venueName'] ?? 'Venue'}',
                        style: const TextStyle(
                          color: _profileInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _smallPill('#${index + 1}'),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Completed court match',
                  style: TextStyle(
                    color: _profileOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _bookingDetailLine(
                  Icons.calendar_today_outlined,
                  '${booking['date'] ?? 'Date unavailable'} · '
                  '${_time(booking['startTime'])}',
                ),
                _bookingDetailLine(
                  Icons.schedule_outlined,
                  '${booking['durationHours'] ?? 0} hour(s) · '
                  '${booking['players'] ?? 0} players',
                ),
                _bookingDetailLine(
                  Icons.payment_outlined,
                  '${booking['paymentMethod'] ?? 'Payment method not specified'}',
                ),
                if (hourlyRate != null)
                  _bookingDetailLine(
                    Icons.sell_outlined,
                    'PHP ${hourlyRate.toStringAsFixed(2)} / hour',
                  ),
                if (extraPlayerCharge != null && extraPlayerCharge > 0)
                  _bookingDetailLine(
                    Icons.group_add_outlined,
                    'Extra player fee: PHP '
                    '${extraPlayerCharge.toStringAsFixed(2)}',
                  ),
                if (total != null)
                  _bookingDetailLine(
                    Icons.receipt_long_outlined,
                    'Booking total: PHP ${total.toStringAsFixed(2)}',
                  ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double? _bookingAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  String _time(dynamic value) {
    final raw = '$value';
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return raw;
    final period = hour >= 12 ? 'PM' : 'AM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display:${minute.toString().padLeft(2, '0')} $period';
  }

  // Kept as a reusable profile module for a future check-in flow.
  // ignore: unused_element
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

  // Kept as a reusable profile module for a future wallet flow.
  // ignore: unused_element
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

  // Kept as a reusable profile module for a future match flow.
  // ignore: unused_element
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

  Widget _whiteCard({
    required List<Widget> children,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) => Container(
    padding: padding,
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
    if (widget.onLogout != null) {
      await widget.onLogout!(context);
      return;
    }

    try {
      final navigator = Navigator.of(context);
      if (context.mounted) {
        navigator.popUntil((route) => route.isFirst);
      }

      await Future.wait<void>([
        FirebaseAuth.instance.signOut(),
        GoogleSignIn.instance.signOut(),
        AppSession.load().then((session) => session.clear()),
      ]);
    } catch (_) {
      if (context.mounted) {
        _message(context, 'Could not log out. Please try again.');
      }
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

  InputDecoration _profileInputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: _profileMuted, size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: _profilePage,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _profileLine),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _profileLine),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _profileOrange, width: 1.5),
    ),
  );

  bool _hasAvatar(dynamic value) {
    return value is String && value.trim().isNotEmpty;
  }

  ImageProvider<Object>? _avatarImage(dynamic value) {
    if (!_hasAvatar(value)) return null;
    final avatarUrl = (value as String).trim();
    if (avatarUrl.startsWith('data:image/')) {
      final separator = avatarUrl.indexOf(',');
      if (separator > 0 && separator < avatarUrl.length - 1) {
        return MemoryImage(base64Decode(avatarUrl.substring(separator + 1)));
      }
      return null;
    }
    return NetworkImage(avatarUrl);
  }
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
