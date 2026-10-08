import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'app_session.dart';
import 'features/activity_log/presentation/activity_log_routes.dart';
import 'saved_dashboard.dart';
import 'messages_dashboard.dart';
import 'customer_bookings_page.dart';
import 'news_feed.dart';
import 'auth_api.dart';
import 'booking_notifications.dart';
import 'app_bottom_navigation.dart';
import 'fitness_booking_calendar.dart';
import 'profile_image_preview.dart';
import 'qr_scanner_page.dart';
import 'core/booking_status.dart';
import 'core/business_type.dart';

import 'app_design_system.dart';
import 'app_preferences.dart';
import 'app_settings_page.dart';
import 'event_dashboard.dart';
import 'fitness_dashboard.dart';

const _profileNavy = AppColors.navy;
Color get _profileInk => AppColors.ink;
Color get _profileOrange => AppColors.accentForeground;
Color get _profilePage => AppColors.page;
Color get _profileMuted => AppColors.muted;
Color get _profileLine => AppColors.borderSubtle;

List<Map<String, dynamic>> bookingsForBusinessType(
  List<Map<String, dynamic>> bookings,
  String? businessType,
) {
  final requestedType = BusinessTypeParser.normalized(businessType)
      .toLowerCase();
  if (requestedType.isEmpty) return bookings;
  return bookings.where((booking) {
    final type = '${booking['businessType'] ?? ''}'.trim().toLowerCase();
    return requestedType == 'fitness & wellness'
        ? type == 'fitness' || type == 'fitness & wellness'
        : type == requestedType;
  }).toList();
}

class ProfileDashboardPage extends StatefulWidget {
  const ProfileDashboardPage({
    super.key,
    this.onLogout,
    this.initialUserPosition,
    this.businessType,
    this.api,
  });

  final Future<void> Function(BuildContext context)? onLogout;
  final Position? initialUserPosition;
  final String? businessType;
  final AuthApi? api;

  @override
  State<ProfileDashboardPage> createState() => _ProfileDashboardPageState();
}

class _ProfileDashboardPageState extends State<ProfileDashboardPage> {
  late final AuthApi _api;
  Timer? _bookingReminderTimer;
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _bookings = [];
  String _selectedHistoryTab = 'Upcoming match';
  bool _matchNotificationsEnabled = false;
  bool _updatingMatchNotificationSetting = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? AuthApi();
    if (_isFitnessProfile) {
      _selectedHistoryTab = 'Booking session';
    } else if (_isEventProfile) {
      _selectedHistoryTab = 'Upcoming event';
    }
    _loadProfile();
    _bookingReminderTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshBookingCountdown(),
    );
  }

  @override
  void dispose() {
    _bookingReminderTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final session = await AppSession.load();
      final token = session.apiToken;
      if (token != null && token.isNotEmpty) {
        final profile = await _api.me(token);
        final bookings = await _api.customerBookings(
          token,
          businessType: widget.businessType,
        );
        if (!mounted) return;
        setState(() {
          _user = profile['user'] as Map<String, dynamic>?;
          _bookings = bookings;
          _matchNotificationsEnabled = session.matchNotificationsEnabled;
        });
        _refreshBookingCountdown();
        if (_matchNotificationsEnabled &&
            BookingNotifications.instance.isSupported) {
          try {
            final notifications = BookingNotifications.instance;
            final allowed = await notifications.notificationsAllowed();
            if (!mounted) return;
            if (!allowed) {
              await session.setMatchNotificationsEnabled(false);
              if (!mounted) return;
              setState(() => _matchNotificationsEnabled = false);
            } else {
              await notifications.synchronizeApprovedBookings(
                accountKey: session.accountEmail ?? _email,
                bookings: bookings,
              );
            }
          } on Exception catch (error) {
            if (mounted) {
              _message(context, 'Could not check match alerts: $error');
            }
          }
        }
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

  bool get _isFitnessProfile => const {
    'fitness',
    'fitness & wellness',
  }.contains(BusinessTypeParser.normalized(widget.businessType).toLowerCase());

  bool get _isEventProfile =>
      BusinessTypeParser.parse(widget.businessType) == BusinessType.event;

  String get _historyTitle => _isFitnessProfile
      ? 'Fitness booking history'
      : _isEventProfile
      ? 'Event booking history'
      : 'Court match history';

  String get _upcomingTitle => _isFitnessProfile
      ? 'Booking session'
      : _isEventProfile
      ? 'Upcoming event'
      : 'Upcoming match';

  String get _peopleLabel => _isFitnessProfile
      ? 'participants'
      : _isEventProfile
      ? 'guests'
      : 'players';

  List<Map<String, dynamic>> get _profileBookings {
    return bookingsForBusinessType(_bookings, widget.businessType);
  }

  List<Map<String, dynamic>> get _upcoming => _profileBookings.where((booking) {
    return BookingStatusParser.isApproved(booking['status']);
  }).toList();

  List<Map<String, dynamic>> get _activeFitnessBookings {
    return _upcoming.where((booking) {
      return isFitnessBookingActive(booking);
    }).toList()..sort((first, second) {
      final firstDate = DateTime.tryParse('${first['date'] ?? ''}');
      final secondDate = DateTime.tryParse('${second['date'] ?? ''}');
      if (firstDate == null) return 1;
      if (secondDate == null) return -1;
      return firstDate.compareTo(secondDate);
    });
  }

  List<Map<String, dynamic>> get _completed => _profileBookings
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
          color: Theme.of(dialogContext).colorScheme.surface,
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
                          Icon(
                            Icons.person_outline_rounded,
                            color: _profileOrange,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: AppText(
                              'Edit profile',
                              style: TextStyle(
                                color: _profileInk,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                              localize: true,
                            ),
                          ),
                          IconButton(
                            tooltip: appLanguageText('Close', 'Close'),
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: _profileLine),
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
                                backgroundColor: AppColors.softOrangeAlt,
                                backgroundImage: _avatarImage(profileImage),
                                child: !_hasAvatar(profileImage)
                                    ? Icon(
                                        Icons.add_a_photo_outlined,
                                        color: _profileOrange,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            AppText(
                              'Tap photo to change',
                              style: TextStyle(
                                color: _profileMuted,
                                fontSize: 11,
                              ),
                              localize: true,
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: nameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _profileInputDecoration(
                                label: 'Name',
                                icon: Icons.person_outline,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: _profileInputDecoration(
                                label: 'Contact number',
                                icon: Icons.phone_outlined,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: addressController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _profileInputDecoration(
                                label: 'Address',
                                icon: Icons.location_on_outlined,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (hobbies.isNotEmpty)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: hobbies
                                      .map(
                                        (hobby) => InputChip(
                                          label: AppText(hobby),
                                          onDeleted: () => setDialogState(
                                            () => hobbies.remove(hobby),
                                          ),
                                          deleteIconColor: _profileOrange,
                                          labelStyle: TextStyle(
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
                            if (hobbies.isNotEmpty) const SizedBox(height: 6),
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
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: AppText(
                                'Press enter after each hobby',
                                style: TextStyle(
                                  color: _profileMuted,
                                  fontSize: 11,
                                ),
                                localize: true,
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
                              child: const AppText('Cancel', localize: true),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const AppText(
                                'Save changes',
                                localize: true,
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
          color: Theme.of(dialogContext).colorScheme.surface,
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
                        Icon(Icons.settings_outlined, color: _profileOrange),
                        const SizedBox(width: 6),
                        Expanded(
                          child: AppText(
                            appLanguageText('Settings', 'Mga Setting'),
                            style: Theme.of(dialogContext).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: appLanguageText(
                            'Close settings',
                            'Close settings',
                          ),
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: _profileLine),
                  const SizedBox(height: 6),
                  if (BookingNotifications.instance.isSupported)
                    StatefulBuilder(
                      builder: (context, setSettingsState) =>
                          _matchNotificationControl(
                            settingsContext: context,
                            setSettingsState: setSettingsState,
                          ),
                    ),
                  ListTile(
                    key: const ValueKey('profile-settings-appearance'),
                    leading: const Icon(Icons.palette_outlined),
                    title: AppText(
                      appLanguageText(
                        'Appearance & language',
                        'Hitsura at wika',
                      ),
                    ),
                    onTap: () => Navigator.pop(dialogContext, 'preferences'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: AppText(
                      appLanguageText('Edit profile', 'I-edit ang profile'),
                    ),
                    onTap: () => Navigator.pop(dialogContext, 'edit'),
                  ),
                  ListTile(
                    key: const ValueKey('profile-settings-activity-log'),
                    leading: const Icon(Icons.history_rounded),
                    title: AppText(
                      appLanguageText('Activity log', 'Tala ng aktibidad'),
                    ),
                    onTap: () => Navigator.pop(dialogContext, 'activity'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.swap_horiz_rounded),
                    title: AppText(
                      appLanguageText(
                        'Switch to Host Portal',
                        'Lumipat sa Portal ng Host',
                      ),
                    ),
                    onTap: () => Navigator.pop(dialogContext, 'switch'),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: Colors.red,
                    ),
                    title: AppText(
                      appLanguageText('Log out', 'Mag-log out'),
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () => Navigator.pop(dialogContext, 'logout'),
                  ),
                  const Spacer(),
                  Divider(height: 1, color: _profileLine),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AppText(
                        appLanguageText('SUPPORT', 'TULONG'),
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
                            label: AppText(
                              appLanguageText(
                                'Help Center',
                                'Sentro ng Tulong',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: TextButton.styleFrom(
                              padding: AppSpacing.buttonPadding,
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () =>
                                Navigator.pop(dialogContext, 'rules'),
                            icon: const Icon(Icons.gavel_outlined, size: 18),
                            label: AppText(
                              appLanguageText(
                                'Court Rules',
                                'Mga Panuntunan sa Court',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: TextButton.styleFrom(
                              padding: AppSpacing.buttonPadding,
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
    if (!mounted || !context.mounted) return;
    switch (action) {
      case 'edit':
        await _editProfile();
      case 'activity':
        await Navigator.of(context).push(ActivityLogRoutes.open(api: _api));
      case 'preferences':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AppSettingsPage()),
        );
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
        title: AppText(
          appLanguageText('Player Profile', 'Profile ng Manlalaro'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: appLanguageText('Scan QR code', 'Scan QR code'),
            onPressed: _openQrScanner,
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
          IconButton(
            tooltip: appLanguageText('Settings', 'Settings'),
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
              const SizedBox(height: 6),
              _statsCard(
                matches: _completed.length,
                venues: _completed
                    .map((booking) => booking['venueId'])
                    .toSet()
                    .length,
                fitness: _isFitnessProfile,
                event: _isEventProfile,
              ),
              const SizedBox(height: 6),
              _profileHistorySection(context),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(
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
                builder: (_) => SavedDashboardPage(
                  onLogout: widget.onLogout,
                  itemType: SavedDashboardPage.itemTypeForBusinessType(
                    widget.businessType,
                  ),
                  initialUserPosition: widget.initialUserPosition,
                ),
              ),
            );
            return;
          }
          if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MessagesDashboardPage(
                  initialUserPosition: widget.initialUserPosition,
                  api: widget.api,
                  businessType: widget.businessType,
                ),
              ),
            );
            return;
          }
          if (index == 3) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => CustomerBookingsPage(
                  onLogout: widget.onLogout,
                  api: widget.api,
                  initialUserPosition: widget.initialUserPosition,
                  businessType: widget.businessType,
                ),
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
      ),
    );
  }

  Future<void> _openExplore(BuildContext context) async {
    if (!context.mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _isEventProfile
            ? EventDashboardPage(
                onLogout: widget.onLogout,
                api: widget.api,
                initialUserPosition: widget.initialUserPosition,
              )
            : _isFitnessProfile
            ? FitnessDashboardPage(
                onLogout: widget.onLogout,
                api: widget.api,
                initialUserPosition: widget.initialUserPosition,
              )
            : NewsFeedPage(
                onLogout: widget.onLogout,
                api: widget.api,
                initialUserPosition: widget.initialUserPosition,
                businessType: widget.businessType ?? 'Sports',
              ),
      ),
    );
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
                TappableProfileAvatar(
                  radius: 31,
                  backgroundColor: AppColors.softOrangeAlt,
                  image: _avatarImage(avatarUrl),
                  fallback: AppText(
                    initials,
                    style: TextStyle(
                      color: _profileOrange,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        name,
                        style: TextStyle(
                          color: _profileInk,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      AppText(
                        email,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _profileMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      _profileHeaderDetail(
                        Icons.location_on_outlined,
                        address.isEmpty ? 'Add your address' : address,
                      ),
                      const SizedBox(height: 6),
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

  Widget _statsCard({
    required int matches,
    required int venues,
    required bool fitness,
    required bool event,
  }) => _whiteCard(
    padding: const EdgeInsets.symmetric(vertical: 14),
    children: [
      Row(
        children: [
          _Stat(
            value: '$matches',
            label: fitness
                ? 'Bookings'
                : event
                ? 'Events'
                : 'Matches',
          ),
          _statDivider(),
          _Stat(
            value: '$venues',
            label: _isEventProfile ? 'Event venues visited' : 'Venues visited',
          ),
        ],
      ),
    ],
  );

  Widget _statDivider() => Container(height: 34, width: 1, color: _profileLine);

  Widget _profileHistorySection(BuildContext context) {
    final historyTitle = _historyTitle;
    final tabs = [
      (
        title: _upcomingTitle,
        icon: Icons.book_outlined,
        key: 'upcoming-booking',
      ),
      (
        title: _isEventProfile ? 'Event venues visited' : 'Venues visited',
        icon: Icons.flag_outlined,
        key: 'venues-visited',
      ),
      (
        title: historyTitle,
        icon: Icons.list_alt_rounded,
        key: _isFitnessProfile
            ? 'fitness-booking-history'
            : _isEventProfile
            ? 'event-booking-history'
            : 'court-match-history',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
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
                        child: _profileHistoryTabIcon(
                          key: tab.key,
                          icon: tab.icon,
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
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AppText(
            _selectedHistoryTab,
            style: TextStyle(
              color: _profileInk,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 6),
        _selectedHistoryTab == tabs[1].title
            ? _visitedVenuesCard(context)
            : _selectedHistoryTab == historyTitle
            ? _courtMatchHistoryCard(context)
            : _upcomingBookingCard(context),
      ],
    );
  }

  Widget _profileHistoryTabIcon({
    required String key,
    required IconData icon,
    required Color color,
  }) {
    if (key != 'upcoming-booking' &&
        key != 'court-match-history' &&
        key != 'event-booking-history') {
      return Icon(icon, size: 23, color: color);
    }

    final isUpcoming = key == 'upcoming-booking';
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 2,
              child: Icon(icon, size: 22, color: color),
            ),
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isUpcoming
                      ? Icons.bookmark_rounded
                      : Icons.access_time_rounded,
                  size: 13,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _bookingStart(Map<String, dynamic> booking) {
    final date = '${booking['date'] ?? ''}'.trim();
    final time = '${booking['startTime'] ?? ''}'.trim();
    if (date.isEmpty || time.isEmpty) return null;
    return DateTime.tryParse('$date $time');
  }

  DateTime? _bookingEnd(Map<String, dynamic> booking) {
    final start = _bookingStart(booking);
    if (start == null) return null;
    final duration = booking['durationHours'];
    final durationHours = duration is num
        ? duration.toDouble()
        : double.tryParse('$duration') ?? 0;
    if (durationHours <= 0) return null;
    return start.add(
      Duration(seconds: (durationHours * Duration.secondsPerHour).round()),
    );
  }

  String _bookingCountdown(Map<String, dynamic> booking) {
    final start = _bookingStart(booking);
    final end = _bookingEnd(booking);
    if (start == null || end == null) return 'Schedule unavailable';
    final now = DateTime.now();
    if (!end.isAfter(now)) {
      return _isFitnessProfile
          ? 'Session complete'
          : _isEventProfile
          ? 'Event complete'
          : 'Match complete';
    }
    if (!start.isAfter(now)) {
      return 'In progress · ${_formatCountdown(end.difference(now))} left';
    }
    final difference = start.difference(DateTime.now());
    if (difference.isNegative || difference.inSeconds == 0) {
      return 'Starting now';
    }
    return '${_formatCountdown(difference)} left';
  }

  String _formatCountdown(Duration difference) {
    if (difference.inDays > 0) {
      final hours = difference.inHours.remainder(24);
      return '${difference.inDays}d ${hours}h';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes.remainder(60)}m';
    }
    return '${difference.inMinutes.clamp(1, 59)}m';
  }

  void _refreshBookingCountdown() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setMatchNotificationsEnabled(
    bool enabled, {
    required BuildContext settingsContext,
    required StateSetter setSettingsState,
  }) async {
    if (_updatingMatchNotificationSetting) return;
    setState(() => _updatingMatchNotificationSetting = true);
    if (settingsContext.mounted) {
      setSettingsState(() => _updatingMatchNotificationSetting = true);
    }
    try {
      final session = await AppSession.load();
      final notifications = BookingNotifications.instance;
      if (enabled) {
        final granted = await notifications.requestPermissions();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: const AppText(
                    'Allow notifications and exact alarms to receive match alerts.',
                    localize: true,
                  ),
                  action: SnackBarAction(
                    label: 'Settings',
                    onPressed: () => unawaited(_openNotificationSettings()),
                  ),
                ),
              );
          }
          return;
        }
        await notifications.synchronizeApprovedBookings(
          accountKey: session.accountEmail ?? _email,
          bookings: _bookings,
        );
      } else {
        await notifications.disableForAccount(session.accountEmail ?? _email);
      }
      await session.setMatchNotificationsEnabled(enabled);
      if (!mounted) return;
      setState(() => _matchNotificationsEnabled = enabled);
      if (settingsContext.mounted) {
        setSettingsState(() => _matchNotificationsEnabled = enabled);
      }
      _message(
        context,
        enabled
            ? 'Match start and end alerts are enabled.'
            : 'Match start and end alerts are turned off.',
      );
    } on Exception catch (error) {
      if (mounted) {
        _message(context, 'Could not update match alerts: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _updatingMatchNotificationSetting = false);
        if (settingsContext.mounted) {
          setSettingsState(() => _updatingMatchNotificationSetting = false);
        }
      }
    }
  }

  Future<void> _openNotificationSettings() async {
    try {
      final opened = await BookingNotifications.instance
          .openSystemNotificationSettings();
      if (opened != true && mounted) {
        _message(context, 'Could not open notification settings.');
      }
    } on Exception catch (error) {
      if (mounted) {
        _message(context, 'Could not open notification settings: $error');
      }
    }
  }

  Widget _matchNotificationControl({
    required BuildContext settingsContext,
    required StateSetter setSettingsState,
  }) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _profileLine),
    ),
    child: SwitchListTile.adaptive(
      key: const ValueKey('profile-match-notifications-switch'),
      value: _matchNotificationsEnabled,
      onChanged: _updatingMatchNotificationSetting
          ? null
          : (enabled) => _setMatchNotificationsEnabled(
              enabled,
              settingsContext: settingsContext,
              setSettingsState: setSettingsState,
            ),
      activeThumbColor: AppColors.accent,
      secondary: Icon(
        Icons.notifications_active_outlined,
        color: _profileOrange,
      ),
      title: AppText(
        'Match notifications',
        style: TextStyle(
          color: _profileInk,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        localize: true,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    ),
  );

  Widget _profileHeaderDetail(IconData icon, String text) => Row(
    children: [
      Icon(icon, color: _profileMuted, size: 13),
      const SizedBox(width: 6),
      Expanded(
        child: AppText(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: _profileMuted, fontSize: 10),
        ),
      ),
    ],
  );

  Widget _upcomingBookingCard(BuildContext context) {
    if (_isFitnessProfile) return _fitnessBookingSessionsCard(context);

    final booking = _upcoming.isEmpty ? null : _upcoming.first;
    if (booking == null) {
      return _whiteCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          AppText(
            _isEventProfile ? 'UPCOMING EVENT' : 'UPCOMING BOOKING',
            style: TextStyle(
              color: _profileOrange,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          AppText(
            _isEventProfile
                ? 'No approved event bookings yet.'
                : 'No approved bookings yet.',
            style: TextStyle(color: _profileInk, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          AppText(
            _isEventProfile
                ? 'Your event booking ticket will appear here after merchant approval.'
                : 'Your booking ticket will appear here after merchant approval.',
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
            Expanded(
              child: AppText(
                _isEventProfile ? 'UPCOMING EVENT' : 'UPCOMING BOOKING',
                style: TextStyle(
                  color: _profileOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _showAllUpcomingBookings(context),
              child: const AppText('View all', localize: true),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AppText(
          '${booking['venueName'] ?? 'Venue'}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _profileInk,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
          localize: true,
        ),
        const SizedBox(height: 6),
        AppText(
          '${booking['date'] ?? ''} · ${_time(booking['startTime'])} · '
          '${booking['durationHours'] ?? 0} hour(s)',
          textAlign: TextAlign.center,
          style: TextStyle(color: _profileMuted, fontSize: 11),
          localize: true,
        ),
        AppText(
          '${booking['players'] ?? 0} $_peopleLabel · '
          '${booking['paymentMethod'] ?? ''}',
          textAlign: TextAlign.center,
          style: TextStyle(color: _profileMuted, fontSize: 11),
          localize: true,
        ),
        ..._fitnessBookingDetails(booking),
        if (_isEventProfile &&
            '${booking['eventType'] ?? ''}'.trim().isNotEmpty)
          _bookingDetailLine(
            Icons.celebration_outlined,
            'Event type: ${booking['eventType']}',
          ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.softOrangeAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: _profileOrange,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: AppText(
                  _bookingCountdown(booking),
                  style: TextStyle(
                    color: _profileOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              Icons.confirmation_num_outlined,
              color: _profileOrange,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AppText(
                'Booking ticket is available in Messages.',
                style: TextStyle(color: _profileMuted, fontSize: 11),
                localize: true,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      MessagesDashboardPage(businessType: widget.businessType),
                ),
              ),
              child: const AppText('View Ticket', localize: true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _fitnessBookingSessionsCard(BuildContext context) {
    final bookings = _activeFitnessBookings;
    return _whiteCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      children: [
        Row(
          children: [
            Expanded(
              child: AppText(
                'ACTIVE BOOKING SESSION',
                style: TextStyle(
                  color: _profileOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
                localize: true,
              ),
            ),
            _smallPill('${bookings.length} active'),
          ],
        ),
        const SizedBox(height: 6),
        if (bookings.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: AppText(
              'No active fitness bookings yet.',
              style: TextStyle(
                color: _profileMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              localize: true,
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: AppText(
                    'Gym name',
                    style: TextStyle(
                      color: _profileMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    localize: true,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Center(
                    child: AppText(
                      'Price',
                      style: TextStyle(
                        color: _profileMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      localize: true,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Center(
                    child: AppText(
                      'Duration',
                      style: TextStyle(
                        color: _profileMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      localize: true,
                    ),
                  ),
                ),
              ),
              Expanded(flex: 2, child: SizedBox()),
            ],
          ),
          const Divider(height: 16),
          for (var index = 0; index < bookings.length; index++) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey(
                  'fitness-booking-calendar-row-${bookings[index]['id'] ?? index}',
                ),
                borderRadius: BorderRadius.circular(10),
                onTap: () =>
                    _showFitnessBookingCalendar(context, bookings[index]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AppText(
                            '${bookings[index]['venueName'] ?? 'Fitness venue'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _profileInk,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                            localize: true,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Center(
                            child: AppText(
                              _fitnessBookingPrice(bookings[index]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _profileInk,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Center(
                            child: AppText(
                              fitnessPlanDurationLabel(
                                '${bookings[index]['fitnessPlanType'] ?? ''}',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _profileInk,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: _profileOrange,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (index < bookings.length - 1) const Divider(height: 12),
          ],
        ],
      ],
    );
  }

  String _fitnessBookingPrice(Map<String, dynamic> booking) {
    final total =
        _bookingAmount(booking['total']) ??
        ((_bookingAmount(booking['fitnessPlanPrice']) ?? 0) +
            (_bookingAmount(booking['fitnessCoachPrice']) ?? 0));
    return '\u{20B1} ${total.toStringAsFixed(2)}';
  }

  Future<void> _showFitnessBookingCalendar(
    BuildContext context,
    Map<String, dynamic> booking,
  ) async {
    final startDate = DateTime.tryParse('${booking['date'] ?? ''}');
    if (startDate == null) {
      _message(context, 'The booking start date is unavailable.');
      return;
    }
    final bookingId = int.tryParse('${booking['id'] ?? ''}');
    if (bookingId == null || bookingId < 1) {
      _message(context, 'The booking ID is unavailable.');
      return;
    }
    final planType = '${booking['fitnessPlanType'] ?? ''}';
    final endDate = fitnessPlanEndDate(startDate, planType);
    final hours = '${booking['hours'] ?? ''}';
    final availability = '${booking['availability'] ?? ''}';
    String? token;
    String? attendanceWarning;
    var attendance = <String, String>{};
    try {
      final session = await AppSession.load();
      if (!context.mounted) return;
      token = session.apiToken;
      if (token == null || token.isEmpty) {
        attendanceWarning = 'Sign in again to sync attendance. The booking calendar is still available.';
      } else {
        try {
          final records = await _api.fitnessBookingAttendance(token, bookingId);
          if (!context.mounted) return;
          attendance = {
            for (final record in records)
              if (record['date'] is String &&
                  (record['status'] == 'present' ||
                      record['status'] == 'absent'))
                record['date'] as String: record['status'] as String,
          };
        } on Exception catch (error) {
          attendanceWarning = _fitnessAttendanceLoadWarning(error);
        }
      }
    } on Exception catch (error) {
      attendanceWarning = _fitnessAttendanceLoadWarning(error);
    }
    if (!context.mounted) return;
    final attendanceToken = token;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .88,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        'Booking session',
                        style: TextStyle(
                          color: _profileInk,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                        localize: true,
                      ),
                    ),
                    IconButton(
                      tooltip: appLanguageText(
                        'Close booking calendar',
                        'Close booking calendar',
                      ),
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                AppText(
                  '${booking['venueName'] ?? 'Fitness venue'} · '
                  '${_fitnessBookingPrice(booking)} · '
                  '${fitnessPlanDurationLabel(planType)}',
                  style: TextStyle(
                    color: _profileMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  localize: true,
                ),
                const SizedBox(height: 6),
                AppText(
                  '${_calendarDateLabel(startDate)} – '
                  '${_calendarDateLabel(endDate)}',
                  style: TextStyle(
                    color: _profileInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  localize: true,
                ),
                if (attendanceWarning != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    key: const ValueKey('fitness-attendance-sync-warning'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.softOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AppText(
                      attendanceWarning,
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                FitnessBookingCalendar(
                  startDate: startDate,
                  endDate: endDate,
                  hours: hours,
                  availability: availability,
                  attendance: attendance,
                  onAttendanceChanged: attendanceToken == null
                      ? null
                      : (date, status) async {
                          final dateKey = fitnessDateKey(date);
                          if (status == null) {
                            await _api.clearFitnessBookingAttendance(
                              token: attendanceToken,
                              bookingId: bookingId,
                              date: dateKey,
                            );
                          } else {
                            await _api.setFitnessBookingAttendance(
                              token: attendanceToken,
                              bookingId: bookingId,
                              date: dateKey,
                              status: status,
                            );
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _calendarDateLabel(DateTime date) =>
      '${date.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.year}';

  String _fitnessAttendanceLoadWarning(Object error) {
    if (error is AuthApiException &&
        error.statusCode == 404 &&
        error.message == 'The requested API endpoint was not found.') {
      return 'The running backend does not have attendance support yet. '
          'Restart the backend to sync attendance. The calendar is still '
          'available.';
    }
    return 'Could not load saved attendance. The calendar is available, '
        'but records may be out of date. $error';
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
          decoration: BoxDecoration(
            color: _profilePage,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 6),
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
                      child: AppText(
                        'Upcoming bookings',
                        style: TextStyle(
                          color: _profileInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                        localize: true,
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
                  separatorBuilder: (_, index) => const SizedBox(height: 6),
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
          const SizedBox(width: 6),
          Expanded(
            child: AppText(
              _isFitnessProfile
                  ? 'APPROVED FITNESS SESSION'
                  : _isEventProfile
                  ? 'APPROVED EVENT BOOKING'
                  : 'APPROVED BOOKING',
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
      const SizedBox(height: 6),
      AppText(
        '${booking['venueName'] ?? 'Venue'}',
        style: TextStyle(
          color: _profileInk,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
        localize: true,
      ),
      const SizedBox(height: 6),
      _bookingDetailLine(
        Icons.calendar_today_outlined,
        '${booking['date'] ?? ''} · ${_time(booking['startTime'])}',
      ),
      _bookingDetailLine(
        Icons.schedule_outlined,
        '${booking['durationHours'] ?? 0} hour(s) · '
        '${booking['players'] ?? 0} $_peopleLabel',
      ),
      if (_isEventProfile && '${booking['eventType'] ?? ''}'.trim().isNotEmpty)
        _bookingDetailLine(
          Icons.celebration_outlined,
          'Event type: ${booking['eventType']}',
        ),
      ..._fitnessBookingDetails(booking),
      _bookingDetailLine(
        Icons.payment_outlined,
        '${booking['paymentMethod'] ?? 'Payment method not specified'}',
      ),
      _bookingDetailLine(
        Icons.notifications_active_outlined,
        _bookingCountdown(booking),
      ),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  MessagesDashboardPage(businessType: widget.businessType),
            ),
          ),
          icon: const Icon(Icons.confirmation_num_outlined, size: 16),
          label: const AppText('View ticket', localize: true),
        ),
      ),
    ],
  );

  Widget _bookingDetailLine(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Row(
      children: [
        Icon(icon, color: _profileMuted, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: AppText(
            value,
            localize: true,
            style: TextStyle(color: _profileMuted, fontSize: 11),
          ),
        ),
      ],
    ),
  );

  List<Widget> _fitnessBookingDetails(Map<String, dynamic> booking) {
    if (!_isFitnessProfile) return const [];
    final details = <(IconData, String)>[];
    final instructor = '${booking['instructorName'] ?? ''}'.trim();
    final sessionDuration = int.tryParse(
      '${booking['sessionDurationMinutes'] ?? ''}',
    );
    final capacity = int.tryParse('${booking['classCapacity'] ?? ''}');
    final classSchedule = '${booking['classSchedule'] ?? ''}'.trim();
    if (instructor.isNotEmpty) {
      details.add((Icons.person_outline_rounded, 'Instructor: $instructor'));
    }
    if (sessionDuration != null && sessionDuration > 0) {
      details.add((
        Icons.timer_outlined,
        'Session length: $sessionDuration minutes',
      ));
    }
    if (capacity != null && capacity > 0) {
      details.add((Icons.groups_outlined, 'Class capacity: $capacity'));
    }
    if (classSchedule.isNotEmpty) {
      details.add((
        Icons.event_note_outlined,
        'Class schedule: $classSchedule',
      ));
    }
    return details
        .map((detail) => _bookingDetailLine(detail.$1, detail.$2))
        .toList();
  }

  Widget _visitedVenuesCard(BuildContext context) {
    final venues = _visitedVenueEntries;
    return _whiteCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 17),
      children: [
        Row(
          children: [
            Expanded(
              child: AppText(
                _isEventProfile ? 'EVENT VENUES VISITED' : 'VENUES VISITED',
                style: TextStyle(
                  color: _profileOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _showVisitedVenues(context),
              child: const AppText('View all', localize: true),
            ),
          ],
        ),
        if (venues.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppText(
                _isFitnessProfile
                    ? 'No completed studio visits yet.'
                    : _isEventProfile
                    ? 'No completed event visits yet.'
                    : 'No completed court visits yet.',
                style: TextStyle(
                  color: _profileInk,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else ...[
          const SizedBox(height: 6),
          for (final venue in venues.take(3)) ...[
            _visitedVenueItem(
              venue,
              onTap: () => _showVisitedVenueTimeline(context, venue),
            ),
            if (venue != venues.take(3).last) const SizedBox(height: 6),
          ],
        ],
      ],
    );
  }

  List<({String name, List<Map<String, dynamic>> bookings})>
  get _visitedVenueEntries {
    final venues =
        <String, ({String name, List<Map<String, dynamic>> bookings})>{};
    for (final booking in _completed) {
      final name = '${booking['venueName'] ?? 'Venue'}';
      final venueId = '${booking['venueId'] ?? ''}'.trim();
      final key = venueId.isEmpty ? name.toLowerCase() : venueId;
      final venue = venues.putIfAbsent(
        key,
        () => (name: name, bookings: <Map<String, dynamic>>[]),
      );
      venue.bookings.add(booking);
    }
    return venues.values.toList();
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
    final price = _isEventProfile
        ? latestBooking['eventFee'] ??
              latestBooking['event_fee'] ??
              latestBooking['pricePerHour']
        : latestBooking['pricePerHour'] ??
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
                      ? ColoredBox(
                          color: AppColors.softOrangeAlt,
                          child: Icon(
                            _isFitnessProfile
                                ? Icons.fitness_center_rounded
                                : _isEventProfile
                                ? Icons.celebration_outlined
                                : Icons.sports_tennis_rounded,
                            color: _profileOrange,
                          ),
                        )
                      : Image(
                          image: image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: AppColors.softOrangeAlt,
                            child: Icon(
                              _isFitnessProfile
                                  ? Icons.fitness_center_rounded
                                  : _isEventProfile
                                  ? Icons.celebration_outlined
                                  : Icons.sports_tennis_rounded,
                              color: _profileOrange,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      venue.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _profileInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppText(
                      amount == null
                          ? _isEventProfile
                                ? 'Event fee unavailable'
                                : 'Hourly rate unavailable'
                          : '\u{20B1} ${amount.toStringAsFixed(2)}'
                                '${_isEventProfile ? ' / event' : ' / hour'}',
                      style: TextStyle(
                        color: _profileInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppText(
                      date.isEmpty ? 'Visit date unavailable' : 'Visited $date',
                      style: TextStyle(color: _profileMuted, fontSize: 11),
                    ),
                    if (details != null) ...[
                      const SizedBox(height: 6),
                      AppText(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _profileMuted, fontSize: 11),
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
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: _profileMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _courtMatchHistoryCard(BuildContext context) {
    final bookings = _completed.take(3).toList();
    return _whiteCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: AppText(
                _isFitnessProfile
                    ? 'FITNESS BOOKING HISTORY'
                    : _isEventProfile
                    ? 'EVENT BOOKING HISTORY'
                    : 'COURT MATCH HISTORY',
                style: TextStyle(
                  color: _profileOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _showCourtMatchHistory(context),
              child: const AppText('View all', localize: true),
            ),
          ],
        ),
        if (_completed.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppText(
                _isFitnessProfile
                    ? 'Completed fitness bookings will appear here.'
                    : _isEventProfile
                    ? 'Completed event bookings will appear here.'
                    : 'Completed bookings will appear here.',
                style: TextStyle(
                  color: _profileInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
        else ...[
          const SizedBox(height: 6),
          for (final entry in bookings.asMap().entries) ...[
            _historyBookingCard(context, entry.value, entry.key),
            if (entry.key < bookings.length - 1) const SizedBox(height: 6),
          ],
        ],
      ],
    );
  }

  Future<void> _showCourtMatchHistory(BuildContext context) =>
      _showProfileListSheet(
        context,
        title: _isFitnessProfile
            ? 'Fitness booking history'
            : _isEventProfile
            ? 'Event booking history'
            : 'Court match history',
        countLabel: '${_completed.length} completed',
        emptyText: _isFitnessProfile
            ? 'No completed fitness bookings yet.'
            : _isEventProfile
            ? 'No completed event bookings yet.'
            : 'No completed bookings yet.',
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
      title: _isEventProfile ? 'Event venues visited' : 'Venues visited',
      countLabel: '${venues.length} venues',
      emptyText: _isFitnessProfile
          ? 'No completed studio visits yet.'
          : _isEventProfile
          ? 'No completed event visits yet.'
          : 'No completed court visits yet.',
      children: venues
          .map(
            (venue) => _visitedVenueItem(
              venue,
              onTap: () => _showVisitedVenueTimeline(context, venue),
            ),
          )
          .toList(),
    );
  }

  Future<void> _showVisitedVenueTimeline(
    BuildContext context,
    ({String name, List<Map<String, dynamic>> bookings}) venue,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .82,
        ),
        decoration: BoxDecoration(
          color: _profilePage,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 6),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: _profileLine,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          venue.name,
                          style: TextStyle(
                            color: _profileInk,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        AppText(
                          '${venue.bookings.length} ${venue.bookings.length == 1 ? 'completed visit' : 'completed visits'}',
                          style: TextStyle(color: _profileMuted, fontSize: 12),
                          localize: true,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: appLanguageText(
                      'Close venue visits',
                      'Close venue visits',
                    ),
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _profileLine),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                itemCount: venue.bookings.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final booking = venue.bookings[index];
                  final activityType = '${booking['category'] ?? ''}'.trim();
                  final businessType = '${booking['businessType'] ?? ''}'
                      .trim();
                  final createdAt = _exactBookingTimestamp(
                    booking['createdAt'],
                  );
                  final visitTime = _visitDateTime(booking);
                  return Container(
                    key: ValueKey(
                      'profile-venue-visit-${booking['id'] ?? index}',
                    ),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _profileLine),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isFitnessProfile
                                  ? Icons.fitness_center_rounded
                                  : Icons.event_available_outlined,
                              color: _profileOrange,
                              size: 19,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: AppText(
                                '${_isEventProfile ? 'Completed event' : 'Completed visit'} ${venue.bookings.length - index}',
                                style: TextStyle(
                                  color: _profileInk,
                                  fontWeight: FontWeight.w900,
                                ),
                                localize: true,
                              ),
                            ),
                          ],
                        ),
                        if (activityType.isNotEmpty ||
                            (businessType.isNotEmpty &&
                                !_isFitnessProfile)) ...[
                          const SizedBox(height: 6),
                          _bookingDetailLine(
                            _isFitnessProfile
                                ? Icons.fitness_center_rounded
                                : _isEventProfile
                                ? Icons.celebration_outlined
                                : Icons.sports_tennis_outlined,
                            [
                              if (activityType.isNotEmpty) activityType,
                              if (businessType.isNotEmpty &&
                                  !_isFitnessProfile &&
                                  businessType.toLowerCase() !=
                                      activityType.toLowerCase())
                                businessType,
                            ].join(' · '),
                          ),
                        ],
                        const SizedBox(height: 6),
                        _bookingDetailLine(
                          Icons.schedule_outlined,
                          'Visit: $visitTime',
                        ),
                        if (createdAt.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _bookingDetailLine(
                            Icons.history_rounded,
                            'Booking created: $createdAt',
                          ),
                        ],
                        const SizedBox(height: 6),
                        _bookingDetailLine(
                          Icons.group_outlined,
                          '${booking['durationHours'] ?? 0} hour(s) · '
                          '${booking['players'] ?? 0} $_peopleLabel',
                        ),
                        if (_isEventProfile &&
                            '${booking['eventType'] ?? ''}'.trim().isNotEmpty)
                          _bookingDetailLine(
                            Icons.celebration_outlined,
                            'Event type: ${booking['eventType']}',
                          ),
                        ..._fitnessBookingDetails(booking),
                        if (booking['id'] != null) ...[
                          const SizedBox(height: 6),
                          _bookingDetailLine(
                            Icons.confirmation_number_outlined,
                            'Booking #${booking['id']}',
                          ),
                        ],
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

  String _visitDateTime(Map<String, dynamic> booking) {
    final date = '${booking['date'] ?? ''}'.trim();
    final time = '${booking['startTime'] ?? ''}'.trim();
    if (date.isEmpty && time.isEmpty) return 'Schedule unavailable';
    if (date.isEmpty) return time;
    if (time.isEmpty) return date;
    return '$date · $time';
  }

  String _exactBookingTimestamp(dynamic value) {
    final timestamp = DateTime.tryParse('${value ?? ''}');
    if (timestamp == null) return '';
    final local = timestamp.toLocal();
    return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} '
        '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}:${_twoDigits(local.second)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

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
          decoration: BoxDecoration(
            color: _profilePage,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 6),
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
                      child: AppText(
                        title,
                        style: TextStyle(
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
                        child: AppText(
                          emptyText,
                          style: TextStyle(color: _profileMuted),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: children.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 6),
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
        '${_isFitnessProfile
            ? 'Completed session'
            : _isEventProfile
            ? 'Completed event'
            : 'Completed match'} · '
        '${_time(booking['startTime'])} · '
        '${booking['durationHours'] ?? 0} hour(s) · '
        '${booking['players'] ?? 0} $_peopleLabel'
        '${_isEventProfile && '${booking['eventType'] ?? ''}'.trim().isNotEmpty ? ' · ${booking['eventType']}' : ''}',
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
    final bookingRate = _bookingAmount(
      _isEventProfile
          ? booking['eventFee'] ??
                booking['event_fee'] ??
                booking['venuePricePerHour']
          : booking['pricePerHour'] ?? booking['venuePricePerHour'],
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
          decoration: BoxDecoration(
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
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 190,
                    child: image == null
                        ? ColoredBox(
                            color: AppColors.softOrangeAlt,
                            child: Icon(
                              _isEventProfile
                                  ? Icons.celebration_outlined
                                  : Icons.sports_tennis_rounded,
                              color: _profileOrange,
                              size: 44,
                            ),
                          )
                        : Image(
                            image: image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: AppColors.softOrangeAlt,
                              child: Icon(
                                _isEventProfile
                                    ? Icons.celebration_outlined
                                    : Icons.sports_tennis_rounded,
                                color: _profileOrange,
                                size: 44,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        '${booking['venueName'] ?? 'Venue'}',
                        style: TextStyle(
                          color: _profileInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                        localize: true,
                      ),
                    ),
                    _smallPill('#${index + 1}'),
                  ],
                ),
                const SizedBox(height: 6),
                AppText(
                  _isFitnessProfile
                      ? 'Completed fitness session'
                      : _isEventProfile
                      ? 'Completed event booking'
                      : 'Completed court match',
                  style: TextStyle(
                    color: _profileOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                _bookingDetailLine(
                  Icons.calendar_today_outlined,
                  '${booking['date'] ?? 'Date unavailable'} · '
                  '${_time(booking['startTime'])}',
                ),
                _bookingDetailLine(
                  Icons.schedule_outlined,
                  '${booking['durationHours'] ?? 0} hour(s) · '
                  '${booking['players'] ?? 0} $_peopleLabel',
                ),
                if (_isEventProfile &&
                    '${booking['eventType'] ?? ''}'.trim().isNotEmpty)
                  _bookingDetailLine(
                    Icons.celebration_outlined,
                    'Event type: ${booking['eventType']}',
                  ),
                ..._fitnessBookingDetails(booking),
                _bookingDetailLine(
                  Icons.payment_outlined,
                  '${booking['paymentMethod'] ?? 'Payment method not specified'}',
                ),
                if (bookingRate != null)
                  _bookingDetailLine(
                    Icons.sell_outlined,
                    '\u{20B1} ${bookingRate.toStringAsFixed(2)}'
                    '${_isEventProfile ? ' / event' : ' / hour'}',
                  ),
                if (extraPlayerCharge != null && extraPlayerCharge > 0)
                  _bookingDetailLine(
                    Icons.group_add_outlined,
                    'Extra player fee: ? '
                    '${extraPlayerCharge.toStringAsFixed(2)}',
                  ),
                if (total != null)
                  _bookingDetailLine(
                    Icons.receipt_long_outlined,
                    'Booking total: \u{20B1} ${total.toStringAsFixed(2)}',
                  ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const AppText('Close', localize: true),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'PLAYER FAST PASS',
                style: TextStyle(
                  color: _profileOrange,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
                localize: true,
              ),
              SizedBox(height: 6),
              AppText(
                'Court Express Check-in',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                localize: true,
              ),
              SizedBox(height: 6),
              AppText(
                'ID: #SLT-8824',
                style: TextStyle(color: Colors.white70, fontSize: 10),
                localize: true,
              ),
              SizedBox(height: 6),
              AppText(
                'Valid at 55 · Cebu Courts',
                style: TextStyle(color: Colors.white70, fontSize: 10),
                localize: true,
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
            const SizedBox(height: 6),
            FilledButton(
              onPressed: _openQrScanner,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                minimumSize: const Size(0, 30),
                padding: AppSpacing.buttonPadding,
              ),
              child: const AppText(
                'Scan at Venue',
                style: TextStyle(fontSize: 10),
                localize: true,
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
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Available Balance',
                  style: TextStyle(color: _profileMuted, fontSize: 10),
                  localize: true,
                ),
                AppText(
                  '₱1,850.00',
                  style: TextStyle(
                    color: _profileInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                  localize: true,
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: null,
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(AppColors.accent),
              foregroundColor: WidgetStatePropertyAll(AppColors.onAccent),
              padding: const WidgetStatePropertyAll(
                AppSpacing.buttonPadding,
              ),
            ),
            child: AppText(
              '＋ Top Up',
              style: TextStyle(fontSize: 10),
              localize: true,
            ),
          ),
        ],
      ),
      const Divider(height: 20),
      Row(
        children: [
          Icon(Icons.local_offer_outlined, color: _profileOrange, size: 15),
          SizedBox(width: 6),
          Expanded(
            child: AppText(
              'Promo Court Credits',
              style: TextStyle(color: _profileMuted, fontSize: 10),
              localize: true,
            ),
          ),
          AppText(
            '₱350.00',
            style: TextStyle(
              color: _profileOrange,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
            localize: true,
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
          Expanded(
            child: AppText(
              '● NEXT COURT MATCH',
              style: TextStyle(
                color: _profileOrange,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
              localize: true,
            ),
          ),
          _smallPill('Tonight'),
        ],
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.softOrangeAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: AppText(
              'OCT\n24',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _profileOrange,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
              localize: true,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'SLT Court · Court 1 (Outdoor)',
                  style: TextStyle(
                    color: _profileInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  localize: true,
                ),
                SizedBox(height: 6),
                AppText(
                  '7:00 PM - 8:30 PM · 1.5 hrs',
                  style: TextStyle(color: _profileMuted, fontSize: 10),
                  localize: true,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Icon(Icons.location_on_outlined, color: _profileMuted, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: AppText(
              'Minglanilla, Cebu',
              style: TextStyle(color: _profileMuted, fontSize: 10),
              localize: true,
            ),
          ),
          TextButton(
            onPressed: () =>
                _message(context, 'Your ticket details are ready.'),
            child: AppText(
              'View Ticket →',
              style: TextStyle(color: _profileOrange, fontSize: 10),
              localize: true,
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
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _profileLine),
    ),
    child: Column(children: children),
  );

  Widget _smallPill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
    ),
    child: AppText(text, style: TextStyle(color: _profileInk, fontSize: 9)),
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
        AppPreferences.instance.load(),
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
      ..showSnackBar(SnackBar(content: AppText(message)));
  }

  Future<void> _openQrScanner() async {
    final scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const QrScannerPage(),
      ),
    );
    if (!mounted || scannedValue == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('QR code scanned', localize: true),
        content: SelectableText(scannedValue),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const AppText('Close', localize: true),
          ),
        ],
      ),
    );
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
    labelText: appLanguageText(label, label),
    prefixIcon: Icon(icon, color: _profileMuted, size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: _profilePage,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: _profileLine),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: _profileLine),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: _profileOrange, width: 1.5),
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
        AppText(
          value,
          style: TextStyle(color: _profileInk, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        AppText(label, style: TextStyle(color: _profileMuted, fontSize: 9)),
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
