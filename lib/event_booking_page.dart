import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_session.dart';
import 'auth_api.dart';

class EventBookingPage extends StatefulWidget {
  const EventBookingPage({required this.business, this.api, super.key});

  final Map<String, dynamic> business;
  final AuthApi? api;

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
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  int _durationHours = 4;
  String? _eventType;
  String _paymentMethod = 'online';
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

  int _number(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  double _decimal(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  String get _venueName => '${widget.business['name'] ?? 'Event venue'}';

  String get _dateValue =>
      '${_date.year.toString().padLeft(4, '0')}-'
      '${_date.month.toString().padLeft(2, '0')}-'
      '${_date.day.toString().padLeft(2, '0')}';

  String get _timeValue =>
      '${_startTime.hour.toString().padLeft(2, '0')}:'
      '${_startTime.minute.toString().padLeft(2, '0')}';

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date != null) setState(() => _date = date);
  }

  Future<void> _chooseTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (time != null) setState(() => _startTime = time);
  }

  Future<void> _submit() async {
    final guests = int.tryParse(_guestCountController.text.trim());
    if (_eventType == null) {
      _showError('Choose an event type offered by this venue.');
      return;
    }
    if (guests == null ||
        guests < 1 ||
        (_attendanceMin > 0 && guests < _attendanceMin) ||
        (_attendanceMax > 0 && guests > _attendanceMax)) {
      final range = _attendanceMin > 0 && _attendanceMax > 0
          ? 'Choose between $_attendanceMin and $_attendanceMax guests.'
          : 'Enter a valid guest count.';
      _showError(range);
      return;
    }
    if (_eventFee <= 0) {
      _showError('This venue does not have a valid event fee.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final token = (await AppSession.load()).apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Please sign in before booking.', 401);
      }
      if (_paymentMethod == 'online' &&
          !await _api.payMongoPaymentsEnabled(token)) {
        throw const AuthApiException(
          'Online payments are not configured for this venue yet. Select Cash on Arrival or try later.',
          503,
        );
      }
      final bookingResponse = await _api.createBooking(
        token: token,
        venueId: _number(widget.business['id']),
        date: _dateValue,
        startTime: _timeValue,
        durationHours: _durationHours.toDouble(),
        players: guests,
        paymentMethod: _paymentMethod,
        eventType: _eventType!,
      );
      final booking = bookingResponse['booking'] as Map<String, dynamic>?;
      if (booking == null) {
        throw const AuthApiException(
          'The server did not return the event booking details.',
          502,
        );
      }

      if (_paymentMethod == 'online') {
        final checkout = await _api.createPayMongoCheckout(
          token: token,
          bookingId: _number(booking['id']),
          paymentMethod: 'gcash',
        );
        final checkoutUrl = checkout['checkoutUrl'] as String?;
        if (checkoutUrl == null || checkoutUrl.isEmpty) {
          throw const AuthApiException(
            'The payment provider did not return a checkout link.',
            502,
          );
        }
        final launched = await launchUrl(
          Uri.parse(checkoutUrl),
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          throw const AuthApiException('Could not open the payment page.', 0);
        }
      }

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
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final guests = int.tryParse(_guestCountController.text) ?? 0;
    final guestRange = _attendanceMin > 0 && _attendanceMax > 0
        ? 'Venue capacity: $_attendanceMin–$_attendanceMax guests'
        : 'Enter the expected number of guests.';
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Book an event'),
        backgroundColor: const Color(0xFFF7F9FC),
        foregroundColor: const Color(0xFF101B33),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Text(
              _venueName,
              style: const TextStyle(
                color: Color(0xFF101B33),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Choose your event details. The venue will review your request.',
              style: TextStyle(color: Color(0xFF68748A)),
            ),
            const SizedBox(height: 20),
            _sectionLabel('EVENT TYPE'),
            DropdownButtonFormField<String>(
              initialValue: _eventType,
              decoration: _inputDecoration('Select event type'),
              items: _eventTypes
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _eventType = value),
            ),
            const SizedBox(height: 16),
            _sectionLabel('DATE AND TIME'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : _chooseDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(_dateValue),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : _chooseTime,
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(_startTime.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _sectionLabel('DURATION'),
            DropdownButtonFormField<int>(
              initialValue: _durationHours,
              decoration: _inputDecoration('Event duration'),
              items: List.generate(
                24,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text('${index + 1} hour${index == 0 ? '' : 's'}'),
                ),
              ),
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value != null) setState(() => _durationHours = value);
                    },
            ),
            const SizedBox(height: 16),
            _sectionLabel('GUESTS'),
            TextField(
              controller: _guestCountController,
              enabled: !_submitting,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(guestRange),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _sectionLabel('PAYMENT'),
            RadioGroup<String>(
              groupValue: _paymentMethod,
              onChanged: (value) {
                if (!_submitting && value != null) {
                  setState(() => _paymentMethod = value);
                }
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'online',
                    title: const Text('Pay online with GCash'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<String>(
                    value: 'cash_on_arrival',
                    title: const Text('Cash on arrival'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _summaryRow('Guests', '$guests'),
                    const SizedBox(height: 8),
                    _summaryRow(
                      'Event fee',
                      'PHP ${_eventFee.toStringAsFixed(2)}',
                    ),
                    const Divider(height: 20),
                    _summaryRow(
                      'Total',
                      'PHP ${_eventFee.toStringAsFixed(2)}',
                      bold: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.event_available_rounded),
              label: Text(
                _submitting
                    ? 'Submitting...'
                    : _paymentMethod == 'online'
                    ? 'Request and pay online'
                    : 'Request event booking',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF8200),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFF68748A),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: .7,
      ),
    ),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDCE3EF)),
    ),
  );

  Widget _summaryRow(String label, String value, {bool bold = false}) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: const Color(0xFF68748A),
            fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color: const Color(0xFF101B33),
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
    ],
  );
}
