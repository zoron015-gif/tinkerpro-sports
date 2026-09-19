import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_session.dart';
import 'auth_api.dart';
import 'merchant_add_page.dart';
import 'merchant_profile_dashboard.dart';

const _merchantNavy = Color(0xFF192B50);
const _merchantInk = Color(0xFF101B33);
const _merchantOrange = Color(0xFFFF8200);
const _merchantPage = Color(0xFFF7F9FC);
const _merchantMuted = Color(0xFF68748A);
const _merchantLine = Color(0xFFE2E7EF);

class MerchantDashboardPage extends StatefulWidget {
  const MerchantDashboardPage({super.key, this.onLogout});

  final Future<void> Function(BuildContext context)? onLogout;

  @override
  State<MerchantDashboardPage> createState() => _MerchantDashboardPageState();
}

class _MerchantDashboardPageState extends State<MerchantDashboardPage> {
  final _api = AuthApi();
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _businessName = TextEditingController();
  final _businessType = TextEditingController();
  final _registrationNumber = TextEditingController();
  final _address = TextEditingController();
  final _contactEmail = TextEditingController();
  final _designation = TextEditingController();
  final _selectedCategories = <String>{};
  final _imagePicker = ImagePicker();
  String _facilityType = 'Indoor';
  String? _businessTypeValue;
  final _customCategories = <String>{};
  Map<String, dynamic> _owner = const {};
  String? _profileImage;
  String? _businessImage;
  bool _loading = true;
  bool _saving = false;
  bool _profileSaved = false;
  List<Map<String, dynamic>> _businesses = [];
  int _merchantTab = 0;
  String? _selectedBookingType;

  List<Map<String, dynamic>> get _visibleBusinesses {
    return _businesses
        .where((business) {
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
        })
        .toList();
  }

  static const _categoriesByBusinessType = {
    'Sports': [
      'Tennis',
      'Pickleball',
      'Basketball',
      'Volleyball',
      'Badminton',
    ],
    'Event': [
      'Ballroom',
      'Terrace',
      'Private Dining',
      'Garden',
    ],
    'Fitness & Wellness': [
      'CrossFit',
      'Pilates',
      'Boxing',
      'Yoga',
      'Zumba',
      'Martial Arts',
    ],
  };

  List<String> get _availableCategories => [
    ...(_categoriesByBusinessType[_businessTypeValue] ?? const []),
    ..._customCategories,
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
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
      final accountEmail =
          (profile['email'] as String?) ?? session.accountEmail ?? '';
      final profileCompleted = _hasCompletedProfile(profile) ||
          (accountEmail.isNotEmpty &&
              session.merchantProfileCompletedFor(accountEmail));
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
        _profileSaved = profileCompleted;
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
      if (_profileSaved) await _loadBusinesses();
    } on Exception catch (error) {
      if (mounted) {
        _showMessage('Could not load merchant profile: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _hasCompletedProfile(Map<String, dynamic> profile) {
    final profileExists = profile['profileExists'];
    final hasProfileRecord = profileExists == true ||
        profileExists == 1 ||
        profileExists == '1' ||
        profileExists == 'true' ||
        profileExists == 'TRUE';
    final requiredFields = [
      profile['firstName'],
      profile['lastName'],
      profile['phone'],
      profile['ownerDesignation'],
      profile['businessType'],
    ];
    final hasRequiredFields = requiredFields.every(
      (value) => value is String && value.trim().isNotEmpty,
    );
    return hasProfileRecord || hasRequiredFields;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
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
      if (mounted) setState(() => _profileSaved = true);
      _showMessage('Merchant profile saved and ready for customer listings.');
    } on Exception catch (error) {
      _showMessage('Could not save merchant profile: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }

  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    if (widget.onLogout == null) return;
    await widget.onLogout!(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _merchantPage,
      appBar: AppBar(
        title: const Text(
          'Merchant Dashboard',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: _merchantPage,
        foregroundColor: _merchantInk,
        elevation: 0,
        actions: [
          if (widget.onLogout != null)
            TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Log out'),
              style: TextButton.styleFrom(
                foregroundColor: _merchantOrange,
              ),
            ),
        ],
      ),
      bottomNavigationBar: _profileSaved ? _merchantBottomNavigation() : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profileSaved
          ? _merchantContent()
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: Form(
                key: _formKey,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    _section(
                      title: 'Person in charge',
                      child: Column(
                        children: [
                          _ownerCard(),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  _firstName,
                                  'First name',
                                  'Your first name',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _field(
                                  _lastName,
                                  'Last name',
                                  'Your last name',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _field(
                            _phone,
                            'Direct contact phone',
                            '+63 917 123 4567',
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 10),
                          _field(
                            _designation,
                            'Official role / designation',
                            'Example: Court Owner & Facility Manager',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _section(
                      title: 'Business & facility information',
                      child: Column(
                        children: [
                          _field(
                            _businessName,
                            'Business / facility name (Optional)',
                            'Skip if you do not have one yet',
                            required: false,
                          ),
                          const SizedBox(height: 10),
                          _businessTypeSelector(),
                          const SizedBox(height: 10),
                          _field(
                            _registrationNumber,
                            'Business registration / permit number (Optional)',
                            'Optional',
                            required: false,
                          ),
                          const SizedBox(height: 10),
                          _categorySelector(),
                          const SizedBox(height: 10),
                          _facilitySelector(),
                          const SizedBox(height: 10),
                          _field(
                            _address,
                            'Full location and physical address (Optional)',
                            'Skip if you do not have an address yet',
                            required: false,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 10),
                          _field(
                            _contactEmail,
                            'Official business email (Optional)',
                            'Skip if you do not have a business email yet',
                            required: false,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 10),
                          _businessImagePicker(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : _saveProfile,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_rounded),
                      label: Text(
                        _saving ? 'Saving...' : 'Save merchant profile',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _merchantOrange,
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _merchantContent() {
    if (_merchantTab == 1) {
      return MerchantAddPage(
        initialBusinessType: _businessTypeValue,
        businesses: _businesses,
        onBusinessesChanged: _loadBusinesses,
      );
    }
    return _merchantHome();
  }

  Widget _merchantHome() => RefreshIndicator(
    onRefresh: _loadBusinesses,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final businesses = _visibleBusinesses;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 8, wide ? 24 : 16, 28),
          children: [
            const SizedBox(height: 12),
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
      children: const [
        Icon(Icons.storefront_outlined, size: 42, color: _merchantMuted),
        SizedBox(height: 8),
        Text(
          'No businesses added yet',
          style: TextStyle(color: _merchantInk, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 4),
        Text(
          'Add a venue to publish it for customers.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _merchantMuted),
        ),
      ],
    ),
  );

  Future<void> _switchBookingType() async {
    final selected = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Switch booking type'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const Text('All booking types'),
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
                  Text(type),
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
      color: Colors.white,
      border: Border.all(color: _merchantLine),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.circle, color: Colors.green, size: 9),
        const SizedBox(width: 7),
        Text(
          '${_visibleBusinesses.length} Active ${_visibleBusinesses.length == 1 ? 'Venue' : 'Venues'}',
          style: const TextStyle(
            color: _merchantInk,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '• Live on App',
          style: TextStyle(color: _merchantMuted, fontSize: 11),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: _switchBookingType,
          style: OutlinedButton.styleFrom(
            foregroundColor: _merchantOrange,
            backgroundColor: Colors.white,
            side: const BorderSide(color: _merchantLine),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const StadiumBorder(),
          ),
          child: Text(_selectedBookingType ?? 'Switch Type'),
        ),
      ],
    ),
  );

  Widget _businessCard(Map<String, dynamic> business) {
    final images = _businessImages(business);
    final name = _businessText(business, ['name']) ?? 'Unnamed venue';
    final type = _businessText(business, ['businessType', 'business_type']) ??
        'Booking';
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
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _merchantLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                images.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFFFFE8D2),
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
                  child: _statusPill(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _merchantInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    _businessTag(Icons.event_available_rounded, type),
                    if (category.isNotEmpty)
                      _businessTag(Icons.category_outlined, category),
                  ],
                ),
                if (address.isNotEmpty)
                  _businessDetail(Icons.location_on_outlined, address),
                if (facility.isNotEmpty)
                  _businessDetail(Icons.business_outlined, 'Facility: $facility'),
                if (type == 'Sports' && category.isNotEmpty)
                  _businessDetail(Icons.sports_rounded, 'Sport: $category'),
                if (type == 'Event' && category.isNotEmpty)
                  _businessDetail(Icons.celebration_outlined, 'Event type: $category'),
                if (type == 'Fitness & Wellness' && category.isNotEmpty)
                  _businessDetail(Icons.fitness_center_rounded, 'Class: $category'),
                if (courts.isNotEmpty)
                  _businessDetail(Icons.grid_3x3, 'Courts: $courts'),
                if (sessions.isNotEmpty)
                  _businessDetail(Icons.event_available_outlined, 'Sessions: $sessions'),
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
                const Text(
                  'Amenities',
                  style: TextStyle(
                    color: _merchantMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                if (tags.isEmpty)
                  const Text(
                    'No amenities listed',
                    style: TextStyle(color: _merchantMuted, fontSize: 12),
                  )
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
                        onPressed: () =>
                            _showMessage('Opening $name'),
                        icon: const Icon(Icons.language, size: 15),
                        label: const Text('Visit'),
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
                        label: const Text('Book now'),
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
    final value = business['pricePerHour'] ??
        business['price_per_hour'] ??
        business['price'] ??
        business['hourlyRate'];
    final price = value is num
        ? value.toDouble()
        : double.tryParse('$value');
    if (price == null || price <= 0) return '';
    final formatted = price == price.roundToDouble()
        ? price.toStringAsFixed(0)
        : price.toStringAsFixed(2);
    return '₱$formatted / hr';
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
    final value = business['tags'] ??
        business['amenities'] ??
        business['amenities_json'];
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

  Widget _statusPill() => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Text(
        'LIVE',
        style: TextStyle(
          color: Colors.green,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );

  Widget _priceBox(
    String type,
    String price, {
    bool hasRatePeriods = false,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFAFBFD),
      border: Border.all(color: _merchantLine),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            hasRatePeriods
                ? 'Rate schedule'
                : type == 'Fitness & Wellness'
                ? 'Session price'
                : type == 'Event'
                ? 'Event package'
                : 'Price / hour',
            style: const TextStyle(
              color: _merchantMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          price,
          style: const TextStyle(
            color: _merchantInk,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  Widget _tag(String label) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1E4),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Text(
        label,
        style: const TextStyle(color: _merchantInk, fontSize: 10),
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
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _merchantMuted, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _businessTag(IconData icon, String label) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1E4),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _merchantOrange),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: _merchantOrange,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _merchantBottomNavigation() => NavigationBar(
    selectedIndex: _merchantTab,
    onDestinationSelected: (index) {
      setState(() => _merchantTab = index);
      if (index == 1) {
        return;
      } else if (index == 3) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MerchantProfileDashboardPage(
              owner: _owner,
              profileImage: _imageProvider(_profileImage),
              venueCount: _businesses.length,
              onEditProfile: () {
                Navigator.of(context).pop();
                setState(() => _profileSaved = false);
              },
              onLogout: widget.onLogout ?? (_) async {},
            ),
          ),
        );
      } else if (index != 0) {
        _showMessage('${['Venues', 'Add', 'Payouts', 'Profile'][index]} is coming soon.');
      }
    },
    destinations: const [
      NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront_rounded), label: 'Venues'),
      NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Add'),
      NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments_rounded), label: 'Payouts'),
      NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
    ],
  );

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
    String category = (_categoriesByBusinessType[type] ?? const ['Other']).first;
    String facility = 'Indoor';
    String? image;
    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add business'),
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
                        decoration:
                            const InputDecoration(labelText: 'Booking type'),
                        items: const [
                          DropdownMenuItem(
                            value: 'Sports',
                            child: Text('Sports'),
                          ),
                          DropdownMenuItem(
                            value: 'Event',
                            child: Text('Event'),
                          ),
                          DropdownMenuItem(
                            value: 'Fitness & Wellness',
                            child: Text('Fitness & Wellness'),
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
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: <String>{
                          ...(_categoriesByBusinessType[type] ?? const []),
                          'Other',
                        }
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
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
                        decoration: const InputDecoration(
                          labelText: 'Business name',
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Enter a business name'
                            : null,
                      ),
                      TextFormField(
                        controller: address,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Enter an address'
                            : null,
                      ),
                      TextFormField(
                        controller: pricePerHour,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Price per hour',
                          prefixText: '₱ ',
                          hintText: '300.00',
                        ),
                        validator: (value) {
                          final price = double.tryParse(value?.trim() ?? '');
                          return price == null || price <= 0
                              ? 'Enter a price greater than 0'
                              : null;
                        },
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: facility,
                        decoration: const InputDecoration(
                          labelText: 'Facility type',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Indoor',
                            child: Text('Indoor'),
                          ),
                          DropdownMenuItem(
                            value: 'Outdoor',
                            child: Text('Outdoor'),
                          ),
                          DropdownMenuItem(
                            value: 'Covered',
                            child: Text('Covered'),
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
                        decoration: const InputDecoration(
                          labelText: 'Details (optional)',
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
                        label: Text(
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
              child: const Text('Cancel'),
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
                  _showMessage('Your session has expired. Please log in again.');
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
              child: const Text('Add business'),
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
        setState(() => _merchantTab = 1);
        _showMessage('Business added. It is now available in Add and Venues.');
      }
    }
  }

  Widget _ownerCard() {
    final first = _owner['firstName'] as String? ?? '';
    final last = _owner['lastName'] as String? ?? '';
    final name = '$first $last'.trim();
    final email = _owner['email'] as String? ?? 'Account email';
    final phone = _owner['phone'] as String? ?? 'Phone not provided';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _merchantLine),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 29,
            backgroundColor: const Color(0xFFFFE8D2),
            backgroundImage: _imageProvider(_profileImage),
            child: _profileImage == null
                ? Text(
                    _initials(name),
                    style: const TextStyle(
                      color: _merchantNavy,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Merchant account owner' : name,
                  style: const TextStyle(
                    color: _merchantInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _merchantMuted),
                ),
                Text(
                  phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _merchantMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green),
                TextButton(
                  onPressed: _pickProfileImage,
                  child: const Text('Change photo'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _businessImagePicker() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Business image',
        style: TextStyle(color: _merchantInk, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _pickBusinessImage,
        child: Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _merchantPage,
            border: Border.all(color: _merchantLine),
            borderRadius: BorderRadius.circular(14),
          ),
          child: _businessImage == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: _merchantOrange),
                    SizedBox(height: 6),
                    Text('Add a photo of your business'),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image(
                    image: _imageProvider(_businessImage!)!,
                    fit: BoxFit.cover,
                  ),
                ),
        ),
      ),
    ],
  );

  Future<void> _pickProfileImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 75,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (mounted) setState(() => _profileImage = _dataUri(bytes));
  }

  Future<void> _pickBusinessImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      maxHeight: 900,
      imageQuality: 75,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (mounted) setState(() => _businessImage = _dataUri(bytes));
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
              errorBuilder: (_, error, stack) => const ColoredBox(
                color: Color(0xFFFFE8D2),
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
                child: Text(
                  '${currentIndex + 1} of ${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
                    setDialogState(
                      () => currentIndex = index % images.length,
                    );
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
                        child: Text(
                          '${currentIndex + 1} of ${images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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

  Widget _section({required String title, required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _merchantLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _merchantInk,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );

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
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: _merchantPage,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _merchantLine),
      ),
    ),
    validator: required
        ? (value) => value == null || value.trim().isEmpty
              ? '$label is required'
              : null
        : null,
  );

  Widget _businessTypeSelector() => DropdownButtonFormField<String>(
    initialValue: _businessTypeValue,
    decoration: InputDecoration(
      labelText: 'Business type',
      filled: true,
      fillColor: _merchantPage,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _merchantLine),
      ),
    ),
    hint: const Text('Select a booking type'),
    items: const [
      DropdownMenuItem(value: 'Sports', child: Text('Sports')),
      DropdownMenuItem(value: 'Event', child: Text('Event')),
      DropdownMenuItem(
        value: 'Fitness & Wellness',
        child: Text('Fitness & Wellness'),
      ),
    ],
    onChanged: (value) {
      if (value != null) {
        setState(() {
          _businessTypeValue = value;
          _businessType.text = value;
          _selectedCategories.clear();
          _customCategories.clear();
        });
      }
    },
  );

  Widget _categorySelector() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Business categories',
        style: TextStyle(color: _merchantInk, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      if (_businessTypeValue == null)
        const Text(
          'Select a business type first.',
          style: TextStyle(color: _merchantMuted, fontSize: 12),
        ),
      SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.start,
          runAlignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.start,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in _availableCategories)
              FilterChip(
                label: Text(category),
                selected: _selectedCategories.contains(category),
                selectedColor: const Color(0xFFFFE8D2),
                checkmarkColor: _merchantOrange,
                onSelected: (selected) => setState(
                  () => selected
                      ? _selectedCategories.add(category)
                      : _selectedCategories.remove(category),
                ),
              ),
            if (_businessTypeValue != null)
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Add category'),
                onPressed: _addCustomCategory,
              ),
          ],
        ),
      ),
    ],
  );

  Future<void> _addCustomCategory() async {
    final controller = TextEditingController();
    final category = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add business category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Category name',
            hintText: 'Example: Table Tennis',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (!mounted || category == null || category.isEmpty) return;
    if (_availableCategories.any(
      (value) => value.toLowerCase() == category.toLowerCase(),
    )) {
      _showMessage('That category is already available.');
      return;
    }
    setState(() {
      _customCategories.add(category);
      _selectedCategories.add(category);
    });
  }

  Widget _facilitySelector() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Facility layout type',
        style: TextStyle(color: _merchantInk, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'Indoor', label: Text('Indoor')),
          ButtonSegment(value: 'Outdoor', label: Text('Outdoor')),
          ButtonSegment(value: 'Covered', label: Text('Covered')),
        ],
        selected: {_facilityType},
        onSelectionChanged: (selection) =>
            setState(() => _facilityType = selection.first),
      ),
    ],
  );

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    final letters = parts.map((part) => part[0]).take(2).join();
    return letters.isEmpty ? 'M' : letters.toUpperCase();
  }
}
