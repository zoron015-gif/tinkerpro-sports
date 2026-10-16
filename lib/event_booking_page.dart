import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_session.dart';
import 'auth_api.dart';
import 'app_design_system.dart';
import 'booking_cancellation_notice.dart';
import 'features/bookings/presentation/booking_schedule_conflict.dart';
import 'app_preferences.dart';
import 'features/bookings/data/http_booking_schedule_repository.dart';
import 'features/bookings/application/booking_schedule_controller.dart';

class _EventVenueHours {
  const _EventVenueHours(this.openingMinute, this.closingMinute);

  final int openingMinute;
  final int closingMinute;

  TimeOfDay get openingTime =>
      TimeOfDay(hour: openingMinute ~/ 60, minute: openingMinute % 60);
  TimeOfDay get closingTime =>
      TimeOfDay(
        hour: (closingMinute % (24 * 60)) ~/ 60,
        minute: closingMinute % 60,
      );
  double get durationHours => (closingMinute - openingMinute) / 60;

  static _EventVenueHours? parse(String value) {
    final match = RegExp(
      r'^\s*(\d{1,2})(?::(\d{2}))?\s*(AM|PM)\s*[-–]\s*(\d{1,2})(?::(\d{2}))?\s*(AM|PM)\s*$',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return null;

    int? toMinutes(
      String? hourText,
      String? minuteText,
      String? period, {
      bool isClosing = false,
    }) {
      final hour = int.tryParse(hourText ?? '');
      final minute = int.tryParse(minuteText ?? '0');
      if (hour == null ||
          hour < 1 ||
          hour > 12 ||
          minute == null ||
          minute > 59 ||
          period == null) {
        return null;
      }
      final minutes =
          (hour % 12 + (period.toUpperCase() == 'PM' ? 12 : 0)) * 60 +
          minute;
      if (isClosing &&
          hour == 12 &&
          minute == 0 &&
          period.toUpperCase() == 'AM') {
        return 24 * 60;
      }
      return minutes;
    }

    final opening = toMinutes(match.group(1), match.group(2), match.group(3));
    final closing = toMinutes(
      match.group(4),
      match.group(5),
      match.group(6),
      isClosing: true,
    );
    if (opening == null || closing == null || closing <= opening) return null;
    return _EventVenueHours(opening, closing);
  }
}

class EventBookingPage extends StatefulWidget {
  const EventBookingPage({
    required this.business,
    this.api,
    this.asCheckoutSheet = false,
    super.key,
  });

  final Map<String, dynamic> business;
  final AuthApi? api;
  final bool asCheckoutSheet;

  @override
  State<EventBookingPage> createState() => _EventBookingPageState();
}

class _EventBookingPageState extends State<EventBookingPage> {
  late final AuthApi _api = widget.api ?? AuthApi();
  late final List<String> _eventTypes = _readEventTypes();
  late final int _attendanceMin = _number(widget.business['attendanceMin']);
  late final int _attendanceMax = _number(widget.business['attendanceMax']);
  late final double _eventFee = _decimal(
    widget.business['eventFee'] ?? widget.business['event_fee'],
  );
  final _guestCountController = TextEditingController();
  late DateTime _date = DateTime.now().add(const Duration(days: 1));
  late final _EventVenueHours? _venueHours = _EventVenueHours.parse(
    '${widget.business['hours'] ?? ''}',
  );
  String? _eventType;
  String? _eventTypeError;
  String? _guestCountError;
  final _eventTypeFieldKey = GlobalKey();
  final _guestCountFieldKey = GlobalKey();
  String _paymentMethod = 'cash_on_arrival';
  final String _bookingIdempotencyKey = newBookingIdempotencyKey();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _eventType = _eventTypes.isEmpty ? null : _eventTypes.first;
    final initialGuests = _attendanceMin > 0 ? _attendanceMin : 1;
    _guestCountController.text = '$initialGuests';
  }

  @override
  void dispose() {
    _guestCountController.dispose();
    super.dispose();
  }

  List<String> _readEventTypes() {
    final raw = widget.business['eventTypes'] ?? widget.business['event_types'];
    if (raw is List) {
      return raw
          .map((value) => '$value'.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    final category = '${widget.business['category'] ?? ''}'.trim();
    return category.isEmpty ? const [] : [category];
  }

  IconData _eventTypeIcon(String eventType) {
    final normalized = eventType.trim().toLowerCase();
    if (normalized.contains('wedding')) return Icons.favorite_rounded;
    if (normalized.contains('birthday')) return Icons.cake_rounded;
    if (normalized.contains('conference') ||
        normalized.contains('corporate') ||
        normalized.contains('business')) {
      return Icons.business_center_rounded;
    }
    if (normalized.contains('meeting')) return Icons.groups_rounded;
    if (normalized.contains('party') || normalized.contains('celebration')) {
      return Icons.celebration_rounded;
    }
    return Icons.event_available_rounded;
  }

  int _number(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  double _decimal(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  String get _venueName => '${widget.business['name'] ?? 'Event venue'}';

  String get _dateValue =>
      '${_date.year.toString().padLeft(4, '0')}-'
      '${_date.month.toString().padLeft(2, '0')}-'
      '${_date.day.toString().padLeft(2, '0')}';

  TimeOfDay get _startTime =>
      _venueHours?.openingTime ?? const TimeOfDay(hour: 9, minute: 0);

  String get _timeValue =>
      '${_startTime.hour.toString().padLeft(2, '0')}:'
      '${_startTime.minute.toString().padLeft(2, '0')}';

  double get _durationHours => _venueHours?.durationHours ?? 0;

  double get _cashOnArrivalAmount =>
      double.parse((_eventFee * 0.5).toStringAsFixed(2));

  List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return _readStringList(decoded);
      } on FormatException {
        return value
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }

  String get _merchantDetails {
    const generatedLabels = [
      'Event type:',
      'Event types:',
      'Estimated attendance:',
      'Accessibility needs:',
      'Parking needs:',
      'Security needs:',
    ];
    return '${widget.business['details'] ?? ''}'
        .split('\n')
        .where(
          (line) => !generatedLabels.any((label) => line.startsWith(label)),
        )
        .join('\n')
        .trim();
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date != null) setState(() => _date = date);
  }

  void _scrollToField(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 250),
      alignment: .15,
    );
  }

  Future<void> _submit() async {
    if (_eventType == null) {
      setState(
        () => _eventTypeError =
            'Choose one of the event types offered by this venue.',
      );
      _scrollToField(_eventTypeFieldKey);
      return;
    }
    if (_venueHours == null) {
      _showError(
        'This venue must provide valid same-day opening and closing hours before an event can be booked.',
      );
      return;
    }
    setState(() => _eventTypeError = null);
    final guestText = _guestCountController.text.trim();
    final guests = int.tryParse(guestText);
    String? guestError;
    if (guestText.isEmpty) {
      guestError = 'Enter how many guests you’re expecting.';
    } else if (guests == null || guests < 1) {
      guestError = 'Enter a whole number of at least 1 guest.';
    } else if (_attendanceMin > 0 && guests < _attendanceMin) {
      guestError =
          'This venue requires at least $_attendanceMin guests. Please adjust your count.';
    } else if (_attendanceMax > 0 && guests > _attendanceMax) {
      guestError =
          'This venue can host up to $_attendanceMax guests. Please adjust your count.';
    }
    if (guestError != null) {
      setState(() => _guestCountError = guestError);
      _scrollToField(_guestCountFieldKey);
      return;
    }
    if (guests == null) {
      setState(
        () => _guestCountError = 'Enter a whole number of at least 1 guest.',
      );
      _scrollToField(_guestCountFieldKey);
      return;
    }
    setState(() => _guestCountError = null);
    if (_eventFee <= 0) {
      _showError(
        'This venue’s event price isn’t available right now. Please contact the venue.',
      );
      return;
    }

    try {
      final token = (await AppSession.load()).apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Please sign in before booking.', 401);
      }
      if (!mounted) return;
      final paymentLabel = _paymentMethod == 'cash_on_arrival'
          ? 'Cash on Arrival · 50% cash downpayment after approval'
          : 'Online payment · due after approval';
      final bookingStart = DateTime(
        _date.year,
        _date.month,
        _date.day,
        _startTime.hour,
        _startTime.minute,
      );
      final scheduleAvailable = await confirmBookingScheduleConflict(
        context: context,
        controller: BookingScheduleController(
          repository: HttpBookingScheduleRepository(
            client: _api.httpClient,
            authHeaders: _api.authHeadersForToken,
            token: token,
          ),
        ),
        venueId: _number(widget.business['id']),
        venueName: _venueName,
        startsAt: bookingStart,
        durationHours: _durationHours.toDouble(),
      );
      if (!scheduleAvailable || !mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const AppText('Confirm event booking', localize: true),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Please check that all information is correct before continuing.',
                  style: TextStyle(color: AppColors.muted),
                  localize: true,
                ),
                const SizedBox(height: 6),
                _confirmationRow('Venue', _venueName),
                _confirmationRow('Event type', _eventType!),
                _confirmationRow('Date', _dateValue),
                _confirmationRow(
                  'Venue hours',
                  '${_venueHours.openingTime.format(context)} - ${_venueHours.closingTime.format(context)}',
                ),
                _confirmationRow('Guests', '$guests'),
                _confirmationRow('Payment', paymentLabel),
                _confirmationRow(
                  _paymentMethod == 'cash_on_arrival'
                      ? 'Cash downpayment due after approval'
                      : 'Online amount due after approval',
                  '\u{20B1} ${(_paymentMethod == 'cash_on_arrival' ? _cashOnArrivalAmount : _eventFee).toStringAsFixed(2)}',
                ),
                if (_paymentMethod == 'online')
                  const AppText(
                    'Pay the full amount within 15 minutes after venue approval.',
                    localize: true,
                  ),
                const SizedBox(height: 12),
                const BookingCancellationNotice(),
                if (_paymentMethod == 'cash_on_arrival')
                  _confirmationRow(
                    'Remaining cash balance',
                    '\u{20B1} ${(_eventFee - _cashOnArrivalAmount).toStringAsFixed(2)}',
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel', localize: true),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const AppText('Confirm booking', localize: true),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _submitting = true);
      await _api.createBooking(
        token: token,
        idempotencyKey: _bookingIdempotencyKey,
        venueId: _number(widget.business['id']),
        date: _dateValue,
        startTime: '$_timeValue:00',
        durationHours: _durationHours,
        players: guests,
        paymentMethod: _paymentMethod,
        eventType: _eventType!,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Exception catch (error) {
      _showError('Could not submit event booking: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(message)));
  }

  @override
  Widget build(BuildContext context) {
    final guests = int.tryParse(_guestCountController.text) ?? 0;
    final guestRange = _attendanceMin > 0 && _attendanceMax > 0
        ? 'Venue capacity: $_attendanceMin–$_attendanceMax guests'
        : _attendanceMin > 0
        ? 'Minimum $_attendanceMin guests'
        : _attendanceMax > 0
        ? 'Maximum $_attendanceMax guests'
        : 'Enter the expected number of guests.';
    final amenities = _readStringList(
      widget.business['tags'] ?? widget.business['amenities'],
    );
    final accessibilityNeeds = _readStringList(
      widget.business['accessibilityNeeds'],
    );
    final parkingNeeds = _readStringList(widget.business['parkingNeeds']);
    final securityNeeds = _readStringList(widget.business['securityNeeds']);
    final availability = '${widget.business['availability'] ?? ''}'.trim();
    return Scaffold(
      backgroundColor: widget.asCheckoutSheet ? AppColors.page : AppColors.page,
      appBar: widget.asCheckoutSheet
          ? null
          : AppBar(
              title: Column(
                children: [
                  AppText('Book Event', localize: true),
                  SizedBox(height: 6),
                  AppText(
                    'Step 2 of 2 · Checkout',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    localize: true,
                  ),
                ],
              ),
              centerTitle: true,
              backgroundColor: AppColors.page,
              foregroundColor: AppColors.ink,
              surfaceTintColor: Colors.transparent,
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: widget.asCheckoutSheet
                  ? EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      MediaQuery.viewInsetsOf(context).bottom + 20,
                    )
                  : const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                if (widget.asCheckoutSheet) ...[
                  Row(
                    children: [
                      _checkoutIconButton(
                        Icons.arrow_back_rounded,
                        () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            AppText(
                              'Book Event',
                              style: TextStyle(
                                color: AppColors.ink,
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
                      _checkoutIconButton(
                        Icons.help_outline_rounded,
                        () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const AppText(
                              'Event booking',
                              localize: true,
                            ),
                            content: const AppText(
                              'Choose your event details and payment method. '
                              'The venue merchant will review your request.',
                              localize: true,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const AppText('Got it', localize: true),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Container(
                  key: const ValueKey('event-booking-summary-card'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
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
                                    'EVENT',
                                    style: TextStyle(
                                      color: AppColors.accentForeground,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .7,
                                    ),
                                    localize: true,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                AppText(
                                  _venueName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          AppText(
                            '\u{20B1} ${_eventFee.toStringAsFixed(2)}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: AppColors.accentForeground,
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
                      if ('${widget.business['facilityType'] ?? ''}'
                          .trim()
                          .isNotEmpty)
                        _bookingDetail(
                          Icons.business_outlined,
                          'Venue type: ${widget.business['facilityType']}',
                        ),
                      if ('${widget.business['hours'] ?? ''}'.trim().isNotEmpty)
                        _bookingDetail(
                          Icons.access_time_rounded,
                          'Venue hours: ${widget.business['hours']}',
                        ),
                      if (availability.isNotEmpty)
                        _bookingDetail(
                          Icons.event_available_outlined,
                          'Available days: $availability',
                        ),
                      if (_eventTypes.isNotEmpty)
                        _bookingDetail(
                          Icons.celebration_outlined,
                          'Events offered: ${_eventTypes.join(', ')}',
                        ),
                      if (_attendanceMin > 0 || _attendanceMax > 0)
                        _bookingDetail(
                          Icons.groups_outlined,
                          'Guest capacity: '
                          '${_attendanceMin > 0 ? _attendanceMin : 'No minimum'}'
                          '–${_attendanceMax > 0 ? _attendanceMax : 'No maximum'}',
                        ),
                      if (amenities.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        AppText(
                          'VENUE AMENITIES',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .8,
                          ),
                          localize: true,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: amenities
                              .map(
                                (amenity) => Chip(
                                  label: AppText(amenity),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      if (accessibilityNeeds.isNotEmpty)
                        _bookingDetail(
                          Icons.accessible_forward_rounded,
                          'Accessibility: ${accessibilityNeeds.join(', ')}',
                        ),
                      if (parkingNeeds.isNotEmpty)
                        _bookingDetail(
                          Icons.local_parking_rounded,
                          'Parking: ${parkingNeeds.join(', ')}',
                        ),
                      if (securityNeeds.isNotEmpty)
                        _bookingDetail(
                          Icons.security_rounded,
                          'Security: ${securityNeeds.join(', ')}',
                        ),
                      if (_merchantDetails.isNotEmpty)
                        _bookingDetail(
                          Icons.info_outline_rounded,
                          _merchantDetails,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                _sectionLabel('BOOKING CONFIGURATION'),
                DropdownButtonFormField<String>(
                  key: _eventTypeFieldKey,
                  initialValue: _eventType,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    'Select event type',
                    prefixIcon: Icon(_eventTypeIcon(_eventType ?? '')),
                    labelText: appLanguageText('Event type', 'Event type'),
                  ).copyWith(errorText: _eventTypeError),
                  items: _eventTypes
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: AppText(type)),
                      )
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() {
                          _eventType = value;
                          _eventTypeError = null;
                        }),
                ),
                const SizedBox(height: 6),
                _sectionLabel('CHOOSE DATE'),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _chooseDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: AppText(_dateValue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _sectionLabel('EVENT HOURS'),
                if (_venueHours == null)
                  const AppText(
                    'This venue has not provided valid opening and closing hours. Event bookings are unavailable until the venue updates its hours.',
                    localize: true,
                  )
                else
                  AppText(
                    'The event reserves the venue from ${_venueHours.openingTime.format(context)} to ${_venueHours.closingTime.format(context)}.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                const SizedBox(height: 6),
                _sectionLabel('GUESTS'),
                TextField(
                  key: _guestCountFieldKey,
                  controller: _guestCountController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(
                    guestRange,
                    prefixIcon: const Icon(Icons.groups_outlined),
                    labelText: appLanguageText(
                      'Expected guests',
                      'Expected guests',
                    ),
                  ).copyWith(errorText: _guestCountError),
                  onChanged: (_) => setState(() => _guestCountError = null),
                ),
                const SizedBox(height: 6),
                _sectionLabel('PAYMENT METHOD'),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 380;
                    return SegmentedButton<String>(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? AppColors.accent
                              : AppColors.surface,
                        ),
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? AppColors.onAccent
                              : AppColors.ink,
                        ),
                        side: WidgetStateProperty.all(
                          BorderSide(color: AppColors.border),
                        ),
                      ),
                      segments: [
                        ButtonSegment(
                          value: 'online',
                          label: AppText(compact ? 'Online' : 'Online payment'),
                          icon: const Icon(Icons.lock_rounded),
                        ),
                        const ButtonSegment(
                          value: 'cash_on_arrival',
                          label: AppText('COA', localize: true),
                          icon: Icon(Icons.payments_outlined),
                        ),
                      ],
                      selected: {_paymentMethod},
                      onSelectionChanged: _submitting
                          ? null
                          : (selection) => setState(
                              () => _paymentMethod = selection.first,
                            ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                AppText(
                  _paymentMethod == 'cash_on_arrival'
                      ? 'After approval, pay \u{20B1} ${_cashOnArrivalAmount.toStringAsFixed(2)} cash as a downpayment at the venue and \u{20B1} ${(_eventFee - _cashOnArrivalAmount).toStringAsFixed(2)} cash as the remaining balance.'
                      : 'No payment is taken with this request. After approval, pay \u{20B1} ${_eventFee.toStringAsFixed(2)} online within 15 minutes.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const Divider(height: 24),
                _paymentSummaryRow(
                  'Event fee',
                  '\u{20B1} ${_eventFee.toStringAsFixed(2)}',
                ),
                _paymentSummaryRow('Guests', '$guests'),
                _paymentScheduleRow(),
                _paymentSummaryRow(
                  'Event total',
                  '\u{20B1} ${_eventFee.toStringAsFixed(2)}',
                ),
                _paymentSummaryRow(
                  _paymentMethod == 'cash_on_arrival'
                      ? 'Cash downpayment after approval'
                      : 'Online amount after approval',
                  '\u{20B1} ${(_paymentMethod == 'cash_on_arrival' ? _cashOnArrivalAmount : _eventFee).toStringAsFixed(2)}',
                  strong: true,
                ),
                if (_paymentMethod == 'cash_on_arrival')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: AppText(
                      'Cash on Arrival is fixed at 50% of the event fee.',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      localize: true,
                    ),
                  ),
                const SizedBox(height: 6),
                FilledButton.icon(
                  key: const ValueKey('event-booking-submit'),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_outline_rounded),
                  label: AppText(
                    _submitting
                        ? 'Submitting...'
                        : 'Request booking',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    shadowColor: AppColors.accent.withValues(alpha: .34),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bookingDetail(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.muted, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: AppText(value, style: TextStyle(color: AppColors.muted)),
        ),
      ],
    ),
  );

  Widget _checkoutIconButton(IconData icon, VoidCallback onPressed) => SizedBox(
    width: 44,
    height: 44,
    child: IconButton(
      onPressed: onPressed,
      padding: AppSpacing.buttonPadding,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surfaceVariant,
        foregroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      icon: Icon(icon, size: 19),
    ),
  );

  Widget _confirmationRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: AppText(
            label,
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: AppText(
            value,
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: AppText(
      text,
      style: TextStyle(
        color: AppColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: .7,
      ),
    ),
  );

  InputDecoration _inputDecoration(
    String hint, {
    Widget? prefixIcon,
    String? labelText,
  }) => InputDecoration(
    hintText: appLanguageText(hint, hint),
    labelText: labelText == null ? null : appLanguageText(labelText, labelText),
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.border),
    ),
  );

  Widget _paymentSummaryRow(
    String label,
    String value, {
    bool strong = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: AppText(
            label,
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Flexible(
          child: AppText(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _paymentScheduleRow() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          'Schedule',
          style: TextStyle(
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
          localize: true,
        ),
        const SizedBox(height: 2),
        AppText(
          '${MaterialLocalizations.of(context).formatShortDate(_date)} · '
          '${_venueHours == null ? 'Venue hours unavailable' : '${_venueHours.openingTime.format(context)} - ${_venueHours.closingTime.format(context)}'}',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
