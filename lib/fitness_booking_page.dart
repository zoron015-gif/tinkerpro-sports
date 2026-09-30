import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_session.dart';
import 'auth_api.dart';
import 'app_design_system.dart';
import 'fitness_booking_pricing.dart';

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
  static const _ink = AppColors.ink;
  static const _accent = AppColors.orange;

  late final List<Map<String, dynamic>> _categories;
  late final List<Map<String, dynamic>> _coaches;
  String? _category;
  String? _plan;
  String? _coachName;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  TimeOfDay? _time;
  String _payment = 'online';
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
    return FitnessBookingPricing.coachPrice(coach, _plan);
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
      _message('Please sign in before creating a booking.');
      return;
    }
    if (_businessId <= 0 ||
        _category == null ||
        _plan == null ||
        time == null) {
      _message(
        'Choose a category, available plan, date, and first-visit time.',
      );
      return;
    }
    if (_timeUnavailable) {
      _message('That first-visit time overlaps another booking.');
      return;
    }
    final payment = _payment;
    String? provider;
    try {
      if (payment == 'online') {
        provider = await _chooseProvider();
        if (provider == null) return;
        if (!await widget.api.payMongoPaymentsEnabled(token)) {
          if (!mounted) return;
          final useCash = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Online payment unavailable'),
              content: const Text(
                'Online payments are not configured yet. No booking has been '
                'created. You can choose Cash on Arrival or try again later.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Use Cash on Arrival'),
                ),
              ],
            ),
          );
          if (useCash == true && mounted) {
            setState(() => _payment = 'cash_on_arrival');
          }
          return;
        }
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Fitness booking'),
          content: Text(
            '${widget.business['name'] ?? 'Fitness venue'}\n'
            '$_category · ${_plan!.toUpperCase()}\n'
            '${_dateString(_date)} at ${time.format(context)}\n'
            '${_coachName == null ? 'No coach selected' : 'Coach: $_coachName'}\n'
            'One-time total: PHP ${_total.toStringAsFixed(2)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm booking'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _submitting = true);
      final response = await widget.api.createBooking(
        token: token,
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
      title: const Text('Choose online payment'),
      content: const Text('The selected term is charged once at checkout.'),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.pop(context, 'gcash'),
          icon: const Icon(Icons.account_balance_wallet_rounded),
          label: const Text('GCash'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, 'paymaya'),
          icon: const Icon(Icons.payments_rounded),
          label: const Text('PayMaya'),
        ),
      ],
    ),
  );

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
                  const Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Book Fitness',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Step 2 of 2 • Checkout',
                          style: TextStyle(
                            color: Color(0xFF68748A),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 38),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                key: const ValueKey('fitness-booking-summary-card'),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE8ECF3)),
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
                                  color: const Color(0xFFFFF1E8),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  (_category ?? 'FITNESS').toUpperCase(),
                                  style: const TextStyle(
                                    color: _accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .7,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'PHP ${categoryPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: _accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
              const SizedBox(height: 18),
              const Text(
                'FITNESS CONFIGURATION',
                style: TextStyle(
                  color: Color(0xFF68748A),
                  fontSize: 11,
                  letterSpacing: .9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: _decoration(
                  prefixIcon: const Icon(Icons.fitness_center_rounded),
                  labelText: 'Fitness category',
                ),
                items: _categories
                    .map((item) => item['category'])
                    .whereType<String>()
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
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
              const SizedBox(height: 14),
              const Text(
                'PLAN',
                style: TextStyle(
                  color: Color(0xFF68748A),
                  fontSize: 11,
                  letterSpacing: .9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (_availablePlans.isEmpty)
                const Text(
                  'This venue has no priced plans available for this category.',
                  style: TextStyle(color: Color(0xFF68748A)),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availablePlans.map((plan) {
                    final selected = plan == _plan;
                    return ChoiceChip(
                      label: Text(
                        '${_planTitle(plan)} · PHP ${_displayPlanPrice(plan)}',
                      ),
                      selected: selected,
                      onSelected: (_) => setState(() => _plan = plan),
                      selectedColor: const Color(0xFFFFE8D2),
                      labelStyle: TextStyle(
                        color: selected ? _accent : _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  }).toList(),
                ),
              if (_yearlyOfferLabel case final offer?) ...[
                const SizedBox(height: 8),
                Text(
                  offer,
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
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
                      labelText: 'Coach (optional)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No coach'),
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
                              const SizedBox(width: 8),
                              SizedBox(
                                width: coachLabelWidth,
                                child: Text(
                                  '$coachName · PHP '
                                  '${monthly.toStringAsFixed(2)}/month',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
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
                const SizedBox(height: 8),
                _summaryRow(
                  'Coach fee for ${_planTitle(_plan ?? 'session')}',
                  _coachPrice(),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                'FIRST VISIT',
                style: TextStyle(
                  color: Color(0xFF68748A),
                  fontSize: 11,
                  letterSpacing: .9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _chooseDate,
                      style: _choiceStyle(),
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(_dateString(_date)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _chooseTime,
                      style: _choiceStyle(),
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(_time?.format(context) ?? 'Choose time'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _availabilityNote(),
              const SizedBox(height: 18),
              const Text(
                'PAYMENT METHOD',
                style: TextStyle(
                  color: Color(0xFF68748A),
                  fontSize: 11,
                  letterSpacing: .9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? _accent
                        : Colors.white,
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? Colors.white
                        : _ink,
                  ),
                  side: WidgetStateProperty.all(
                    const BorderSide(color: Color(0xFFE2E7EF)),
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: 'online',
                    label: Text('Online payment'),
                    icon: Icon(Icons.lock_rounded),
                  ),
                  ButtonSegment(
                    value: 'cash_on_arrival',
                    label: Text('COA'),
                    icon: Icon(Icons.payments_outlined),
                  ),
                ],
                selected: {_payment},
                onSelectionChanged: (selection) {
                  setState(() => _payment = selection.first);
                },
              ),
              const SizedBox(height: 8),
              Text(
                _payment == 'cash_on_arrival'
                    ? 'Pay the selected plan total once on arrival: '
                          'PHP ${_total.toStringAsFixed(2)}.'
                    : 'Pay securely online once for the selected term: '
                          'PHP ${_total.toStringAsFixed(2)}.',
                style: const TextStyle(color: Color(0xFF68748A)),
              ),
              const Divider(height: 24),
              _summaryRow(
                '${_planTitle(_plan ?? 'Selected')} plan',
                _basePrice(),
              ),
              if (_coachPrice() > 0)
                _summaryRow('Coach · $_coachName', _coachPrice()),
              _summaryRow('First visit duration', 1, suffix: ' hour'),
              _summaryRow(
                'First visit',
                0,
                suffix: _time == null
                    ? _dateString(_date)
                    : '${_dateString(_date)} · ${_time!.format(context)}',
              ),
              _summaryRow('One-time total', _total, strong: true),
              const SizedBox(height: 12),
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
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    shadowColor: const Color(0x55FF8200),
                  ),
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: Text(
                    _submitting
                        ? 'Submitting...'
                        : '${_payment == 'cash_on_arrival' ? 'Continue' : 'Pay'} · '
                              'PHP ${_total.toStringAsFixed(2)}',
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

  Widget _availabilityNote() {
    if (_loadingAvailability) {
      return const Row(
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Checking first-visit availability...'),
        ],
      );
    }
    if (_timeUnavailable) {
      return const Text(
        'This time overlaps a booking. Choose another visit time.',
        style: TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w600),
      );
    }
    return Text(
      _time == null
          ? 'Choose a time to check availability. Visits are reserved in one-hour blocks.'
          : 'This one-hour first-visit time is available.',
      style: const TextStyle(color: Color(0xFF68748A)),
    );
  }

  Widget _modalIconButton(IconData icon, VoidCallback onPressed) => SizedBox(
    width: 38,
    height: 38,
    child: IconButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFF1F3F7),
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
        Icon(icon, size: 16, color: const Color(0xFF68748A)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF68748A),
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
          child: Text(
            label,
            style: TextStyle(
              color: strong ? _ink : const Color(0xFF68748A),
              fontSize: strong ? 14 : 12,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          amount == 0 && suffix.isNotEmpty
              ? suffix
              : 'PHP ${amount.toStringAsFixed(2)}$suffix',
          style: TextStyle(
            color: strong ? _ink : const Color(0xFF68748A),
            fontSize: strong ? 14 : 12,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  ButtonStyle _choiceStyle() => OutlinedButton.styleFrom(
    foregroundColor: _ink,
    backgroundColor: Colors.white,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    side: const BorderSide(color: Color(0xFFE2E7EF), width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
  );

  InputDecoration _decoration({
    required Icon prefixIcon,
    required String labelText,
  }) => InputDecoration(
    prefixIcon: prefixIcon,
    labelText: labelText,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0xFFE2E7EF)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0xFFE2E7EF)),
    ),
  );
}
