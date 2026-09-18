import 'package:flutter/material.dart';

const _profileInk = Color(0xFF101B33);
const _profileMuted = Color(0xFF68748A);
const _profileOrange = Color(0xFFFF8200);
const _profileLine = Color(0xFFE2E7EF);

class MerchantProfileDashboardPage extends StatelessWidget {
  const MerchantProfileDashboardPage({
    super.key,
    required this.owner,
    required this.profileImage,
    required this.venueCount,
    required this.onEditProfile,
    required this.onLogout,
  });

  final Map<String, dynamic> owner;
  final ImageProvider<Object>? profileImage;
  final int venueCount;
  final VoidCallback onEditProfile;
  final Future<void> Function(BuildContext context) onLogout;

  @override
  Widget build(BuildContext context) {
    final name = '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'
        .trim();
    final email = owner['email'] as String? ?? 'Account email';
    final phone = owner['phone'] as String? ?? 'Phone not provided';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Merchant Profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xFFF7F9FC),
        foregroundColor: _profileInk,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () => onLogout(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _profileCard(name, email, phone),
          const SizedBox(height: 14),
          _performanceCard(),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onEditProfile,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit merchant profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _profileOrange,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard(String name, String email, String phone) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _profileLine),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: const Color(0xFFFFE8D2),
          backgroundImage: profileImage,
          child: profileImage == null
              ? Text(
                  _initials(name),
                  style: const TextStyle(
                    color: _profileInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Merchant account owner' : name,
                style: const TextStyle(
                  color: _profileInk,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _profileMuted),
              ),
              Text(
                phone,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _profileMuted),
              ),
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.verified_rounded, size: 15, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'Verified Host',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _performanceCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _profileLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Performance",
          style: TextStyle(
            color: _profileInk,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _metric('Revenue', '₱0'),
            _metric('Booked Slots', '0'),
            _metric('Active Venues', '$venueCount'),
          ],
        ),
      ],
    ),
  );

  Widget _metric(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _profileMuted, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: _profileInk,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  String _initials(String value) {
    final parts = value.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'M';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
