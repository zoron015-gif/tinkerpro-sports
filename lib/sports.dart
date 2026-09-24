import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_api.dart';
import 'app_session.dart';
import 'saved_items.dart';
import 'messages_dashboard.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

typedef SportsVenue = ({
  int id,
  String name,
  String sport,
  String address,
  String ownerName,
  String type,
  String courts,
  String hours,
  String availability,
  String details,
  String image,
  List<String> images,
  String priceDay,
  String priceNight,
  List<String> priceLines,
  double maxPrice,
  List<String> tags,
  List<String> rateLabels,
  double latitude,
  double longitude,
  String visitUrl,
  String merchantEmail,
  String merchantPhone,
  String merchantAvatarUrl,
});

const _sportsNavy = Color(0xFF192B50);
const _sportsInk = Color(0xFF101B33);
const _sportsOrange = Color(0xFFFF8200);
const _sportsLine = Color(0xFFE2E7EF);
const _sportsMuted = Color(0xFF68748A);
const _sportsPage = Color(0xFFF7F9FC);
const _sportsSurface = Colors.white;
const _sportsSoftOrange = Color(0xFFFFF1E4);

class SportsVenueDetailPage extends StatefulWidget {
  const SportsVenueDetailPage({
    super.key,
    required this.venue,
    required this.onReserve,
  });

  final SportsVenue venue;
  final VoidCallback onReserve;

  @override
  State<SportsVenueDetailPage> createState() => _SportsVenueDetailPageState();
}

class _SportsVenueDetailPageState extends State<SportsVenueDetailPage> {
  final Map<String, int> _saveCounts = <String, int>{};
  final Set<String> _savedKeys = <String>{};
  late String _saveKey;
  var _imageIndex = 0;
  late final PageController _imageController;

  @override
  void initState() {
    super.initState();
    _saveKey = _keyForVenue(widget.venue);
    final imageCount = _usableImages(widget.venue).length;
    _imageController = PageController(
      initialPage: imageCount == 0 ? 0 : 50000 - (50000 % imageCount),
    );
    _loadSavedState();
  }

  @override
  void didUpdateWidget(covariant SportsVenueDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.venue != widget.venue) {
      _saveKey = _keyForVenue(widget.venue);
      _loadSavedState();
    }
  }

  String _keyForVenue(SportsVenue venue) => venue.id > 0
      ? 'sports-${venue.id}'
      : (venue.name.trim().isEmpty
            ? 'sports-venue'
            : 'sports-${venue.name.trim()}');

  List<String> _usableImages(SportsVenue venue) {
    return venue.images.map((image) => image.trim()).where((image) {
      if (image.isEmpty) return false;
      if (image.startsWith('data:image/')) {
        final comma = image.indexOf(',');
        if (comma <= 0 || image.substring(comma + 1).trim().isEmpty) {
          return false;
        }
        try {
          base64Decode(image.substring(comma + 1));
          return true;
        } on FormatException {
          return false;
        }
      }
      return image.startsWith('http://') || image.startsWith('https://');
    }).toList();
  }

  Future<void> _loadSavedState() async {
    try {
      final saved = await SavedItemStore.list();
      final counts = await SavedItemStore.counts('sports');
      if (!mounted) return;
      setState(() {
        _savedKeys
          ..clear()
          ..addAll(
            saved
                .where((item) {
                  final itemKey =
                      '${item['itemKey'] ?? item['item_key'] ?? ''}';
                  return itemKey.isNotEmpty;
                })
                .map((item) => '${item['itemKey'] ?? item['item_key']}'),
          );
        _saveCounts
          ..clear()
          ..addAll(counts);
      });
    } on Exception {
      // Ignore backup load failures and keep the booking card usable.
    }
  }

  Future<void> _toggleSaved() async {
    try {
      if (_savedKeys.contains(_saveKey)) {
        await SavedItemStore.remove('sports', _saveKey);
        if (!mounted) return;
        setState(() {
          _savedKeys.remove(_saveKey);
          _saveCounts[_saveKey] = (_saveCounts[_saveKey] ?? 1) - 1;
          if ((_saveCounts[_saveKey] ?? 0) < 0) {
            _saveCounts[_saveKey] = 0;
          }
        });
      } else {
        await SavedItemStore.save(
          type: 'sports',
          key: _saveKey,
          title: widget.venue.name,
          subtitle: '${widget.venue.sport}\n${widget.venue.address}',
          imageUrl: widget.venue.image,
        );
        if (!mounted) return;
        setState(() {
          _savedKeys.add(_saveKey);
          _saveCounts[_saveKey] = (_saveCounts[_saveKey] ?? 0) + 1;
        });
      }
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update saved count: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final merchantName = widget.venue.ownerName.trim();
    final isSaved = _savedKeys.contains(_saveKey);
    final images = _usableImages(widget.venue);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        top: true,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (images.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF17213A),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFF263A72),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: <Widget>[
                      SizedBox(
                        width: double.infinity,
                        height: 280,
                        child: PageView.builder(
                          controller: _imageController,
                          itemCount: 100000,
                          onPageChanged: (index) {
                            final count = images.length;
                            setState(
                              () =>
                                  _imageIndex = count == 0 ? 0 : index % count,
                            );
                          },
                          itemBuilder: (_, index) {
                            return Image(
                              image: _imageProvider(
                                images[index % images.length],
                              ),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  Container(color: const Color(0xFFE5E7EB)),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 14,
                        left: 14,
                        child: _heroAction(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _toggleSaved,
                              child: Icon(
                                isSaved
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: isSaved ? _sportsOrange : Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _heroAction(
                              icon: Icons.ios_share_rounded,
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                      if (images.length > 1)
                        Positioned(
                          right: 14,
                          bottom: 18,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.58),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${_imageIndex + 1}/${images.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.venue.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF1B1C1E),
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.venue.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _sportsMuted,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (widget.venue.availability.trim().isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9FBF2),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: const Color(0xFFA7E5C2),
                                ),
                              ),
                              child: const Text(
                                'OPEN NOW',
                                style: TextStyle(
                                  color: Color(0xFF07854B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF59E0B),
                            size: 17,
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'New listing',
                            style: TextStyle(
                              color: Color(0xFF101B33),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            '  •  ',
                            style: TextStyle(color: Color(0xFFCBD2DD)),
                          ),
                          Text(
                            'Reviews available',
                            style: TextStyle(
                              color: _sportsOrange,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                              decorationColor: _sportsOrange,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _detailRow(
                        Icons.sports_volleyball_outlined,
                        '${widget.venue.sport}${widget.venue.type.trim().isEmpty ? '' : ' · ${widget.venue.type}'}${widget.venue.courts.trim().isEmpty ? '' : ' · ${widget.venue.courts}'}',
                      ),
                      _detailRow(
                        Icons.location_on_outlined,
                        widget.venue.address,
                      ),
                      if (widget.venue.hours.trim().isNotEmpty)
                        _detailRow(
                          Icons.access_time_outlined,
                          widget.venue.hours,
                        ),
                      if (widget.venue.availability.trim().isNotEmpty)
                        _detailRow(
                          Icons.check_circle_outlined,
                          widget.venue.availability,
                        ),
                      if (widget.venue.details.trim().isNotEmpty)
                        _detailRow(Icons.notes_outlined, widget.venue.details),
                      if (widget.venue.tags.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        const Text(
                          'COURT AMENITIES',
                          style: TextStyle(
                            color: Color(0xFF8A97AA),
                            fontSize: 11,
                            letterSpacing: .8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.venue.tags
                              .where((tag) => tag.trim().isNotEmpty)
                              .map(
                                (tag) => DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEFE5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0x33FED7AA),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      tag,
                                      style: const TextStyle(
                                        color: Color(0xFF263247),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (widget.venue.priceDay.trim().isNotEmpty)
                        Text(
                          widget.venue.priceDay,
                          style: const TextStyle(
                            color: Color(0xFF101B33),
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFFD8DDE5), thickness: 1),
                      const SizedBox(height: 18),
                      if (merchantName.isNotEmpty ||
                          widget.venue.merchantEmail.isNotEmpty ||
                          widget.venue.merchantPhone.isNotEmpty) ...[
                        const Text(
                          'Hosted by merchant',
                          style: TextStyle(
                            color: Color(0xFF1B1C1E),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Verified venue manager • Fast responding',
                          style: TextStyle(
                            color: Color(0xFF778398),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF8FAFC), Color(0xFFFFF7ED)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E7EF)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 27,
                                    backgroundColor: Colors.grey.shade300,
                                    backgroundImage:
                                        widget.venue.merchantAvatarUrl
                                            .trim()
                                            .isEmpty
                                        ? null
                                        : _imageProvider(
                                            widget.venue.merchantAvatarUrl,
                                          ),
                                    child:
                                        widget.venue.merchantAvatarUrl
                                            .trim()
                                            .isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      merchantName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF1B1C1E),
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: () =>
                                        _contactMerchant(widget.venue),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(52, 34),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFFD7DEE8),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                    ),
                                    child: const Text(
                                      'Chat',
                                      style: TextStyle(
                                        color: Color(0xFF263247),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.venue.merchantEmail.isNotEmpty ||
                                  widget.venue.merchantPhone.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 10),
                                if (widget.venue.merchantPhone.isNotEmpty)
                                  _contactChip(
                                    Icons.phone_outlined,
                                    widget.venue.merchantPhone,
                                  ),
                                if (widget.venue.merchantEmail.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: _contactChip(
                                      Icons.email_outlined,
                                      widget.venue.merchantEmail,
                                    ),
                                  ),
                              ],
                              if (widget.venue.merchantPhone.isNotEmpty ||
                                  widget.venue.merchantEmail.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .75),
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                      color: const Color(0xFFE2E7EF),
                                    ),
                                  ),
                                  child: const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '⚡ Typical reply: Within 15 minutes',
                                        style: TextStyle(
                                          color: Color(0xFF667389),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '100% Booking Rate',
                                        style: TextStyle(
                                          color: Color(0xFF079455),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (widget.venue.rateLabels.isNotEmpty) ...[
                        const Text(
                          'Rates',
                          style: TextStyle(
                            color: Color(0xFF1B1C1E),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final rate in widget.venue.rateLabels)
                          _detailRow(Icons.payments_outlined, rate),
                        const SizedBox(height: 8),
                      ],
                      if (merchantName.isNotEmpty ||
                          widget.venue.merchantEmail.isNotEmpty ||
                          widget.venue.merchantPhone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE8EDF3)),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Booking & Cancellation Policy',
                                style: TextStyle(
                                  color: Color(0xFF101B33),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Non-marking athletic footwear required on court. Instant confirmation provided upon receipt of booking.',
                                style: TextStyle(
                                  color: Color(0xFF718096),
                                  fontSize: 11,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      if (widget.venue.visitUrl.trim().isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () async {
                              final uri = Uri.tryParse(widget.venue.visitUrl);
                              if (uri == null || !await launchUrl(uri)) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Could not open venue link.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Visit venue website'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(20),
            border: const Border(top: BorderSide(color: Color(0xFFE2E7EF))),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.venue.priceDay,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xFF1B1C1E),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 132,
                height: 48,
                child: FilledButton(
                  onPressed: widget.onReserve,
                  style: FilledButton.styleFrom(
                    backgroundColor: _sportsOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Reserve',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroAction({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18, color: const Color(0xFF263247)),
      ),
    );
  }

  Future<void> _contactMerchant(SportsVenue venue) async {
    try {
      final session = await AppSession.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Your session has expired.', 401);
      }
      final response = await AuthApi().messageOwner(
        token: token,
        businessKey: venue.id > 0 ? '${venue.id}' : venue.name,
      );
      final owner = response['owner'] as Map<String, dynamic>?;
      if (!mounted) return;
      if (owner == null) {
        _showMerchantMessage(
          'This merchant is not available for messages yet.',
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              MessagesDashboardPage(owner: owner, businessTitle: venue.name),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      _showMerchantMessage('Could not open merchant messages: $error');
    }
  }

  void _showMerchantMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _detailRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Color(0xFFF1F3F6),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: const Color(0xFF4D596D)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF263247),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _contactChip(IconData icon, String value) => Row(
    mainAxisSize: MainAxisSize.max,
    children: [
      Icon(icon, size: 18, color: const Color(0xFF68748A)),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          value,
          softWrap: true,
          style: const TextStyle(
            color: Color(0xFF4D5666),
            fontSize: 13,
            height: 1.25,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );

  ImageProvider _imageProvider(String image) {
    if (image.startsWith('data:image/')) {
      final comma = image.indexOf(',');
      if (comma >= 0) {
        try {
          return MemoryImage(base64Decode(image.substring(comma + 1)));
        } on FormatException {
          return const AssetImage('assets/venue/missing-image.png');
        }
      }
    }
    if (image.startsWith('http')) return NetworkImage(image);
    return const AssetImage('assets/venue/missing-image.png');
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }
}

enum SportsDashboardAction { none, openMap }

class SportsDashboardPage extends StatefulWidget {
  const SportsDashboardPage({
    super.key,
    this.onLogout,
    this.initialAction = SportsDashboardAction.none,
    this.initialVenue,
  });

  final Future<void> Function(BuildContext context)? onLogout;
  final SportsDashboardAction initialAction;
  final SportsVenue? initialVenue;

  @override
  State<SportsDashboardPage> createState() => _SportsDashboardPageState();
}

class _SportsDashboardPageState extends State<SportsDashboardPage> {
  final _api = AuthApi();
  final _searchController = TextEditingController();
  final List<SportsVenue> _merchantVenues = [];
  List<SportsVenue> get _allVenues => _merchantVenues;

  String _area = 'All areas';
  String _sport = 'All sports';
  String _courtType = 'All';
  String _availability = 'Any';
  double _maxPrice = 700;
  final Set<String> _selectedAmenities = <String>{};
  bool _locationLoading = false;
  Position? _position;
  final String _sortBy = 'Featured';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadMerchantBusinesses();
  }

  List<dynamic> get _filteredVenues {
    final query = _searchController.text.trim().toLowerCase();
    final venues = _allVenues.where((venue) {
      final matchesQuery =
          query.isEmpty ||
          venue.name.toLowerCase().contains(query) ||
          venue.address.toLowerCase().contains(query);
      final matchesType = _courtType == 'All' || venue.type == _courtType;
      final matchesSport = _sport == 'All sports' || venue.sport == _sport;
      final matchesArea =
          _area == 'All areas' ||
          venue.address.toLowerCase().contains(_area.toLowerCase());
      final matchesAvailability =
          _availability == 'Any' ||
          (venue.hours.toLowerCase().contains(_availability.toLowerCase()) ||
              venue.availability.toLowerCase().contains(
                _availability.toLowerCase(),
              ));
      final matchesPrice = venue.maxPrice <= _maxPrice;
      final matchesAmenities = _selectedAmenities.every(
        (amenity) => venue.tags.any(
          (tag) => tag.toLowerCase().startsWith(amenity.toLowerCase()),
        ),
      );
      return matchesQuery &&
          matchesType &&
          matchesSport &&
          matchesArea &&
          matchesAvailability &&
          matchesPrice &&
          matchesAmenities;
    }).toList();
    venues.sort((a, b) {
      switch (_sortBy) {
        case 'Name A-Z':
          return a.name.compareTo(b.name);
        case 'Price: low to high':
          return a.maxPrice.compareTo(b.maxPrice);
        case 'Price: high to low':
          return b.maxPrice.compareTo(a.maxPrice);
        case 'Nearest':
          if (_position == null) return 0;
          return _distanceSquared(
            _position!.latitude,
            _position!.longitude,
            a.latitude,
            a.longitude,
          ).compareTo(
            _distanceSquared(
              _position!.latitude,
              _position!.longitude,
              b.latitude,
              b.longitude,
            ),
          );
        default:
          return 0;
      }
    });
    return venues;
  }

  int get _activeFilterCount {
    var count = 0;
    if (_area != 'All areas') count++;
    if (_sport != 'All sports') count++;
    if (_courtType != 'All') count++;
    if (_availability != 'Any') count++;
    if (_maxPrice < 700) count++;
    count += _selectedAmenities.length;
    return count;
  }

  List<String> _merchantOptions(
    String Function(SportsVenue venue) selector,
    String allLabel,
  ) {
    final values =
        _allVenues
            .map(selector)
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return [allLabel, ...values];
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
    _loadMerchantBusinesses();
    if (widget.initialAction != SportsDashboardAction.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.initialAction == SportsDashboardAction.openMap) {
          _openMap();
        }
      });
    }
  }

  Future<void> _loadMerchantBusinesses() async {
    try {
      final rows = await AuthApi().customerBusinesses();
      if (!mounted) return;
      setState(
        () => _merchantVenues
          ..clear()
          ..addAll(
            rows
                .where(
                  (b) =>
                      '${b['businessType'] ?? b['business_type'] ?? ''}'
                          .trim()
                          .toLowerCase() ==
                      'sports',
                )
                .map(_sportsVenue),
          ),
      );
    } on Exception catch (error) {
      if (mounted) {
        _showMessage('Could not load merchant Sports venues: $error');
      }
    }
  }

  SportsVenue _sportsVenue(Map<String, dynamic> b) {
    final rawTags = b['tags'];
    final tags = rawTags is List
        ? rawTags.whereType<String>().toList()
        : rawTags is String
        ? (() {
            try {
              final decoded = jsonDecode(rawTags);
              return decoded is List
                  ? decoded.whereType<String>().toList()
                  : <String>[];
            } on FormatException {
              return <String>[];
            }
          })()
        : <String>[];
    final price =
        double.tryParse('${b['pricePerHour'] ?? b['price_per_hour'] ?? 0}') ??
        0;
    final rawPeriods = b['ratePeriods'] ?? b['rate_periods'];
    final periods = rawPeriods is List
        ? rawPeriods.whereType<Map>().map((period) {
            final start = period['start'] ?? period['start_time'] ?? '';
            final end = period['end'] ?? period['end_time'] ?? '';
            final amount = period['pricePerHour'] ?? period['price_per_hour'];
            return '$start - $end|PHP ${double.tryParse('$amount')?.toStringAsFixed(0) ?? amount} / hr';
          }).toList()
        : <String>[];
    final rateValues = rawPeriods is List
        ? rawPeriods
              .whereType<Map>()
              .map(
                (period) => double.tryParse(
                  '${period['pricePerHour'] ?? period['price_per_hour'] ?? 0}',
                ),
              )
              .whereType<double>()
              .where((value) => value > 0)
              .toList()
        : <double>[];
    final maxPrice = [
      price,
      ...rateValues,
    ].reduce((maximum, value) => value > maximum ? value : maximum);
    final images = _merchantImages(b);
    return (
      id: (b['id'] as num?)?.toInt() ?? 0,
      name: b['name'] as String? ?? 'Business',
      sport: '${b['category'] ?? 'Sports'}',
      address: '${b['address'] ?? ''}',
      ownerName: _ownerName(b),
      type: '${b['facilityType'] ?? b['facility_type'] ?? 'Facility'}',
      courts: '${b['details'] ?? 'Sports facility'}',
      hours: '${b['hours'] ?? b['opening_hours'] ?? 'Open hours'}',
      availability: '${b['availability'] ?? b['availability_status'] ?? ''}',
      details: '${b['details'] ?? ''}',
      image: _merchantImage(b),
      images: images,
      priceDay: 'PHP ${maxPrice.toStringAsFixed(0)} / hr',
      priceNight: 'PHP ${maxPrice.toStringAsFixed(0)} / hr',
      priceLines: periods.isEmpty
          ? ['Booking rate|PHP ${price.toStringAsFixed(0)} / hr']
          : periods,
      maxPrice: maxPrice,
      tags: tags,
      rateLabels: periods,
      latitude: 10.3157,
      longitude: 123.8854,
      visitUrl: '${b['visitUrl'] ?? b['visit_url'] ?? ''}',
      merchantEmail: '${b['merchantEmail'] ?? b['merchant_email'] ?? ''}',
      merchantPhone: '${b['merchantPhone'] ?? b['merchant_phone'] ?? ''}',
      merchantAvatarUrl:
          '${b['merchantAvatarUrl'] ?? b['merchant_avatar_url'] ?? ''}',
    );
  }

  String _ownerName(Map<String, dynamic> business) {
    final explicit = business['ownerName'] ?? business['owner_name'];
    if (explicit is String && explicit.trim().isNotEmpty) {
      return explicit.trim();
    }
    final first =
        business['ownerFirstName'] ?? business['owner_first_name'] ?? '';
    final last = business['ownerLastName'] ?? business['owner_last_name'] ?? '';
    final name = '$first $last'.trim();
    return name;
  }

  String _merchantImage(Map<String, dynamic> business) {
    final images = _merchantImages(business);
    return images.isEmpty ? '' : images.first;
  }

  List<String> _merchantImages(Map<String, dynamic> business) {
    final images = <String>[];
    final raw = business['imageUrls'] ?? business['image_urls'];
    if (raw is List && raw.whereType<String>().isNotEmpty) {
      images.addAll(raw.whereType<String>().where((image) => image.isNotEmpty));
    }
    if (images.isEmpty && raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List && decoded.whereType<String>().isNotEmpty) {
          images.addAll(
            decoded.whereType<String>().where((image) => image.isNotEmpty),
          );
        }
      } on FormatException {
        images.add(raw);
      }
    }
    final legacy = business['imageUrl'] as String?;
    if (images.isEmpty && legacy != null && legacy.isNotEmpty) {
      try {
        final decoded = jsonDecode(legacy);
        if (decoded is List && decoded.whereType<String>().isNotEmpty) {
          images.addAll(
            decoded.whereType<String>().where((image) => image.isNotEmpty),
          );
        }
      } on FormatException {
        images.add(legacy);
      }
      if (images.isEmpty) images.add(legacy);
    }
    return images;
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final detailVenue =
        widget.initialVenue ??
        (_allVenues.isNotEmpty ? _allVenues.first : _defaultDetailVenue());
    return SportsVenueDetailPage(
      venue: detailVenue,
      onReserve: () => _openBookingModal(detailVenue),
    );
  }

  SportsVenue _defaultDetailVenue() => (
    id: 0,
    name: '',
    sport: '',
    address: '',
    ownerName: '',
    type: '',
    courts: '',
    hours: '',
    availability: '',
    details: '',
    image: '',
    images: const [],
    priceDay: '',
    priceNight: '',
    priceLines: const [],
    maxPrice: 0,
    tags: const [],
    rateLabels: const [],
    latitude: 0,
    longitude: 0,
    visitUrl: '',
    merchantEmail: '',
    merchantPhone: '',
    merchantAvatarUrl: '',
  );

  // Kept as a reusable desktop filter layout for future inline filter mode.
  // ignore: unused_element
  Widget _filterPanel() {
    final mobile = MediaQuery.sizeOf(context).width < 900;
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom;
    final panelHeight = mobile ? availableHeight * .68 : availableHeight - 96;

    return SizedBox(
      height: panelHeight,
      child: Container(
        margin: EdgeInsets.fromLTRB(16, 14, mobile ? 16 : 0, 16),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        decoration: BoxDecoration(
          color: _sportsSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _sportsLine),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filters',
                      style: TextStyle(
                        color: _sportsInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Reset', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const Divider(height: 16),
              _label('DISTANCE'),
              OutlinedButton.icon(
                onPressed: _useLocation,
                icon: _locationLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.location_on, size: 16),
                label: const Text('Use my location'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _sportsInk,
                  side: const BorderSide(color: _sportsNavy),
                  minimumSize: const Size(double.infinity, 38),
                ),
              ),
              _sectionGap(),
              _label('AREA / CITY'),
              _dropdown(
                value: _area,
                values: const [
                  'All areas',
                  'Cebu City',
                  'Mandaue City',
                  'Talisay',
                ],
                onChanged: (value) => setState(() => _area = value),
              ),
              _sectionGap(),
              _label('SPORT'),
              _dropdown(
                value: _sport,
                values: const [
                  'All sports',
                  'Basketball',
                  'Badminton',
                  'Tennis',
                  'Padel',
                  'Volleyball',
                  'Pickleball',
                ],
                onChanged: (value) => setState(() => _sport = value),
              ),
              _sectionGap(),
              _label('COURT TYPE'),
              _chips(
                const ['All', 'Indoor', 'Outdoor', 'Covered'],
                _courtType,
                (value) => setState(() => _courtType = value),
              ),
              _sectionGap(),
              _label('AMENITIES'),
              _amenityChips(const [
                'Parking',
                'Pet-friendly',
                'Restroom',
                'Shower',
                'Store',
              ]),
              _sectionGap(),
              _label('AVAILABILITY'),
              _chips(
                const ['Any', 'Open 24 hours'],
                _availability,
                (value) => setState(() => _availability = value),
              ),
              _sectionGap(),
              _label('PRICE (₱ / HOUR)'),
              Text(
                _maxPrice >= 700
                    ? '₱0 to ₱700+'
                    : '₱0 to ₱${_maxPrice.round()} / hour',
                style: const TextStyle(
                  color: _sportsInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Slider(
                value: _maxPrice,
                min: 0,
                max: 700,
                divisions: 14,
                activeColor: _sportsOrange,
                label: '₱${_maxPrice.round()}',
                onChanged: (value) => setState(() => _maxPrice = value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  void _openFilterDrawer() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) {
          final height = MediaQuery.sizeOf(context).height;
          return Container(
            height: height * .9,
            decoration: const BoxDecoration(
              color: _sportsSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 12, 12),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: _sportsLine,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Filters',
                                style: TextStyle(
                                  color: _sportsInk,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (_activeFilterCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _sportsSoftOrange,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  '$_activeFilterCount active',
                                  style: const TextStyle(
                                    color: _sportsOrange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            TextButton(
                              onPressed: () {
                                _resetFilters();
                                dialogSetState(() {});
                              },
                              child: const Text('Reset all'),
                            ),
                            IconButton(
                              tooltip: 'Close filters',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: _filterContent(dialogSetState),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: _sportsNavy,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text('Show ${_filteredVenues.length} venues'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filterContent([StateSetter? dialogSetState]) {
    void update(VoidCallback callback) {
      setState(callback);
      dialogSetState?.call(() {});
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('DISTANCE'),
          OutlinedButton.icon(
            onPressed: _useLocation,
            icon: const Icon(Icons.my_location_rounded, size: 16),
            label: const Text('Use my location'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _sportsNavy,
              side: const BorderSide(color: _sportsNavy),
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
          _sectionGap(),
          _label('AREA / CITY'),
          _dropdown(
            value: _area,
            values: _merchantOptions((venue) => venue.address, 'All areas'),
            onChanged: (value) => update(() => _area = value),
          ),
          _sectionGap(),
          _label('SPORT'),
          _dropdown(
            value: _sport,
            values: _merchantOptions((venue) => venue.sport, 'All sports'),
            onChanged: (value) => update(() => _sport = value),
          ),
          _sectionGap(),
          _label('COURT TYPE'),
          _chips(
            _merchantOptions((venue) => venue.type, 'All'),
            _courtType,
            (value) => update(() => _courtType = value),
          ),
          _sectionGap(),

          _label('AMENITIES'),
          _amenityChips(const [
            'Parking',
            'Pet-friendly',
            'Restroom',
            'Shower',
            'Store',
          ], dialogSetState),
          _sectionGap(),
          _label('AVAILABILITY'),
          _chips(
            const ['Any', 'Open 24 hours'],
            _availability,
            (value) => update(() => _availability = value),
          ),
          _sectionGap(),
          _priceFilter(dialogSetState),
        ],
      ),
    );
  }

  Widget _priceFilter([StateSetter? dialogSetState]) {
    void update(VoidCallback callback) {
      setState(callback);
      dialogSetState?.call(() {});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('PRICE (₱ / HOUR)')),
            Text(
              _maxPrice >= 700 ? '₱0 - ₱700+' : '₱0 - ₱${_maxPrice.round()}',
              style: const TextStyle(
                color: _sportsNavy,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: _sportsNavy,
            inactiveTrackColor: _sportsLine,
            thumbColor: _sportsOrange,
            overlayColor: _sportsOrange.withValues(alpha: .14),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: _maxPrice,
            min: 0,
            max: 700,
            divisions: 14,
            onChanged: (value) => update(() => _maxPrice = value),
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('₱0', style: TextStyle(color: _sportsMuted, fontSize: 11)),
            Text('₱350', style: TextStyle(color: _sportsMuted, fontSize: 11)),
            Text('₱700+', style: TextStyle(color: _sportsMuted, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Future<void> _openBookingModal(SportsVenue venue) async {
    if (venue.id <= 0) {
      _showMessage('This merchant venue is not available for booking yet.');
      return;
    }
    final rate = venue.maxPrice;
    if (!rate.isFinite || rate <= 0) {
      _showMessage('This venue does not have a valid merchant rate.');
      return;
    }
    var hours = 1;
    var players = 1;
    var payment = 'online';
    DateTime bookingDate = DateTime.now();
    TimeOfDay bookingTime = TimeOfDay.now();
    var occupiedBookings = <Map<String, dynamic>>[];
    var availabilityLoading = true;
    final session = await AppSession.load();
    final token = session.apiToken;
    if (token != null && token.isNotEmpty) {
      try {
        occupiedBookings = await _api.bookingAvailability(
          token: token,
          venueId: venue.id,
          date: _bookingDateString(bookingDate),
        );
      } on Exception catch (error) {
        _showMessage('Could not load this venue\'s availability: $error');
      }
    }
    availabilityLoading = false;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF8F9FF),
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final total = rate * hours;
          final cashOnArrival = total / 2;
          final dueNow = payment == 'cash_on_arrival' ? cashOnArrival : total;
          final selectedSlotBooked = _bookingSlotOverlaps(
            bookingTime,
            hours,
            occupiedBookings,
          );
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
                          () => Navigator.of(modalContext).pop(),
                        ),
                        const Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Book Court',
                                style: TextStyle(
                                  color: _sportsInk,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Step 2 of 2 • Checkout',
                                style: TextStyle(
                                  color: _sportsMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _modalIconButton(Icons.help_outline_rounded, () {}),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
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
                                        venue.sport.isEmpty
                                            ? 'VENUE'
                                            : venue.sport.toUpperCase(),
                                        style: const TextStyle(
                                          color: _sportsOrange,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: .7,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      venue.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _sportsInk,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'PHP ${rate.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: _sportsOrange,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _bookingDetail(
                            Icons.person_outline,
                            'Owner: ${venue.ownerName}',
                          ),
                          _bookingDetail(
                            Icons.location_on_outlined,
                            venue.address,
                          ),
                          _bookingDetail(
                            Icons.access_time_outlined,
                            'Venue hours: ${venue.hours}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'CHOOSE DATE AND TIME',
                      style: TextStyle(
                        color: _sportsMuted,
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
                            style: _bookingChoiceStyle(),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: bookingDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  bookingDate = picked;
                                  availabilityLoading = true;
                                });
                                if (token != null && token.isNotEmpty) {
                                  try {
                                    final bookings = await _api
                                        .bookingAvailability(
                                          token: token,
                                          venueId: venue.id,
                                          date: _bookingDateString(picked),
                                        );
                                    if (context.mounted) {
                                      setModalState(() {
                                        occupiedBookings = bookings;
                                        availabilityLoading = false;
                                      });
                                    }
                                  } on Exception catch (error) {
                                    if (context.mounted) {
                                      setModalState(
                                        () => availabilityLoading = false,
                                      );
                                      _showMessage(
                                        'Could not refresh availability: $error',
                                      );
                                    }
                                  }
                                } else {
                                  setModalState(
                                    () => availabilityLoading = false,
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(
                              MaterialLocalizations.of(context)
                                  .formatMediumDate(bookingDate),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: _bookingChoiceStyle(),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: bookingTime,
                              );
                              if (picked != null) {
                                setModalState(() => bookingTime = picked);
                              }
                            },
                            icon: const Icon(Icons.schedule_rounded),
                            label: Text(bookingTime.format(context)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select a time within the venue hours: ${venue.hours}.',
                      style: const TextStyle(color: _sportsMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    if (availabilityLoading)
                      const LinearProgressIndicator()
                    else if (occupiedBookings.isEmpty)
                      Text(
                        'No existing bookings for this date.',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else ...[
                      Text(
                        'Already booked on this date',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: occupiedBookings
                            .map(
                              (booking) => Chip(
                                avatar: Icon(
                                  Icons.event_busy_rounded,
                                  size: 16,
                                  color: Colors.red.shade700,
                                ),
                                label: Text(_occupiedBookingLabel(booking)),
                                backgroundColor: Colors.red.shade50,
                                side: BorderSide(color: Colors.red.shade200),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (selectedSlotBooked) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          'This time overlaps an existing booking. Please choose another time.',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Text(
                      'BOOKING CONFIGURATION',
                      style: TextStyle(
                        color: _sportsMuted,
                        fontSize: 11,
                        letterSpacing: .9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: hours,
                      decoration: _bookingInputDecoration(
                        prefixIcon: Icon(Icons.schedule_rounded),
                        labelText: 'Duration',
                      ),
                      items: [
                        for (var value = 1; value <= 8; value++)
                          DropdownMenuItem(
                            value: value,
                            child: Text('$value hour${value == 1 ? '' : 's'}'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setModalState(() => hours = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      initialValue: players,
                      decoration: _bookingInputDecoration(
                        prefixIcon: Icon(Icons.groups_rounded),
                        labelText: 'Number of players',
                      ),
                      items: [
                        for (var value = 1; value <= 30; value++)
                          DropdownMenuItem(
                            value: value,
                            child: Text(
                              '$value player${value == 1 ? '' : 's'}',
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => players = value);
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'PAYMENT METHOD',
                      style: TextStyle(
                        color: _sportsMuted,
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
                              ? _sportsOrange
                              : Colors.white,
                        ),
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.white
                              : _sportsInk,
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
                      selected: {payment},
                      onSelectionChanged: (selection) {
                        setModalState(() => payment = selection.first);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      payment == 'cash_on_arrival'
                          ? 'Pay PHP ${cashOnArrival.toStringAsFixed(2)} now and '
                                'PHP ${cashOnArrival.toStringAsFixed(2)} on arrival.'
                          : 'Pay securely online. Amount due: '
                                'PHP ${total.toStringAsFixed(2)}.',
                      style: const TextStyle(color: _sportsMuted),
                    ),
                    const Divider(height: 24),
                    _bookingAmountRow('Merchant rate', rate, '/ hour'),
                    _bookingAmountRow('Duration', hours.toDouble(), ' hour(s)'),
                    _bookingAmountRow(
                      'Players',
                      players.toDouble(),
                      players == 1 ? ' player' : ' players',
                    ),
                    _bookingScheduleRow(
                      context,
                      bookingDate,
                      bookingTime,
                      hours,
                    ),
                    _bookingAmountRow('Booking total', total, ''),
                    _bookingAmountRow(
                      payment == 'cash_on_arrival' ? 'Pay now' : 'Amount due',
                      dueNow,
                      '',
                      strong: true,
                    ),
                    if (payment == 'cash_on_arrival')
                      Text(
                        'Cash on Arrival is fixed at 50% of the booking total.',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E7EF)),
                      ),
                      child: const Text(
                        'Cancellation Policy: Free cancellation up to 6 hours before the slot. Proper sports footwear is required.',
                        style: TextStyle(
                          color: _sportsMuted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: availabilityLoading || selectedSlotBooked
                            ? null
                            : () {
                                _submitBooking(
                                  modalContext: modalContext,
                                  venue: venue,
                                  bookingDate: bookingDate,
                                  bookingTime: bookingTime,
                                  hours: hours,
                                  players: players,
                                  payment: payment,
                                );
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: _sportsOrange,
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
                          payment == 'cash_on_arrival'
                              ? 'Continue · PHP ${dueNow.toStringAsFixed(2)}'
                              : 'Pay · PHP ${dueNow.toStringAsFixed(2)}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _modalIconButton(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFF1F3F7),
          foregroundColor: _sportsInk,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        icon: Icon(icon, size: 19),
      ),
    );
  }

  InputDecoration _bookingInputDecoration({
    required Icon prefixIcon,
    required String labelText,
  }) {
    return InputDecoration(
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

  ButtonStyle _bookingChoiceStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: _sportsInk,
      backgroundColor: Colors.white,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      side: const BorderSide(color: Color(0xFFE2E7EF), width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    );
  }

  String _bookingDateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  bool _bookingSlotOverlaps(
    TimeOfDay selectedTime,
    int durationHours,
    List<Map<String, dynamic>> bookings,
  ) {
    final selectedStart = selectedTime.hour * 60 + selectedTime.minute;
    final selectedEnd = selectedStart + durationHours * 60;
    for (final booking in bookings) {
      final rawStart = '${booking['startTime'] ?? ''}';
      final parts = rawStart.split(':');
      if (parts.length < 2) continue;
      final startHour = int.tryParse(parts[0]);
      final startMinute = int.tryParse(parts[1]);
      final duration = double.tryParse('${booking['durationHours']}');
      if (startHour == null || startMinute == null || duration == null) {
        continue;
      }
      final bookedStart = startHour * 60 + startMinute;
      final bookedEnd = bookedStart + (duration * 60).round();
      if (selectedStart < bookedEnd && selectedEnd > bookedStart) return true;
    }
    return false;
  }

  String _occupiedBookingLabel(Map<String, dynamic> booking) {
    final rawStart = '${booking['startTime'] ?? ''}';
    final parts = rawStart.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final duration = double.tryParse('${booking['durationHours']}') ?? 0;
    if (hour == null || minute == null) return 'Unavailable';
    final start = TimeOfDay(hour: hour, minute: minute);
    final endMinutes = hour * 60 + minute + (duration * 60).round();
    final end = TimeOfDay(
      hour: (endMinutes ~/ 60) % 24,
      minute: endMinutes % 60,
    );
    return '${_formatTime(start)} - ${_formatTime(end)}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  Future<void> _submitBooking({
    required BuildContext modalContext,
    required SportsVenue venue,
    required DateTime bookingDate,
    required TimeOfDay bookingTime,
    required int hours,
    required int players,
    required String payment,
  }) async {
    final session = await AppSession.load();
    final token = session.apiToken;
    if (token == null || token.isEmpty || venue.id <= 0) {
      _showMessage('Please sign in before creating a booking.');
      return;
    }
    final date =
        '${bookingDate.year.toString().padLeft(4, '0')}-'
        '${bookingDate.month.toString().padLeft(2, '0')}-'
        '${bookingDate.day.toString().padLeft(2, '0')}';
    final startTime =
        '${bookingTime.hour.toString().padLeft(2, '0')}:'
        '${bookingTime.minute.toString().padLeft(2, '0')}:00';
    try {
      final onlineProvider = payment == 'online'
          ? await _chooseOnlineProvider()
          : null;
      if (payment == 'online' && onlineProvider == null) return;
      final confirmed = await _confirmBookingDetails(
        venue: venue,
        bookingDate: bookingDate,
        bookingTime: bookingTime,
        hours: hours,
        players: players,
        payment: payment,
        onlineProvider: onlineProvider,
        total: venue.maxPrice * hours,
      );
      if (!confirmed) return;
      final response = await _api.createBooking(
        token: token,
        venueId: venue.id,
        date: date,
        startTime: startTime,
        durationHours: hours.toDouble(),
        players: players,
        paymentMethod: payment,
      );
      if (!mounted || !modalContext.mounted) return;
      Navigator.of(modalContext).pop();
      final booking = response['booking'] as Map<String, dynamic>? ?? {};
      if (payment == 'online') {
        final checkout = await _api.createPayMongoCheckout(
          token: token,
          bookingId: int.tryParse('${booking['id']}') ?? 0,
          paymentMethod: onlineProvider!,
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
        _showMessage('Complete your GCash or PayMaya payment to continue.');
        return;
      }
      final downpayment =
          booking['downpayment'] ?? (venue.maxPrice * hours / 2);
      _showMessage(
        'Booking request sent to ${venue.ownerName}. '
        'Downpayment: PHP $downpayment. Waiting for approval.',
      );
    } on Exception catch (error) {
      _showMessage('Could not submit booking: $error');
    }
  }

  Future<String?> _chooseOnlineProvider() => showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Choose online payment'),
      content: const Text('Select a payment provider to continue securely.'),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.pop(dialogContext, 'gcash'),
          icon: const Icon(Icons.account_balance_wallet_rounded),
          label: const Text('GCash'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, 'paymaya'),
          icon: const Icon(Icons.payments_rounded),
          label: const Text('PayMaya'),
        ),
      ],
    ),
  );

  Future<bool> _confirmBookingDetails({
    required SportsVenue venue,
    required DateTime bookingDate,
    required TimeOfDay bookingTime,
    required int hours,
    required int players,
    required String payment,
    required String? onlineProvider,
    required double total,
  }) async {
    final paymentLabel = payment == 'online'
        ? onlineProvider == 'gcash'
              ? 'Online payment · GCash'
              : 'Online payment · PayMaya'
        : 'Cash on Arrival (COA)';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm booking details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please check that all information is correct before continuing.',
                style: TextStyle(color: _sportsMuted),
              ),
              const SizedBox(height: 16),
              _confirmationRow('Venue', venue.name),
              _confirmationRow('Date', _bookingDateLabel(bookingDate)),
              _confirmationRow('Time', _timeLabel(bookingTime)),
              _confirmationRow(
                'Duration',
                '$hours hour${hours == 1 ? '' : 's'}',
              ),
              _confirmationRow(
                'Players',
                '$players player${players == 1 ? '' : 's'}',
              ),
              _confirmationRow('Payment', paymentLabel),
              _confirmationRow(
                'Booking total',
                'PHP ${total.toStringAsFixed(2)}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Edit details'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm and continue'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Widget _confirmationRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 98,
          child: Text(
            label,
            style: const TextStyle(
              color: _sportsMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: _sportsInk,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );

  String _bookingDateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _timeLabel(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  Widget _bookingAmountRow(
    String label,
    double amount,
    String suffix, {
    bool strong = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: _sportsMuted,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          label == 'Duration'
              ? '${amount.toStringAsFixed(0)}$suffix'
              : 'PHP ${amount.toStringAsFixed(2)}$suffix',
          style: TextStyle(
            color: _sportsInk,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _bookingDetail(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(icon, size: 15, color: _sportsMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text.isEmpty ? 'Not provided' : text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _sportsMuted, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _bookingScheduleRow(
    BuildContext context,
    DateTime date,
    TimeOfDay time,
    int hours,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Schedule',
            style: TextStyle(color: _sportsMuted, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          '${MaterialLocalizations.of(context).formatShortDate(date)} · '
          '${time.format(context)} · $hours hr',
          style: const TextStyle(
            color: _sportsInk,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  double _distanceSquared(
    double latitude,
    double longitude,
    double otherLatitude,
    double otherLongitude,
  ) {
    final latitudeDelta = latitude - otherLatitude;
    final longitudeDelta = longitude - otherLongitude;
    return latitudeDelta * latitudeDelta + longitudeDelta * longitudeDelta;
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(
        color: _sportsMuted,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: .4,
      ),
    ),
  );

  Widget _sectionGap() => const SizedBox(height: 14);

  Widget _dropdown({
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: _sportsLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: _sportsLine),
      ),
    ),
    items: [
      for (final item in values)
        DropdownMenuItem(value: item, child: Text(item)),
    ],
    onChanged: (item) {
      if (item != null) onChanged(item);
    },
  );

  Widget _chips(
    List<String> values,
    String? selected,
    ValueChanged<String> onChanged,
  ) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final value in values)
        FilterChip(
          label: Text(
            value,
            style: TextStyle(
              fontSize: 10,
              color: selected == value ? _sportsOrange : _sportsInk,
              fontWeight: selected == value ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          selected: selected == value,
          showCheckmark: false,
          side: BorderSide(
            color: selected == value ? _sportsOrange : _sportsLine,
          ),
          selectedColor: _sportsSoftOrange,
          checkmarkColor: _sportsOrange,
          onSelected: (_) => onChanged(value),
        ),
    ],
  );

  Widget _amenityChips(List<String> values, [StateSetter? dialogSetState]) =>
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final value in values)
            FilterChip(
              label: Text(
                value,
                style: TextStyle(
                  fontSize: 10,
                  color: _selectedAmenities.contains(value)
                      ? _sportsOrange
                      : _sportsInk,
                  fontWeight: _selectedAmenities.contains(value)
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
              selected: _selectedAmenities.contains(value),
              showCheckmark: false,
              side: BorderSide(
                color: _selectedAmenities.contains(value)
                    ? _sportsOrange
                    : _sportsLine,
              ),
              selectedColor: _sportsSoftOrange,
              checkmarkColor: _sportsOrange,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedAmenities.add(value);
                  } else {
                    _selectedAmenities.remove(value);
                  }
                });
                dialogSetState?.call(() {});
              },
            ),
        ],
      );

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _area = 'All areas';
      _sport = 'All sports';
      _courtType = 'All';
      _availability = 'Any';
      _maxPrice = 700;
      _selectedAmenities.clear();
    });
  }

  Future<void> _useLocation() async {
    setState(() => _locationLoading = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage('Turn on location services to find nearby sports courts.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Location permission is required for nearby courts.');
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _position = position);
        _showMessage('Showing sports courts near your location.');
      }
    } catch (_) {
      _showMessage('Could not read your location.');
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  void _openMap() {
    final center = _position == null
        ? const LatLng(10.285, 123.885)
        : LatLng(_position!.latitude, _position!.longitude);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Sports court map'),
            backgroundColor: _sportsPage,
            foregroundColor: _sportsInk,
          ),
          body: FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 12),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.myapp',
              ),
              MarkerLayer(
                markers: [
                  for (final venue in _allVenues)
                    Marker(
                      point: LatLng(venue.latitude, venue.longitude),
                      width: 100,
                      height: 50,
                      child: _mapPin(venue.name),
                    ),
                  if (_position != null)
                    Marker(
                      point: LatLng(_position!.latitude, _position!.longitude),
                      width: 112,
                      height: 76,
                      child: _userLocationPin(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapPin(String name) => Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: _sportsNavy,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 9),
        ),
      ),
      const Icon(Icons.location_on, color: _sportsNavy),
    ],
  );

  Widget _userLocationPin() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1769E0),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x331769E0),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          'You are here',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0x331769E0),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x661769E0), width: 1),
        ),
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF1769E0),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
        ),
      ),
    ],
  );

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
