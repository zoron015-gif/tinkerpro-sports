// ignore_for_file: unused_field

import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_api.dart';
import 'app_session.dart';
import 'booking_pricing.dart';
import 'saved_items.dart';
import 'sports_slot_configurations.dart';
import 'saved_icons.dart';
import 'messages_dashboard.dart';
import 'reviews.dart';
import 'app_design_system.dart';
import 'app_preferences.dart';

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
  double averageRating,
  int reviewCount,
  int ratingUserCount,
  int includedPlayers,
  double additionalPlayerFee,
  int totalSlots,
  List<Map<String, dynamic>> sportsSlots,
  List<String> tags,
  List<String> rateLabels,
  double latitude,
  double longitude,
  String distanceLabel,
  int heartCount,
  String visitUrl,
  String merchantEmail,
  String merchantPhone,
  String merchantAvatarUrl,
});

Color get _sportsInk => AppColors.ink;
Color get _sportsOrange => AppColors.accent;
Color get _sportsAccentForeground => AppColors.accentForeground;
Color get _sportsMuted => AppColors.muted;

IconData _sportTypeIcon(String sportType) {
  final normalized = sportType.trim().toLowerCase();
  if (normalized.contains('basketball')) {
    return Icons.sports_basketball_rounded;
  }
  if (normalized.contains('volleyball')) {
    return Icons.sports_volleyball_rounded;
  }
  if (normalized.contains('soccer') || normalized.contains('football')) {
    return Icons.sports_soccer_rounded;
  }
  if (normalized.contains('baseball')) return Icons.sports_baseball_rounded;
  if (normalized.contains('tennis') ||
      normalized.contains('badminton') ||
      normalized.contains('pickleball')) {
    return Icons.sports_tennis_rounded;
  }
  return Icons.sports_rounded;
}

class SportsVenueDetailPage extends StatefulWidget {
  const SportsVenueDetailPage({
    super.key,
    required this.venue,
    required this.onReserve,
    this.savedItemType = 'sports',
    this.amenitiesHeading = 'COURT AMENITIES',
    this.isEvent = false,
    this.primaryActionLabel = 'Reserve',
  });

  final SportsVenue venue;
  final VoidCallback onReserve;
  final String savedItemType;
  final String amenitiesHeading;
  final bool isEvent;
  final String primaryActionLabel;

  @override
  State<SportsVenueDetailPage> createState() => _SportsVenueDetailPageState();
}

class _SportsVenueDetailPageState extends State<SportsVenueDetailPage> {
  final _reviewsApi = AuthApi();
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
      ? '${widget.savedItemType}-${venue.id}'
      : (venue.name.trim().isEmpty
            ? '${widget.savedItemType}-venue'
            : '${widget.savedItemType}-${venue.name.trim()}');

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
      final counts = await SavedItemStore.counts(widget.savedItemType);
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
        await SavedItemStore.remove(widget.savedItemType, _saveKey);
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
          type: widget.savedItemType,
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
        SnackBar(
          content: AppText(
            'Could not update saved count: $error',
            localize: true,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final merchantName = widget.venue.ownerName.trim();
    final isSaved = _savedKeys.contains(_saveKey);
    final images = _usableImages(widget.venue);

    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      body: SafeArea(
        top: true,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (images.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  height: MediaQuery.sizeOf(context).height * 0.5,
                  child: ClipRRect(
                    key: const ValueKey('sports-venue-hero-image'),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: <Widget>[
                        PageView.builder(
                          controller: _imageController,
                          itemCount: 100000,
                          onPageChanged: (index) {
                            final count = images.length;
                            setState(
                              () =>
                                  _imageIndex = count == 0 ? 0 : index % count,
                            );
                          },
                          itemBuilder: (_, index) => GestureDetector(
                            onTap: () => _openImageViewer(images, index),
                            child: Image(
                              image: _imageProvider(
                                images[index % images.length],
                              ),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  Container(color: AppColors.surfaceVariant),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 32,
                          left: 14,
                          child: _heroAction(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        Positioned(
                          top: 32,
                          right: 14,
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _toggleSaved,
                                child: Icon(
                                  isSaved
                                      ? savedItemSelectedIcon
                                      : savedItemIcon,
                                  color: isSaved ? _sportsOrange : Colors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 6),
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
                            bottom: 44,
                            child: Container(
                              key: const ValueKey('sports-venue-image-count'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.58),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: AppText(
                                '${_imageIndex + 1}/${images.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                localize: true,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(0, images.isNotEmpty ? -26 : 0),
                child: Container(
                  key: const ValueKey('sports-venue-content-panel'),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 18,
                        offset: Offset(0, -7),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppText(
                                key: const ValueKey('sports-venue-title'),
                                widget.venue.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _sportsInk,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Semantics(
                              label: '${widget.venue.heartCount} venue hearts',
                              child: Row(
                                key: const ValueKey('sports-venue-heart-count'),
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.favorite_rounded,
                                    color: Colors.red.shade600,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  AppText(
                                    '${widget.venue.heartCount}',
                                    style: TextStyle(
                                      color: _sportsInk,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    localize: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: AppText(
                                widget.venue.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _sportsMuted,
                                  fontSize: 13,
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
                                  color: AppColors.successSurface,
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(color: AppColors.success),
                                ),
                                child: AppText(
                                  'OPEN NOW',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  localize: true,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _ratingStars(widget.venue.averageRating),
                            const SizedBox(width: 6),
                            AppText(
                              widget.venue.averageRating == 0
                                  ? 'No ratings yet'
                                  : widget.venue.averageRating.toStringAsFixed(
                                      1,
                                    ),
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            AppText(
                              '  •  ',
                              style: TextStyle(color: AppColors.border),
                              localize: true,
                            ),
                            TextButton(
                              key: const ValueKey('sports-venue-open-reviews'),
                              onPressed: widget.venue.id <= 0
                                  ? null
                                  : _showVenueReviews,
                              style: TextButton.styleFrom(
                                foregroundColor: _sportsAccentForeground,
                                padding: AppSpacing.buttonPadding,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: AppText(
                                '${widget.venue.reviewCount} '
                                '${widget.venue.reviewCount == 1 ? 'review' : 'reviews'} · '
                                '${widget.venue.ratingUserCount} rated',
                                style: TextStyle(
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                  decorationColor: _sportsAccentForeground,
                                  fontWeight: FontWeight.w700,
                                ),
                                localize: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _detailRow(
                          widget.isEvent
                              ? Icons.celebration_outlined
                              : Icons.sports_volleyball_outlined,
                          widget.isEvent
                              ? '${widget.venue.sport.isEmpty ? 'Event venue' : widget.venue.sport}${widget.venue.type.trim().isEmpty ? '' : ' · ${widget.venue.type}'}'
                              : '${widget.venue.sport}${widget.venue.type.trim().isEmpty ? '' : ' · ${widget.venue.type}'}${widget.venue.courts.trim().isEmpty ? '' : ' · ${widget.venue.courts}'}',
                        ),
                        _detailRow(
                          Icons.location_on_outlined,
                          widget.venue.address,
                        ),
                        if (widget.venue.distanceLabel.isNotEmpty)
                          KeyedSubtree(
                            key: const ValueKey('sports-venue-distance'),
                            child: _detailRow(
                              Icons.near_me_outlined,
                              widget.venue.distanceLabel,
                            ),
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
                        if (widget.venue.additionalPlayerFee > 0 &&
                            widget.venue.includedPlayers > 0)
                          _detailRow(
                            Icons.groups_outlined,
                            'Includes ${widget.venue.includedPlayers} players · '
                            '\u{20B1} ${widget.venue.additionalPlayerFee.toStringAsFixed(2)} '
                            'per extra player',
                          ),
                        if (widget.venue.tags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          AppText(
                            widget.amenitiesHeading,
                            style: TextStyle(
                              color: _sportsMuted,
                              fontSize: 11,
                              letterSpacing: .8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: widget.venue.tags
                                .where((tag) => tag.trim().isNotEmpty)
                                .map(
                                  (tag) => DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: AppColors.softOrangeAlt,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _sportsOrange.withValues(
                                          alpha: .25,
                                        ),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      child: AppText(
                                        tag,
                                        style: TextStyle(
                                          color: _sportsInk,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 6),
                        if (widget.venue.priceDay.trim().isNotEmpty)
                          AppText(
                            widget.venue.priceDay,
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Divider(color: AppColors.border, thickness: 1),
                        const SizedBox(height: 6),
                        if (merchantName.isNotEmpty ||
                            widget.venue.merchantEmail.isNotEmpty ||
                            widget.venue.merchantPhone.isNotEmpty) ...[
                          AppText(
                            'Hosted by merchant',
                            style: TextStyle(
                              color: _sportsInk,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                            localize: true,
                          ),
                          const SizedBox(height: 6),
                          AppText(
                            'Verified venue manager • Fast responding',
                            style: TextStyle(
                              color: _sportsMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            localize: true,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: AppGradients.warmSurface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: AppColors.softSurface,
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
                                          ? Icon(
                                              Icons.person,
                                              color: _sportsMuted,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: AppText(
                                        merchantName,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _sportsInk,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    OutlinedButton(
                                      onPressed: () =>
                                          _contactMerchant(widget.venue),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(52, 34),
                                        padding: AppSpacing.buttonPadding,
                                        side: BorderSide(
                                          color: AppColors.border,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            9,
                                          ),
                                        ),
                                      ),
                                      child: AppText(
                                        'Chat',
                                        style: TextStyle(
                                          color: _sportsInk,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        localize: true,
                                      ),
                                    ),
                                  ],
                                ),
                                if (widget.venue.merchantEmail.isNotEmpty ||
                                    widget.venue.merchantPhone.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Divider(height: 1, color: AppColors.border),
                                  const SizedBox(height: 6),
                                  if (widget.venue.merchantPhone.isNotEmpty)
                                    _contactChip(
                                      Icons.phone_outlined,
                                      widget.venue.merchantPhone,
                                    ),
                                  if (widget.venue.merchantEmail.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
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
                        const SizedBox(height: 6),
                        if (widget.venue.rateLabels.isNotEmpty) ...[
                          AppText(
                            'Rates',
                            style: TextStyle(
                              color: _sportsInk,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                            localize: true,
                          ),
                          const SizedBox(height: 6),
                          for (final rate in widget.venue.rateLabels)
                            _detailRow(Icons.payments_outlined, rate),
                          const SizedBox(height: 6),
                        ],
                        if (widget.venue.details.trim().isNotEmpty)
                          KeyedSubtree(
                            key: const ValueKey('sports-venue-description'),
                            child: _detailRow(
                              Icons.notes_outlined,
                              widget.venue.details,
                            ),
                          ),
                        const SizedBox(height: 6),
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
                                        content: AppText(
                                          'Could not open venue link.',
                                          localize: true,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const AppText(
                                'Visit venue website',
                                localize: true,
                              ),
                            ),
                          ),
                      ],
                    ),
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
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(20),
            border: Border(top: BorderSide(color: AppColors.border)),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: AppText(
                        widget.venue.priceDay,
                        maxLines: 1,
                        style: TextStyle(
                          color: _sportsInk,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (widget.venue.additionalPlayerFee > 0 &&
                        widget.venue.includedPlayers > 0)
                      AppText(
                        '${widget.venue.includedPlayers} included · '
                        '\u{20B1} ${widget.venue.additionalPlayerFee.toStringAsFixed(2)} '
                        'per extra player',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                        localize: true,
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 132,
                height: 48,
                child: FilledButton(
                  onPressed: widget.onReserve,
                  style: FilledButton.styleFrom(
                    backgroundColor: _sportsOrange,
                    foregroundColor: AppColors.onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: AppText(
                    widget.primaryActionLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
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
        padding: AppSpacing.buttonPadding,
        icon: Icon(icon, size: 18, color: _sportsInk),
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
      ..showSnackBar(SnackBar(content: AppText(message)));
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

  Widget _ratingStars(double rating) {
    final value = rating.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            value >= star
                ? Icons.star_rounded
                : value >= star - .5
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            color: AppColors.warning,
            size: 16,
          ),
      ],
    );
  }

  Future<void> _showVenueReviews() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ReviewsSheet(
      api: _reviewsApi,
      businessId: widget.venue.id,
      businessName: widget.venue.name,
    ),
  );

  Widget _detailRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: AppColors.muted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: AppText(
            text,
            style: TextStyle(
              color: _sportsInk,
              fontSize: 13,
              height: 1.3,
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
      Icon(icon, size: 18, color: AppColors.muted),
      const SizedBox(width: 6),
      Expanded(
        child: AppText(
          value,
          softWrap: true,
          style: TextStyle(
            color: AppColors.muted,
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
          return const AssetImage('assets/court/pickle-court.jpg');
        }
      }
    }
    if (image.startsWith('http')) return NetworkImage(image);
    return const AssetImage('assets/court/pickle-court.jpg');
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
    final includedPlayers =
        int.tryParse('${b['includedPlayers'] ?? b['included_players'] ?? 0}') ??
        0;
    final additionalPlayerFee =
        double.tryParse(
          '${b['additionalPlayerFee'] ?? b['additional_player_fee'] ?? 0}',
        ) ??
        0;
    final rawPeriods = b['ratePeriods'] ?? b['rate_periods'];
    final periods = rawPeriods is List
        ? rawPeriods.whereType<Map>().map((period) {
            final start = period['start'] ?? period['start_time'] ?? '';
            final end = period['end'] ?? period['end_time'] ?? '';
            final amount = period['pricePerHour'] ?? period['price_per_hour'];
            return '$start - $end|\u{20B1} ${double.tryParse('$amount')?.toStringAsFixed(0) ?? amount} / hr';
          }).toList()
        : <String>[];
    final totalSlots =
        int.tryParse('${b['slotCount'] ?? b['slot_count'] ?? 1}') ?? 1;
    final sportsSlots = normalizeSportsSlotConfigurations(
      raw: b['sportsSlots'] ?? b['sports_slots_json'],
      legacySportTypes: '${b['sport'] ?? b['category'] ?? 'Sports'}',
      legacyPrice: price,
      totalSlots: totalSlots,
      includedPlayers: includedPlayers,
      additionalPlayerFee: additionalPlayerFee,
    );
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
    final sportsRateValues = sportsSlots
        .map((sport) => (sport['pricePerHour'] as num).toDouble())
        .where((value) => value > 0)
        .toList();
    final sportRateLabels = sportsSlots.map((sport) {
      final rate = (sport['pricePerHour'] as num).toDouble();
      final rateUnit = sport['fullStudio'] == true
          ? 'whole studio'
          : 'per slot';
      final included = (sport['includedPlayers'] as num).toInt();
      final extraFee = (sport['additionalPlayerFee'] as num).toDouble();
      final playerFee = included > 0 && extraFee > 0
          ? ' · $included included · \u{20B1} ${extraFee.toStringAsFixed(2)} / extra player'
          : '';
      return '${sport['sportType']}: \u{20B1} ${rate.toStringAsFixed(2)} / hr / '
          '$rateUnit$playerFee';
    }).toList();
    final maxPrice = [
      price,
      ...rateValues,
      ...sportsRateValues,
    ].reduce((maximum, value) => value > maximum ? value : maximum);
    final images = _merchantImages(b);
    return (
      id: (b['id'] as num?)?.toInt() ?? 0,
      name: b['name'] as String? ?? 'Business',
      sport: sportsSlots.map((item) => item['sportType']).join(', '),
      address: '${b['address'] ?? ''}',
      ownerName: _ownerName(b),
      type: '${b['facilityType'] ?? b['facility_type'] ?? 'Facility'}',
      courts: '${b['details'] ?? 'Sports facility'}',
      hours: '${b['hours'] ?? b['opening_hours'] ?? 'Open hours'}',
      availability: '${b['availability'] ?? b['availability_status'] ?? ''}',
      details: '${b['details'] ?? ''}',
      image: _merchantImage(b),
      images: images,
      priceDay: '\u{20B1} ${maxPrice.toStringAsFixed(0)} / hr',
      priceNight: '\u{20B1} ${maxPrice.toStringAsFixed(0)} / hr',
      priceLines: sportRateLabels.isNotEmpty
          ? sportRateLabels
          : periods.isEmpty
          ? ['Booking rate|\u{20B1} ${price.toStringAsFixed(0)} / hr']
          : periods,
      maxPrice: maxPrice,
      averageRating:
          double.tryParse(
            '${b['averageRating'] ?? b['average_rating'] ?? 0}',
          ) ??
          0,
      reviewCount:
          int.tryParse('${b['reviewCount'] ?? b['review_count'] ?? 0}') ?? 0,
      ratingUserCount:
          int.tryParse(
            '${b['ratingUserCount'] ?? b['rating_user_count'] ?? 0}',
          ) ??
          0,
      includedPlayers: includedPlayers,
      additionalPlayerFee: additionalPlayerFee,
      totalSlots: totalSlots,
      sportsSlots: sportsSlots,
      tags: tags,
      rateLabels: sportRateLabels.isNotEmpty ? sportRateLabels : periods,
      latitude: 0,
      longitude: 0,
      distanceLabel: '',
      heartCount: 0,
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
    averageRating: 0,
    reviewCount: 0,
    ratingUserCount: 0,
    includedPlayers: 0,
    additionalPlayerFee: 0,
    totalSlots: 1,
    sportsSlots: const [],
    tags: const [],
    rateLabels: const [],
    latitude: 0,
    longitude: 0,
    distanceLabel: '',
    heartCount: 0,
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
    if (venue.sportsSlots.isEmpty ||
        venue.sportsSlots.any(
          (sport) =>
              !((sport['pricePerHour'] as num?)?.toDouble() ?? 0).isFinite ||
              ((sport['pricePerHour'] as num?)?.toDouble() ?? 0) <= 0,
        )) {
      _showMessage('This venue does not have a valid merchant rate.');
      return;
    }
    var selectedSportType = '${venue.sportsSlots.first['sportType']}';
    var selectedSlotNumber = 1;
    var hours = 1;
    var players = 1;
    var payment = 'online';
    DateTime bookingDate = DateTime.now();
    TimeOfDay bookingTime = TimeOfDay.now();
    var occupiedBookings = <Map<String, dynamic>>[];
    var availabilityLoading = true;
    var availabilityNow = DateTime.now();
    final bookingIdempotencyKey = newBookingIdempotencyKey();
    Timer? availabilityTimer;
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
      backgroundColor: AppColors.surface,
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) {
          availabilityTimer ??= Timer.periodic(const Duration(seconds: 30), (
            _,
          ) {
            if (context.mounted) {
              setModalState(() => availabilityNow = DateTime.now());
            }
          });
          final selectedSport = venue.sportsSlots.firstWhere(
            (sport) => sport['sportType'] == selectedSportType,
            orElse: () => venue.sportsSlots.first,
          );
          final rate = (selectedSport['pricePerHour'] as num).toDouble();
          final selectedIncludedPlayers =
              (selectedSport['includedPlayers'] as num).toInt();
          final selectedAdditionalPlayerFee =
              (selectedSport['additionalPlayerFee'] as num).toDouble();
          final selectedSportIsFullStudio = selectedSport['fullStudio'] == true;
          final selectedSportSlotCount = selectedSportIsFullStudio
              ? 1
              : (selectedSport['slotCount'] as num).toInt();
          final extraPlayerCharge = calculateExtraPlayerCharge(
            players: players,
            includedPlayers: selectedIncludedPlayers,
            feePerExtraPlayer: selectedAdditionalPlayerFee,
          );
          final total = rate * hours + extraPlayerCharge;
          final cashOnArrival = double.parse((total * 0.5).toStringAsFixed(2));
          final dueNow = payment == 'cash_on_arrival' ? cashOnArrival : total;
          final selectedSlotBooked = _bookingSlotOverlaps(
            bookingTime,
            hours,
            occupiedBookings,
            slotNumber: selectedSlotNumber,
            fullStudio: selectedSportIsFullStudio,
          );
          final relevantBookings = occupiedBookings.where((booking) {
            return selectedSportIsFullStudio ||
                _bookingUsesSlot(
                  booking,
                  selectedSlotNumber,
                  fullStudio: false,
                );
          }).toList();
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
                        Expanded(
                          child: Column(
                            children: [
                              AppText(
                                'Book Court',
                                style: TextStyle(
                                  color: _sportsInk,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                                localize: true,
                              ),
                              SizedBox(height: 6),
                              AppText(
                                'Step 2 of 2 • Checkout',
                                style: TextStyle(
                                  color: _sportsMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                localize: true,
                              ),
                            ],
                          ),
                        ),
                        _modalIconButton(Icons.help_outline_rounded, () {}),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
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
                                        venue.sport.isEmpty
                                            ? 'VENUE'
                                            : venue.sport.toUpperCase(),
                                        style: TextStyle(
                                          color: _sportsAccentForeground,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: .7,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    AppText(
                                      venue.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _sportsInk,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AppText(
                                '\u{20B1} ${rate.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: _sportsAccentForeground,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                                localize: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
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
                    const SizedBox(height: 6),
                    AppText(
                      'CHOOSE SPORT AND SLOT',
                      style: TextStyle(
                        color: _sportsMuted,
                        fontSize: 11,
                        letterSpacing: .9,
                        fontWeight: FontWeight.w800,
                      ),
                      localize: true,
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSportType,
                      decoration: _bookingInputDecoration(
                        prefixIcon: Icon(_sportTypeIcon(selectedSportType)),
                        labelText: appLanguageText('Sport type', 'Sport type'),
                      ),
                      items: [
                        for (final sport in venue.sportsSlots)
                          DropdownMenuItem(
                            value: '${sport['sportType']}',
                            child: AppText(
                              '${sport['sportType']} · ? '
                              '${(sport['pricePerHour'] as num).toStringAsFixed(2)} / hr',
                              localize: true,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() {
                          selectedSportType = value;
                          selectedSlotNumber = 1;
                        });
                      },
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (
                          var slot = 1;
                          slot <= selectedSportSlotCount;
                          slot++
                        )
                          Builder(
                            builder: (context) {
                              final blocked = _bookingSlotOverlaps(
                                bookingTime,
                                hours,
                                occupiedBookings,
                                slotNumber: slot,
                                fullStudio: selectedSportIsFullStudio,
                              );
                              final selected = selectedSlotNumber == slot;
                              final label = selectedSportIsFullStudio
                                  ? 'Whole studio'
                                  : 'Slot $slot';
                              return ChoiceChip(
                                selected: selected,
                                onSelected: (_) => setModalState(
                                  () => selectedSlotNumber = slot,
                                ),
                                avatar: Icon(
                                  blocked
                                      ? Icons.event_busy_rounded
                                      : Icons.check_circle_outline_rounded,
                                  size: 16,
                                  color: blocked
                                      ? AppColors.errorText
                                      : AppColors.success,
                                ),
                                label: AppText(
                                  '$label · ${blocked ? 'Unavailable' : 'Open'}',
                                  localize: true,
                                ),
                                selectedColor: blocked
                                    ? AppColors.error.withValues(alpha: .14)
                                    : AppColors.successSurface,
                                labelStyle: TextStyle(
                                  color: selected
                                      ? blocked
                                            ? AppColors.errorText
                                            : AppColors.success
                                      : _sportsInk,
                                  fontWeight: FontWeight.w700,
                                ),
                                side: BorderSide(
                                  color: blocked
                                      ? AppColors.errorText.withValues(
                                          alpha: .55,
                                        )
                                      : AppColors.success.withValues(
                                          alpha: .55,
                                        ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AppText(
                      selectedSportIsFullStudio
                          ? 'This sport uses the whole studio; its bookings block every small slot.'
                          : '\u{20B1} ${rate.toStringAsFixed(2)} per slot per hour. '
                                'Different slots can be booked at the same time.',
                      style: TextStyle(color: _sportsMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    AppText(
                      'CHOOSE DATE AND TIME',
                      style: TextStyle(
                        color: _sportsMuted,
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
                            label: AppText(
                              MaterialLocalizations.of(context)
                                  .formatMediumDate(bookingDate),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
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
                            label: AppText(bookingTime.format(context)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AppText(
                      'Please choose a time within the venue’s opening hours (${venue.hours}).',
                      style: TextStyle(color: _sportsMuted, fontSize: 12),
                      localize: true,
                    ),
                    const SizedBox(height: 6),
                    if (availabilityLoading)
                      const LinearProgressIndicator()
                    else if (relevantBookings.isEmpty)
                      AppText(
                        'Selected slot is open for this date.',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        localize: true,
                      )
                    else ...[
                      AppText(
                        'Selected slot schedule',
                        style: TextStyle(
                          color: AppColors.errorText,
                          fontWeight: FontWeight.w800,
                        ),
                        localize: true,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: relevantBookings
                            .map(
                              (booking) => Chip(
                                avatar: Icon(
                                  Icons.event_busy_rounded,
                                  size: 16,
                                  color: AppColors.errorText,
                                ),
                                label: AppText(
                                  _occupiedBookingLabel(
                                    booking,
                                    bookingDate: bookingDate,
                                    now: availabilityNow,
                                  ),
                                ),
                                backgroundColor: AppColors.error.withValues(
                                  alpha: .12,
                                ),
                                side: BorderSide(color: AppColors.errorText),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (selectedSlotBooked) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.errorText),
                        ),
                        child: AppText(
                          'That time is already booked. Please choose another available time.',
                          style: TextStyle(
                            color: AppColors.errorText,
                            fontWeight: FontWeight.w800,
                          ),
                          localize: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    AppText(
                      'BOOKING CONFIGURATION',
                      style: TextStyle(
                        color: _sportsMuted,
                        fontSize: 11,
                        letterSpacing: .9,
                        fontWeight: FontWeight.w800,
                      ),
                      localize: true,
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: hours,
                      decoration: _bookingInputDecoration(
                        prefixIcon: Icon(Icons.schedule_rounded),
                        labelText: appLanguageText('Duration', 'Duration'),
                      ),
                      items: [
                        for (var value = 1; value <= 8; value++)
                          DropdownMenuItem(
                            value: value,
                            child: AppText(
                              value == 1 ? '1 hour' : '$value hours',
                              localize: true,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setModalState(() => hours = value);
                      },
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: players,
                      decoration: _bookingInputDecoration(
                        prefixIcon: Icon(Icons.groups_rounded),
                        labelText: appLanguageText(
                          'Number of players',
                          'Number of players',
                        ),
                      ),
                      items: [
                        for (var value = 1; value <= 30; value++)
                          DropdownMenuItem(
                            value: value,
                            child: AppText(
                              '$value player${value == 1 ? '' : 's'}',
                              localize: true,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => players = value);
                        }
                      },
                    ),
                    if (selectedAdditionalPlayerFee > 0 &&
                        selectedIncludedPlayers > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: AppText(
                          '$selectedIncludedPlayers players included; '
                          'each additional player costs ? '
                          '${selectedAdditionalPlayerFee.toStringAsFixed(2)}.',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          localize: true,
                        ),
                      ),
                    const SizedBox(height: 6),
                    AppText(
                      'PAYMENT METHOD',
                      style: TextStyle(
                        color: _sportsMuted,
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
                              ? _sportsOrange
                              : AppColors.surface,
                        ),
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? AppColors.onAccent
                              : _sportsInk,
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
                      selected: {payment},
                      onSelectionChanged: (selection) {
                        setModalState(() => payment = selection.first);
                      },
                    ),
                    const SizedBox(height: 6),
                    AppText(
                      payment == 'cash_on_arrival'
                          ? 'Pay \u{20B1} ${cashOnArrival.toStringAsFixed(2)} cash as a downpayment at the venue. '
                                'Remaining cash balance: \u{20B1} ${(total - cashOnArrival).toStringAsFixed(2)}.'
                          : 'Pay securely online. Amount due: '
                                '\u{20B1} ${total.toStringAsFixed(2)}.',
                      style: TextStyle(color: _sportsMuted),
                    ),
                    const Divider(height: 24),
                    _bookingAmountRow('Merchant rate', rate, '/ hour'),
                    _bookingAmountRow('Duration', hours.toDouble(), ' hour(s)'),
                    _bookingAmountRow(
                      'Players',
                      players.toDouble(),
                      players == 1 ? ' player' : ' players',
                    ),
                    if (extraPlayerCharge > 0)
                      _bookingAmountRow(
                        'Extra players (${players - selectedIncludedPlayers} × '
                            '\u{20B1} ${selectedAdditionalPlayerFee.toStringAsFixed(2)})',
                        extraPlayerCharge,
                        '',
                      ),
                    _bookingScheduleRow(
                      context,
                      bookingDate,
                      bookingTime,
                      hours,
                    ),
                    _bookingAmountRow('Booking total', total, ''),
                    _bookingAmountRow(
                      payment == 'cash_on_arrival'
                          ? 'Cash downpayment due at venue'
                          : 'Amount due',
                      dueNow,
                      '',
                      strong: true,
                    ),
                    if (payment == 'cash_on_arrival')
                      AppText(
                        'Cash on Arrival is fixed at 50% of the booking total.',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        localize: true,
                      ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: AppText(
                        'Cancellation Policy: Free cancellation up to 6 hours before the slot. Proper sports footwear is required.',
                        style: TextStyle(
                          color: _sportsMuted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                        localize: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: availabilityLoading || selectedSlotBooked
                            ? null
                            : () {
                                _submitBooking(
                                  modalContext: modalContext,
                                  idempotencyKey: bookingIdempotencyKey,
                                  venue: venue,
                                  bookingDate: bookingDate,
                                  bookingTime: bookingTime,
                                  hours: hours,
                                  players: players,
                                  sportType: selectedSportType,
                                  slotNumber: selectedSlotNumber,
                                  total: total,
                                  extraPlayerCharge: extraPlayerCharge,
                                  payment: payment,
                                  onPaymentChanged: (value) =>
                                      setModalState(() => payment = value),
                                );
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: _sportsOrange,
                          foregroundColor: AppColors.onAccent,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 5,
                          shadowColor: _sportsOrange.withValues(alpha: .34),
                        ),
                        icon: const Icon(Icons.lock_outline_rounded),
                        label: AppText(
                          payment == 'cash_on_arrival'
                              ? 'Continue · \u{20B1} ${dueNow.toStringAsFixed(2)}'
                              : 'Pay · \u{20B1} ${dueNow.toStringAsFixed(2)}',
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
    availabilityTimer?.cancel();
  }

  Widget _modalIconButton(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: onPressed,
        padding: AppSpacing.buttonPadding,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surfaceVariant,
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

  ButtonStyle _bookingChoiceStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: _sportsInk,
      backgroundColor: AppColors.surface,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      side: BorderSide(color: AppColors.border, width: 1.5),
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
    List<Map<String, dynamic>> bookings, {
    required int slotNumber,
    required bool fullStudio,
  }) {
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
      if (selectedStart < bookedEnd &&
          selectedEnd > bookedStart &&
          _bookingUsesSlot(booking, slotNumber, fullStudio: fullStudio)) {
        return true;
      }
    }
    return false;
  }

  bool _bookingUsesSlot(
    Map<String, dynamic> booking,
    int slotNumber, {
    required bool fullStudio,
  }) {
    final bookingIsFullStudio =
        booking['occupiesFullStudio'] == true ||
        booking['occupiesFullStudio'] == 1 ||
        booking['occupies_full_studio'] == 1;
    if (fullStudio || bookingIsFullStudio) return true;
    return int.tryParse(
          '${booking['slotNumber'] ?? booking['slot_number'] ?? ''}',
        ) ==
        slotNumber;
  }

  String _occupiedBookingLabel(
    Map<String, dynamic> booking, {
    required DateTime bookingDate,
    required DateTime now,
  }) {
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
    final startDateTime = DateTime(
      bookingDate.year,
      bookingDate.month,
      bookingDate.day,
      hour,
      minute,
    );
    final durationMinutes = (duration * 60).round();
    final endDateTime = startDateTime.add(Duration(minutes: durationMinutes));
    final remaining = endDateTime.difference(now);
    final activeCountdown =
        !now.isBefore(startDateTime) && remaining.inSeconds > 0;
    final slot =
        booking['occupiesFullStudio'] == true ||
            booking['occupiesFullStudio'] == 1 ||
            booking['occupies_full_studio'] == 1
        ? 'Whole studio'
        : 'Slot ${booking['slotNumber'] ?? booking['slot_number'] ?? ''}';
    final sport = '${booking['sportType'] ?? ''}'.trim();
    final countdown = activeCountdown
        ? ' · ${remaining.inHours}h ${remaining.inMinutes % 60}m remaining'
        : '';
    return '${sport.isEmpty ? slot : '$sport · $slot'} · '
        '${_formatTime(start)} - ${_formatTime(end)}$countdown';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  Future<void> _submitBooking({
    required BuildContext modalContext,
    required String idempotencyKey,
    required SportsVenue venue,
    required DateTime bookingDate,
    required TimeOfDay bookingTime,
    required int hours,
    required int players,
    required String sportType,
    required int slotNumber,
    required double total,
    required double extraPlayerCharge,
    required String payment,
    required ValueChanged<String> onPaymentChanged,
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
      if (payment == 'online' && !await _api.payMongoPaymentsEnabled(token)) {
        _showMessage(
          'Online payments are unavailable right now. No booking has been created.',
        );
        return;
      }
      final confirmed = await _confirmBookingDetails(
        venue: venue,
        bookingDate: bookingDate,
        bookingTime: bookingTime,
        hours: hours,
        players: players,
        sportType: sportType,
        slotNumber: slotNumber,
        fullStudio:
            venue.sportsSlots.firstWhere(
              (sport) => sport['sportType'] == sportType,
              orElse: () => venue.sportsSlots.first,
            )['fullStudio'] ==
            true,
        payment: payment,
        onlineProvider: onlineProvider,
        total: total,
        extraPlayerCharge: extraPlayerCharge,
      );
      if (!confirmed) return;
      final response = await _api.createBooking(
        token: token,
        idempotencyKey: idempotencyKey,
        venueId: venue.id,
        date: date,
        startTime: startTime,
        durationHours: hours.toDouble(),
        players: players,
        paymentMethod: payment,
        sportType: sportType,
        slotNumber: slotNumber,
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
        'Cash downpayment due at venue: \u{20B1} $downpayment. Waiting for approval.',
      );
    } on Exception catch (error) {
      _showMessage('Could not submit booking: $error');
    }
  }

  Future<String?> _chooseOnlineProvider() => showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const AppText('Choose online payment', localize: true),
      content: const AppText(
        'Select a payment provider to continue securely.',
        localize: true,
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.pop(dialogContext, 'gcash'),
          icon: const Icon(Icons.account_balance_wallet_rounded),
          label: const AppText('GCash', localize: true),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, 'paymaya'),
          icon: const Icon(Icons.payments_rounded),
          label: const AppText('PayMaya', localize: true),
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
    required String sportType,
    required int slotNumber,
    required bool fullStudio,
    required String payment,
    required String? onlineProvider,
    required double total,
    required double extraPlayerCharge,
  }) async {
    final paymentLabel = payment == 'cash_on_arrival'
        ? 'Cash on Arrival · 50% cash downpayment at venue'
        : payment == 'online'
        ? onlineProvider == 'gcash'
              ? 'Online payment · GCash'
              : 'Online payment · PayMaya'
        : 'Cash on Arrival (COA)';
    final coaDownpayment = double.parse((total * 0.5).toStringAsFixed(2));
    final coaRemaining = total - coaDownpayment;
    final bookingStart = DateTime(
      bookingDate.year,
      bookingDate.month,
      bookingDate.day,
      bookingTime.hour,
      bookingTime.minute,
    );
    final timeUntilBooking = bookingStart.difference(DateTime.now());
    final startsWithin24Hours =
        !timeUntilBooking.isNegative &&
        timeUntilBooking < const Duration(hours: 24);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Confirm booking details', localize: true),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'Please check that all information is correct before continuing.',
                style: TextStyle(color: _sportsMuted),
                localize: true,
              ),
              const SizedBox(height: 6),
              _confirmationRow('Venue', venue.name),
              _confirmationRow('Sport', sportType),
              _confirmationRow(
                'Booked area',
                fullStudio ? 'Whole studio' : 'Slot $slotNumber',
              ),
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
              if (extraPlayerCharge > 0)
                _confirmationRow(
                  'Extra-player fee',
                  '\u{20B1} ${extraPlayerCharge.toStringAsFixed(2)}',
                ),
              _confirmationRow('Payment', paymentLabel),
              _confirmationRow(
                'Booking total',
                '\u{20B1} ${total.toStringAsFixed(2)}',
              ),
              if (payment == 'cash_on_arrival') ...[
                _confirmationRow(
                  'Cash downpayment due at venue',
                  '\u{20B1} ${coaDownpayment.toStringAsFixed(2)}',
                ),
                _confirmationRow(
                  'Remaining cash balance',
                  '\u{20B1} ${coaRemaining.toStringAsFixed(2)}',
                ),
              ],
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Edit details', localize: true),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AppText('Confirm and continue', localize: true),
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
          child: AppText(
            label,
            style: TextStyle(
              color: _sportsMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: AppText(
            value,
            style: TextStyle(
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
          child: AppText(
            label,
            style: TextStyle(
              color: _sportsMuted,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        AppText(
          label == 'Duration'
              ? '${amount.toStringAsFixed(0)}$suffix'
              : '\u{20B1} ${amount.toStringAsFixed(2)}$suffix',
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
          child: AppText(
            text.isEmpty ? 'Not provided' : text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _sportsMuted, fontSize: 12),
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
        Expanded(
          child: AppText(
            'Schedule',
            style: TextStyle(color: _sportsMuted, fontWeight: FontWeight.w600),
            localize: true,
          ),
        ),
        AppText(
          '${MaterialLocalizations.of(context).formatShortDate(date)} · '
          '${time.format(context)} · $hours hr',
          style: TextStyle(color: _sportsInk, fontWeight: FontWeight.w800),
          localize: true,
        ),
      ],
    ),
  );

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: AppText(message)));
  }
}
