import 'dart:convert';

import 'package:flutter/material.dart';

const messageBackground = Color(0xFFF7F9FC);
const messageNavy = Color(0xFF192B50);
const messageMuted = Color(0xFF68748A);
const messageOrange = Color(0xFFFF8200);
const messageSoftOrange = Color(0xFFFFE8D2);

String safeString(Object? value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

int? asInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String displayName(Map<String, dynamic> user) {
  final first = safeString(user['firstName']);
  final last = safeString(user['lastName']);
  final name = '$first $last'.trim();
  if (name.isNotEmpty) return name;
  final email = safeString(user['email']);
  if (email.isNotEmpty) return email;
  return 'User';
}

String initials(Map<String, dynamic> user) {
  final name = displayName(user);
  if (name.isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

Map<String, dynamic>? attachmentValue(Map<String, dynamic> message) {
  final raw = message['attachment'];
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return null;
}

String messageBody(Map<String, dynamic> message) => safeString(message['body']);

ImageProvider<Object>? avatarImageProvider(String image) {
  final value = image.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('data:image/')) {
    final separator = value.indexOf(',');
    if (separator <= 0 || separator >= value.length - 1) return null;
    try {
      return MemoryImage(base64Decode(value.substring(separator + 1)));
    } on FormatException {
      return null;
    }
  }
  return NetworkImage(value);
}

class MessagesAvatar extends StatelessWidget {
  const MessagesAvatar(this.user, {super.key, this.radius = 22});

  final Map<String, dynamic> user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final image = safeString(user['avatarUrl']);
    final provider = avatarImageProvider(image);
    return CircleAvatar(
      radius: radius,
      backgroundColor: messageSoftOrange,
      backgroundImage: provider,
      child: image.trim().isEmpty || provider == null
          ? Text(
              initials(user),
              style: const TextStyle(
                color: messageOrange,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}

class MessagesImageAttachment extends StatelessWidget {
  const MessagesImageAttachment(this.rawAttachment, {super.key});

  final dynamic rawAttachment;

  @override
  Widget build(BuildContext context) {
    final attachment = rawAttachment is Map
        ? Map<String, dynamic>.from(rawAttachment)
        : <String, dynamic>{};
    final data = safeString(attachment['data']);
    if (data.isEmpty || !data.startsWith('data:image/')) {
      return const Text('Image unavailable');
    }
    try {
      final encoded = data.contains(',') ? data.split(',').last : data;
      final bytes = base64Decode(encoded);
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(bytes, width: 220, height: 220, fit: BoxFit.cover),
      );
    } on FormatException {
      return const Text('Image unavailable');
    }
  }
}
