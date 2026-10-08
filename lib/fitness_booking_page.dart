import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_session.dart';
import 'auth_api.dart';
import 'app_design_system.dart';
import 'fitness_booking_pricing.dart';
import 'app_preferences.dart';

class FitnessBookingPage extends StatefulWidget {
  const FitnessBookingPage({
    super.key,
    required this.business,
    required this.api,
    this.onLogout,
  });

  final Map<String, dynamic> business;
  final AuthApi api;
  final Future<void> Function(BuildContext)? onLogout;

  @override
  State<FitnessBookingPage> createState() => _FitnessBookingPageState();
}

class _FitnessBookingPageState extends State<FitnessBookingPage> {
  static const _maximumCoachDurationMonths = 4294967295;

  static Color get _ink => AppColors.ink;
  Color get _accent => AppColors.accent;
  Color get _accentForeground => AppColors.accentForeground;

  late final List<Map<String, dynamic>> _categories;
  late final List<Map<String, dynamic>> _coaches;
  String? _category;
  String? _plan;
  String? _coachName;
  int _coachDurationMonths = 1;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  TimeOfDay? _time;
  String _payment = 'online';
  final String _bookingIdempotencyKey = newBookingIdempotencyKey();
  String? _token;
  List<Map<String, dynamic>> _busyTimes = [];
  bool _loadingAvailability = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _categories = _readList(widget.business['fitnessCategories']);
    _coaches = _readList(widget.business['fitnessCoaches']);
    if (_categories.isNotEmpty) {
      _category = _categories.first['category'] as String?;
      _selectFirstPlan();
    }
    _loadAvailability();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final session = await AppSession.load();
    if (mounted) setState(() => _token = session.apiToken);
  }

  List<Map<String, dynamic>> _readList(dynamic value) {
    if (value is! List) return [];
    return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Map<String, dynamic>? get _selectedCategory {
    for (final item in _categories) {
      if (item['category'] == _category) return item;
    }
    return null;
  }

  IconData _fitnessCategoryIcon(String category) {
    final normalized = category.trim().toLowerCase();
    if (normalized.contains('yoga')) return Icons.self_improvement_rounded;
    if (normalized.contains('dance')) return Icons.music_note_rounded;
    if (normalized.contains('martial') || normalized.contains('boxing')) {
      return Icons.sports_martial_arts_rounded;
    }
    if (normalized.contains('swim')) return Icons.pool_rounded;
    if (normalized.contains('cycling') || normalized.contains('spin')) {
      return Icons.directions_bike_rounded;
    }
    if (normalized.contains('pilates')) return Icons.accessibility_new_rounded;
    return Icons.fitness_center_rounded;
  }

  List<String> get _availablePlans =>
      FitnessBookingPricing.availablePlans(_selectedCategory);

  double _basePrice([String? selectedPlan]) {
    return FitnessBookingPricing.planPrice(
      _selectedCategory,
      selectedPlan ?? _plan,
    );
  }

  double _coachPrice() {
    if (_coachName == null || _plan == null) return 0;
    final coach = _coaches
        .where((item) => item['name'] == _coachName)
        .firstOrNull;
    return FitnessBookingPricing.coachPrice(
      coach,
      durationMonths: _coachDurationMonths,
    );
  }

  double get _total => _basePrice() + _coachPrice();

  String? get _yearlyOfferLabel =>
      FitnessBookingPricing.yearlyOfferLabel(_selectedCategory, _plan);

  void _selectFirstPlan() {
    final plans = _availablePlans;
    _plan = plans.isEmpty ? null : plans.first;
  }

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _loadAvailability() async {
    final token = _token ?? (await AppSession.load()).apiToken;
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _loadingAvailability = false);
      return;
    }
    if (mounted) setState(() => _loadingAvailability = true);
    try {
      final bookings = await widget.api.bookingAvailability(
        token: token,
        venueId: _businessId,
        date: _dateString(_date),
      );
      if (!mounted) return;
      setState(() {
        _busyTimes = bookings;
        _loadingAvailability = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _loadingAvailability = false);
      _message('Could not load available visit times: $error');
    }
  }

  int get _businessId => int.tryParse('${widget.business['id'] ?? ''}') ?? 0;

  bool get _timeUnavailable {
    final time = _time;
    if (time == null) return false;
    final selectedStart = time.hour * 60 + time.minute;
    final selectedEnd = selectedStart + 60;
    for (final booking in _busyTimes) {
      final pieces = '${booking['startTime'] ?? ''}'.split(':');
      if (pieces.length < 2) continue;
      final hour = int.tryParse(pieces[0]);
      final minute = int.tryParse(pieces[1]);
      final duration = double.tryParse('${booking['durationHours'] ?? 0}') ?? 0;
      if (hour == null || minute == null) continue;
      final start = hour * 60 + minute;
      final end = start + (duration * 60).round();
      if (selectedStart < end && selectedEnd > start) return true;
    }
    return false;
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) return;
    setState(() {
      _date = selected;
      _time = null;
    });
    await _loadAvailability();
  }

  Future<void> _chooseTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (selected != null) setState(() => _time = selected);
  }

  Future<void> _submit() async {
    final token = _token;
    final time = _time;
    if (token == null || token.isEmpty) {
      _message('Please sign in to book a fitness session.');
      return;
    }
    if (_businessId <= 0) {
      _message(
        'We couldn’t find this venue’s booking details. Please go back and try again.',
      );
      return;
    }
    if (_category == null) {
      _message('Please choose a fitness category.');
      return;
    }
    if (_plan == null) {
      _message('Please choose a plan to see its price and availability.');
      return;
    }
    if (time == null) {
      _message('Please choose a time for your first visit.');
      return;
    }
    if (_timeUnavailable) {
      _message(
        'That time is already booked. Please choose another time for your first visit.',
      );
      return;
    }
    final payment = _payment;
    String? provider;
    try {
      if (payment == 'online') {
        provider = await _chooseProvider();
        if (provider == null) return;
      }
      if (payment == 'online' &&
          !await widget.api.payMongoPaymentsEnabled(token)) {
        _message(
          'Online payments are unavailable right now. No booking has been created.',
        );
        return;
      }
      if (!mounted) return;
      final coaDownpayment = double.parse((_total * 0.5).toStringAsFixed(2));
      final coaRemaining = _total - coaDownpayment;
      final bookingStart = DateTime(
        _date.year,
        _date.month,
        _date.day,
        time.hour,
        time.minute,
      );
      final timeUntilBooking = bookingStart.difference(DateTime.now());
      final startsWithin24Hours =
          !timeUntilBooking.isNegative &&
          timeUntilBooking < const Duration(hours: 24);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const AppText('Confirm Fitness booking', localize: true),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                '${widget.business['name'] ?? 'Fitness venue'}\n'
                '$_category · ${_plan!.toUpperCase()}\n'
                '${_dateString(_date)} at ${time.format(context)}\n'
                '${_coachName == null ? 'No coach selected' : 'Coach: $_coachName'}\n'
                '${_coachName == null ? '' : 'Coach duration: ${_coachDurationLabel(_coachDurationMonths)}\n'}'
                '${_payment == 'cash_on_arrival' ? 'Cash on arrival · Pay the 50% downpayment of \u{20B1} ${coaDownpayment.toStringAsFixed(2)} at the venue. Remaining cash balance: \u{20B1} ${coaRemaining.toStringAsFixed(2)}.' : 'One-time total: \u{20B1} ${_total.toStringAsFixed(2)}'}',
                localize: true,
              ),
              if (startsWithin24Hours) ...[
                const SizedBox(height: 12),
                AppText(
                  'This booking starts within 24 hours. You may cancel it '
                  'at any time. If cancelled at least 6 hours before it starts, '
                  'an online payment refund will be requested. If cancelled '
                  'less than 6 hours before it starts or after it has started, '
                  'the payment will not be voided or refunded. Cash already '
                  'collected must be returned manually.',
                  localize: true,
                  style: TextStyle(
                    color: AppColors.errorText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('Cancel', localize: true),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('Confirm booking', localize: true),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _submitting = true);
      final response = await widget.api.createBooking(
        token: token,
        idempotencyKey: _bookingIdempotencyKey,
        venueId: _businessId,
        date: _dateString(_date),
        startTime:
            '${time.hour.toString().padLeft(2, '0')}:'
            '${time.minute.toString().padLeft(2, '0')}:00',
        durationHours: 1,
        players: 1,
        paymentMethod: payment,
        sportType: _category!,
        fitnessPlanType: _plan!,
        fitnessCoachName: _coachName ?? '',
        fitnessCoachDurationMonths: _coachName == null
            ? 0
            : _coachDurationMonths,
      );
      final booking = response['booking'] as Map<String, dynamic>? ?? const {};
      if (payment == 'online') {
        final checkout = await widget.api.createPayMongoCheckout(
          token: token,
          bookingId: int.tryParse('${booking['id']}') ?? 0,
          paymentMethod: provider!,
        );
        final checkoutUrl = checkout['checkoutUrl'] as String?;
        if (checkoutUrl == null || checkoutUrl.isEmpty) {
          throw const AuthApiException(
            'PayMongo did not return a checkout link.',
            502,
          );
        }
        final launched = await launchUrl(
          Uri.parse(checkoutUrl),
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          throw const AuthApiException(
            'Could not open the PayMongo checkout page.',
            0,
          );
        }
        _message('Complete your one-time Fitness plan payment to continue.');
      } else {
        _message('Fitness booking request sent. Waiting for venue approval.');
      }
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (error) {
      _message('Could not submit Fitness booking: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<String?> _chooseProvider() => showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const AppText('Choose online payment', localize: true),
      content: const AppText(
        'The selected term is charged once at checkout.',
        localize: true,
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.pop(context, 'gcash'),
          icon: const Icon(Icons.account_balance_wallet_rounded),
          label: const AppText('GCash', localize: true),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, 'paymaya'),
          icon: const Icon(Icons.payments_rounded),
          label: const AppText('PayMaya', localize: true),
        ),
      ],
    ),
  );

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(text)));
  }

  String _planTitle(String value) => FitnessBookingPricing.planTitle(value);

  ImageProvider<Object>? _profileImage(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    if (value.startsWith('data:image/')) {
      final separator = value.indexOf(',');
      if (separator <= 0 || separator == value.length - 1) return null;
      try {
        return MemoryImage(base64Decode(value.substring(separator + 1)));
      } on FormatException {
        return null;
      }
    }
    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return NetworkImage(value);
  }

  @override
  Widget build(BuildContext context) {
    final name = '${widget.business['name'] ?? 'Fitness venue'}';
    final categoryPrice = _basePrice();
    final coaDownpayment = double.parse((_total * 0.5).toStringAsFixed(2));
    final coaRemaining = _total - coaDownpayment;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _modalIconButton(
                    Icons.arrow_back_rounded,
                    () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        AppText(
                          'Book Fitness',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                          localize: true,
                        ),
                        SizedBox(height: 6),
                        AppText(
                          'Step 2 of 2 • Checkout',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          localize: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                key: const ValueKey('fitness-booking-summary-card'),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D0F172A),
                      blurRadius: 16,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.softOrangeAlt,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: AppText(
                                  (_category ?? 'FITNESS').toUpperCase(),
                                  style: TextStyle(
                                    color: _accentForeground,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .7,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              AppText(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppText(
                          '\u{20B1} ${categoryPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: _accentForeground,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                          localize: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _bookingDetail(
                      Icons.person_outline_rounded,
                      'Owner: ${widget.business['ownerName'] ?? 'Venue merchant'}',
                    ),
                    _bookingDetail(
                      Icons.location_on_outlined,
                      '${widget.business['address'] ?? 'Address not provided'}',
                    ),
                    _bookingDetail(
                      Icons.fitness_center_rounded,
                      'Selected plan: ${_plan == null ? 'Choose a plan' : _planTitle(_plan!)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              AppText(
                'FITNESS CONFIGURATION',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  letterSpacing: .9,
                  fontWeight: FontWeight.w800,
                ),
                localize: true,
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: _decoration(
                  prefixIcon: Icon(_fitnessCategoryIcon(_category ?? '')),
                  labelText: appLanguageText(
                    'Fitness category',
                    'Fitness category',
                  ),
                ),
                items: _categories
                    .map((item) => item['category'])
                    .whereType<String>()
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: AppText(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _category = value;
                    _selectFirstPlan();
                  });
                },
              ),
              const SizedBox(height: 6),
              AppText(
                'PLAN',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  letterSpacing: .9,
                  fontWeight: FontWeight.w800,
                ),
                localize: true,
              ),
              const SizedBox(height: 6),
              if (_availablePlans.isEmpty)
                AppText(
                  'This venue has no priced plans available for this category.',
                  style: TextStyle(color: AppColors.muted),
                  localize: true,
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _availablePlans.map((plan) {
                    final selected = plan == _plan;
                    return ChoiceChip(
                      label: AppText(
                        '${_planTitle(plan)} · \u{20B1} ${_displayPlanPrice(plan)}',
                        localize: true,
                      ),
                      selected: selected,
                      onSelected: (_) => setState(() => _plan = plan),
                      selectedColor: AppColors.softOrange,
                      labelStyle: TextStyle(
                        color: selected ? _accentForeground : _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  }).toList(),
                ),
              if (_yearlyOfferLabel case final offer?) ...[
                const SizedBox(height: 6),
                AppText(
                  offer,
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  final coachLabelWidth = (constraints.maxWidth - 160).clamp(
                    72.0,
                    240.0,
                  );
                  return DropdownButtonFormField<String?>(
                    initialValue: _coachName,
                    decoration: _decoration(
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      labelText: appLanguageText(
                        'Coach (optional)',
                        'Coach (optional)',
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: AppText('No coach', localize: true),
                      ),
                      ..._coaches.map((coach) {
                        final coachName = '${coach['name'] ?? ''}';
                        final monthly =
                            double.tryParse('${coach['monthlyPrice']}') ?? 0;
                        final profileImage = _profileImage(
                          coach['profileImageUrl'],
                        );
                        return DropdownMenuItem<String?>(
                          value: coachName,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundImage: profileImage,
                                child: profileImage == null
                                    ? const Icon(Icons.person, size: 18)
                                    : null,
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: coachLabelWidth,
                                child: AppText(
                                  '$coachName · ? '
                                  '${monthly.toStringAsFixed(2)}/month',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  localize: true,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) => setState(() => _coachName = value),
                  );
                },
              ),
              if (_coachName != null) ...[
                const SizedBox(height: 6),
                _coachDurationSelector(),
                const SizedBox(height: 6),
                _summaryRow('Coach fee', _coachPrice()),
              ],
              const SizedBox(height: 6),
              AppText(
                'FIRST VISIT',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  letterSpacing: .9,
                  fontWeight: FontWeight.w800,
                ),
                localize: true,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _chooseDate,
                      style: _choiceStyle(),
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: AppText(_dateString(_date)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _chooseTime,
                      style: _choiceStyle(),
                      icon: const Icon(Icons.schedule_rounded),
                      label: AppText(_time?.format(context) ?? 'Choose time'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _availabilityNote(),
              const SizedBox(height: 6),
              AppText(
                'PAYMENT METHOD',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  letterSpacing: .9,
                  fontWeight: FontWeight.w800,
                ),
                localize: true,
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? _accent
                        : AppColors.surface,
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? AppColors.onAccent
                        : _ink,
                  ),
                  side: WidgetStateProperty.all(
                    BorderSide(color: AppColors.border),
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: 'online',
                    label: AppText('Online payment', localize: true),
                    icon: Icon(Icons.lock_rounded),
                  ),
                  ButtonSegment(
                    value: 'cash_on_arrival',
                    label: AppText('COA', localize: true),
                    icon: Icon(Icons.payments_outlined),
                  ),
                ],
                selected: {_payment},
                onSelectionChanged: (selection) {
                  setState(() => _payment = selection.first);
                },
              ),
              const SizedBox(height: 6),
              AppText(
                _payment == 'cash_on_arrival'
                    ? 'Pay a 50% cash downpayment at the venue: '
                          '\u{20B1} ${coaDownpayment.toStringAsFixed(2)}. '
                          'Remaining cash balance: \u{20B1} ${coaRemaining.toStringAsFixed(2)}.'
                    : 'Pay securely online once for the selected term: '
                          '\u{20B1} ${_total.toStringAsFixed(2)}.',
                style: TextStyle(color: AppColors.muted),
              ),
              const Divider(height: 24),
              _summaryRow(
                '${_planTitle(_plan ?? 'Selected')} plan',
                _basePrice(),
              ),
              if (_coachPrice() > 0)
                _summaryRow(
                  'Coach · $_coachName '
                  '(${_coachDurationLabel(_coachDurationMonths)})',
                  _coachPrice(),
                ),
              _summaryRow('First visit duration', 1, suffix: ' hour'),
              _summaryRow(
                'First visit',
                0,
                suffix: _time == null
                    ? _dateString(_date)
                    : '${_dateString(_date)} · ${_time!.format(context)}',
              ),
              _summaryRow('One-time total', _total, strong: true),
              if (_payment == 'cash_on_arrival') ...[
                _summaryRow('Cash downpayment (50%)', coaDownpayment),
                _summaryRow('Remaining cash balance', coaRemaining),
              ],
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _submitting ||
                          _loadingAvailability ||
                          _timeUnavailable ||
                          _total <= 0
                      ? null
                      : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: AppColors.onAccent,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    shadowColor: AppColors.accent.withValues(alpha: .34),
                  ),
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: AppText(
                    _submitting
                        ? 'Submitting...'
                        : _payment == 'cash_on_arrival'
                        ? 'Continue · \u{20B1} ${coaDownpayment.toStringAsFixed(2)} downpayment'
                        : 'Pay · \u{20B1} ${_total.toStringAsFixed(2)}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayPlanPrice(String plan) {
    return _basePrice(plan).toStringAsFixed(2);
  }

  String _coachDurationLabel(int months) =>
      '$months ${months == 1 ? 'month' : 'months'}';

  Widget _coachDurationSelector() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: AppText(
            'Coach duration',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
            localize: true,
          ),
        ),
        IconButton(
          key: const ValueKey('fitness-coach-duration-decrease'),
          tooltip: appLanguageText(
            'Decrease coach duration',
            'Decrease coach duration',
          ),
          onPressed: _coachDurationMonths <= 1
              ? null
              : () => setState(() => _coachDurationMonths--),
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        AppText(
          _coachDurationLabel(_coachDurationMonths),
          key: const ValueKey('fitness-coach-duration-value'),
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
        IconButton(
          key: const ValueKey('fitness-coach-duration-increase'),
          tooltip: appLanguageText(
            'Increase coach duration',
            'Increase coach duration',
          ),
          onPressed: _coachDurationMonths >= _maximumCoachDurationMonths
              ? null
              : () => setState(() => _coachDurationMonths++),
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    ),
  );

  Widget _availabilityNote() {
    if (_loadingAvailability) {
      return const Row(
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 6),
          AppText('Checking first-visit availability...', localize: true),
        ],
      );
    }
    if (_timeUnavailable) {
      return AppText(
        'This time overlaps a booking. Choose another visit time.',
        style: TextStyle(
          color: AppColors.errorText,
          fontWeight: FontWeight.w600,
        ),
        localize: true,
      );
    }
    return AppText(
      _time == null
          ? 'Choose a time to check availability. Visits are reserved in one-hour blocks.'
          : 'This one-hour first-visit time is available.',
      style: TextStyle(color: AppColors.muted),
    );
  }

  Widget _modalIconButton(IconData icon, VoidCallback onPressed) => SizedBox(
    width: 44,
    height: 44,
    child: IconButton(
      onPressed: onPressed,
      padding: AppSpacing.buttonPadding,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surfaceVariant,
        foregroundColor: _ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      icon: Icon(icon, size: 19),
    ),
  );

  Widget _bookingDetail(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 6),
        Expanded(
          child: AppText(
            text,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _summaryRow(
    String label,
    double amount, {
    String suffix = '',
    bool strong = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: AppText(
            label,
            style: TextStyle(
              color: strong ? _ink : AppColors.muted,
              fontSize: strong ? 14 : 12,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        AppText(
          amount == 0 && suffix.isNotEmpty
              ? suffix
              : '\u{20B1} ${amount.toStringAsFixed(2)}$suffix',
          style: TextStyle(
            color: strong ? _ink : AppColors.muted,
            fontSize: strong ? 14 : 12,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  ButtonStyle _choiceStyle() => OutlinedButton.styleFrom(
    foregroundColor: _ink,
    backgroundColor: AppColors.surface,
    alignment: Alignment.centerLeft,
    padding: AppSpacing.buttonPadding,
    side: BorderSide(color: AppColors.border, width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
  );

  InputDecoration _decoration({
    required Icon prefixIcon,
    required String labelText,
  }) => InputDecoration(
    prefixIcon: prefixIcon,
    labelText: appLanguageText(labelText, labelText),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: AppColors.border),
    ),
  );
}
