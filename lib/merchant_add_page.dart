import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import 'app_session.dart';
import 'app_card_styles.dart';
import 'auth_api.dart';
import 'merchant_news_cards_section.dart';
import 'venue_address_geocoder.dart';
import 'app_design_system.dart';

const _addNavy = AppColors.navy;
const _addInk = AppColors.ink;
const _addOrange = AppColors.orange;
const _addSoftOrange = AppColors.softOrange;
const _addMuted = AppColors.muted;
const _addLine = AppColors.border;

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty && item != 'null')
        .toList();
  }
  return const [];
}

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

class _SportSlotInput {
  _SportSlotInput({
    required String sportType,
    required String pricePerHour,
    required this.fullStudio,
    required this.slotCount,
    required String includedPlayers,
    required String additionalPlayerFee,
  }) : sportType = TextEditingController(text: sportType),
       pricePerHour = TextEditingController(text: pricePerHour),
       includedPlayers = TextEditingController(text: includedPlayers),
       additionalPlayerFee = TextEditingController(text: additionalPlayerFee);

  final TextEditingController sportType;
  final TextEditingController pricePerHour;
  final TextEditingController includedPlayers;
  final TextEditingController additionalPlayerFee;
  bool fullStudio;
  int slotCount;

  void dispose() {
    sportType.dispose();
    pricePerHour.dispose();
    includedPlayers.dispose();
    additionalPlayerFee.dispose();
  }
}

class _FitnessCategoryInput {
  _FitnessCategoryInput({
    required String category,
    String sessionPrice = '',
    String monthlyPrice = '',
    String yearlyPrice = '',
    this.yearlyDiscountType = 'none',
    String yearlyDiscountValue = '',
  }) : category = TextEditingController(text: category),
       sessionPrice = TextEditingController(text: sessionPrice),
       monthlyPrice = TextEditingController(text: monthlyPrice),
       yearlyPrice = TextEditingController(text: yearlyPrice),
       yearlyDiscountValue = TextEditingController(text: yearlyDiscountValue);

  final TextEditingController category;
  final TextEditingController sessionPrice;
  final TextEditingController monthlyPrice;
  final TextEditingController yearlyPrice;
  final TextEditingController yearlyDiscountValue;
  String yearlyDiscountType;

  void dispose() {
    category.dispose();
    sessionPrice.dispose();
    monthlyPrice.dispose();
    yearlyPrice.dispose();
    yearlyDiscountValue.dispose();
  }
}

class _FitnessCoachInput {
  _FitnessCoachInput({
    String name = '',
    String monthlyPrice = '',
    this.profileImageUrl,
  }) : name = TextEditingController(text: name),
       monthlyPrice = TextEditingController(text: monthlyPrice);

  final TextEditingController name;
  final TextEditingController monthlyPrice;
  String? profileImageUrl;

  void dispose() {
    name.dispose();
    monthlyPrice.dispose();
  }
}

class MerchantAddPage extends StatefulWidget {
  const MerchantAddPage({
    super.key,
    required this.initialBusinessType,
    required this.businesses,
    required this.onBusinessesChanged,
    this.api,
  });

  final String? initialBusinessType;
  final List<Map<String, dynamic>> businesses;
  final Future<void> Function() onBusinessesChanged;
  final AuthApi? api;

  @override
  MerchantAddPageState createState() => MerchantAddPageState();
}

class MerchantAddPageState extends State<MerchantAddPage> {
  static const _categories = {
    'Sports': [
      'Tennis',
      'Pickleball',
      'Basketball',
      'Volleyball',
      'Badminton',
      'Football',
      'Futsal',
      'Table Tennis',
      'Squash',
    ],
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

  late final AuthApi _api;
  bool _saving = false;
  String _selectedBusinessType = 'All';
  String _selectedAddSection = 'Booking cards';
  String _businessSearchQuery = '';
  final _businessSearchController = TextEditingController();
  List<Map<String, dynamic>> _newsPosts = [];
  bool _newsLoading = false;

  @override
  void dispose() {
    _businessSearchController.dispose();
    super.dispose();
  }

  void openAddBusinessForm() {
    _openForm();
  }

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? AuthApi();
    _loadNewsPosts();
  }

  @override
  void didUpdateWidget(covariant MerchantAddPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businesses != widget.businesses) {
      _loadNewsPosts();
    }
  }

  int? _id(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  int? _businessId(Map<String, dynamic> business) =>
      _id(business['id'] ?? business['businessId']);

  int? _postBusinessId(Map<String, dynamic> post) =>
      _id(post['businessId'] ?? post['business_id']);

  double? _mapCoordinate(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  Future<LatLng?> _chooseBusinessLocation({
    required double? latitude,
    required double? longitude,
    required String address,
  }) async {
    LatLng? selected = latitude == null || longitude == null
        ? null
        : LatLng(latitude, longitude);
    String? lookupMessage;
    if (address.trim().isNotEmpty) {
      try {
        final addressLocation = await geocodeVenueAddress(address);
        if (addressLocation == null) {
          lookupMessage = 'Could not find this address. Tap the map to place the pin manually.';
        } else {
          selected = addressLocation;
        }
      } on Exception catch (error) {
        lookupMessage =
            'Could not look up the address ($error). Tap the map to place the pin manually.';
      }
    }
    if (!mounted) return null;
    final center = selected ?? const LatLng(10.3157, 123.8854);
    return showDialog<LatLng>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pin court location'),
          content: SizedBox(
            width: 520,
            height: MediaQuery.sizeOf(context).height * .58,
            child: Column(
              children: [
                const Text(
                  'The address is pinned automatically. Tap the map to adjust it to the exact venue entrance.',
                  style: TextStyle(fontSize: 12),
                ),
                if (lookupMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    lookupMessage,
                    style: const TextStyle(
                      color: Colors.deepOrange,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: selected == null ? 12 : 15,
                        onTap: (_, point) =>
                            setDialogState(() => selected = point),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.myapp',
                        ),
                        if (selected != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: selected!,
                                width: 44,
                                height: 48,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: _addOrange,
                                  size: 42,
                                ),
                              ),
                            ],
                          ),
                        RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution('OpenStreetMap contributors'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  selected == null
                      ? 'No map pin selected'
                      : '${selected!.latitude.toStringAsFixed(6)}, '
                            '${selected!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(dialogContext, selected),
              child: const Text('Use this location'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadNewsPosts() async {
    final token = (await AppSession.load()).apiToken;
    if (!mounted || token == null || token.isEmpty) return;
    setState(() => _newsLoading = true);
    try {
      final posts = await _api.merchantNewsPosts(token);
      if (mounted) setState(() => _newsPosts = posts);
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load news posts: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _newsLoading = false);
    }
  }

  Future<void> _refreshAddPage() async {
    await widget.onBusinessesChanged();
    await _loadNewsPosts();
  }

  Future<void> _openForm([Map<String, dynamic>? editingBusiness]) async {
    final editing = editingBusiness != null;
    final name = TextEditingController();
    final address = TextEditingController();
    double? latitude = _mapCoordinate(
      editingBusiness?['latitude'] ?? editingBusiness?['lat'],
    );
    double? longitude = _mapCoordinate(
      editingBusiness?['longitude'] ?? editingBusiness?['lng'],
    );
    final visitUrl = TextEditingController();
    final price = TextEditingController();
    final totalSlots = TextEditingController(
      text:
          '${editingBusiness?['slotCount'] ?? editingBusiness?['slot_count'] ?? 1}',
    );
    final includedPlayers = TextEditingController();
    final additionalPlayerFee = TextEditingController();
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
    String category =
        {..._categories[type]!, 'Other'}.contains(existingCategory)
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
    final sportSlots = <_SportSlotInput>[];
    final fitnessCategories = <_FitnessCategoryInput>[];
    final fitnessCoaches = <_FitnessCoachInput>[];
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
      images.addAll(
        existingImages.whereType<String>().where((value) => value.isNotEmpty),
      );
    } else if (existingImages is String && existingImages.isNotEmpty) {
      try {
        final decoded = jsonDecode(existingImages);
        if (decoded is List) {
          images.addAll(
            decoded.whereType<String>().where((value) => value.isNotEmpty),
          );
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
            images.addAll(
              decoded.whereType<String>().where((value) => value.isNotEmpty),
            );
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
    final existingPrice = type == 'Event'
        ? (editingBusiness?['eventFee'] ??
              editingBusiness?['event_fee'] ??
              editingBusiness?['pricePerHour'] ??
              editingBusiness?['price_per_hour'])
        : (editingBusiness?['pricePerHour'] ??
              editingBusiness?['price_per_hour'] ??
              editingBusiness?['price'] ??
              editingBusiness?['hourlyRate']);
    price.text = existingPrice?.toString() ?? '';
    includedPlayers.text =
        '${editingBusiness?['includedPlayers'] ?? editingBusiness?['included_players'] ?? ''}';
    additionalPlayerFee.text =
        '${editingBusiness?['additionalPlayerFee'] ?? editingBusiness?['additional_player_fee'] ?? ''}';
    details.text = editingBusiness?['details'] as String? ?? '';
    dynamic existingEventTypes = editingBusiness?['eventTypes'];
    if (existingEventTypes is String) {
      try {
        existingEventTypes = jsonDecode(existingEventTypes);
      } on FormatException {
        existingEventTypes = null;
      }
    }
    if (existingEventTypes is List) {
      eventTypes.addAll(existingEventTypes.whereType<String>());
    }
    eventAttendanceMin.text =
        '${editingBusiness?['attendanceMin'] ?? editingBusiness?['estimatedAttendanceMin'] ?? ''}';
    eventAttendanceMax.text =
        '${editingBusiness?['attendanceMax'] ?? editingBusiness?['estimatedAttendanceMax'] ?? ''}';
    accessibilityNeeds.addAll(
      _stringList(editingBusiness?['accessibilityNeeds']),
    );
    parkingNeeds.addAll(_stringList(editingBusiness?['parkingNeeds']));
    securityNeeds.addAll(_stringList(editingBusiness?['securityNeeds']));
    String eventDetailValue(String label) {
      final match = RegExp(
        '^${RegExp.escape(label)}:\\s*(.*)\$',
        multiLine: true,
      ).firstMatch(details.text);
      return match?.group(1)?.trim() ?? '';
    }

    if (editing && type == 'Event') {
      if (eventTypes.isEmpty) {
        eventTypes.addAll(
          eventDetailValue('Event types')
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty),
        );
      }
      if (eventTypes.isEmpty) {
        eventTypes.addAll(
          eventDetailValue('Event type')
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty),
        );
      }
      final customEventType = eventTypes
          .where(
            (value) => !eventTypeOptions.contains(value) || value == 'Other',
          )
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
      if (eventAttendanceMin.text.isEmpty && attendance.isNotEmpty) {
        eventAttendanceMin.text = attendance.first;
      }
      if (eventAttendanceMax.text.isEmpty && attendance.length > 1) {
        eventAttendanceMax.text = attendance[1];
      }
      List<String> parseNeeds(String label) =>
          eventDetailValue(label)
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();
      if (accessibilityNeeds.isEmpty) {
        accessibilityNeeds.addAll(parseNeeds('Accessibility needs'));
      }
      if (parkingNeeds.isEmpty) {
        parkingNeeds.addAll(parseNeeds('Parking needs'));
      }
      if (securityNeeds.isEmpty) {
        securityNeeds.addAll(parseNeeds('Security needs'));
      }
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
          .where((line) => !eventLabels.any((label) => line.startsWith(label)))
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
    dynamic rawSportsSlots =
        editingBusiness?['sportsSlots'] ??
        editingBusiness?['sports_slots_json'];
    if (rawSportsSlots is String) {
      try {
        rawSportsSlots = jsonDecode(rawSportsSlots);
      } on FormatException {
        rawSportsSlots = null;
      }
    }
    if (rawSportsSlots is List) {
      for (final item in rawSportsSlots.whereType<Map>()) {
        sportSlots.add(
          _SportSlotInput(
            sportType: '${item['sportType'] ?? ''}',
            pricePerHour: '${item['pricePerHour'] ?? ''}',
            fullStudio: item['fullStudio'] == true,
            slotCount: int.tryParse('${item['slotCount']}') ?? 1,
            includedPlayers:
                '${item['includedPlayers'] ?? includedPlayers.text}',
            additionalPlayerFee:
                '${item['additionalPlayerFee'] ?? additionalPlayerFee.text}',
          ),
        );
      }
    }
    if (sportSlots.isEmpty && editingBusiness != null && type == 'Sports') {
      final total = int.tryParse(totalSlots.text) ?? 1;
      sportSlots.add(
        _SportSlotInput(
          sportType: category == 'Other' ? categoryOther.text.trim() : category,
          pricePerHour: price.text,
          fullStudio: true,
          slotCount: total,
          includedPlayers: includedPlayers.text,
          additionalPlayerFee: additionalPlayerFee.text,
        ),
      );
    }
    List<dynamic> decodeJsonList(dynamic value) {
      if (value is List) return value;
      if (value is String && value.isNotEmpty) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) return decoded;
        } on FormatException {
          return const [];
        }
      }
      return const [];
    }

    final existingFitnessCategories = decodeJsonList(
      editingBusiness?['fitnessCategories'] ??
          editingBusiness?['fitness_categories_json'],
    );
    for (final item in existingFitnessCategories.whereType<Map>()) {
      final discountType = '${item['yearlyDiscountType'] ?? 'none'}';
      fitnessCategories.add(
        _FitnessCategoryInput(
          category: '${item['category'] ?? item['name'] ?? ''}',
          sessionPrice: '${item['sessionPrice'] ?? ''}',
          monthlyPrice: '${item['monthlyPrice'] ?? ''}',
          yearlyPrice: '${item['yearlyPrice'] ?? ''}',
          yearlyDiscountType:
              const {'none', 'freeMonths', 'percentage'}.contains(discountType)
              ? discountType
              : 'none',
          yearlyDiscountValue: '${item['yearlyDiscountValue'] ?? ''}',
        ),
      );
    }
    if (fitnessCategories.isNotEmpty && type == 'Fitness & Wellness') {
      categoryOther.clear();
    }
    if (fitnessCategories.isEmpty &&
        editingBusiness != null &&
        type == 'Fitness & Wellness') {
      fitnessCategories.add(
        _FitnessCategoryInput(
          category: existingCategory == 'Other'
              ? categoryOther.text.trim()
              : existingCategory ?? '',
          sessionPrice: price.text,
        ),
      );
    }
    for (final item in decodeJsonList(
      editingBusiness?['fitnessCoaches'] ??
          editingBusiness?['fitness_coaches_json'],
    ).whereType<Map>()) {
      fitnessCoaches.add(
        _FitnessCoachInput(
          name: '${item['name'] ?? ''}',
          monthlyPrice: '${item['monthlyPrice'] ?? ''}',
          profileImageUrl: '${item['profileImageUrl'] ?? ''}'.trim().isEmpty
              ? null
              : '${item['profileImageUrl']}',
        ),
      );
    }
    if (type == 'Sports') categoryOther.clear();
    String? validationMessage;
    var submitted = false;
    var panelOpen = true;
    var setupStep = 0;

    bool basicsComplete() =>
        name.text.trim().isNotEmpty &&
        (type == 'Sports' ||
            type == 'Fitness & Wellness' ||
            category != 'Other' ||
            categoryOther.text.trim().isNotEmpty);

    bool bookingDetailsComplete() {
      if (type == 'Sports') {
        final capacity = int.tryParse(totalSlots.text.trim());
        final names = sportSlots
            .map((sport) => sport.sportType.text.trim().toLowerCase())
            .toList();
        return capacity != null &&
            capacity >= 1 &&
            capacity <= 100 &&
            sportSlots.isNotEmpty &&
            names.toSet().length == names.length &&
            sportSlots.every((sport) {
              final price = double.tryParse(sport.pricePerHour.text.trim());
              final players = int.tryParse(sport.includedPlayers.text.trim());
              final fee = double.tryParse(
                sport.additionalPlayerFee.text.trim(),
              );
              return sport.sportType.text.trim().isNotEmpty &&
                  price != null &&
                  price.isFinite &&
                  price > 0 &&
                  sport.slotCount >= 1 &&
                  sport.slotCount <= capacity &&
                  (sport.includedPlayers.text.trim().isEmpty ||
                      (players != null && players >= 1 && players <= 1000)) &&
                  (sport.additionalPlayerFee.text.trim().isEmpty ||
                      (fee != null &&
                          fee.isFinite &&
                          fee > 0 &&
                          fee <= 99999999.99 &&
                          players != null &&
                          players >= 1));
            });
      }
      if (type == 'Fitness & Wellness') {
        final categoryNames = fitnessCategories
            .map((item) => item.category.text.trim().toLowerCase())
            .toList();
        final coachNames = fitnessCoaches
            .map((coach) => coach.name.text.trim().toLowerCase())
            .toList();
        return fitnessCategories.isNotEmpty &&
            categoryNames.toSet().length == categoryNames.length &&
            fitnessCategories.every((item) {
              final prices = [
                item.sessionPrice.text,
                item.monthlyPrice.text,
                item.yearlyPrice.text,
              ].map((value) => double.tryParse(value.trim()));
              final discountValue = item.yearlyDiscountValue.text.trim();
              final discount = double.tryParse(discountValue);
              final validDiscount = switch (item.yearlyDiscountType) {
                'none' => discountValue.isEmpty,
                'freeMonths' =>
                  discount != null &&
                      discount.isFinite &&
                      discount >= 1 &&
                      discount <= 11 &&
                      discount == discount.roundToDouble(),
                'percentage' =>
                  discount != null &&
                      discount.isFinite &&
                      discount > 0 &&
                      discount <= 100,
                _ => false,
              };
              return item.category.text.trim().isNotEmpty &&
                  validDiscount &&
                  prices.every(
                    (price) =>
                        price != null &&
                        price.isFinite &&
                        price > 0 &&
                        price <= 99999999.99,
                  );
            }) &&
            coachNames.toSet().length == coachNames.length &&
            fitnessCoaches.every((coach) {
              final price = double.tryParse(coach.monthlyPrice.text.trim());
              return coach.name.text.trim().isNotEmpty &&
                  price != null &&
                  price.isFinite &&
                  price > 0 &&
                  price <= 99999999.99;
            });
      }
      final minimum = int.tryParse(eventAttendanceMin.text.trim());
      final maximum = int.tryParse(eventAttendanceMax.text.trim());
      return eventTypes.isNotEmpty &&
          (!eventTypes.contains('Other') ||
              eventTypeOther.text.trim().isNotEmpty) &&
          minimum != null &&
          maximum != null &&
          minimum >= 1 &&
          maximum >= minimum;
    }

    bool scheduleComplete() =>
        openingTime != null &&
        closingTime != null &&
        address.text.trim().isNotEmpty &&
        availableDays.isNotEmpty;

    String currentStepTitle() => switch (setupStep) {
      0 => 'Business basics',
      1 => 'Booking details',
      _ => 'Schedule & review',
    };

    String bookingDetailsError() => switch (type) {
      'Sports' => 'Select at least one sport and enter a valid rate and slot setup for each.',
      'Fitness & Wellness' => 'Select at least one fitness category and enter valid plan prices. Complete any coach you add.',
      _ => 'Select at least one event type and enter a valid guest range.',
    };

    final added = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: editing
          ? 'Close edit business panel'
          : 'Close add business panel',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (dialogContext, animation, secondaryAnimation) => _MerchantBusinessFormPanel(
        builder: (context, setDialogState) => PopScope<bool>(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) panelOpen = false;
          },
          child: SafeArea(
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
                    titlePadding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
                    contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    actionsPadding: const EdgeInsets.fromLTRB(12, 0, 16, 12),
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
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                editing ? 'Edit business' : 'Add business',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () {
                                panelOpen = false;
                                Navigator.pop(dialogContext, false);
                              },
                              icon: const Icon(Icons.close_rounded),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          editing
                              ? 'Update this venue for customers'
                              : 'Publish a new venue for customers',
                          style: TextStyle(
                            color: _addMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'STEP ${setupStep + 1} OF 3  ·  ${currentStepTitle()}',
                          style: const TextStyle(
                            color: _addMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: (setupStep + 1) / 3,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(99),
                          backgroundColor: _addLine,
                          color: _addOrange,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _setupStepLabel(
                              'Basics',
                              complete: basicsComplete(),
                              current: setupStep == 0,
                            ),
                            const SizedBox(width: 8),
                            _setupStepLabel(
                              'Details',
                              complete: bookingDetailsComplete(),
                              current: setupStep == 1,
                            ),
                            const SizedBox(width: 8),
                            _setupStepLabel(
                              'Schedule',
                              complete: scheduleComplete(),
                              current: setupStep == 2,
                            ),
                          ],
                        ),
                      ],
                    ),
                    content: SizedBox(
                      width: double.infinity,
                      height: MediaQuery.sizeOf(context).height * .52,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          visualDensity: VisualDensity.compact,
                          textSelectionTheme: const TextSelectionThemeData(
                            cursorColor: _addNavy,
                            selectionColor: Color(0x55365A91),
                            selectionHandleColor: _addNavy,
                          ),
                          textTheme: Theme.of(context).textTheme.copyWith(
                            bodyLarge: const TextStyle(
                              color: _addInk,
                              fontSize: 14,
                            ),
                            bodyMedium: const TextStyle(
                              color: _addInk,
                              fontSize: 13,
                            ),
                            bodySmall: const TextStyle(
                              color: _addMuted,
                              fontSize: 11,
                            ),
                          ),
                          inputDecorationTheme: const InputDecorationTheme(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            labelStyle: TextStyle(
                              color: _addMuted,
                              fontSize: 13,
                            ),
                            floatingLabelStyle: TextStyle(
                              color: _addNavy,
                              fontSize: 13,
                            ),
                            hintStyle: TextStyle(
                              color: _addMuted,
                              fontSize: 12,
                            ),
                            helperStyle: TextStyle(fontSize: 11),
                            errorStyle: TextStyle(fontSize: 11),
                            prefixStyle: TextStyle(
                              color: _addInk,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Form(
                            key: formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (validationMessage != null) ...[
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
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
                                              fontSize: 12,
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
                                if (setupStep == 0) ...[
                                  _sectionLabel('BUSINESS BASICS'),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
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
                                      });
                                    },
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 2,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        type == 'Sports'
                                            ? 'Add courts, fields, and sports facilities for customers to book.'
                                            : type == 'Event'
                                            ? 'Add an event venue with the space and amenities needed for gatherings.'
                                            : 'Add a wellness space for classes, sessions, and fitness activities.',
                                        style: const TextStyle(
                                          color: _addMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (type != 'Sports' &&
                                      type != 'Fitness & Wellness')
                                    DropdownButtonFormField<String>(
                                      isExpanded: true,
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
                                          setDialogState(
                                            () => category = value,
                                          );
                                        }
                                      },
                                    ),
                                  if (type != 'Sports' &&
                                      type != 'Fitness & Wellness' &&
                                      category == 'Other')
                                    TextFormField(
                                      controller: categoryOther,
                                      decoration: const InputDecoration(
                                        labelText: 'Custom category (required)',
                                        hintText: 'Enter the venue category',
                                      ),
                                    ),
                                  TextFormField(
                                    controller: name,
                                    decoration: const InputDecoration(
                                      labelText: 'Venue name (required)',
                                    ),
                                    onChanged: (_) => setDialogState(() {}),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'Enter a business name'
                                        : null,
                                  ),
                                ],
                                if (setupStep == 1) ...[
                                  if (type == 'Sports') ...[
                                    const SizedBox(height: 10),
                                    _sectionLabel('SPORTS, SLOTS & RATES'),
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Set the studio capacity, then configure each sport. Full-studio sports block all slots.',
                                        style: TextStyle(
                                          color: _addMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    TextFormField(
                                      controller: totalSlots,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Total small slots (required)',
                                        hintText: 'e.g. 5',
                                      ),
                                      validator: (value) {
                                        final count = int.tryParse(
                                          value?.trim() ?? '',
                                        );
                                        return count == null ||
                                                count < 1 ||
                                                count > 100
                                            ? 'Enter a slot count from 1 to 100'
                                            : null;
                                      },
                                      onChanged: (value) {
                                        final count = int.tryParse(value);
                                        if (count == null ||
                                            count < 1 ||
                                            count > 100) {
                                          return;
                                        }
                                        setDialogState(() {
                                          for (final sport in sportSlots) {
                                            if (sport.fullStudio) {
                                              sport.slotCount = count;
                                            } else if (sport.slotCount >
                                                count) {
                                              sport.slotCount = count;
                                            }
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Choose at least one sport. Each selected sport needs its own rate and slot setup.',
                                        style: TextStyle(
                                          color: _addMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    for (final sportType
                                        in <String>{
                                          ..._categories['Sports']!,
                                          ...sportSlots.map(
                                            (sport) => sport.sportType.text,
                                          ),
                                        }.toList()..sort(
                                          (left, right) =>
                                              left.compareTo(right),
                                        ))
                                      CheckboxListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        title: Text(sportType),
                                        value: sportSlots.any(
                                          (sport) =>
                                              sport.sportType.text == sportType,
                                        ),
                                        onChanged: (checked) {
                                          setDialogState(() {
                                            if (checked == true) {
                                              final usesWholeStudio = !const {
                                                'Badminton',
                                                'Tennis',
                                                'Pickleball',
                                                'Table Tennis',
                                                'Squash',
                                              }.contains(sportType);
                                              sportSlots.add(
                                                _SportSlotInput(
                                                  sportType: sportType,
                                                  pricePerHour: '',
                                                  fullStudio: usesWholeStudio,
                                                  slotCount: usesWholeStudio
                                                      ? (int.tryParse(
                                                              totalSlots.text,
                                                            ) ??
                                                            1)
                                                      : (int.tryParse(
                                                              totalSlots.text,
                                                            ) ??
                                                            1),
                                                  includedPlayers: '',
                                                  additionalPlayerFee: '',
                                                ),
                                              );
                                            } else {
                                              sportSlots.removeWhere((sport) {
                                                if (sport.sportType.text !=
                                                    sportType) {
                                                  return false;
                                                }
                                                sport.dispose();
                                                return true;
                                              });
                                            }
                                          });
                                        },
                                      ),
                                    TextFormField(
                                      controller: categoryOther,
                                      decoration: const InputDecoration(
                                        labelText: 'Other sport (optional)',
                                        hintText: 'e.g. Squash',
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: () {
                                          final customSport = categoryOther.text
                                              .trim();
                                          if (customSport.isEmpty) return;
                                          if (sportSlots.any(
                                            (sport) =>
                                                sport.sportType.text
                                                    .toLowerCase() ==
                                                customSport.toLowerCase(),
                                          )) {
                                            setDialogState(
                                              () => validationMessage = 'That sport is already selected.',
                                            );
                                            return;
                                          }
                                          setDialogState(() {
                                            validationMessage = null;
                                            sportSlots.add(
                                              _SportSlotInput(
                                                sportType: customSport,
                                                pricePerHour: '',
                                                fullStudio: true,
                                                slotCount:
                                                    int.tryParse(
                                                      totalSlots.text,
                                                    ) ??
                                                    1,
                                                includedPlayers: '',
                                                additionalPlayerFee: '',
                                              ),
                                            );
                                            categoryOther.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.add_rounded),
                                        label: const Text('Add other sport'),
                                      ),
                                    ),
                                    if (sportSlots.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'Chosen categories: ${sportSlots.map((sport) => sport.sportType.text).join(', ')}',
                                            style: const TextStyle(
                                              color: _addNavy,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    for (
                                      var index = 0;
                                      index < sportSlots.length;
                                      index++
                                    ) ...[
                                      const SizedBox(height: 8),
                                      Builder(
                                        builder: (context) {
                                          final sport = sportSlots[index];
                                          final capacity =
                                              int.tryParse(totalSlots.text) ??
                                              1;
                                          return Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              border: Border.all(
                                                color: const Color(0xFFE2E7EF),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        sport.sportType.text,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                TextFormField(
                                                  controller:
                                                      sport.pricePerHour,
                                                  keyboardType:
                                                      const TextInputType.numberWithOptions(
                                                        decimal: true,
                                                      ),
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Price per hour (required)',
                                                        prefixText: '₱ ',
                                                      ),
                                                  validator: (value) {
                                                    final amount =
                                                        double.tryParse(
                                                          value?.trim() ?? '',
                                                        );
                                                    return amount == null ||
                                                            amount <= 0
                                                        ? 'Enter a price above ₱0'
                                                        : null;
                                                  },
                                                ),
                                                DropdownButtonFormField<bool>(
                                                  isExpanded: true,
                                                  initialValue:
                                                      sport.fullStudio,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Space used by this sport',
                                                      ),
                                                  items: const [
                                                    DropdownMenuItem(
                                                      value: true,
                                                      child: Text(
                                                        'Whole court',
                                                      ),
                                                    ),
                                                    DropdownMenuItem(
                                                      value: false,
                                                      child: Text(
                                                        'Small slots',
                                                      ),
                                                    ),
                                                  ],
                                                  onChanged: (value) {
                                                    if (value == null) return;
                                                    setDialogState(() {
                                                      sport.fullStudio = value;
                                                      sport.slotCount = value
                                                          ? capacity
                                                          : 1;
                                                    });
                                                  },
                                                ),
                                                Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 12,
                                                          top: 2,
                                                        ),
                                                    child: Text(
                                                      sport.fullStudio
                                                          ? 'One booking blocks all small slots.'
                                                          : 'Customers book one available small slot.',
                                                      style: const TextStyle(
                                                        color: _addMuted,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (!sport.fullStudio)
                                                  DropdownButtonFormField<int>(
                                                    initialValue: sport
                                                        .slotCount
                                                        .clamp(1, capacity)
                                                        .toInt(),
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText: 'Number of small slots',
                                                        ),
                                                    items: [
                                                      for (
                                                        var slot = 1;
                                                        slot <= capacity;
                                                        slot++
                                                      )
                                                        DropdownMenuItem(
                                                          value: slot,
                                                          child: Text(
                                                            '$slot slot${slot == 1 ? '' : 's'}',
                                                          ),
                                                        ),
                                                    ],
                                                    onChanged: (value) {
                                                      if (value != null) {
                                                        setDialogState(
                                                          () =>
                                                              sport.slotCount =
                                                                  value,
                                                        );
                                                      }
                                                    },
                                                  ),
                                                const SizedBox(height: 8),
                                                Builder(
                                                  builder: (context) {
                                                    final includedPlayersField =
                                                        TextFormField(
                                                          controller: sport
                                                              .includedPlayers,
                                                          keyboardType:
                                                              TextInputType
                                                                  .number,
                                                          decoration:
                                                              const InputDecoration(
                                                                labelText: 'Included players (optional)',
                                                              ),
                                                          validator: (value) {
                                                            final raw =
                                                                value?.trim() ??
                                                                '';
                                                            if (raw.isEmpty) {
                                                              return null;
                                                            }
                                                            final count =
                                                                int.tryParse(
                                                                  raw,
                                                                );
                                                            return count ==
                                                                        null ||
                                                                    count < 1 ||
                                                                    count > 1000
                                                                ? 'Enter 1–1000'
                                                                : null;
                                                          },
                                                        );
                                                    final extraPlayerFeeField = TextFormField(
                                                      controller: sport
                                                          .additionalPlayerFee,
                                                      keyboardType:
                                                          const TextInputType.numberWithOptions(
                                                            decimal: true,
                                                          ),
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText: 'Fee / extra player (optional)',
                                                            prefixText: '₱ ',
                                                          ),
                                                      validator: (value) {
                                                        final raw =
                                                            value?.trim() ?? '';
                                                        if (raw.isEmpty) {
                                                          return null;
                                                        }
                                                        final fee =
                                                            double.tryParse(
                                                              raw,
                                                            );
                                                        return fee == null ||
                                                                !fee.isFinite ||
                                                                fee <= 0 ||
                                                                fee >
                                                                    99999999.99
                                                            ? 'Enter a valid fee'
                                                            : null;
                                                      },
                                                    );
                                                    if (MediaQuery.sizeOf(
                                                          context,
                                                        ).width <
                                                        440) {
                                                      return Column(
                                                        children: [
                                                          includedPlayersField,
                                                          const SizedBox(
                                                            height: 8,
                                                          ),
                                                          extraPlayerFeeField,
                                                        ],
                                                      );
                                                    }
                                                    return Row(
                                                      children: [
                                                        Expanded(
                                                          child:
                                                              includedPlayersField,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Expanded(
                                                          child:
                                                              extraPlayerFeeField,
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                  if (type == 'Fitness & Wellness') ...[
                                    const SizedBox(height: 10),
                                    _sectionLabel(
                                      'FITNESS CATEGORIES & PRICES',
                                    ),
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Choose at least one activity (up to 20), then set its session, monthly, and yearly prices. Yearly offers may include an optional discount.',
                                        style: TextStyle(
                                          color: _addMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    for (final fitnessCategory
                                        in <String>{
                                          ..._categories['Fitness & Wellness']!,
                                          ...fitnessCategories.map(
                                            (item) => item.category.text,
                                          ),
                                        }.toList()..sort(
                                          (left, right) =>
                                              left.compareTo(right),
                                        ))
                                      CheckboxListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        title: Text(fitnessCategory),
                                        value: fitnessCategories.any(
                                          (item) =>
                                              item.category.text
                                                  .toLowerCase() ==
                                              fitnessCategory.toLowerCase(),
                                        ),
                                        onChanged:
                                            !fitnessCategories.any(
                                                  (item) =>
                                                      item.category.text
                                                          .toLowerCase() ==
                                                      fitnessCategory
                                                          .toLowerCase(),
                                                ) &&
                                                fitnessCategories.length >= 20
                                            ? null
                                            : (checked) {
                                                setDialogState(() {
                                                  if (checked == true) {
                                                    fitnessCategories.add(
                                                      _FitnessCategoryInput(
                                                        category:
                                                            fitnessCategory,
                                                      ),
                                                    );
                                                  } else {
                                                    fitnessCategories.removeWhere((
                                                      item,
                                                    ) {
                                                      if (item.category.text
                                                              .toLowerCase() !=
                                                          fitnessCategory
                                                              .toLowerCase()) {
                                                        return false;
                                                      }
                                                      item.dispose();
                                                      return true;
                                                    });
                                                  }
                                                });
                                              },
                                      ),
                                    TextField(
                                      controller: categoryOther,
                                      decoration: const InputDecoration(
                                        labelText: 'Other fitness category',
                                        hintText: 'e.g. Strength training',
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed:
                                            fitnessCategories.length >= 20
                                            ? null
                                            : () {
                                                final custom = categoryOther
                                                    .text
                                                    .trim();
                                                if (custom.isEmpty) return;
                                                if (fitnessCategories.any(
                                                  (item) =>
                                                      item.category.text
                                                          .toLowerCase() ==
                                                      custom.toLowerCase(),
                                                )) {
                                                  setDialogState(
                                                    () => validationMessage = 'That fitness category is already selected.',
                                                  );
                                                  return;
                                                }
                                                setDialogState(() {
                                                  fitnessCategories.add(
                                                    _FitnessCategoryInput(
                                                      category: custom,
                                                    ),
                                                  );
                                                  categoryOther.clear();
                                                  validationMessage = null;
                                                });
                                              },
                                        icon: const Icon(Icons.add_rounded),
                                        label: const Text('Add other category'),
                                      ),
                                    ),
                                    if (fitnessCategories.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'Chosen categories: ${fitnessCategories.map((item) => item.category.text).join(', ')}',
                                            style: const TextStyle(
                                              color: _addNavy,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    for (
                                      var index = 0;
                                      index < fitnessCategories.length;
                                      index++
                                    ) ...[
                                      const SizedBox(height: 8),
                                      _fitnessCategoryCard(
                                        fitnessCategories[index],
                                        onDiscountChanged: (value) =>
                                            setDialogState(() {
                                              fitnessCategories[index]
                                                      .yearlyDiscountType =
                                                  value;
                                              if (value == 'none') {
                                                fitnessCategories[index]
                                                    .yearlyDiscountValue
                                                    .clear();
                                              }
                                            }),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    _sectionLabel('COACH STAFF (OPTIONAL)'),
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Add up to 20 coaches with optional profile photos and individual monthly prices.',
                                        style: TextStyle(
                                          color: _addMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    for (
                                      var index = 0;
                                      index < fitnessCoaches.length;
                                      index++
                                    ) ...[
                                      const SizedBox(height: 8),
                                      _fitnessCoachCard(
                                        fitnessCoaches[index],
                                        onPickImage: () async {
                                          try {
                                            final picked = await ImagePicker()
                                                .pickImage(
                                                  source: ImageSource.gallery,
                                                  maxWidth: 600,
                                                  maxHeight: 600,
                                                  imageQuality: 55,
                                                );
                                            if (picked == null) return;
                                            final image = _dataUri(
                                              await picked.readAsBytes(),
                                            );
                                            if (panelOpen && context.mounted) {
                                              setDialogState(
                                                () =>
                                                    fitnessCoaches[index]
                                                            .profileImageUrl =
                                                        image,
                                              );
                                            }
                                          } on Exception catch (error) {
                                            if (panelOpen && context.mounted) {
                                              setDialogState(
                                                () => validationMessage =
                                                    'Could not load the coach profile image: $error',
                                              );
                                            }
                                          }
                                        },
                                        onRemove: () {
                                          final coach = fitnessCoaches.removeAt(
                                            index,
                                          );
                                          coach.dispose();
                                          setDialogState(() {});
                                        },
                                      ),
                                    ],
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: fitnessCoaches.length >= 20
                                            ? null
                                            : () => setDialogState(
                                                () => fitnessCoaches.add(
                                                  _FitnessCoachInput(),
                                                ),
                                              ),
                                        icon: const Icon(
                                          Icons.person_add_alt_1,
                                        ),
                                        label: const Text('Add coach'),
                                      ),
                                    ),
                                  ],
                                  if (type == 'Event') ...[
                                    const SizedBox(height: 8),
                                    _sectionLabel('EVENT BOOKING DETAILS'),
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Event types this venue can hold (required)',
                                        style: TextStyle(
                                          color: _addMuted,
                                          fontSize: 11,
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
                                                color:
                                                    eventTypes.contains(option)
                                                    ? _addOrange
                                                    : _addInk,
                                                fontWeight:
                                                    eventTypes.contains(option)
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                            selected: eventTypes.contains(
                                              option,
                                            ),
                                            showCheckmark: false,
                                            selectedColor: _addSoftOrange,
                                            backgroundColor: Colors.white,
                                            shape: const StadiumBorder(),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
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
                                              labelText:
                                                  'Minimum guests (required)',
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
                                              labelText:
                                                  'Maximum guests (required)',
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
                                ],
                                if (setupStep == 2) ...[
                                  const SizedBox(height: 8),
                                  _sectionLabel('SCHEDULE AND PRICING'),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _timePickerField(
                                          context: context,
                                          label: 'Opens (required)',
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
                                          label: 'Closes (required)',
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
                                      labelText: 'Venue address (required)',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      labelStyle: TextStyle(fontSize: 13),
                                    ),
                                    style: const TextStyle(fontSize: 14),
                                    onChanged: (_) => setDialogState(() {}),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'Enter an address'
                                        : null,
                                  ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 6,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            final location =
                                                await _chooseBusinessLocation(
                                                  latitude: latitude,
                                                  longitude: longitude,
                                                  address: address.text,
                                                );
                                            if (location != null && panelOpen) {
                                              setDialogState(() {
                                                latitude = location.latitude;
                                                longitude = location.longitude;
                                              });
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.location_on_outlined,
                                            size: 18,
                                          ),
                                          label: Text(
                                            latitude == null ||
                                                    longitude == null
                                                ? 'Choose map pin'
                                                : 'Update map pin',
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            minimumSize: const Size(0, 34),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            textStyle: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        if (latitude != null &&
                                            longitude != null)
                                          TextButton(
                                            onPressed: () => setDialogState(() {
                                              latitude = null;
                                              longitude = null;
                                            }),
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 4,
                                                  ),
                                              minimumSize: const Size(0, 30),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              textStyle: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            child: const Text('Clear pin'),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        latitude == null || longitude == null
                                            ? 'Map pin is optional.'
                                            : 'Pinned at ${latitude!.toStringAsFixed(5)}, '
                                                  '${longitude!.toStringAsFixed(5)}',
                                        style: const TextStyle(
                                          color: _addMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
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
                                  if (type == 'Event')
                                    TextFormField(
                                      controller: price,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: InputDecoration(
                                        labelText:
                                            'Fee per event booking (required)',
                                        prefixText: '₱ ',
                                        hintText: '25000 (one complete event)',
                                      ),
                                      validator: (value) {
                                        final amount = double.tryParse(
                                          value?.trim() ?? '',
                                        );
                                        return amount == null || amount <= 0
                                            ? 'Enter an event fee greater than ₱0'
                                            : null;
                                      },
                                    ),
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
                                        Expanded(
                                          child: Text(
                                            'Availability / booking schedule',
                                            style: TextStyle(
                                              color: _addMuted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Available days (required · choose at least one)',
                                      style: TextStyle(
                                        color: _addMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        for (final day in _weekdays)
                                          FilterChip(
                                            label: Text(
                                              day,
                                              style: TextStyle(
                                                color:
                                                    availableDays.contains(day)
                                                    ? _addOrange
                                                    : _addInk,
                                                fontWeight:
                                                    availableDays.contains(day)
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                            selected: availableDays.contains(
                                              day,
                                            ),
                                            showCheckmark: false,
                                            selectedColor: _addSoftOrange,
                                            backgroundColor: Colors.white,
                                            shape: const StadiumBorder(),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
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
                                  const SizedBox(height: 8),
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
                                    child: _sectionLabel(
                                      'AMENITIES (OPTIONAL)',
                                    ),
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
                                                color:
                                                    amenities.contains(amenity)
                                                    ? _addOrange
                                                    : _addInk,
                                                fontWeight:
                                                    amenities.contains(amenity)
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                            selected: amenities.contains(
                                              amenity,
                                            ),
                                            showCheckmark: false,
                                            selectedColor: _addSoftOrange,
                                            backgroundColor: Colors.white,
                                            shape: const StadiumBorder(),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
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
                                    icon: const Icon(
                                      Icons.add_a_photo_outlined,
                                    ),
                                    label: Text(
                                      images.isEmpty
                                          ? 'Add images'
                                          : '${images.length} images selected',
                                    ),
                                  ),
                                  if (images.isNotEmpty)
                                    SizedBox(
                                      height: 72,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (
                                            var index = 0;
                                            index < images.length;
                                            index++
                                          ) ...[
                                            Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image(
                                                    image: _imageProvider(
                                                      images[index],
                                                    )!,
                                                    width: 72,
                                                    height: 72,
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
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
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
                                  _businessReviewCard(
                                    name: name.text.trim(),
                                    type: type,
                                    category: type == 'Sports'
                                        ? sportSlots
                                              .map(
                                                (sport) => sport.sportType.text,
                                              )
                                              .where(
                                                (value) => value.isNotEmpty,
                                              )
                                              .join(', ')
                                        : type == 'Fitness & Wellness'
                                        ? fitnessCategories
                                              .map((item) => item.category.text)
                                              .where(
                                                (value) => value.isNotEmpty,
                                              )
                                              .join(', ')
                                        : category == 'Other'
                                        ? categoryOther.text.trim()
                                        : category,
                                    address: address.text.trim(),
                                    hours: _formatHours(
                                      openingTime,
                                      closingTime,
                                    ),
                                    availableDays: _weekdays
                                        .where(availableDays.contains)
                                        .join(', '),
                                    imageCount: images.length,
                                    complete: scheduleComplete(),
                                  ),
                                ],
                              ],
                            ),
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
                        style: TextButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 13),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                      if (setupStep > 0)
                        TextButton(
                          onPressed: () => setDialogState(() {
                            validationMessage = null;
                            setupStep--;
                          }),
                          child: const Text('Back'),
                        ),
                      if (setupStep < 2)
                        FilledButton(
                          key: ValueKey('business-setup-next-$setupStep'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _addNavy,
                            minimumSize: const Size(112, 40),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () {
                            setDialogState(() => validationMessage = null);
                            if (setupStep == 0) {
                              if (!(formKey.currentState?.validate() ??
                                  false)) {
                                return;
                              }
                              if (!basicsComplete()) {
                                setDialogState(
                                  () => validationMessage = 'Enter a venue name and complete any custom category.',
                                );
                                return;
                              }
                            } else {
                              if (!(formKey.currentState?.validate() ??
                                  false)) {
                                return;
                              }
                              if (!bookingDetailsComplete()) {
                                setDialogState(
                                  () =>
                                      validationMessage = bookingDetailsError(),
                                );
                                return;
                              }
                            }
                            setDialogState(() => setupStep++);
                          },
                          child: Text(setupStep == 0 ? 'Continue' : 'Review'),
                        ),
                      if (setupStep == 2)
                        FilledButton(
                          key: const ValueKey('business-setup-publish'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _addNavy,
                            minimumSize: const Size(136, 40),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () async {
                            setDialogState(() => validationMessage = null);
                            if (name.text.trim().isEmpty) {
                              setDialogState(() {
                                validationMessage =
                                    'Enter a venue name before publishing.';
                                setupStep = 0;
                              });
                              return;
                            }
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
                            if (type == 'Sports') {
                              final capacity = int.tryParse(
                                totalSlots.text.trim(),
                              );
                              final names = sportSlots
                                  .map(
                                    (sport) => sport.sportType.text
                                        .trim()
                                        .toLowerCase(),
                                  )
                                  .toList();
                              final invalidSportConfig =
                                  capacity == null ||
                                  capacity < 1 ||
                                  capacity > 100 ||
                                  sportSlots.isEmpty ||
                                  names.any((name) => name.isEmpty) ||
                                  names.toSet().length != names.length ||
                                  sportSlots.any((sport) {
                                    final rate = double.tryParse(
                                      sport.pricePerHour.text.trim(),
                                    );
                                    final includedCount = int.tryParse(
                                      sport.includedPlayers.text.trim(),
                                    );
                                    final extraFee = double.tryParse(
                                      sport.additionalPlayerFee.text.trim(),
                                    );
                                    return rate == null ||
                                        rate <= 0 ||
                                        sport.slotCount < 1 ||
                                        sport.slotCount > capacity ||
                                        (sport.includedPlayers.text
                                                .trim()
                                                .isNotEmpty &&
                                            (includedCount == null ||
                                                includedCount < 1 ||
                                                includedCount > 1000)) ||
                                        (sport.additionalPlayerFee.text
                                                .trim()
                                                .isNotEmpty &&
                                            (extraFee == null ||
                                                !extraFee.isFinite ||
                                                extraFee <= 0 ||
                                                extraFee > 99999999.99 ||
                                                includedCount == null ||
                                                includedCount < 1));
                                  });
                              if (invalidSportConfig) {
                                setDialogState(
                                  () => validationMessage = 'Check each sport name and rate, and make sure its slot count fits the studio capacity.',
                                );
                                return;
                              }
                            }
                            if (type == 'Fitness & Wellness') {
                              final names = fitnessCategories
                                  .map(
                                    (item) =>
                                        item.category.text.trim().toLowerCase(),
                                  )
                                  .toList();
                              final invalidCategory =
                                  fitnessCategories.isEmpty ||
                                  names.any((name) => name.isEmpty) ||
                                  names.toSet().length != names.length ||
                                  fitnessCategories.any((item) {
                                    final prices =
                                        [
                                          item.sessionPrice.text,
                                          item.monthlyPrice.text,
                                          item.yearlyPrice.text,
                                        ].map(
                                          (value) =>
                                              double.tryParse(value.trim()),
                                        );
                                    if (prices.any(
                                      (value) =>
                                          value == null ||
                                          !value.isFinite ||
                                          value <= 0 ||
                                          value > 99999999.99,
                                    )) {
                                      return true;
                                    }
                                    final discountValue = item
                                        .yearlyDiscountValue
                                        .text
                                        .trim();
                                    if (item.yearlyDiscountType == 'none') {
                                      return discountValue.isNotEmpty;
                                    }
                                    final discount = double.tryParse(
                                      discountValue,
                                    );
                                    if (discount == null ||
                                        !discount.isFinite ||
                                        discount <= 0) {
                                      return true;
                                    }
                                    return item.yearlyDiscountType ==
                                            'freeMonths'
                                        ? discount > 11 ||
                                              discount !=
                                                  discount.roundToDouble()
                                        : discount > 100;
                                  });
                              if (invalidCategory) {
                                setDialogState(
                                  () => validationMessage = 'Choose at least one unique fitness category and enter valid session, monthly, and yearly prices. Check yearly discounts too.',
                                );
                                return;
                              }
                              final coachNames = fitnessCoaches
                                  .map(
                                    (coach) =>
                                        coach.name.text.trim().toLowerCase(),
                                  )
                                  .toList();
                              final invalidCoach =
                                  coachNames.any((name) => name.isEmpty) ||
                                  fitnessCoaches.any((coach) {
                                    final amount = double.tryParse(
                                      coach.monthlyPrice.text.trim(),
                                    );
                                    return amount == null ||
                                        !amount.isFinite ||
                                        amount <= 0 ||
                                        amount > 99999999.99 ||
                                        (coach.profileImageUrl?.length ?? 0) >
                                            400000;
                                  });
                              if (invalidCoach) {
                                setDialogState(
                                  () => validationMessage = 'Enter a coach name and a valid monthly price for each coach.',
                                );
                                return;
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
                                  () => validationMessage = 'Select at least one event type this venue can hold.',
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
                                  () => validationMessage = 'Enter a valid estimated attendance range.',
                                );
                                return;
                              }
                            }
                            if (type != 'Sports' &&
                                type != 'Fitness & Wellness' &&
                                category == 'Other' &&
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
                              final selectedCategory = type == 'Sports'
                                  ? sportSlots.first.sportType.text.trim()
                                  : type == 'Fitness & Wellness'
                                  ? fitnessCategories.first.category.text.trim()
                                  : category == 'Other'
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
                                      if (eventAttendanceMin.text
                                              .trim()
                                              .isNotEmpty ||
                                          eventAttendanceMax.text
                                              .trim()
                                              .isNotEmpty)
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
                                'latitude': latitude,
                                'longitude': longitude,
                                'visitUrl': visitUrl.text.trim(),
                                'pricePerHour': type == 'Event'
                                    ? double.parse(price.text.trim())
                                    : type == 'Sports'
                                    ? double.parse(
                                        sportSlots.first.pricePerHour.text
                                            .trim(),
                                      )
                                    : type == 'Fitness & Wellness'
                                    ? double.parse(
                                        fitnessCategories
                                            .first
                                            .sessionPrice
                                            .text
                                            .trim(),
                                      )
                                    : double.parse(price.text.trim()),
                                'slotCount': type == 'Sports'
                                    ? int.parse(totalSlots.text.trim())
                                    : 1,
                                'sportsSlots': type == 'Sports'
                                    ? [
                                        for (final sport in sportSlots)
                                          {
                                            'sportType': sport.sportType.text
                                                .trim(),
                                            'pricePerHour': double.parse(
                                              sport.pricePerHour.text.trim(),
                                            ),
                                            'fullStudio': sport.fullStudio,
                                            'slotCount': sport.fullStudio
                                                ? int.parse(
                                                    totalSlots.text.trim(),
                                                  )
                                                : sport.slotCount,
                                            'includedPlayers':
                                                int.tryParse(
                                                  sport.includedPlayers.text
                                                      .trim(),
                                                ) ??
                                                0,
                                            'additionalPlayerFee':
                                                double.tryParse(
                                                  sport.additionalPlayerFee.text
                                                      .trim(),
                                                ) ??
                                                0,
                                          },
                                      ]
                                    : const [],
                                'eventFee': type == 'Event'
                                    ? double.parse(price.text.trim())
                                    : 0,
                                'includedPlayers': 0,
                                'additionalPlayerFee': 0,
                                'ratePeriods': const [],
                                'fitnessCategories':
                                    type == 'Fitness & Wellness'
                                    ? [
                                        for (final item in fitnessCategories)
                                          {
                                            'category': item.category.text
                                                .trim(),
                                            'sessionPrice': double.parse(
                                              item.sessionPrice.text.trim(),
                                            ),
                                            'monthlyPrice': double.parse(
                                              item.monthlyPrice.text.trim(),
                                            ),
                                            'yearlyPrice': double.parse(
                                              item.yearlyPrice.text.trim(),
                                            ),
                                            'yearlyDiscountType':
                                                item.yearlyDiscountType,
                                            'yearlyDiscountValue':
                                                item.yearlyDiscountType ==
                                                    'none'
                                                ? null
                                                : double.parse(
                                                    item
                                                        .yearlyDiscountValue
                                                        .text
                                                        .trim(),
                                                  ),
                                          },
                                      ]
                                    : const [],
                                'fitnessCoaches': type == 'Fitness & Wellness'
                                    ? [
                                        for (final coach in fitnessCoaches)
                                          {
                                            'name': coach.name.text.trim(),
                                            'monthlyPrice': double.parse(
                                              coach.monthlyPrice.text.trim(),
                                            ),
                                            'profileImageUrl':
                                                coach.profileImageUrl,
                                          },
                                      ]
                                    : const [],
                                'hours': _formatHours(openingTime, closingTime),
                                'availability': _weekdays
                                    .where(availableDays.contains)
                                    .join(', '),
                                'tags': selectedAmenities,
                                'facilityType': facility,
                                'details': submittedDetails,
                                'eventTypes': type == 'Event'
                                    ? selectedEventTypes
                                    : const [],
                                'attendanceMin': type == 'Event'
                                    ? int.tryParse(
                                        eventAttendanceMin.text.trim(),
                                      )
                                    : null,
                                'attendanceMax': type == 'Event'
                                    ? int.tryParse(
                                        eventAttendanceMax.text.trim(),
                                      )
                                    : null,
                                'accessibilityNeeds': type == 'Event'
                                    ? accessibilityNeeds
                                    : const [],
                                'parkingNeeds': type == 'Event'
                                    ? parkingNeeds
                                    : const [],
                                'securityNeeds': type == 'Event'
                                    ? securityNeeds
                                    : const [],
                                'imageUrl': images.isEmpty
                                    ? null
                                    : jsonEncode(images),
                                'imageUrls': images,
                              };
                              if (editing) {
                                await _api.updateMerchantBusiness(
                                  token: token,
                                  id: _businessId(editingBusiness)!,
                                  business: payload,
                                );
                              } else {
                                await _api.createMerchantBusiness(
                                  token: token,
                                  business: payload,
                                );
                                await widget.onBusinessesChanged();
                                await _loadNewsPosts();
                                if (mounted) {
                                  setState(
                                    () => _selectedAddSection = 'News cards',
                                  );
                                }
                              }
                              if (dialogContext.mounted) {
                                submitted = true;
                                await Navigator.of(dialogContext)
                                    .maybePop(true);
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
                              : Text(
                                  editing
                                      ? 'Save changes'
                                      : 'Publish booking card',
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
            opacity: animation.drive(CurveTween(curve: Curves.easeInOutCubic)),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(-1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOutCubic,
                      reverseCurve: Curves.easeInOutCubic,
                    ),
                  ),
              child: child,
            ),
          ),
    );
    // Let the dialog route finish its reverse animation before disposing the
    // controllers used by its form widgets.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    name.dispose();
    address.dispose();
    visitUrl.dispose();
    price.dispose();
    totalSlots.dispose();
    includedPlayers.dispose();
    additionalPlayerFee.dispose();
    details.dispose();
    categoryOther.dispose();
    amenityOther.dispose();
    eventTypeOther.dispose();
    eventAttendanceMin.dispose();
    eventAttendanceMax.dispose();
    accessibilityInput.dispose();
    parkingInput.dispose();
    securityInput.dispose();
    for (final sport in sportSlots) {
      sport.dispose();
    }
    for (final item in fitnessCategories) {
      item.dispose();
    }
    for (final coach in fitnessCoaches) {
      coach.dispose();
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

  Widget _fitnessCategoryCard(
    _FitnessCategoryInput category, {
    required ValueChanged<String> onDiscountChanged,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      border: Border.all(color: _addLine),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category.category.text,
          style: const TextStyle(color: _addNavy, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final entry in <(String, TextEditingController)>[
          ('Session price (required)', category.sessionPrice),
          ('Monthly price (required)', category.monthlyPrice),
          ('Yearly price (required)', category.yearlyPrice),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextFormField(
              controller: entry.$2,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: entry.$1,
                prefixText: '₱ ',
              ),
            ),
          ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: category.yearlyDiscountType,
          decoration: const InputDecoration(
            labelText: 'Yearly offer (optional)',
          ),
          items: const [
            DropdownMenuItem(value: 'none', child: Text('No discount')),
            DropdownMenuItem(value: 'freeMonths', child: Text('Free months')),
            DropdownMenuItem(
              value: 'percentage',
              child: Text('Percentage off'),
            ),
          ],
          onChanged: (value) {
            if (value != null) onDiscountChanged(value);
          },
        ),
        if (category.yearlyDiscountType != 'none')
          TextFormField(
            controller: category.yearlyDiscountValue,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: category.yearlyDiscountType == 'freeMonths'
                  ? 'Free months (1–11)'
                  : 'Discount percentage (1–100%)',
              suffixText: category.yearlyDiscountType == 'percentage'
                  ? '%'
                  : null,
            ),
          ),
      ],
    ),
  );

  Widget _fitnessCoachCard(
    _FitnessCoachInput coach, {
    required VoidCallback onPickImage,
    required VoidCallback onRemove,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      border: Border.all(color: _addLine),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onPickImage,
              child: CircleAvatar(
                radius: 26,
                backgroundColor: _addSoftOrange,
                backgroundImage: coach.profileImageUrl == null
                    ? null
                    : _safeImageProvider(coach.profileImageUrl!),
                child: coach.profileImageUrl == null
                    ? const Icon(
                        Icons.add_a_photo_outlined,
                        color: _addOrange,
                        size: 19,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Coach profile photo (optional)',
                style: TextStyle(color: _addMuted, fontSize: 11),
              ),
            ),
            IconButton(
              tooltip: 'Remove coach',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        TextFormField(
          controller: coach.name,
          decoration: const InputDecoration(labelText: 'Coach name (required)'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: coach.monthlyPrice,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Coach monthly price (required)',
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
    padding: const EdgeInsets.only(top: 6, bottom: 3),
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

  Widget _setupStepLabel(
    String label, {
    required bool complete,
    required bool current,
  }) => Expanded(
    child: Row(
      children: [
        Icon(
          complete ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 16,
          color: complete
              ? Colors.green.shade700
              : current
              ? _addOrange
              : _addMuted,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: current ? _addNavy : _addMuted,
              fontSize: 10,
              fontWeight: current ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _businessReviewCard({
    required String name,
    required String type,
    required String category,
    required String address,
    required String hours,
    required String availableDays,
    required int imageCount,
    required bool complete,
  }) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: complete ? const Color(0xFFEAF7EE) : const Color(0xFFFFF8EF),
      border: Border.all(
        color: complete ? const Color(0xFFB8DEC2) : const Color(0xFFFFD8AF),
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              complete ? Icons.task_alt_rounded : Icons.rate_review_outlined,
              size: 19,
              color: complete ? Colors.green.shade700 : _addOrange,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                complete ? 'Ready to publish' : 'Finish required details',
                style: const TextStyle(
                  color: _addInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _reviewRow('Business type', type),
        _reviewRow('Venue name', name.isEmpty ? 'Not entered' : name),
        _reviewRow(
          'Categories',
          category.isEmpty ? 'Not configured' : category,
        ),
        _reviewRow('Address', address.isEmpty ? 'Not entered' : address),
        _reviewRow('Hours', hours.isEmpty ? 'Not selected' : hours),
        _reviewRow(
          'Available',
          availableDays.isEmpty ? 'Select at least one day' : availableDays,
        ),
        _reviewRow(
          'Photos',
          imageCount == 0 ? 'Optional · none added' : '$imageCount added',
        ),
        const SizedBox(height: 4),
        Text(
          complete
              ? 'Check the information above, then publish your booking card.'
              : 'Name, opening hours, at least one available day, and address are required. Photos and amenity notes are optional.',
          style: const TextStyle(color: _addMuted, fontSize: 11, height: 1.35),
        ),
      ],
    ),
  );

  Widget _reviewRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: const TextStyle(
              color: _addMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: _addInk,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refreshAddPage,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const Text(
          'Complete a News Card for each business before its Booking Card is published.',
          style: TextStyle(color: _addMuted, fontSize: 13, height: 1.3),
        ),
        const SizedBox(height: 12),
        _addSectionTabs(),
        const SizedBox(height: 10),
        _businessFilterAndSearch(),
        if (_selectedAddSection == 'News cards') ...[
          const SizedBox(height: 16),
          if (widget.businesses.isNotEmpty &&
              _filteredNewsCardBusinesses.isEmpty)
            const Text(
              'No businesses in this category',
              style: TextStyle(color: _addMuted),
            )
          else
            MerchantNewsCardsSection(
              businesses: _filteredNewsCardBusinesses,
              posts: _newsPosts,
              loading: _newsLoading,
              onComplete: _openNewsFormForBusiness,
              onEdit: _openNewsForm,
              onDelete: _deleteNewsPost,
              onPublish: _publishNewsPost,
            ),
        ] else ...[
          const SizedBox(height: 16),
          if (_newsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filteredBusinesses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.storefront_outlined, size: 42, color: _addMuted),
                  SizedBox(height: 8),
                  Text(
                    'No businesses in this category',
                    style: TextStyle(
                      color: _addInk,
                      fontWeight: FontWeight.w800,
                    ),
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
      ],
    ),
  );

  Widget _addSectionTabs() => SegmentedButton<String>(
    segments: const [
      ButtonSegment(value: 'Booking cards', label: Text('Booking cards')),
      ButtonSegment(value: 'News cards', label: Text('News cards')),
    ],
    selected: {_selectedAddSection},
    onSelectionChanged: (value) {
      setState(() => _selectedAddSection = value.first);
      if (value.first == 'News cards' && _newsPosts.isEmpty) {
        _loadNewsPosts();
      }
    },
  );

  Future<void> _openNewsFormForBusiness(Map<String, dynamic> business) async {
    final id = _businessId(business);
    if (id == null) return;
    await _openNewsForm({'businessId': id, '_incomplete': true});
  }

  Future<void> _openNewsForm([Map<String, dynamic>? editing]) async {
    final isIncomplete = editing?['_incomplete'] == true;
    final body = TextEditingController(
      text: isIncomplete ? '' : '${editing?['body'] ?? ''}',
    );
    var businessId = _id(editing?['businessId']);
    final selected = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: Text(
          isIncomplete
              ? 'Complete news card'
              : editing == null
              ? 'Create news card'
              : 'Edit news card',
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .68,
          ),
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: businessId,
                    decoration: const InputDecoration(
                      labelText: 'Booking card',
                    ),
                    items: [
                      for (final business in widget.businesses)
                        DropdownMenuItem(
                          value: _businessId(business),
                          child: Text('${business['name'] ?? 'Business'}'),
                        ),
                    ],
                    onChanged: (value) => setState(() => businessId = value),
                  ),
                  if (businessId != null)
                    _newsVenuePreview(businessId!, body.text),
                  TextField(
                    controller: body,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Short venue news',
                      hintText: 'Add a short update about this venue',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (selected != true || businessId == null || body.text.trim().isEmpty) {
      body.dispose();
      return;
    }
    final token = (await AppSession.load()).apiToken;
    if (token == null || token.isEmpty) {
      body.dispose();
      return;
    }
    final business = widget.businesses.firstWhere(
      (item) => _businessId(item) == businessId,
      orElse: () => <String, dynamic>{},
    );
    final image = _businessPrimaryImage(business);
    final venueName = '${business['name'] ?? 'Venue'}';
    final payload = {
      'businessId': businessId,
      'title': editing?['title'] as String? ?? '$venueName update',
      'body': body.text.trim(),
      'imageUrl': image,
      'status': editing?['status'] ?? 'published',
    };
    try {
      if (editing == null || isIncomplete) {
        await _api.createMerchantNewsPost(token: token, post: payload);
      } else {
        await _api.updateMerchantNewsPost(
          token: token,
          id: _id(editing['id'])!,
          post: payload,
        );
      }
      await _loadNewsPosts();
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      body.dispose();
    }
  }

  Widget _newsVenuePreview(int businessId, String newsText) {
    final business = widget.businesses.firstWhere(
      (item) => _businessId(item) == businessId,
      orElse: () => <String, dynamic>{},
    );
    final image = _businessPrimaryImage(business);
    final name = '${business['name'] ?? 'Venue'}';
    final type = '${business['businessType'] ?? 'Booking'}';
    final category = '${business['category'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'News Feed preview',
              style: TextStyle(
                color: _addMuted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: .4,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _addLine),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: const Text(
                    'News Feed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 170,
                  child:
                      image == null ||
                          image.isEmpty ||
                          _safeImageProvider(image) == null
                      ? const ColoredBox(
                          color: Color(0xFFFFE8D2),
                          child: Icon(
                            Icons.storefront_rounded,
                            size: 48,
                            color: _addOrange,
                          ),
                        )
                      : Image(
                          image: _safeImageProvider(image)!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFFFFE8D2),
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 42,
                              color: _addOrange,
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _addInk,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category.isEmpty ? type : '$type · $category',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _addOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        newsText.trim().isEmpty
                            ? 'Your short venue news will appear here.'
                            : newsText.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _addMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 17,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'No ratings yet',
                            style: TextStyle(
                              color: _addInk,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F4F7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'View info: Booking Card',
                              style: TextStyle(
                                color: _addMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
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
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNewsPost(Map<String, dynamic> post) async {
    final token = (await AppSession.load()).apiToken;
    final id = _id(post['id']);
    if (token == null || token.isEmpty || id == null) return;
    await _api.deleteMerchantNewsPost(token: token, id: id);
    await _loadNewsPosts();
  }

  Future<void> _publishNewsPost(Map<String, dynamic> post) async {
    final token = (await AppSession.load()).apiToken;
    final id = _id(post['id']);
    if (token == null || token.isEmpty || id == null) {
      _showNewsCardMessage('Could not publish this News Card.');
      return;
    }
    try {
      await _api.updateMerchantNewsPost(
        token: token,
        id: id,
        post: {
          'businessId': _postBusinessId(post),
          'title': '${post['title'] ?? ''}',
          'body': '${post['body'] ?? ''}',
          'imageUrl':
              post['imageUrl'] ?? post['image_url'] ?? post['businessImageUrl'],
          'status': 'published',
        },
      );
      await widget.onBusinessesChanged();
      final updatedPosts = await _api.merchantNewsPosts(token);
      final updatedPost = updatedPosts.where((item) => _id(item['id']) == id);
      if (updatedPost.isEmpty ||
          '${updatedPost.first['status'] ?? ''}'.toLowerCase() != 'published') {
        throw const AuthApiException(
          'The News Card was saved, but its published status could not be confirmed.',
          500,
        );
      }
      if (mounted) {
        setState(() {
          _newsPosts = updatedPosts;
          _selectedAddSection = 'Booking cards';
        });
      }
      if (mounted) _showNewsCardMessage('News Card published.');
    } on Exception catch (error) {
      _showNewsCardMessage('Could not publish News Card: $error');
    }
  }

  void _showNewsCardMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  List<Map<String, dynamic>> get _filteredBusinesses {
    return widget.businesses
        .where(
          (business) =>
              _hasCompleteNewsCard(business) &&
              _matchesBusinessFilters(business),
        )
        .toList();
  }

  List<Map<String, dynamic>> get _filteredNewsCardBusinesses {
    return widget.businesses.where(_matchesBusinessFilters).toList();
  }

  bool _matchesBusinessFilters(Map<String, dynamic> business) {
    final type =
        '${business['businessType'] ?? business['business_type'] ?? ''}';
    if (_selectedBusinessType != 'All' && type != _selectedBusinessType) {
      return false;
    }
    final query = _businessSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    final searchableValues = [
      business['name'],
      type,
      business['category'],
      business['address'],
    ];
    return searchableValues.any(
      (value) => '${value ?? ''}'.toLowerCase().contains(query),
    );
  }

  bool _hasCompleteNewsCard(Map<String, dynamic> business) {
    final id = _businessId(business);
    if (id == null) return false;
    return _newsPosts.any((post) {
      final imageUrl =
          post['imageUrl'] ??
          post['image_url'] ??
          post['businessImageUrl'] ??
          business['imageUrl'] ??
          business['image_url'];
      final image = '$imageUrl'.trim();
      return _postBusinessId(post) == id &&
          '${post['status'] ?? ''}'.toLowerCase() == 'published' &&
          '${post['body'] ?? ''}'.trim().isNotEmpty &&
          '${post['title'] ?? ''}'.trim().isNotEmpty &&
          image.isNotEmpty &&
          image != 'null';
    });
  }

  Widget _businessFilterAndSearch() {
    const businessTypes = ['All', 'Sports', 'Event', 'Fitness & Wellness'];
    return Row(
      children: [
        SizedBox(
          width: 128,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedBusinessType,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: _addLine),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: _addLine),
              ),
            ),
            style: const TextStyle(
              color: _addInk,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            icon: const Icon(Icons.filter_list_rounded, size: 18),
            items: [
              for (final type in businessTypes)
                DropdownMenuItem(
                  value: type,
                  child: Text(type == 'Fitness & Wellness' ? 'Fitness' : type),
                ),
            ],
            onChanged: (type) {
              if (type != null) {
                setState(() => _selectedBusinessType = type);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 48,
            child: TextField(
              controller: _businessSearchController,
              onChanged: (query) =>
                  setState(() => _businessSearchQuery = query),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search businesses',
                hintStyle: const TextStyle(fontSize: 12, color: _addMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 38,
                  minHeight: 38,
                ),
                suffixIcon: _businessSearchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _businessSearchController.clear();
                          setState(() => _businessSearchQuery = '');
                        },
                        icon: const Icon(Icons.close_rounded, size: 17),
                        visualDensity: VisualDensity.compact,
                      ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: _addLine),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: _addLine),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _businessCard(Map<String, dynamic> business) {
    final id = _businessId(business);
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
    final includedPlayerLimit =
        int.tryParse(
          '${business['includedPlayers'] ?? business['included_players'] ?? 0}',
        ) ??
        0;
    final extraPlayerFeeValue =
        business['additionalPlayerFee'] ?? business['additional_player_fee'];
    final extraPlayerFee = extraPlayerFeeValue is num
        ? extraPlayerFeeValue.toDouble()
        : double.tryParse('$extraPlayerFeeValue') ?? 0;
    final ratePeriods = _businessRatePeriods(business);
    final details = business['details'] as String? ?? '';
    final priceText = _formatPrice(
      type == 'Event'
          ? business['eventFee'] ??
                business['event_fee'] ??
                business['pricePerHour'] ??
                business['price_per_hour']
          : business['pricePerHour'] ??
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
      color: Colors.white,
      shape: AppCardStyles.merchantShape,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: AppCardStyles.merchantImageHeight,
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
                if (type == 'Sports' && extraPlayerFee > 0)
                  _detail(
                    Icons.groups_rounded,
                    'Includes $includedPlayerLimit players; '
                    'PHP ${extraPlayerFee.toStringAsFixed(2)} '
                    'per extra player',
                  ),
                if (type == 'Event' && category.isNotEmpty)
                  _detail(Icons.celebration_outlined, 'Event type: $category'),
                if (type == 'Fitness & Wellness' && category.isNotEmpty)
                  _detail(Icons.fitness_center_rounded, 'Class: $category'),
                if (type == 'Fitness & Wellness') _fitnessPlanSummary(business),
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

  Widget _fitnessPlanSummary(Map<String, dynamic> business) {
    dynamic readList(String camelCase, String snakeCase) {
      final raw = business[camelCase] ?? business[snakeCase];
      if (raw is List) return raw;
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) return decoded;
        } on FormatException {
          return const [];
        }
      }
      return const [];
    }

    final categories = readList(
      'fitnessCategories',
      'fitness_categories_json',
    ).whereType<Map>().toList();
    final coaches = readList(
      'fitnessCoaches',
      'fitness_coaches_json',
    ).whereType<Map>().toList();
    if (categories.isEmpty && coaches.isEmpty) {
      return const SizedBox.shrink();
    }
    String money(dynamic value) {
      final amount = value is num
          ? value.toDouble()
          : double.tryParse('$value');
      return amount == null ? 'Not set' : '₱${amount.toStringAsFixed(2)}';
    }

    String yearlyOffer(Map item) => switch (item['yearlyDiscountType']) {
      'freeMonths' => ' · ${item['yearlyDiscountValue'] ?? ''} free month(s)',
      'percentage' => ' · ${item['yearlyDiscountValue'] ?? ''}% off yearly',
      _ => '',
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: _addLine),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in categories) ...[
            Text(
              '${item['category'] ?? 'Fitness'} · '
              'Session ${money(item['sessionPrice'])} · '
              'Monthly ${money(item['monthlyPrice'])} · '
              'Yearly ${money(item['yearlyPrice'])}'
              '${yearlyOffer(item)}',
              style: const TextStyle(
                color: _addInk,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (item != categories.last) const SizedBox(height: 4),
          ],
          if (coaches.isNotEmpty) ...[
            if (categories.isNotEmpty) const SizedBox(height: 8),
            for (final coach in coaches)
              Text(
                'Coach ${coach['name'] ?? ''} · '
                '${money(coach['monthlyPrice'])} / month',
                style: const TextStyle(color: _addMuted, fontSize: 11),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleBusiness(
    Map<String, dynamic> business,
    bool enabled,
  ) async {
    final id = _businessId(business);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"$name" was deleted.')));
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

  ImageProvider<Object>? _safeImageProvider(String value) {
    try {
      return _imageProvider(value);
    } on FormatException {
      return null;
    }
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
