import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_bottom_navigation.dart';
import 'app_session.dart';
import 'auth_api.dart';
import 'core/booking_status.dart';
import 'merchant_add_page.dart';
import 'merchant_profile_dashboard.dart';
import 'messages_dashboard.dart';
import 'skeleton_loader.dart';
import 'app_card_styles.dart';
import 'app_design_system.dart';
import 'app_preferences.dart';

part 'merchant_dashboard_analytics.dart';
part 'merchant_dashboard_analytics_section.dart';

const _merchantNavy = AppColors.navy;
Color get _merchantInk => AppColors.ink;
Color get _merchantOrange => AppColors.accent;
Color get _merchantPage => AppColors.page;
Color get _merchantMuted => AppColors.muted;
Color get _merchantLine => AppColors.border;

class _MerchantDashboardLoadingSkeleton extends StatelessWidget {
  const _MerchantDashboardLoadingSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey('merchant-dashboard-loading-skeleton'),
    padding: const EdgeInsets.all(16),
    children: [
      const Row(
        children: [
          SkeletonBlock(width: 54, height: 54, borderRadius: 27),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBlock(width: 170, height: 18),
                SizedBox(height: 8),
                SkeletonBlock(width: 110, height: 12),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      const Row(
        children: [
          Expanded(child: SkeletonBlock(height: 92, borderRadius: 16)),
          SizedBox(width: 12),
          Expanded(child: SkeletonBlock(height: 92, borderRadius: 16)),
        ],
      ),
      const SizedBox(height: 16),
      const SkeletonBlock(height: 230, borderRadius: 18),
      const SizedBox(height: 16),
      const SkeletonBlock(height: 170, borderRadius: 18),
    ],
  );
}

class MerchantDashboardPage extends StatefulWidget {
  const MerchantDashboardPage({super.key, this.onLogout, this.api});

  final Future<void> Function(BuildContext context)? onLogout;
  final AuthApi? api;

  @override
  State<MerchantDashboardPage> createState() => _MerchantDashboardPageState();
}

class _MerchantDashboardPageState extends State<MerchantDashboardPage> {
  late final AuthApi _api;
  final _formKey = GlobalKey<FormState>();
  final _merchantAddPageKey = GlobalKey<MerchantAddPageState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _businessName = TextEditingController();
  final _businessType = TextEditingController();
  final _registrationNumber = TextEditingController();
  final _address = TextEditingController();
  final _contactEmail = TextEditingController();
  final _designation = TextEditingController();
  final _venueSearchController = TextEditingController();
  final _payoutSearchController = TextEditingController();
  final _selectedCategories = <String>{};
  final _imagePicker = ImagePicker();
  String _facilityType = 'Indoor';
  String? _businessTypeValue;
  String? _selectedBookingType;
  String _venueSearchQuery = '';
  final _customCategories = <String>{};
  Map<String, dynamic> _owner = const {};
  String? _profileImage;
  String? _businessImage;
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _businesses = [];
  List<Map<String, dynamic>> _bookings = [];
  int _merchantTab = 0;
  int _payoutTab = 0;
  String _payoutBookingType = 'All';
  String _payoutSearchQuery = '';
  Timer? _payoutRefreshTimer;

  String _analyticsPeriod = 'Daily';
  String _analyticsView = 'Sales report';
  String _venueComparisonMetric = 'Bookings';
  DateTimeRange? _analyticsDateRange;

  void _setAnalyticsState(VoidCallback callback) => setState(callback);

  List<Map<String, dynamic>> get _visibleBusinesses {
    return _businesses.where((business) {
      final enabled = business['enabled'];
      final isEnabled =
          enabled != false &&
          enabled != 0 &&
          enabled != '0' &&
          enabled != 'false' &&
          enabled != 'FALSE';
      return isEnabled &&
          (_selectedBookingType == null ||
              business['businessType'] == _selectedBookingType);
    }).toList();
  }

  List<Map<String, dynamic>> get _liveBusinesses =>
      _visibleBusinesses.where(_isLiveOnApp).toList();

  bool _isLiveOnApp(Map<String, dynamic> business) {
    final value = business['hasPublishedNewsCard'];
    return value == true ||
        value == 1 ||
        value == '1' ||
        value == 'true' ||
        value == 'TRUE';
  }

  static const _categoriesByBusinessType = {
    'Sports': ['Tennis', 'Pickleball', 'Basketball', 'Volleyball', 'Badminton'],
    'Event': ['Ballroom', 'Terrace', 'Private Dining', 'Garden'],
    'Fitness & Wellness': [
      'CrossFit',
      'Pilates',
      'Boxing',
      'Yoga',
      'Zumba',
      'Martial Arts',
    ],
  };

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? AuthApi();
    _loadProfile();
  }

  @override
  void dispose() {
    _payoutRefreshTimer?.cancel();
    for (final controller in [
      _firstName,
      _lastName,
      _phone,
      _businessName,
      _businessType,
      _registrationNumber,
      _address,
      _contactEmail,
      _designation,
      _venueSearchController,
      _payoutSearchController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final session = await AppSession.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Your session has expired.', 401);
      }
      final response = await _api.merchantProfile(token);
      final profile = response['profile'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _owner = profile;
        _profileImage = profile['avatarUrl'] as String?;
        _businessImage = profile['businessImage'] as String?;
        _firstName.text = profile['firstName'] as String? ?? '';
        _lastName.text = profile['lastName'] as String? ?? '';
        _phone.text = profile['phone'] as String? ?? '';
        _businessName.text = profile['businessName'] as String? ?? '';
        _businessTypeValue = profile['businessType'] as String?;
        _businessType.text = _businessTypeValue ?? '';
        _registrationNumber.text =
            profile['registrationNumber'] as String? ?? '';
        _address.text = profile['address'] as String? ?? '';
        _contactEmail.text = profile['contactEmail'] as String? ?? '';
        _designation.text = profile['ownerDesignation'] as String? ?? '';
        _facilityType = profile['facilityType'] as String? ?? 'Indoor';
        _selectedCategories
          ..clear()
          ..addAll(
            (profile['categories'] as List<dynamic>? ?? []).whereType<String>(),
          );
        _customCategories
          ..clear()
          ..addAll(
            _selectedCategories.where(
              (category) =>
                  !(_categoriesByBusinessType[_businessTypeValue] ?? const [])
                      .contains(category),
            ),
          );
      });
      await _loadBusinesses();
      await _loadBookings();
    } on Exception catch (error) {
      if (mounted) {
        _showMessage('Could not load merchant profile: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? true)) return false;
    setState(() => _saving = true);
    try {
      final session = await AppSession.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Your session has expired.', 401);
      }
      await _api.saveMerchantProfile(
        token: token,
        profile: {
          'firstName': _firstName.text.trim(),
          'lastName': _lastName.text.trim(),
          'phone': _phone.text.trim(),
          'businessName': _businessName.text.trim(),
          'businessType': _businessType.text.trim(),
          'registrationNumber': _registrationNumber.text.trim(),
          'categories': _selectedCategories.toList(),
          'facilityType': _facilityType,
          'address': _address.text.trim(),
          'contactEmail': _contactEmail.text.trim(),
          'ownerDesignation': _designation.text.trim(),
          'profileImage': _profileImage,
          'businessImage': _businessImage,
        },
      );
      final accountEmail =
          (_owner['email'] as String?) ?? session.accountEmail ?? '';
      if (accountEmail.isNotEmpty) {
        await session.markMerchantProfileCompleted(accountEmail);
      }
      await _loadBusinesses();
      _showMessage('Merchant profile saved and ready for customer listings.');
      return true;
    } on Exception catch (error) {
      _showMessage('Could not save merchant profile: $error');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: AppText(message)));
  }

  Widget _merchantSectionNotice({
    required String key,
    required String title,
    required String message,
  }) => IconButton(
    key: ValueKey(key),
    tooltip: appLanguageText('About $title', 'About $title'),
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    icon: const Icon(Icons.info_outline_rounded, size: 19),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText(title),
        content: AppText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const AppText('Got it', localize: true),
          ),
        ],
      ),
    ),
  );

  Future<Map<String, dynamic>?> _openMerchantEditPanel() async {
    var panelProfileImage = _profileImage;
    final saved = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close merchant profile editor',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (panelContext, animation, secondaryAnimation) =>
          StatefulBuilder(
            builder: (panelContext, setPanelState) => Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: AppColors.surface,
                child: SizedBox(
                  width: MediaQuery.sizeOf(panelContext).width * .88,
                  height: double.infinity,
                  child: SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.storefront_outlined,
                                color: _merchantOrange,
                              ),
                              const SizedBox(width: 10),
                               Expanded(
                                child: AppText(
                                  'Edit merchant profile',
                                  style: TextStyle(
                                    color: _merchantInk,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                 localize: true,),
                              ),
                              IconButton(
                                onPressed: () =>
                                    Navigator.pop(panelContext, false),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: Column(
                            children: [
                              const SizedBox(height: 18),
                              GestureDetector(
                                onTap: () async {
                                  final selected = await _pickProfileImage();
                                  if (selected == null) return;
                                  panelProfileImage = selected;
                                  if (mounted) setPanelState(() {});
                                },
                                child: CircleAvatar(
                                  radius: 42,
                                  backgroundColor: AppColors.softOrange,
                                  backgroundImage: _imageProvider(
                                    panelProfileImage,
                                  ),
                                  child: panelProfileImage == null
                                      ? Icon(
                                          Icons.add_a_photo_outlined,
                                          color: _merchantOrange,
                                          size: 25,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 8),
                               AppText(
                                'Tap to upload avatar',
                                style: TextStyle(
                                  color: _merchantMuted,
                                  fontSize: 11,
                                ),
                               localize: true,),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Form(
                                  key: _formKey,
                                  child: ListView(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      6,
                                      20,
                                      20,
                                    ),
                                    children: [
                                      _field(
                                        _firstName,
                                        'First name',
                                        'First name',
                                      ),
                                      const SizedBox(height: 10),
                                      _field(
                                        _lastName,
                                        'Last name',
                                        'Last name',
                                      ),
                                      const SizedBox(height: 10),
                                      _field(
                                        _phone,
                                        'Direct contact phone',
                                        'Contact phone',
                                        keyboardType: TextInputType.phone,
                                      ),
                                      const SizedBox(height: 10),
                                      _field(
                                        _address,
                                        'Address',
                                        'Address',
                                        required: false,
                                        maxLines: 2,
                                      ),
                                      const SizedBox(height: 10),
                                      _field(
                                        _contactEmail,
                                        'Official business email',
                                        'Business email',
                                        required: false,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  10,
                                  20,
                                  18,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            Navigator.pop(panelContext, false),
                                        child: const AppText('Cancel', localize: true),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: _saving
                                            ? null
                                            : () async {
                                                final didSave =
                                                    await _saveProfile();
                                                if (didSave &&
                                                    panelContext.mounted) {
                                                  Navigator.pop(
                                                    panelContext,
                                                    true,
                                                  );
                                                }
                                              },
                                        child: const AppText('Save changes', localize: true),
                                      ),
                                    ),
                                  ],
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
    if (saved == true && mounted) {
      await _loadProfile();
      return {'owner': _owner, 'profileImage': _profileImage};
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _merchantPage,
      appBar: AppBar(
        toolbarHeight: 56,
        titleSpacing: 16,
        leadingWidth: 56,
        titleTextStyle: AppTypography.pageTitle,
        title: _merchantTab == 1
            ? Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                         Flexible(
                          child: AppText(
                            'Add business',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.pageTitle,
                           localize: true,),
                        ),
                        const SizedBox(width: 4),
                        _merchantSectionNotice(
                          key: 'merchant-add-info',
                          title: 'Add business',
                          message: 'Complete a News Card for each business before its Booking Card is published.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () =>
                        _merchantAddPageKey.currentState?.openAddBusinessForm(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const AppText('Add', localize: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: _merchantOrange,
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              )
            : _merchantTab == 3
            ? Row(
                children: [
                   AppText('Payouts', style: AppTypography.pageTitle, localize: true),
                  _merchantSectionNotice(
                    key: 'merchant-payouts-info',
                    title: 'Payouts',
                    message: 'Manage booking requests and track your earnings.',
                  ),
                ],
              )
            : AppText(switch (_merchantTab) {
                0 => 'Merchant Dashboard',
                1 => 'Add business',
                3 => 'Payouts',
                _ => 'Merchant Dashboard',
              }),
        backgroundColor: _merchantPage,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _merchantInk,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      bottomNavigationBar: _merchantBottomNavigation(),
      body: _loading
          ? const _MerchantDashboardLoadingSkeleton()
          : _merchantContent(),
    );
  }

  Widget _merchantContent() {
    if (_merchantTab == 1) {
      return MerchantAddPage(
        key: _merchantAddPageKey,
        initialBusinessType: _businessTypeValue,
        businesses: _businesses,
        onBusinessesChanged: _loadBusinesses,
      );
    }
    if (_merchantTab == 3) {
      return _merchantPayouts();
    }
    if (_merchantTab == 2 || _merchantTab == 4) {
      return const SizedBox.shrink();
    }
    if (_merchantTab == 0) return _merchantAnalyticsDashboard();
    return _merchantHome();
  }

  Widget _merchantPayouts() => RefreshIndicator(
    onRefresh: _loadBookings,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(flex: 2, child: _payoutTypeFilter()),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: _payoutSearchBar()),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          key: const ValueKey('merchant-payout-tabs'),
          style: _analyticsFilterStyle,
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 0, label: AppText('Booking requests', localize: true)),
            ButtonSegment(value: 1, label: AppText('Active bookings', localize: true)),
            ButtonSegment(value: 2, label: AppText('Payout track', localize: true)),
          ],
          selected: {_payoutTab},
          onSelectionChanged: (selection) {
            setState(() => _payoutTab = selection.first);
          },
        ),
        const SizedBox(height: 20),
        if (_payoutTab == 0)
          _bookingRequestsContent()
        else if (_payoutTab == 1)
          _activeBookingsContent()
        else
          _payoutTrackContent(),
      ],
    ),
  );

  Widget _bookingRequestsContent() {
    final requests = _filteredPayoutBookings.where(_isPendingBooking).toList();
    final hasRequests = requests.isNotEmpty;
    return hasRequests
        ? _pendingBookingsCard(requests)
        : _emptyPayoutCard(
            Icons.inbox_outlined,
            'No booking requests',
            'New customer requests will appear here. Approved bookings move to Active bookings.',
          );
  }

  Widget _payoutTrackContent() {
    final tracked = _filteredPayoutBookings.where(_isFinishedBooking).toList();
    if (tracked.isEmpty) {
      return _emptyPayoutCard(
        Icons.payments_outlined,
        'No completed bookings',
        'Bookings will appear here automatically after their scheduled end.',
      );
    }

    return Column(
      children: [
        for (final booking in tracked) ...[
          _payoutBookingCard(booking),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _activeBookingsContent() {
    final active = _filteredPayoutBookings.where(_isApprovedBooking).toList();
    if (active.isEmpty) {
      return _emptyPayoutCard(
        Icons.event_available_outlined,
        'No active bookings',
        'Approved bookings will appear here until their scheduled end time.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: AppText(
            'Approved bookings finish automatically at their scheduled end.',
            style: TextStyle(color: _merchantMuted, fontSize: 13),
           localize: true,),
        ),
        for (final booking in active) ...[
          _payoutBookingCard(booking),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  List<Map<String, dynamic>> get _filteredPayoutBookings {
    return _bookings.where((booking) {
      final matchesType =
          _payoutBookingType == 'All' ||
          booking['businessType'] == _payoutBookingType;
      if (!matchesType || _payoutSearchQuery.isEmpty) return matchesType;
      final searchable = [
        booking['customerName'],
        booking['customerEmail'],
        booking['venueName'],
        booking['businessName'],
        booking['businessType'],
        booking['date'],
        booking['status'],
        booking['id'],
      ].whereType<Object>().join(' ').toLowerCase();
      return searchable.contains(_payoutSearchQuery);
    }).toList();
  }

  Widget _payoutSearchBar() => TextField(
    key: const ValueKey('merchant-payout-search'),
    controller: _payoutSearchController,
    onChanged: (value) =>
        setState(() => _payoutSearchQuery = value.trim().toLowerCase()),
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: appLanguageText('Search bookings', 'Search bookings'),
      hintStyle: const TextStyle(fontSize: 12),
      prefixIcon: const Icon(Icons.search_rounded, size: 18),
      prefixIconConstraints: const BoxConstraints(minWidth: 36),
      suffixIcon: _payoutSearchQuery.isEmpty
          ? null
          : IconButton(
              tooltip: appLanguageText('Clear search', 'Clear search'),
              onPressed: () {
                _payoutSearchController.clear();
                setState(() => _payoutSearchQuery = '');
              },
              icon: const Icon(Icons.clear_rounded, size: 18),
              visualDensity: VisualDensity.compact,
            ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      constraints: const BoxConstraints(minHeight: 40, maxHeight: 40),
      border:  OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _merchantLine),
      ),
      enabledBorder:  OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _merchantLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _merchantOrange, width: 1.5),
      ),
    ),
  );

  Widget _payoutTypeFilter() {
    return DropdownButtonFormField<String>(
      key: const ValueKey('merchant-payout-type-filter'),
      initialValue: _payoutBookingType,
      isExpanded: true,
      style:  TextStyle(
        color: _merchantInk,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      iconSize: 18,
      decoration:  InputDecoration(
        hintText: appLanguageText('All booking types', 'All booking types'),
        prefixIcon: Icon(Icons.filter_list_rounded, size: 18),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        constraints: BoxConstraints(minHeight: 40, maxHeight: 40),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _merchantLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _merchantLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _merchantOrange, width: 1.5),
        ),
      ),
      items: const [
        DropdownMenuItem(
          value: 'All',
          child: AppText('All booking types', maxLines: 1, localize: true),
        ),
        DropdownMenuItem(value: 'Sports', child: AppText('Sports', maxLines: 1, localize: true)),
        DropdownMenuItem(value: 'Event', child: AppText('Event', maxLines: 1, localize: true)),
        DropdownMenuItem(
          value: 'Fitness & Wellness',
          child: AppText('Fitness & Wellness', maxLines: 1, localize: true),
        ),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _payoutBookingType = value);
      },
    );
  }

  Widget _emptyPayoutCard(IconData icon, String title, String message) {
    return Card(
      elevation: 0,
      color: AppColors.softOrange,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: _merchantOrange, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    title,
                    style:  TextStyle(
                      color: _merchantInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AppText(message, style:  TextStyle(color: _merchantInk)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isPendingBooking(Map<String, dynamic> booking) =>
      BookingStatusParser.isPending(booking['status']);

  bool _isApprovedBooking(Map<String, dynamic> booking) =>
      BookingStatusParser.isApproved(booking['status']);

  bool _isFinishedBooking(Map<String, dynamic> booking) =>
      BookingStatusParser.parse(booking['status']) == BookingStatus.finished ||
      BookingStatusParser.parse(booking['status']) == BookingStatus.completed ||
      BookingStatusParser.parse(booking['status']) == BookingStatus.done;

  Widget _payoutBookingCard(Map<String, dynamic> booking) {
    final total = _bookingAmount(booking['total']);
    final downpayment = _bookingAmount(booking['downpayment']);
    final balance = total - downpayment;
    final finished = _isFinishedBooking(booking);
    return Card(
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppText(
                    '${booking['venueName'] ?? 'Venue'} · '
                    '${booking['customerName'] ?? 'Customer'}',
                    style:  TextStyle(
                      color: _merchantInk,
                      fontWeight: FontWeight.w800,
                    ),
                   localize: true,),
                ),
                Chip(
                  label: AppText(finished ? 'Finished' : 'Active'),
                  backgroundColor: finished
                      ? const Color(0xFFE4F5E9)
                      : AppColors.softOrange,
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppText(
              '${_bookingServiceLabel(booking)} · '
              '${booking['date']} ${booking['startTime']} · '
              '${_bookingVisitLabel(booking)}',
              style: TextStyle(color: Colors.grey.shade700),
             localize: true,),
            const SizedBox(height: 12),
            AppText('Total: PHP ${total.toStringAsFixed(2)}', localize: true),
            if ('${booking['fitnessPlanType'] ?? ''}'.isNotEmpty)
              AppText(
                'Plan: PHP ${_bookingAmount(booking['fitnessPlanPrice']).toStringAsFixed(2)}'
                '${'${booking['fitnessCoachName'] ?? ''}'.isEmpty ? '' : ' · Coach ${booking['fitnessCoachName']}: PHP ${_bookingAmount(booking['fitnessCoachPrice']).toStringAsFixed(2)}'}',
               localize: true,),
            if (_bookingAmount(booking['extraPlayerCharge']) > 0)
              AppText(
                'Extra-player fee: PHP '
                '${_bookingAmount(booking['extraPlayerCharge']).toStringAsFixed(2)}',
               localize: true,),
            AppText('Downpayment received: PHP ${downpayment.toStringAsFixed(2)}', localize: true),
            AppText('Remaining balance: PHP ${balance.toStringAsFixed(2)}', localize: true),
          ],
        ),
      ),
    );
  }

  double _bookingAmount(dynamic value) {
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }

  String _bookingServiceLabel(Map<String, dynamic> booking) {
    final plan = '${booking['fitnessPlanType'] ?? ''}';
    final category = '${booking['fitnessCategory'] ?? ''}';
    final coach = '${booking['fitnessCoachName'] ?? ''}';
    final isEvent = '${booking['businessType'] ?? ''}'.toLowerCase() == 'event';
    final eventType = '${booking['eventType'] ?? ''}';
    if (isEvent) {
      return eventType.isEmpty ? 'Event booking' : eventType;
    }
    if (plan.isNotEmpty) {
      final planLabel = '${plan[0].toUpperCase()}${plan.substring(1)} plan';
      return '${category.isEmpty ? booking['sportType'] : category} · '
          '$planLabel${coach.isEmpty ? '' : ' · Coach $coach'}';
    }
    final area =
        booking['occupiesFullStudio'] == true ||
            booking['occupiesFullStudio'] == 1
        ? 'Whole studio'
        : 'Slot ${booking['slotNumber'] ?? '—'}';
    return '${booking['sportType'] ?? 'Sport'} · $area';
  }

  String _bookingVisitLabel(Map<String, dynamic> booking) {
    if ('${booking['fitnessPlanType'] ?? ''}'.isNotEmpty) {
      return 'First visit';
    }
    return '${booking['businessType'] ?? ''}'.toLowerCase() == 'event'
        ? '${booking['players']} guests'
        : '${booking['players']} players';
  }

  Widget _merchantHome() => RefreshIndicator(
    onRefresh: () async {
      await _loadBusinesses();
      await _loadBookings();
    },
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final businesses = _visibleBusinesses
            .where(_venueMatchesSearch)
            .toList();
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 8, wide ? 24 : 16, 28),
          children: [
            const SizedBox(height: 12),
            _venueSearchBar(),
            const SizedBox(height: 14),
            _venueSwitcher(),
            const SizedBox(height: 16),
            if (businesses.isEmpty)
              _emptyBusinesses()
            else
              _businessGrid(businesses, wide),
          ],
        );
      },
    ),
  );

  Widget _venueSearchBar() {
    return TextField(
      controller: _venueSearchController,
      onChanged: (value) =>
          setState(() => _venueSearchQuery = value.trim().toLowerCase()),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: appLanguageText('Search your venues...', 'Search your venues...'),
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _venueSearchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: appLanguageText('Clear search', 'Clear search'),
                onPressed: () {
                  _venueSearchController.clear();
                  setState(() => _venueSearchQuery = '');
                },
                icon: const Icon(Icons.clear_rounded),
              ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:  BorderSide(color: _merchantLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:  BorderSide(color: _merchantLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _merchantOrange, width: 1.5),
        ),
      ),
    );
  }

  bool _venueMatchesSearch(Map<String, dynamic> business) {
    if (_venueSearchQuery.isEmpty) return true;
    final searchable = [
      business['name'],
      business['category'],
      business['businessType'],
      business['address'],
      business['facilityType'],
      business['details'],
    ].whereType<String>().join(' ').toLowerCase();
    return searchable.contains(_venueSearchQuery);
  }

  Widget _pendingBookingsCard(List<Map<String, dynamic>> pending) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             AppText(
              'Booking requests',
              style: TextStyle(
                color: _merchantInk,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
             localize: true,),
            const SizedBox(height: 8),
            for (final booking in pending)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.person_outline_rounded),
                ),
                title: AppText(
                  booking['customerName'] as String? ?? 'Customer',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: AppText(
                  '${booking['venueName'] ?? 'Venue'} · '
                  '${_bookingServiceLabel(booking)} · '
                  '${booking['date']} ${booking['startTime']} · '
                  '${_bookingVisitLabel(booking)} · '
                  'PHP ${booking['total']}',
                 localize: true,),
                trailing: _isPendingBooking(booking)
                    ? FilledButton(
                        onPressed: () => _approveMerchantBooking(
                          (booking['id'] as num).toInt(),
                        ),
                        child: const AppText('Approve', localize: true),
                      )
                    : const Chip(label: AppText('Active', localize: true)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _businessGrid(List<Map<String, dynamic>> businesses, bool wide) {
    if (!wide) {
      return Column(
        children: [
          for (final business in businesses) ...[
            _businessCard(business),
            const SizedBox(height: 14),
          ],
        ],
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: businesses.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: .58,
      ),
      itemBuilder: (context, index) => _businessCard(businesses[index]),
    );
  }

  Widget _emptyBusinesses() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children:  [
        Icon(Icons.storefront_outlined, size: 42, color: _merchantMuted),
        SizedBox(height: 8),
        AppText(
          'No businesses added yet',
          style: TextStyle(color: _merchantInk, fontWeight: FontWeight.w800),
         localize: true,),
        SizedBox(height: 4),
        AppText(
          'Add a venue to publish it for customers.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _merchantMuted),
         localize: true,),
      ],
    ),
  );

  Future<void> _switchBookingType() async {
    final selected = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const AppText('Switch booking type', localize: true),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const AppText('All booking types', localize: true),
          ),
          for (final type in const ['Sports', 'Fitness & Wellness', 'Event'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, type),
              child: Row(
                children: [
                  Icon(
                    type == 'Sports'
                        ? Icons.sports_tennis_rounded
                        : type == 'Event'
                        ? Icons.auto_awesome_rounded
                        : Icons.fitness_center_rounded,
                    color: _merchantOrange,
                  ),
                  const SizedBox(width: 10),
                  AppText(type == 'Fitness & Wellness' ? 'Fitness' : type),
                  const Spacer(),
                  if (_selectedBookingType == type)
                    const Icon(Icons.check_rounded, color: Colors.green),
                ],
              ),
            ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedBookingType = selected.isEmpty ? null : selected;
    });
  }

  Widget _venueSwitcher() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: _merchantLine),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(
          Icons.circle,
          color: _liveBusinesses.isEmpty ? _merchantOrange : Colors.green,
          size: 9,
        ),
        const SizedBox(width: 7),
        AppText(
          '${_liveBusinesses.length} Live ${_liveBusinesses.length == 1 ? 'Venue' : 'Venues'}',
          style:  TextStyle(
            color: _merchantInk,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
         localize: true,),
        const SizedBox(width: 8),
        AppText(
          _visibleBusinesses.length == _liveBusinesses.length
              ? '• Live on App'
              : '• Setup needed',
          style:  TextStyle(color: _merchantMuted, fontSize: 11.5),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: _switchBookingType,
          style: OutlinedButton.styleFrom(
            foregroundColor: _merchantOrange,
            backgroundColor: AppColors.surface,
            side:  BorderSide(color: _merchantLine),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 34),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: AppText(
            _selectedBookingType == 'Fitness & Wellness'
                ? 'Fitness'
                : _selectedBookingType ?? 'Switch Type',
          ),
        ),
      ],
    ),
  );

  Widget _businessCard(Map<String, dynamic> business) {
    final images = _businessImages(business);
    final name = _businessText(business, ['name']) ?? 'Unnamed venue';
    final type =
        _businessText(business, ['businessType', 'business_type']) ?? 'Booking';
    final category = _businessText(business, ['category']) ?? '';
    final address = _businessText(business, ['address']) ?? '';
    final facility =
        _businessText(business, ['facilityType', 'facility_type']) ?? '';
    final details = _businessText(business, ['details']) ?? '';
    final hours = _businessValue(business, ['hours', 'openingHours']);
    final availability = _businessValue(business, ['availability']);
    final courts = _businessValue(business, ['courts', 'courtCount']);
    final price = _hourlyPrice(business);
    final ratePeriods = _businessRatePeriods(business);
    final sessions = _businessValue(business, ['sessions', 'session']);
    final tags = _businessTags(business);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: AppColors.surface,
      shape: AppCardStyles.merchantShape,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: AppCardStyles.merchantImageHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                images.isEmpty
                    ?  ColoredBox(
                        color: AppColors.softOrange,
                        child: Icon(
                          Icons.storefront_rounded,
                          size: 48,
                          color: _merchantOrange,
                        ),
                      )
                    : GestureDetector(
                        onTap: () => _showImageGallery(context, images),
                        child: _imageCarousel(images),
                      ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: _statusPill(isLive: _isLiveOnApp(business)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:  TextStyle(
                    color: _merchantInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!_isLiveOnApp(business))
                  _businessDetail(
                    Icons.info_outline_rounded,
                    'Not live on the app — complete and publish a News Card.',
                  ),
                if (address.isNotEmpty)
                  _businessDetail(Icons.location_on_outlined, address),
                if (facility.isNotEmpty)
                  _businessDetail(
                    Icons.business_outlined,
                    'Facility: $facility',
                  ),
                if (type == 'Sports' && category.isNotEmpty)
                  _businessDetail(Icons.sports_rounded, 'Sport: $category'),
                if (type == 'Event' && category.isNotEmpty)
                  _businessDetail(
                    Icons.celebration_outlined,
                    'Event type: $category',
                  ),
                if (type == 'Fitness & Wellness' && category.isNotEmpty)
                  _businessDetail(
                    Icons.fitness_center_rounded,
                    'Class: $category',
                  ),
                if (courts.isNotEmpty)
                  _businessDetail(Icons.grid_3x3, 'Courts: $courts'),
                if (sessions.isNotEmpty)
                  _businessDetail(
                    Icons.event_available_outlined,
                    'Sessions: $sessions',
                  ),
                if (hours.isNotEmpty)
                  _businessDetail(Icons.access_time, 'Hours: $hours'),
                if (availability.isNotEmpty)
                  _businessDetail(
                    Icons.check_circle_outline,
                    'Availability: $availability',
                  ),
                if (ratePeriods.isNotEmpty)
                  _businessDetail(
                    Icons.payments_outlined,
                    'Special rates: ${_formatRatePeriods(ratePeriods)}',
                  ),
                if (details.isNotEmpty)
                  _businessDetail(Icons.info_outline, details),
                const SizedBox(height: 10),
                _priceBox(
                  type,
                  ratePeriods.isNotEmpty
                      ? 'See special rates above'
                      : price.isEmpty
                      ? 'Price not set'
                      : price,
                  hasRatePeriods: ratePeriods.isNotEmpty,
                ),
                const SizedBox(height: 8),
                 AppText(
                  'Amenities',
                  style: TextStyle(
                    color: _merchantMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                 localize: true,),
                const SizedBox(height: 5),
                if (tags.isEmpty)
                   AppText(
                    'No amenities listed',
                    style: TextStyle(color: _merchantMuted, fontSize: 12),
                   localize: true,)
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [for (final tag in tags) _tag(tag)],
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showMessage('Opening $name'),
                        icon: const Icon(Icons.language, size: 15),
                        label: const AppText('Visit', localize: true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _merchantNavy,
                          side: const BorderSide(color: _merchantNavy),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            _showMessage('Booking $name is ready.'),
                        icon: const Icon(Icons.calendar_month, size: 15),
                        label: const AppText('Book now', localize: true),
                        style: FilledButton.styleFrom(
                          backgroundColor: _merchantOrange,
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _businessValue(Map<String, dynamic> business, List<String> keys) {
    for (final key in keys) {
      final value = business[key] ?? business[_snakeCase(key)];
      if (value != null && '$value'.trim().isNotEmpty) return '$value';
    }
    return '';
  }

  String? _businessText(Map<String, dynamic> business, List<String> keys) {
    for (final key in keys) {
      final value = business[key] ?? business[_snakeCase(key)];
      if (value == null) continue;
      final text = '$value'.trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return null;
  }

  String _snakeCase(String value) =>
      value.replaceAllMapped(RegExp(r'([A-Z])'), (match) {
        return '_${match.group(1)!.toLowerCase()}';
      });

  String _hourlyPrice(Map<String, dynamic> business) {
    final isEvent =
        business['businessType'] == 'Event' ||
        business['business_type'] == 'Event';
    final value = isEvent
        ? (business['eventFee'] ??
              business['event_fee'] ??
              business['pricePerHour'] ??
              business['price_per_hour'])
        : business['pricePerHour'] ??
              business['price_per_hour'] ??
              business['price'] ??
              business['hourlyRate'];
    final price = value is num ? value.toDouble() : double.tryParse('$value');
    if (price == null || price <= 0) return '';
    final formatted = price == price.roundToDouble()
        ? price.toStringAsFixed(0)
        : price.toStringAsFixed(2);
    return isEvent ? '₱$formatted / event' : '₱$formatted / hr';
  }

  List<Map<String, dynamic>> _businessRatePeriods(
    Map<String, dynamic> business,
  ) {
    final value = business['ratePeriods'] ?? business['rate_periods'];
    dynamic decoded = value;
    if (value is String) {
      try {
        decoded = jsonDecode(value);
      } on FormatException {
        return [];
      }
    }
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((period) => Map<String, dynamic>.from(period))
        .where(
          (period) =>
              '${period['start'] ?? ''}'.trim().isNotEmpty &&
              '${period['end'] ?? ''}'.trim().isNotEmpty,
        )
        .toList();
  }

  String _formatRatePeriods(List<Map<String, dynamic>> periods) => periods
      .map((period) {
        final start = period['start'];
        final end = period['end'];
        final value = period['pricePerHour'] ?? period['price_per_hour'];
        final price = value is num
            ? value.toDouble()
            : double.tryParse('$value');
        final formattedPrice = price == null
            ? ''
            : price == price.roundToDouble()
            ? '₱${price.toStringAsFixed(0)}'
            : '₱${price.toStringAsFixed(2)}';
        return '$start - $end${formattedPrice.isEmpty ? '' : ' ($formattedPrice / hr)'}';
      })
      .join(', ');

  List<String> _businessTags(Map<String, dynamic> business) {
    final value =
        business['tags'] ?? business['amenities'] ?? business['amenities_json'];
    if (value is List) {
      return value.whereType<String>().where((tag) => tag.isNotEmpty).toList();
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .whereType<String>()
              .where((tag) => tag.isNotEmpty)
              .toList();
        }
      } on FormatException {
        return value
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  Widget _statusPill({required bool isLive}) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: AppText(
        isLive ? 'LIVE' : 'NOT LIVE',
        style: TextStyle(
          color: isLive ? Colors.green : _merchantOrange,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );

  Widget _priceBox(String type, String price, {bool hasRatePeriods = false}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: _merchantLine),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: AppText(
                hasRatePeriods
                    ? 'Rate schedule'
                    : type == 'Fitness & Wellness'
                    ? 'Session price'
                    : type == 'Event'
                    ? 'Event package'
                    : 'Price / hour',
                style:  TextStyle(
                  color: _merchantMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            AppText(
              price,
              style:  TextStyle(
                color: _merchantInk,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );

  Widget _tag(String label) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.softOrangeAlt,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: AppText(
        label,
        style:  TextStyle(color: _merchantInk, fontSize: 10),
      ),
    ),
  );

  Widget _businessDetail(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _merchantMuted),
        const SizedBox(width: 6),
        Expanded(
          child: AppText(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style:  TextStyle(color: _merchantMuted, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _merchantBottomNavigation() => AppBottomNavigation(
    merchantMode: true,
    selectedIndex: _merchantTab,
    onDestinationSelected: (index) {
      setState(() => _merchantTab = index);
      if (index == 3) {
        _payoutRefreshTimer ??= Timer.periodic(
          const Duration(seconds: 5),
          (_) => _loadBookings(),
        );
      } else {
        _payoutRefreshTimer?.cancel();
        _payoutRefreshTimer = null;
      }
      if (index == 2) _openMerchantMessages();
      if (index == 4) _openMerchantProfile();
    },
  );

  void _openMerchantProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerchantProfileDashboardPage(
          owner: _owner,
          profileImage: _imageProvider(_profileImage),
          venueCount: _visibleBusinesses.length,
          bookings: _bookings,
          onEditProfile: _openMerchantEditPanel,
          onLogout: widget.onLogout ?? (_) async {},
          api: _api,
          onNavigate: _navigateFromMerchantProfile,
        ),
      ),
    );
  }

  void _navigateFromMerchantProfile(int index) {
    setState(() => _merchantTab = index);
    if (index == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openMerchantMessages();
      });
    }
  }

  void _openMerchantMessages() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessagesDashboardPage(
          onFooterNavigate: _navigateFromMerchantMessages,
        ),
      ),
    );
  }

  void _navigateFromMerchantMessages(int index) {
    setState(() => _merchantTab = index);
    Navigator.of(context).pop();
    if (index == 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openMerchantProfile();
      });
    }
  }

  Future<void> _loadBusinesses() async {
    try {
      final session = await AppSession.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) return;
      final businesses = await _api.merchantBusinesses(token);
      if (mounted) setState(() => _businesses = businesses);
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not load businesses: $error');
    }
  }

  Future<void> _loadBookings() async {
    try {
      final session = await AppSession.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) return;
      final bookings = await _api.merchantBookings(token);
      if (mounted) setState(() => _bookings = bookings);
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not load booking requests: $error');
    }
  }

  Future<void> _approveMerchantBooking(int bookingId) async {
    try {
      final token = (await AppSession.load()).apiToken;
      if (token == null || token.isEmpty) return;
      await _api.approveBooking(token: token, bookingId: bookingId);
      await _loadBookings();
      _showMessage('Booking approved. The customer will be notified.');
    } on Exception catch (error) {
      _showMessage('Could not approve booking: $error');
    }
  }

  // Kept temporarily for compatibility with older hot-reload state.
  // ignore: unused_element
  Future<void> _addBusiness() async {
    final name = TextEditingController();
    final address = TextEditingController();
    final details = TextEditingController();
    final pricePerHour = TextEditingController();
    final imagePicker = ImagePicker();
    final formKey = GlobalKey<FormState>();
    const bookingTypes = ['Sports', 'Event', 'Fitness & Wellness'];
    String type = bookingTypes.contains(_businessTypeValue)
        ? _businessTypeValue!
        : 'Sports';
    String category =
        (_categoriesByBusinessType[type] ?? const ['Other']).first;
    String facility = 'Indoor';
    String? image;
    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const AppText('Add business', localize: true),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Form(
                  key: formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: InputDecoration(
                          labelText: appLanguageText('Booking type', 'Booking type'),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Sports',
                            child: AppText('Sports', localize: true),
                          ),
                          DropdownMenuItem(
                            value: 'Event',
                            child: AppText('Event', localize: true),
                          ),
                          DropdownMenuItem(
                            value: 'Fitness & Wellness',
                            child: AppText('Fitness & Wellness', localize: true),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            type = value;
                            category =
                                (_categoriesByBusinessType[type] ??
                                        const ['Other'])
                                    .first;
                          });
                        },
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: InputDecoration(
                          labelText: appLanguageText('Category', 'Category'),
                        ),
                        items:
                            <String>{
                                  ...(_categoriesByBusinessType[type] ??
                                      const []),
                                  'Other',
                                }
                                .map(
                                  (value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: AppText(value),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => category = value);
                          }
                        },
                      ),
                      TextFormField(
                        controller: name,
                        decoration: InputDecoration(
                          labelText: appLanguageText('Business name', 'Business name'),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Please enter a name for your business.'
                            : null,
                      ),
                      TextFormField(
                        controller: address,
                        decoration: InputDecoration(labelText: appLanguageText('Address', 'Address')),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Please add your business address.'
                            : null,
                      ),
                      TextFormField(
                        controller: pricePerHour,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: appLanguageText('Price per hour', 'Price per hour'),
                          prefixText: '₱ ',
                          hintText: '300.00',
                        ),
                        validator: (value) {
                          final price = double.tryParse(value?.trim() ?? '');
                          return price == null || price <= 0
                              ? 'Enter a price greater than ₱0.'
                              : null;
                        },
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: facility,
                        decoration: InputDecoration(
                          labelText: appLanguageText('Facility type', 'Facility type'),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Indoor',
                            child: AppText('Indoor', localize: true),
                          ),
                          DropdownMenuItem(
                            value: 'Outdoor',
                            child: AppText('Outdoor', localize: true),
                          ),
                          DropdownMenuItem(
                            value: 'Covered',
                            child: AppText('Covered', localize: true),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => facility = value);
                          }
                        },
                      ),
                      TextField(
                        controller: details,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: appLanguageText('Details (optional)', 'Details (optional)'),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await imagePicker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1400,
                            maxHeight: 900,
                            imageQuality: 75,
                          );
                          if (picked == null) return;
                          final bytes = await picked.readAsBytes();
                          setDialogState(() => image = _dataUri(bytes));
                        },
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: AppText(
                          image == null ? 'Add image' : 'Image selected',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const AppText('Cancel', localize: true),
            ),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final session = await AppSession.load();
                final token = session.apiToken;
                if (token == null || token.isEmpty) {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(false);
                  }
                  _showMessage(
                    'Your session has expired. Please log in again.',
                  );
                  return;
                }
                await _api.createMerchantBusiness(
                  token: token,
                  business: {
                    'businessType': type,
                    'name': name.text.trim(),
                    'category': category,
                    'address': address.text.trim(),
                    'pricePerHour': double.parse(pricePerHour.text.trim()),
                    'facilityType': facility,
                    'details': details.text.trim(),
                    'imageUrl': image,
                  },
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const AppText('Add business', localize: true),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    address.dispose();
    details.dispose();
    pricePerHour.dispose();
    if (added == true) {
      await _loadBusinesses();
      if (mounted) {
        setState(() => _merchantTab = 0);
        _showMessage('Business added. You can finish setting it up in Add.');
      }
    }
  }

  Future<String?> _pickProfileImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 75,
      );
      if (image == null) return null;
      final bytes = await image.readAsBytes();
      final dataUri = _dataUri(bytes);
      if (mounted) setState(() => _profileImage = dataUri);
      return dataUri;
    } on Exception catch (error) {
      _showMessage('Could not select avatar: $error');
      return null;
    }
  }

  String _dataUri(List<int> bytes) =>
      'data:image/jpeg;base64,${base64Encode(bytes)}';

  ImageProvider<Object>? _imageProvider(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('data:image/')) {
      return MemoryImage(base64Decode(value.split(',').last));
    }
    return NetworkImage(value);
  }

  List<String> _businessImages(Map<String, dynamic> business) {
    final raw = business['imageUrls'] ?? business['image_urls'];
    final images = <String>[];
    if (raw is List) {
      images.addAll(raw.whereType<String>().where((value) => value.isNotEmpty));
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          images.addAll(
            decoded.whereType<String>().where((value) => value.isNotEmpty),
          );
        }
      } on FormatException {
        // Ignore malformed optional gallery data and use the legacy image.
      }
    }
    if (images.isEmpty) {
      final legacy = _businessText(business, ['imageUrl', 'image_url']);
      if (legacy != null && legacy.isNotEmpty) {
        try {
          final decoded = jsonDecode(legacy);
          if (decoded is List) {
            images.addAll(
              decoded.whereType<String>().where((value) => value.isNotEmpty),
            );
          }
        } on FormatException {
          images.add(legacy);
        }
        if (images.isEmpty) images.add(legacy);
      }
    }
    return images;
  }

  Widget _imageCarousel(List<String> images) {
    final controller = PageController(initialPage: 100000);
    var currentIndex = 0;
    return StatefulBuilder(
      builder: (context, setState) => Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: controller,
            onPageChanged: (index) {
              setState(() => currentIndex = index % images.length);
            },
            itemBuilder: (_, index) => Image(
              image: _imageProvider(images[index % images.length])!,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) =>  ColoredBox(
                color: AppColors.softOrange,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: _merchantOrange,
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: AppText(
                  '${currentIndex + 1} of ${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                 localize: true,),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showImageGallery(
    BuildContext context,
    List<String> images,
  ) async {
    var currentIndex = 0;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: StatefulBuilder(
          builder: (context, setDialogState) => SizedBox(
            height: MediaQuery.sizeOf(context).height * .75,
            child: Stack(
              children: [
                PageView.builder(
                  controller: PageController(initialPage: 100000),
                  itemCount: 1000000,
                  onPageChanged: (index) {
                    setDialogState(() => currentIndex = index % images.length);
                  },
                  itemBuilder: (_, index) => Center(
                    child: Image(
                      image: _imageProvider(images[index % images.length])!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: AppText(
                          '${currentIndex + 1} of ${images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                         localize: true,),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    bool required = true,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) => TextFormField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      labelText: appLanguageText(label, label),
      hintText: appLanguageText(hint, hint),
      filled: true,
      fillColor: _merchantPage,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:  BorderSide(color: _merchantLine),
      ),
    ),
    validator: required
        ? (value) => value == null || value.trim().isEmpty
              ? 'Please enter $label.'
              : null
        : null,
  );
}
