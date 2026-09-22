import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_session.dart';
import 'auth_api.dart';

const _addNavy = Color(0xFF192B50);
const _addInk = Color(0xFF101B33);
const _addOrange = Color(0xFFFF8200);
const _addSoftOrange = Color(0xFFFFE8D2);
const _addMuted = Color(0xFF68748A);
const _addLine = Color(0xFFE2E7EF);

class _MerchantBusinessFormPanel extends StatefulWidget {
  const _MerchantBusinessFormPanel({required this.builder});

  final Widget Function(BuildContext context, StateSetter setPanelState)
  builder;

  @override
  State<_MerchantBusinessFormPanel> createState() =>
      _MerchantBusinessFormPanelState();
}

class _MerchantBusinessFormPanelState
    extends State<_MerchantBusinessFormPanel> {
  void _setPanelState(VoidCallback callback) {
    if (!mounted) return;
    setState(callback);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _setPanelState);
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

class _RatePeriod {
  TimeOfDay? start;
  TimeOfDay? end;
  final price = TextEditingController();

  void dispose() => price.dispose();
}

class MerchantAddPage extends StatefulWidget {
  const MerchantAddPage({
    super.key,
    required this.initialBusinessType,
    required this.businesses,
    required this.onBusinessesChanged,
  });

  final String? initialBusinessType;
  final List<Map<String, dynamic>> businesses;
  final Future<void> Function() onBusinessesChanged;

  @override
  State<MerchantAddPage> createState() => _MerchantAddPageState();
}

class _MerchantAddPageState extends State<MerchantAddPage> {
  static const _categories = {
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

  final _api = AuthApi();
  bool _saving = false;
  String _selectedBusinessType = 'All';

  Future<void> _openForm([Map<String, dynamic>? editingBusiness]) async {
    final editing = editingBusiness != null;
    final name = TextEditingController();
    final address = TextEditingController();
    final visitUrl = TextEditingController();
    final price = TextEditingController();
    final details = TextEditingController();
    final categoryOther = TextEditingController();
    final amenityOther = TextEditingController();
    final eventTypeOther = TextEditingController();
    final eventAttendanceMin = TextEditingController();
    final eventAttendanceMax = TextEditingController();
    final accessibilityInput = TextEditingController();
    final parkingInput = TextEditingController();
    final securityInput = TextEditingController();
    final formKey = GlobalKey<FormState>();
    const types = ['Sports', 'Event', 'Fitness & Wellness'];
    String type = types.contains(editingBusiness?['businessType'])
        ? editingBusiness!['businessType'] as String
        : types.contains(widget.initialBusinessType)
        ? widget.initialBusinessType!
        : 'Sports';
    final existingCategory = editingBusiness?['category'] as String?;
    String category = {..._categories[type]!, 'Other'}.contains(existingCategory)
        ? existingCategory ?? _categories[type]!.first
        : 'Other';
    if (category == 'Other' && existingCategory != null) {
      categoryOther.text = existingCategory == 'Other' ? '' : existingCategory;
    }
    String facility = editingBusiness?['facilityType'] as String? ?? 'Indoor';
    TimeOfDay? parseTime(dynamic value) {
      final text = '$value'.trim();
      final match = RegExp(
        r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
        caseSensitive: false,
      ).firstMatch(text);
      if (match == null) {
        return null;
      }
      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      if (match.group(3)!.toUpperCase() == 'PM' && hour != 12) hour += 12;
      if (match.group(3)!.toUpperCase() == 'AM' && hour == 12) hour = 0;
      return hour < 24 && minute < 60
          ? TimeOfDay(hour: hour, minute: minute)
          : null;
    }

    (TimeOfDay?, TimeOfDay?) parseHours(String? value) {
      if (value == null) return (null, null);
      final parts = value.split(' - ');
      return parts.length == 2
          ? (parseTime(parts[0]), parseTime(parts[1]))
          : (null, null);
    }

    final availableDays = <String>{..._weekdays};
    final existingAvailability = editingBusiness?['availability'] as String?;
    if (existingAvailability != null &&
        existingAvailability.trim().isNotEmpty) {
      availableDays
        ..clear()
        ..addAll(existingAvailability.split(',').map((day) => day.trim()));
    }
    final hours = parseHours(editingBusiness?['hours'] as String?);
    TimeOfDay? openingTime = hours.$1;
    TimeOfDay? closingTime = hours.$2;
    final ratePeriods = <_RatePeriod>[];
    final amenities = <String>{};
    final eventTypes = <String>[];
    final accessibilityNeeds = <String>[];
    final parkingNeeds = <String>[];
    final securityNeeds = <String>[];
    const eventTypeOptions = [
      'Conference',
      'Wedding',
      'Workshop',
      'Corporate meeting',
      'Birthday',
      'Seminar',
      'Party',
      'Other',
    ];
    const amenityOptions = [
      'Parking',
      'Pet-friendly',
      'Restroom',
      'Shower',
      'Store',
      'Other',
    ];
    final images = <String>[];
    final existingImages =
        editingBusiness?['imageUrls'] ?? editingBusiness?['image_urls'];
    if (existingImages is List) {
      images.addAll(existingImages.whereType<String>().where((value) => value.isNotEmpty));
    } else if (existingImages is String && existingImages.isNotEmpty) {
      try {
        final decoded = jsonDecode(existingImages);
        if (decoded is List) {
          images.addAll(decoded.whereType<String>().where((value) => value.isNotEmpty));
        }
      } on FormatException {
        // Fall back to the legacy single-image field below.
      }
    }
    if (images.isEmpty) {
      final legacyImage = editingBusiness?['imageUrl'] as String?;
      if (legacyImage != null && legacyImage.isNotEmpty) {
        try {
          final decoded = jsonDecode(legacyImage);
          if (decoded is List) {
            images.addAll(decoded.whereType<String>().where((value) => value.isNotEmpty));
          }
        } on FormatException {
          images.add(legacyImage);
        }
        if (images.isEmpty) images.add(legacyImage);
      }
    }
    name.text = editingBusiness?['name'] as String? ?? '';
    address.text = editingBusiness?['address'] as String? ?? '';
    visitUrl.text =
        editingBusiness?['visitUrl'] as String? ??
        editingBusiness?['visit_url'] as String? ??
        '';
    price.text =
        '${editingBusiness?['eventFee'] ??
        editingBusiness?['event_fee'] ??
        editingBusiness?['pricePerHour'] ??
        ''}';
    details.text = editingBusiness?['details'] as String? ?? '';
    String eventDetailValue(String label) {
      final match = RegExp(
        '^${RegExp.escape(label)}:\\s*(.*)\$',
        multiLine: true,
      ).firstMatch(details.text);
      return match?.group(1)?.trim() ?? '';
    }

    if (editing && type == 'Event') {
      eventTypes.addAll(
        eventDetailValue('Event types')
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      );
      if (eventTypes.isEmpty) {
        eventTypes.addAll(
          eventDetailValue('Event type')
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty),
        );
      }
      final customEventType = eventTypes
          .where((value) => !eventTypeOptions.contains(value) || value == 'Other')
          .firstWhere((value) => value != 'Other', orElse: () => '');
      if (customEventType.isNotEmpty) {
        eventTypes
          ..remove(customEventType)
          ..remove('Other')
          ..add('Other');
        eventTypeOther.text = customEventType;
      }
      final attendance = eventDetailValue('Estimated attendance')
          .replaceAll('guests', '')
          .trim()
          .split('-')
          .map((value) => value.trim())
          .toList();
      if (attendance.isNotEmpty) eventAttendanceMin.text = attendance.first;
      if (attendance.length > 1) eventAttendanceMax.text = attendance[1];
      List<String> parseNeeds(String label) => eventDetailValue(label)
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      accessibilityNeeds.addAll(parseNeeds('Accessibility needs'));
      parkingNeeds.addAll(parseNeeds('Parking needs'));
      securityNeeds.addAll(parseNeeds('Security needs'));
      const eventLabels = [
        'Event type:',
        'Event types:',
        'Estimated attendance:',
        'Accessibility needs:',
        'Parking needs:',
        'Security needs:',
      ];
      details.text = details.text
          .split('\n')
          .where(
            (line) => !eventLabels.any((label) => line.startsWith(label)),
          )
          .join('\n')
          .trim();
    }
    dynamic existingAmenities = editingBusiness?['tags'];
    if (existingAmenities is String) {
      try {
        existingAmenities = jsonDecode(existingAmenities);
      } on FormatException {
        existingAmenities = null;
      }
    }
    if (existingAmenities is List) {
      amenities.addAll(existingAmenities.whereType<String>());
      final customAmenities = amenities
          .where((value) => !amenityOptions.contains(value))
          .toList();
      if (customAmenities.isNotEmpty) {
        amenities
          ..removeAll(customAmenities)
          ..add('Other');
        amenityOther.text = customAmenities.join(', ');
      }
    }
    dynamic rawPeriods =
        editingBusiness?['ratePeriods'] ?? editingBusiness?['rate_periods'];
    if (rawPeriods is String) {
      try {
        rawPeriods = jsonDecode(rawPeriods);
      } on FormatException {
        rawPeriods = null;
      }
    }

    if (rawPeriods is List) {
      for (final item in rawPeriods.whereType<Map>()) {
        ratePeriods.add(
          _RatePeriod()
            ..start = parseTime(item['start'])
            ..end = parseTime(item['end'])
            ..price.text =
                '${item['pricePerHour'] ?? item['price_per_hour'] ?? ''}',
        );
      }
    }
    if (type == 'Event') ratePeriods.clear();
    String? validationMessage;
    var submitted = false;
    var panelOpen = true;

    final added = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: editing
          ? 'Close edit business panel'
          : 'Close add business panel',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          _MerchantBusinessFormPanel(
            builder: (context, setDialogState) => PopScope<bool>(
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) panelOpen = false;
              },
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: MediaQuery.sizeOf(context).width < 600
                      ? .94
                      : .52,
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(24),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AlertDialog(
                      insetPadding: EdgeInsets.zero,
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                editing
                                    ? Icons.edit_outlined
                                    : Icons.add_business_rounded,
                                color: _addOrange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  editing ? 'Edit business' : 'Add business',
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: () {
                                  panelOpen = false;
                                  Navigator.pop(dialogContext, false);
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            editing
                                ? 'Update this venue for customers'
                                : 'Publish a new venue for customers',
                            style: TextStyle(
                              color: _addMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      content: SizedBox(
                        width: double.infinity,
                        child: SingleChildScrollView(
                          child: Form(
                            key: formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (validationMessage != null) ...[
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFE8E8),
                                      border: Border.all(
                                        color: const Color(0xFFE09A9A),
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: Color(0xFFB42318),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            validationMessage!,
                                            style: const TextStyle(
                                              color: Color(0xFFB42318),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Dismiss validation message',
                                          onPressed: () => setDialogState(
                                            () => validationMessage = null,
                                          ),
                                          icon: const Icon(
                                            Icons.close,
                                            color: Color(0xFFB42318),
                                            size: 18,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                _sectionLabel('BASIC INFORMATION'),
                                DropdownButtonFormField<String>(
                                  initialValue: type,
                                  decoration: InputDecoration(
                                    labelText: 'Booking type',
                                  ),
                                  items: [
                                    for (final item in types)
                                      DropdownMenuItem(
                                        value: item,
                                        child: Text(item),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setDialogState(() {
                                      type = value;
                                      category = _categories[type]!.first;
                                      if (type == 'Event') {
                                        for (final period in ratePeriods) {
                                          period.dispose();
                                        }
                                        ratePeriods.clear();
                                      }
                                    });
                                  },
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      top: 6,
                                      bottom: 2,
                                    ),
                                    child: Text(
                                      type == 'Sports'
                                          ? 'Add courts, fields, and sports facilities for customers to book.'
                                          : type == 'Event'
                                          ? 'Add an event venue with the space and amenities needed for gatherings.'
                                          : 'Add a wellness space for classes, sessions, and fitness activities.',
                                      style: const TextStyle(
                                        color: _addMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                DropdownButtonFormField<String>(
                                  initialValue: category,
                                  decoration: InputDecoration(
                                    labelText: 'Category / activity',
                                  ),
                                  items: [
                                    for (final item in {
                                      ..._categories[type]!,
                                      'Other',
                                    })
                                      DropdownMenuItem(
                                        value: item,
                                        child: Text(item),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setDialogState(() => category = value);
                                    }
                                  },
                                ),
                                if (category == 'Other')
                                  TextFormField(
                                    controller: categoryOther,
                                    decoration: const InputDecoration(
                                      labelText: 'Custom category',
                                      hintText: 'Enter the venue category',
                                    ),
                                  ),
                                TextFormField(
                                  controller: name,
                                  decoration: const InputDecoration(
                                    labelText: 'Venue name',
                                  ),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Enter a business name'
                                      : null,
                                ),
                                if (type == 'Event') ...[
                                  const SizedBox(height: 12),
                                  _sectionLabel('EVENT BOOKING DETAILS'),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Event types this venue can hold',
                                      style: TextStyle(
                                        color: _addMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      for (final option in eventTypeOptions)
                                        FilterChip(
                                          label: Text(
                                            option,
                                            style: TextStyle(
                                              color: eventTypes.contains(option)
                                                  ? _addOrange
                                                  : _addInk,
                                              fontWeight:
                                                  eventTypes.contains(option)
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                            ),
                                          ),
                                          selected: eventTypes.contains(option),
                                          showCheckmark: false,
                                          selectedColor: _addSoftOrange,
                                          backgroundColor: Colors.white,
                                          shape: const StadiumBorder(),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          checkmarkColor: _addOrange,
                                          side: BorderSide(
                                            color: eventTypes.contains(option)
                                                ? _addOrange
                                                : _addLine,
                                          ),
                                          onSelected: (selected) =>
                                              setDialogState(() {
                                                if (selected) {
                                                  eventTypes.add(option);
                                                } else {
                                                  eventTypes.remove(option);
                                                  if (option == 'Other') {
                                                    eventTypeOther.clear();
                                                  }
                                                }
                                              }),
                                        ),
                                    ],
                                  ),
                                  if (eventTypes.contains('Other'))
                                    TextFormField(
                                      controller: eventTypeOther,
                                      decoration: const InputDecoration(
                                        labelText: 'Other event type',
                                        hintText: 'Enter another event type',
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: eventAttendanceMin,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Minimum guests',
                                            hintText: '40',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextFormField(
                                          controller: eventAttendanceMax,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Maximum guests',
                                            hintText: '250',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  _repeatableEventNeeds(
                                    label: 'Accessibility needs (optional)',
                                    hint: 'Wheelchair ramp or specialized seating',
                                    controller: accessibilityInput,
                                    values: accessibilityNeeds,
                                    setDialogState: setDialogState,
                                  ),
                                  _repeatableEventNeeds(
                                    label: 'Parking needs (optional)',
                                    hint: 'Reserved parking or VIP parking',
                                    controller: parkingInput,
                                    values: parkingNeeds,
                                    setDialogState: setDialogState,
                                  ),
                                  _repeatableEventNeeds(
                                    label: 'Security needs (optional)',
                                    hint: 'Dedicated security personnel or VIP access',
                                    controller: securityInput,
                                    values: securityNeeds,
                                    setDialogState: setDialogState,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                _sectionLabel('SCHEDULE AND PRICING'),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _timePickerField(
                                        context: context,
                                        label: 'Opens',
                                        value: openingTime,
                                        onChanged: (value) =>
                                            panelOpen && context.mounted
                                            ? setDialogState(
                                                () => openingTime = value,
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _timePickerField(
                                        context: context,
                                        label: 'Closes',
                                        value: closingTime,
                                        onChanged: (value) =>
                                            panelOpen && context.mounted
                                            ? setDialogState(
                                                () => closingTime = value,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                TextFormField(
                                  controller: address,
                                  decoration: const InputDecoration(
                                    labelText: 'Venue address',
                                  ),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Enter an address'
                                      : null,
                                ),
                                TextFormField(
                                    controller: visitUrl,
                                    keyboardType: TextInputType.url,
                                    decoration: const InputDecoration(
                                      labelText: 'Visit link (optional)',
                                      hintText: 'https://example.com',
                                      helperText: 'Customers open this link from Visit.',
                                    ),
                                    validator: (value) {
                                      final text = value?.trim() ?? '';
                                      if (text.isEmpty) return null;
                                      final uri = Uri.tryParse(text);
                                      if (uri == null ||
                                          !uri.hasScheme ||
                                          (uri.scheme != 'http' &&
                                              uri.scheme != 'https') ||
                                          uri.host.isEmpty) {
                                        return 'Enter a valid http:// or https:// link';
                                      }
                                      return null;
                                    },
                                ),
                                TextFormField(
                                  controller: price,
                                  enabled: type == 'Event' || ratePeriods.isEmpty,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: type == 'Event'
                                        ? 'Fee per event booking'
                                        : type == 'Fitness & Wellness'
                                        ? 'Session price'
                                        : 'Booking price per hour',
                                    prefixText: '₱ ',
                                    hintText: type == 'Event'
                                        ? '25000 (one complete event)'
                                        : type == 'Fitness & Wellness'
                                        ? '500 (per session)'
                                        : '300.00 (base booking rate)',
                                  ),
                                  validator: (value) {
                                    if (type != 'Event' && ratePeriods.isNotEmpty) {
                                      return null;
                                    }
                                    final amount = double.tryParse(
                                      value?.trim() ?? '',
                                    );
                                    return amount == null || amount <= 0
                                        ? type == 'Event'
                                            ? 'Enter an event fee greater than ₱0'
                                            : 'Enter a price greater than 0'
                                        : null;
                                  },
                                ),
                                if (type != 'Event') ...[
                                  const SizedBox(height: 12),
                                  _sectionLabel('OPTIONAL RATE PERIODS'),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Add different hourly prices for specific time ranges. '
                                      'When used, the base price is disabled.',
                                      style: TextStyle(
                                        color: _addMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  for (
                                    var index = 0;
                                    index < ratePeriods.length;
                                    index++
                                  )
                                    _ratePeriodRow(
                                      context: context,
                                      period: ratePeriods[index],
                                      onStartChanged: (value) => setDialogState(
                                        () => ratePeriods[index].start = value,
                                      ),
                                      onEndChanged: (value) => setDialogState(
                                        () => ratePeriods[index].end = value,
                                      ),
                                      onRemove: () {
                                        final period = ratePeriods.removeAt(
                                          index,
                                        );
                                        period.dispose();
                                        setDialogState(() {});
                                      },
                                    ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () {
                                        setDialogState(
                                          () => ratePeriods.add(_RatePeriod()),
                                        );
                                      },
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add rate period'),
                                    ),
                                  ),
                                ],
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_month_rounded,
                                        color: _addNavy,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Availability / booking schedule',
                                        style: TextStyle(
                                          color: _addMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final day in _weekdays)
                                        FilterChip(
                                          label: Text(
                                            day,
                                            style: TextStyle(
                                              color: availableDays.contains(day)
                                                  ? _addOrange
                                                  : _addInk,
                                              fontWeight:
                                                  availableDays.contains(day)
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                            ),
                                          ),
                                          selected: availableDays.contains(day),
                                          showCheckmark: false,
                                          selectedColor: _addSoftOrange,
                                          backgroundColor: Colors.white,
                                          shape: const StadiumBorder(),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          checkmarkColor: _addOrange,
                                          side: BorderSide(
                                            color: availableDays.contains(day)
                                                ? _addOrange
                                                : _addLine,
                                          ),
                                          onSelected: (selected) {
                                            setDialogState(() {
                                              if (selected) {
                                                availableDays.add(day);
                                              } else {
                                                availableDays.remove(day);
                                              }
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _sectionLabel('FACILITY DETAILS'),
                                DropdownButtonFormField<String>(
                                  initialValue: facility,
                                  decoration: InputDecoration(
                                    labelText: type == 'Sports'
                                        ? 'Court / field type'
                                        : type == 'Event'
                                        ? 'Event space type'
                                        : 'Studio / wellness space type',
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
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _sectionLabel('Amenities'),
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 2,
                                    children: [
                                      for (final amenity in amenityOptions)
                                        FilterChip(
                                          label: Text(
                                            amenity,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: amenities.contains(amenity)
                                                  ? _addOrange
                                                  : _addInk,
                                              fontWeight:
                                                  amenities.contains(amenity)
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                            ),
                                          ),
                                          selected: amenities.contains(amenity),
                                          showCheckmark: false,
                                          selectedColor: _addSoftOrange,
                                          backgroundColor: Colors.white,
                                          shape: const StadiumBorder(),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          checkmarkColor: _addOrange,
                                          side: BorderSide(
                                            color: amenities.contains(amenity)
                                                ? _addOrange
                                                : _addLine,
                                          ),
                                          onSelected: (selected) {
                                            setDialogState(() {
                                              if (selected) {
                                                amenities.add(amenity);
                                              } else {
                                                amenities.remove(amenity);
                                                if (amenity == 'Other') {
                                                  amenityOther.clear();
                                                }
                                              }
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                                if (amenities.contains('Other'))
                                  TextField(
                                    controller: amenityOther,
                                    decoration: const InputDecoration(
                                      labelText: 'Other amenity',
                                      hintText: 'Example: Water station',
                                    ),
                                  ),
                                TextField(
                                  controller: details,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    labelText: type == 'Sports'
                                        ? 'Court or facility details (optional)'
                                        : type == 'Event'
                                        ? 'Additional event venue details (optional)'
                                        : 'Classes, sessions & capacity',
                                    hintText: type == 'Event'
                                        ? 'Example: Banquet package • 250 guests'
                                        : type == 'Fitness & Wellness'
                                        ? 'Example: 12 classes today • 20 participants/session'
                                        : 'Example: 2 courts • Equipment included',
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    try {
                                      final picked = await ImagePicker()
                                          .pickMultiImage(
                                            maxWidth: 700,
                                            maxHeight: 500,
                                            imageQuality: 50,
                                          );
                                      if (picked.isEmpty) return;
                                      final selected = <String>[];
                                      for (final file in picked.take(3)) {
                                        selected.add(
                                          _dataUri(await file.readAsBytes()),
                                        );
                                      }
                                      if (panelOpen && context.mounted) {
                                        setDialogState(
                                          () => images
                                            ..clear()
                                            ..addAll(selected),
                                        );
                                      }
                                    } on Exception catch (error) {
                                      if (panelOpen && context.mounted) {
                                        setDialogState(
                                          () => validationMessage =
                                              'Could not load the selected images: $error',
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.add_a_photo_outlined),
                                  label: Text(
                                    images.isEmpty
                                        ? 'Add images'
                                        : '${images.length} images selected',
                                  ),
                                ),
                                if (images.isNotEmpty)
                                  SizedBox(
                                    height: 84,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (var index = 0;
                                            index < images.length;
                                            index++) ...[
                                          Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image(
                                                  image: _imageProvider(
                                                    images[index],
                                                  )!,
                                                  width: 84,
                                                  height: 84,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                              Positioned(
                                                left: 4,
                                                bottom: 4,
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    color: Colors.black54,
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 5,
                                                          vertical: 2,
                                                        ),
                                                    child: Text(
                                                      '${index + 1} of ${images.length}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (index < images.length - 1)
                                            const SizedBox(width: 8),
                                        ],
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            panelOpen = false;
                            Navigator.pop(dialogContext, false);
                          },
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _addNavy,
                            minimumSize: const Size(150, 46),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () async {
                            setDialogState(() => validationMessage = null);
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            if (openingTime == null || closingTime == null) {
                              setDialogState(
                                () => validationMessage =
                                    'Select both opening and closing times.',
                              );
                              return;
                            }
                            if (type != 'Event') {
                              for (final period in ratePeriods) {
                                final amount = double.tryParse(
                                  period.price.text.trim(),
                                );
                                if (period.start == null ||
                                    period.end == null ||
                                    amount == null ||
                                    amount <= 0) {
                                  setDialogState(
                                    () => validationMessage =
                                        'Complete each rate period with a start time, '
                                        'end time, and a price greater than ₱0.',
                                  );
                                  return;
                                }
                              }
                            }
                            if (availableDays.isEmpty) {
                              setDialogState(
                                () => validationMessage =
                                    'Select at least one available day.',
                              );
                              return;
                            }
                            if (type == 'Event') {
                              final minimum = int.tryParse(
                                eventAttendanceMin.text.trim(),
                              );
                              final maximum = int.tryParse(
                                eventAttendanceMax.text.trim(),
                              );
                              if (eventTypes.isEmpty) {
                                setDialogState(
                                  () => validationMessage =
                                      'Select at least one event type this venue can hold.',
                                );
                                return;
                              }
                              if (eventTypes.contains('Other') &&
                                  eventTypeOther.text.trim().isEmpty) {
                                setDialogState(
                                  () => validationMessage =
                                      'Enter the custom event type.',
                                );
                                return;
                              }
                              if (minimum == null ||
                                  maximum == null ||
                                  minimum < 1 ||
                                  maximum < minimum) {
                                setDialogState(
                                  () => validationMessage =
                                      'Enter a valid estimated attendance range.',
                                );
                                return;
                              }
                            }
                            if (category == 'Other' &&
                                categoryOther.text.trim().isEmpty) {
                              setDialogState(
                                () => validationMessage =
                                    'Enter the custom category.',
                              );
                              return;
                            }
                            setDialogState(() => _saving = true);
                            try {
                              final selectedEventTypes = eventTypes
                                  .map(
                                    (value) => value == 'Other'
                                        ? eventTypeOther.text.trim()
                                        : value,
                                  )
                                  .where((value) => value.isNotEmpty)
                                  .toList();
                              final selectedCategory = category == 'Other'
                                  ? categoryOther.text.trim()
                                  : category;
                              final selectedAmenities = amenities
                                  .map(
                                    (value) => value == 'Other'
                                        ? amenityOther.text.trim()
                                        : value,
                                  )
                                  .where((value) => value.isNotEmpty)
                                  .toList();
                              if (amenities.contains('Other') &&
                                  amenityOther.text.trim().isEmpty) {
                                setDialogState(
                                  () => validationMessage =
                                      'Enter the other amenity before saving.',
                                );
                                return;
                              }
                              final submittedDetails = type == 'Event'
                                  ? [
                                      if (eventTypes.isNotEmpty)
                                        'Event types: ${selectedEventTypes.join(', ')}',
                                      if (eventAttendanceMin.text.trim().isNotEmpty ||
                                          eventAttendanceMax.text.trim().isNotEmpty)
                                        'Estimated attendance: ${eventAttendanceMin.text.trim().isEmpty ? '?' : eventAttendanceMin.text.trim()} - ${eventAttendanceMax.text.trim().isEmpty ? '?' : eventAttendanceMax.text.trim()} guests',
                                      if (accessibilityNeeds.isNotEmpty)
                                        'Accessibility needs: ${accessibilityNeeds.join(', ')}',
                                      if (parkingNeeds.isNotEmpty)
                                        'Parking needs: ${parkingNeeds.join(', ')}',
                                      if (securityNeeds.isNotEmpty)
                                        'Security needs: ${securityNeeds.join(', ')}',
                                      if (details.text.trim().isNotEmpty)
                                        details.text.trim(),
                                    ].join('\n')
                                  : details.text.trim();
                              final session = await AppSession.load();
                              final token = session.apiToken;
                              if (token == null || token.isEmpty) {
                                throw const AuthApiException(
                                  'Your session has expired.',
                                  401,
                                );
                              }
                              final payload = <String, dynamic>{
                                'businessType': type,
                                'name': name.text.trim(),
                                'category': selectedCategory,
                                'address': address.text.trim(),
                                'visitUrl': visitUrl.text.trim(),
                                'pricePerHour': type == 'Event'
                                    ? double.parse(price.text.trim())
                                    : ratePeriods.isEmpty
                                    ? double.parse(price.text.trim())
                                    : 0,
                                'eventFee': type == 'Event'
                                    ? double.parse(price.text.trim())
                                    : 0,
                                'ratePeriods': [
                                  for (final period in ratePeriods)
                                    {
                                      'start': _formatTime(period.start!),
                                      'end': _formatTime(period.end!),
                                      'pricePerHour': double.parse(
                                        period.price.text.trim(),
                                      ),
                                    },
                                ],
                                'hours': _formatHours(openingTime, closingTime),
                                'availability': _weekdays
                                    .where(availableDays.contains)
                                    .join(', '),
                                'tags': selectedAmenities,
                                'facilityType': facility,
                                'details': submittedDetails,
                                'imageUrl': images.isEmpty
                                    ? null
                                    : jsonEncode(images),
                                'imageUrls': images,
                              };
                              if (editing) {
                                await _api.updateMerchantBusiness(
                                  token: token,
                                  id: (editingBusiness['id'] as num).toInt(),
                                  business: payload,
                                );
                              } else {
                                await _api.createMerchantBusiness(
                                  token: token,
                                  business: payload,
                                );
                              }
                              if (dialogContext.mounted) {
                                submitted = true;
                                await Navigator.of(
                                  dialogContext,
                                ).maybePop(true);
                              }
                            } on Exception catch (error) {
                              if (dialogContext.mounted) {
                                setDialogState(
                                  () => validationMessage =
                                      'Could not ${editing ? 'update' : 'add'} business: $error',
                                );
                              }
                            } finally {
                              if (!submitted && dialogContext.mounted) {
                                setDialogState(() => _saving = false);
                              }
                            }
                          },
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(editing ? 'Save changes' : 'Add business'),
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
            position:
                Tween<Offset>(
                  begin: const Offset(-1, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
    );
    // Let the dialog route finish its reverse animation before disposing the
    // controllers used by its form widgets.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    name.dispose();
    address.dispose();
    visitUrl.dispose();
    price.dispose();
    details.dispose();
    categoryOther.dispose();
    amenityOther.dispose();
    eventTypeOther.dispose();
    eventAttendanceMin.dispose();
    eventAttendanceMax.dispose();
    accessibilityInput.dispose();
    parkingInput.dispose();
    securityInput.dispose();
    for (final period in ratePeriods) {
      period.dispose();
    }
    if (added == true && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      await widget.onBusinessesChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editing ? 'Business updated.' : 'Business added and published.',
          ),
        ),
      );
    }
  }

  Widget _timePickerField({
    required BuildContext context,
    required String label,
    required TimeOfDay? value,
    required ValueChanged<TimeOfDay> onChanged,
  }) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () async {
      final selected = await showTimePicker(
        context: context,
        initialTime: value ?? TimeOfDay.now(),
      );
      if (selected != null) onChanged(selected);
    },
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.schedule_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        value?.format(context) ?? 'Select time',
        style: TextStyle(
          color: value == null ? _addMuted : _addInk,
          fontWeight: value == null ? FontWeight.normal : FontWeight.w700,
        ),
      ),
    ),
  );

  Widget _ratePeriodRow({
    required BuildContext context,
    required _RatePeriod period,
    required ValueChanged<TimeOfDay> onStartChanged,
    required ValueChanged<TimeOfDay> onEndChanged,
    required VoidCallback onRemove,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _timePickerField(
                context: context,
                label: 'From',
                value: period.start,
                onChanged: onStartChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _timePickerField(
                context: context,
                label: 'To',
                value: period.end,
                onChanged: onEndChanged,
              ),
            ),
            IconButton(
              tooltip: 'Remove rate period',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        TextField(
          controller: period.price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Rate per hour',
            prefixText: '₱ ',
          ),
        ),
      ],
    ),
  );

  String _formatTime(TimeOfDay value) {
    final hour = value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatHours(TimeOfDay? opening, TimeOfDay? closing) {
    if (opening == null || closing == null) return '';
    return '${_formatTime(opening)} - ${_formatTime(closing)}';
  }

  Widget _repeatableEventNeeds({
    required String label,
    required String hint,
    required TextEditingController controller,
    required List<String> values,
    required StateSetter setDialogState,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: IconButton(
            tooltip: 'Add',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty || values.contains(value)) return;
              setDialogState(() {
                values.add(value);
                controller.clear();
              });
            },
          ),
        ),
        onSubmitted: (_) {
          final value = controller.text.trim();
          if (value.isEmpty || values.contains(value)) return;
          setDialogState(() {
            values.add(value);
            controller.clear();
          });
        },
      ),
      if (values.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final value in values)
                InputChip(
                  label: Text(value),
                  onDeleted: () => setDialogState(() => values.remove(value)),
                ),
            ],
          ),
        ),
    ],
  );

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: _addMuted,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: .6,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: widget.onBusinessesChanged,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Add business',
                style: TextStyle(
                  color: _addInk,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _openForm,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: FilledButton.styleFrom(backgroundColor: _addOrange),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Businesses you add are shown here and published in Venues.',
          style: TextStyle(color: _addMuted),
        ),
        const SizedBox(height: 18),
        _businessTypeTabs(),
        const SizedBox(height: 16),
        if (_filteredBusinesses.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(Icons.storefront_outlined, size: 42, color: _addMuted),
                SizedBox(height: 8),
                Text(
                  'No businesses in this category',
                  style: TextStyle(color: _addInk, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          )
        else
          for (final business in _filteredBusinesses) ...[
            _businessCard(business),
            const SizedBox(height: 12),
          ],
      ],
    ),
  );

  List<Map<String, dynamic>> get _filteredBusinesses {
    if (_selectedBusinessType == 'All') return widget.businesses;
    return widget.businesses
        .where(
          (business) =>
              business['businessType'] == _selectedBusinessType ||
              business['business_type'] == _selectedBusinessType,
        )
        .toList();
  }

  Widget _businessTypeTabs() {
    const tabs = ['All', 'Sports', 'Event', 'Fitness & Wellness'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _addLine),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ChoiceChip(
                  label: Text(
                    tab == 'Fitness & Wellness' ? 'Fitness' : tab,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: _selectedBusinessType == tab,
                  showCheckmark: false,
                  selectedColor: _addNavy,
                  labelStyle: TextStyle(
                    color: _selectedBusinessType == tab
                        ? Colors.white
                        : _addInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) {
                    if (!mounted) return;
                    setState(() => _selectedBusinessType = tab);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _businessCard(Map<String, dynamic> business) {
    final id = (business['id'] as num?)?.toInt();
    final enabled =
        business['enabled'] != false &&
        business['enabled'] != 0 &&
        business['enabled'] != '0';
    final image = _businessPrimaryImage(business);
    final name = business['name'] as String? ?? 'Unnamed business';
    final type = business['businessType'] as String? ?? 'Booking';
    final category = business['category'] as String? ?? '';
    final address = business['address'] as String? ?? '';
    final facility = business['facilityType'] as String? ?? '';
    final hours = business['hours'] as String? ?? '';
    final availability = business['availability'] as String? ?? '';
    final ratePeriods = _businessRatePeriods(business);
    final details = business['details'] as String? ?? '';
    final priceText = _formatPrice(
      business['eventFee'] ??
          business['event_fee'] ??
          business['pricePerHour'] ??
          business['price_per_hour'] ??
          business['price'] ??
          business['hourlyRate'],
      hourly: type != 'Event',
    );
    final tags = _businessTags(
      business['tags'] ?? business['amenities'] ?? business['amenities_json'],
    );
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _addLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 145,
            width: double.infinity,
            child: image == null || image.isEmpty
                ? const ColoredBox(
                    color: Color(0xFFFFE8D2),
                    child: Icon(
                      Icons.storefront_rounded,
                      size: 48,
                      color: _addOrange,
                    ),
                  )
                : Image(image: _imageProvider(image)!, fit: BoxFit.cover),
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
                    color: _addInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (address.isNotEmpty)
                  _detail(Icons.location_on_outlined, address),
                if (facility.isNotEmpty)
                  _detail(Icons.business_outlined, 'Facility: $facility'),
                if (type == 'Sports' && category.isNotEmpty)
                  _detail(Icons.sports_rounded, 'Sport: $category'),
                if (type == 'Event' && category.isNotEmpty)
                  _detail(Icons.celebration_outlined, 'Event type: $category'),
                if (type == 'Fitness & Wellness' && category.isNotEmpty)
                  _detail(Icons.fitness_center_rounded, 'Class: $category'),
                if (hours.isNotEmpty)
                  _detail(Icons.access_time_rounded, 'Hours: $hours'),
                if (availability.isNotEmpty)
                  _detail(Icons.check_circle_outline, availability),
                if (ratePeriods.isNotEmpty)
                  _detail(
                    Icons.payments_outlined,
                    'Special rates: ${_formatRatePeriods(ratePeriods)}',
                  ),
                if (details.isNotEmpty) _detail(Icons.info_outline, details),
                const SizedBox(height: 8),
                _priceBox(
                  ratePeriods.isNotEmpty
                      ? 'See special rates above'
                      : priceText.isEmpty
                      ? 'Price not set'
                      : priceText,
                  label: type == 'Event' ? 'Event fee' : 'Price / hour',
                  hasRatePeriods: ratePeriods.isNotEmpty,
                ),
                const SizedBox(height: 8),
                Text(
                  'Amenities',
                  style: const TextStyle(
                    color: _addMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                if (tags.isEmpty)
                  const Text(
                    'No amenities listed',
                    style: TextStyle(color: _addMuted, fontSize: 12),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [for (final tag in tags) _tag(null, tag)],
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: id == null
                            ? null
                            : () => _openForm(business),
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: id == null
                            ? null
                            : () => _toggleBusiness(business, enabled),
                        icon: Icon(
                          enabled
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 17,
                        ),
                        label: Text(enabled ? 'Disable' : 'Enable'),
                        style: FilledButton.styleFrom(
                          backgroundColor: enabled ? _addNavy : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: id == null
                        ? null
                        : () => _confirmDeleteBusiness(id, name),
                    icon: const Icon(Icons.delete_outline, size: 17),
                    label: const Text('Delete business'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB42318),
                      side: const BorderSide(color: Color(0xFFE09A9A)),
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

  Future<void> _toggleBusiness(
    Map<String, dynamic> business,
    bool enabled,
  ) async {
    final id = (business['id'] as num?)?.toInt();
    if (id == null) {
      return;
    }
    try {
      final session = await AppSession.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Your session has expired.', 401);
      }
      await _api.setMerchantBusinessEnabled(
        token: token,
        id: id,
        enabled: !enabled,
      );
      await widget.onBusinessesChanged();
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update business status: $error')),
        );
      }
    }
  }

  Future<void> _confirmDeleteBusiness(int id, String name) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete business?'),
          content: Text(
            'This will permanently delete "$name" and its venue details. '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      try {
        final session = await AppSession.load();
        final token = session.apiToken;
        if (token == null || token.isEmpty) {
          throw const AuthApiException('Your session has expired.', 401);
        }
        await _api.deleteMerchantBusiness(token: token, id: id);
        await widget.onBusinessesChanged();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$name" was deleted.')),
        );
      } on Exception catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete business: $error')),
        );
      }
  }

  String _formatPrice(dynamic value, {bool hourly = true}) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value');
    if (amount == null || amount <= 0) return '';
    final formatted = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return hourly ? '₱$formatted / hr' : '₱$formatted';
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

  List<String> _businessTags(dynamic value) {
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

  Widget _detail(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _addMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _addMuted, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _tag(IconData? icon, String label) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1E4),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: _addOrange),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              color: _addOrange,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _priceBox(
    String price, {
    String label = 'Price / hour',
    bool hasRatePeriods = false,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFAFBFD),
      border: Border.all(color: _addLine),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            hasRatePeriods ? 'Rate schedule' : label,
            style: TextStyle(
              color: _addMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          price,
          style: const TextStyle(color: _addInk, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );

  ImageProvider<Object>? _imageProvider(String value) {
    if (value.startsWith('data:image/')) {
      return MemoryImage(base64Decode(value.split(',').last));
    }
    return NetworkImage(value);
  }

  String? _businessPrimaryImage(Map<String, dynamic> business) {
    final value = business['imageUrl'];
    if (value is! String || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.whereType<String>().firstWhere(
          (image) => image.isNotEmpty,
          orElse: () => '',
        );
      }
    } on FormatException {
      return value;
    }
    return value;
  }

  String _dataUri(List<int> bytes) =>
      'data:image/jpeg;base64,${base64Encode(bytes)}';

  String _formatRatePeriods(List<Map<String, dynamic>> periods) => periods
        .whereType<Map>()
        .map((period) {
          final start = period['start'] ?? '';
          final end = period['end'] ?? '';
          final price = _formatPrice(
            period['pricePerHour'] ?? period['price_per_hour'] ?? period['price'],
          );
          return '$start - $end${price.isEmpty ? '' : ' ($price)'}';
        })
        .join(', ');
}
