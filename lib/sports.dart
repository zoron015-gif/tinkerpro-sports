// ignore_for_file: unused_field

import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_api.dart';
import 'app_session.dart';
import 'saved_items.dart';
import 'messages_dashboard.dart';

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

const _sportsInk = Color(0xFF101B33);
const _sportsOrange = Color(0xFFFF8200);
const _sportsMuted = Color(0xFF68748A);

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
  Timer? _imageAutoScrollTimer;

  @override
  void initState() {
    super.initState();
    _saveKey = _keyForVenue(widget.venue);
    final imageCount = _usableImages(widget.venue).length;
    _imageController = PageController(
      initialPage: imageCount == 0 ? 0 : 50000 - (50000 % imageCount),
    );
    _startImageAutoScroll(imageCount);
    _loadSavedState();
  }

  @override
  void didUpdateWidget(covariant SportsVenueDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.venue != widget.venue) {
      _saveKey = _keyForVenue(widget.venue);
      _imageAutoScrollTimer?.cancel();
      _imageIndex = 0;
      final imageCount = _usableImages(widget.venue).length;
      if (_imageController.hasClients && imageCount > 0) {
        _imageController.jumpToPage(50000 - (50000 % imageCount));
      }
      _startImageAutoScroll(imageCount);
      _loadSavedState();
    }
  }

  void _startImageAutoScroll(int imageCount) {
    if (imageCount < 2) return;
    _imageAutoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_imageController.hasClients) return;
      _imageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
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
                            return GestureDetector(
                              onTap: () => _openImageViewer(images, index),
                              child: Image(
                                image: _imageProvider(
                                  images[index % images.length],
                                ),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    Container(color: const Color(0xFFE5E7EB)),
                              ),
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
                      const SizedBox(height: 12),
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
                            fontSize: 18,
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

  Future<void> _openImageViewer(List<String> images, int pageIndex) async {
    if (images.isEmpty || !mounted) return;
    final initialIndex = pageIndex % images.length;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) => Material(
        color: Colors.black,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: images.length,
              itemBuilder: (_, index) => Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image(
                    image: _imageProvider(images[index]),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    _imageAutoScrollTimer?.cancel();
    _imageController.dispose();
    super.dispose();
  }
}

class SportsDashboardPage extends StatefulWidget {
  const SportsDashboardPage({super.key, this.onLogout, this.initialVenue});

  final Future<void> Function(BuildContext context)? onLogout;
  final SportsVenue? initialVenue;

  @override
  State<SportsDashboardPage> createState() => _SportsDashboardPageState();
}

class _SportsDashboardPageState extends State<SportsDashboardPage> {
  final _api = AuthApi();
  final List<SportsVenue> _merchantVenues = [];
  List<SportsVenue> get _allVenues => _merchantVenues;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadMerchantBusinesses();
  }

  @override
  void initState() {
    super.initState();
    _loadMerchantBusinesses();
  }

  Future<void> _loadMerchantBusinesses() async {
    try {
      final rows = await AuthApi().customerBusinesses();
      if (!mounted) return;
      final venues = <SportsVenue>[];
      for (final business in rows) {
        final businessType =
            '${business['businessType'] ?? business['business_type'] ?? ''}'
                .trim()
                .toLowerCase();
        if (businessType != 'sports' && businessType != 'sport') continue;
        venues.add(_sportsVenue(business));
      }
      setState(
        () => _merchantVenues
          ..clear()
          ..addAll(venues),
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
      latitude: 0,
      longitude: 0,
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
    super.dispose();
  }

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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
