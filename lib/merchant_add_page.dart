import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_session.dart';
import 'auth_api.dart';

const _addNavy = Color(0xFF192B50);
const _addInk = Color(0xFF101B33);
const _addOrange = Color(0xFFFF8200);
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
  Widget build(BuildContext context) =>
      widget.builder(context, _setPanelState);
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

  Future<void> _openForm() async {
    final name = TextEditingController();
    final address = TextEditingController();
    final price = TextEditingController();
    final details = TextEditingController();
    final formKey = GlobalKey<FormState>();
    const types = ['Sports', 'Event', 'Fitness & Wellness'];
    String type = types.contains(widget.initialBusinessType)
        ? widget.initialBusinessType!
        : 'Sports';
    String category = _categories[type]!.first;
    String facility = 'Indoor';
    String availability = 'Any';
    TimeOfDay? openingTime;
    TimeOfDay? closingTime;
    final amenities = <String>{};
    const amenityOptions = [
      'Parking',
      'Pet-friendly',
      'Restroom',
      'Shower',
      'Store',
    ];
    String? image;
    var submitted = false;
    var panelOpen = true;

    final added = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Close add business panel',
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
            widthFactor: MediaQuery.sizeOf(context).width < 600 ? .94 : .52,
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
                        const Icon(
                          Icons.add_business_rounded,
                          color: _addOrange,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Add business')),
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
                    const Text(
                      'Publish a new venue for customers',
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
                  _sectionLabel('BASIC INFORMATION'),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Booking type',
                    ),
                    items: [
                      for (final item in types)
                        DropdownMenuItem(value: item, child: Text(item)),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        type = value;
                        category = _categories[type]!.first;
                      });
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      for (final item in {..._categories[type]!, 'Other'})
                        DropdownMenuItem(value: item, child: Text(item)),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => category = value);
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
                                  ? setDialogState(() => openingTime = value)
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
                                  ? setDialogState(() => closingTime = value)
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: address,
                    decoration: const InputDecoration(labelText: 'Address'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter an address'
                        : null,
                  ),
                  TextFormField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Price per hour',
                      prefixText: '₱ ',
                      hintText: '300.00',
                    ),
                    validator: (value) {
                      final amount = double.tryParse(value?.trim() ?? '');
                      return amount == null || amount <= 0
                          ? 'Enter a price greater than 0'
                          : null;
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: availability,
                    decoration: const InputDecoration(
                      labelText: 'Availability',
                      prefixIcon: Icon(Icons.access_time_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Any', child: Text('Available')),
                      DropdownMenuItem(
                        value: 'Open 24 hours',
                        child: Text('Open 24 hours'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => availability = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _sectionLabel('FACILITY DETAILS'),
                  DropdownButtonFormField<String>(
                    initialValue: facility,
                    decoration: const InputDecoration(
                      labelText: 'Facility type',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Indoor', child: Text('Indoor')),
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
                      if (value != null) setDialogState(() => facility = value);
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
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: amenities.contains(amenity),
                            showCheckmark: false,
                            selectedColor: const Color(0xFFFFE8D2),
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
                                }
                              });
                            },
                          ),
                      ],
                    ),
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
                      final picked = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1400,
                        maxHeight: 900,
                        imageQuality: 75,
                      );
                      if (picked == null) return;
                      final bytes = await picked.readAsBytes();
                      if (panelOpen && context.mounted) {
                        setDialogState(() => image = _dataUri(bytes));
                      }
                    },
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(image == null ? 'Add image' : 'Image selected'),
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
                if (!(formKey.currentState?.validate() ?? false)) return;
                if (openingTime == null || closingTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Select opening and closing times.'),
                    ),
                  );
                  return;
                }
                setDialogState(() => _saving = true);
                try {
                  final session = await AppSession.load();
                  final token = session.apiToken;
                  if (token == null || token.isEmpty) {
                    throw const AuthApiException(
                      'Your session has expired.',
                      401,
                    );
                  }
                  await _api.createMerchantBusiness(
                    token: token,
                    business: {
                      'businessType': type,
                      'name': name.text.trim(),
                      'category': category,
                      'address': address.text.trim(),
                      'pricePerHour': double.parse(price.text.trim()),
                      'hours': _formatHours(openingTime, closingTime),
                      'availability': availability,
                      'tags': amenities.toList(),
                      'facilityType': facility,
                      'details': details.text.trim(),
                      'imageUrl': image,
                    },
                  );
                  if (dialogContext.mounted) {
                    submitted = true;
                    Navigator.pop(dialogContext, true);
                  }
                } on Exception catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not add business: $error')),
                    );
                  }
                } finally {
                  if (!submitted && context.mounted) {
                    setDialogState(() => _saving = false);
                  }
                }
              },
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add business'),
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
            position: Tween<Offset>(
              begin: const Offset(-1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
    );
    name.dispose();
    address.dispose();
    price.dispose();
    details.dispose();
    if (added == true && mounted) {
      await widget.onBusinessesChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business added and published.')),
      );
    }

  }

  Widget _timePickerField({
    required BuildContext context,
    required String label,
    required TimeOfDay? value,
    required ValueChanged<TimeOfDay> onChanged,
  }) =>
      InkWell(
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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

  String _formatHours(TimeOfDay? opening, TimeOfDay? closing) {
    if (opening == null || closing == null) return '';
    String formatTime(TimeOfDay value) {
      final hour = value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod;
      final minute = value.minute.toString().padLeft(2, '0');
      final period = value.period == DayPeriod.am ? 'AM' : 'PM';
      return '$hour:$minute $period';
    }
    return '${formatTime(opening)} - ${formatTime(closing)}';
  }

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
            const Expanded(
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
        if (widget.businesses.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(Icons.storefront_outlined, size: 42, color: _addMuted),
                SizedBox(height: 8),
                Text(
                  'No businesses added yet',
                  style: TextStyle(color: _addInk, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          )
        else
          for (final business in widget.businesses) ...[
            _businessCard(business),
            const SizedBox(height: 12),
          ],
      ],
    ),
  );

  Widget _businessCard(Map<String, dynamic> business) {
    final image = business['imageUrl'] as String?;
    final name = business['name'] as String? ?? 'Unnamed business';
    final type = business['businessType'] as String? ?? 'Booking';
    final category = business['category'] as String? ?? '';
    final address = business['address'] as String? ?? '';
    final facility = business['facilityType'] as String? ?? '';
    final hours = business['hours'] as String? ?? '';
    final availability = business['availability'] as String? ?? '';
    final details = business['details'] as String? ?? '';
    final priceText = _formatPrice(
      business['pricePerHour'] ??
          business['price_per_hour'] ??
          business['price'] ??
          business['hourlyRate'],
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
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    _tag(Icons.event_available_rounded, type),
                    if (category.isNotEmpty)
                      _tag(Icons.category_outlined, category),
                  ],
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
                if (details.isNotEmpty)
                  _detail(Icons.info_outline, details),
                const SizedBox(height: 8),
                _priceBox(priceText.isEmpty ? 'Price not set' : priceText),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic value) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value');
    if (amount == null || amount <= 0) return '';
    final formatted = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '₱$formatted / hr';
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

  Widget _priceBox(String price) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFAFBFD),
      border: Border.all(color: _addLine),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Price / hour',
            style: TextStyle(
              color: _addMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          price,
          style: const TextStyle(
            color: _addInk,
            fontWeight: FontWeight.w900,
          ),
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

  String _dataUri(List<int> bytes) =>
      'data:image/jpeg;base64,${base64Encode(bytes)}';
}
