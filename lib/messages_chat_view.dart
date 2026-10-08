import './app_design_system.dart';

import 'dart:convert';

import 'package:flutter/material.dart';

import 'messages_ui.dart';
import 'app_preferences.dart';

class MessagesChatView extends StatelessWidget {
  const MessagesChatView({
    super.key,
    required this.messages,
    required this.currentUserId,
    required this.blocked,
    required this.composer,
    required this.pendingImageData,
    required this.sending,
    required this.onDeleteMessage,
    required this.onPickImage,
    required this.onRemovePendingImage,
    required this.onSend,
  });

  final List<Map<String, dynamic>> messages;
  final int? currentUserId;
  final bool blocked;
  final TextEditingController composer;
  final String? pendingImageData;
  final bool sending;
  final ValueChanged<Map<String, dynamic>> onDeleteMessage;
  final VoidCallback onPickImage;
  final VoidCallback onRemovePendingImage;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: AppText('Write the first message.', localize: true),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final mine = asInt(message['senderId']) == currentUserId;
                    final attachment = attachmentValue(message);
                    final body = messageBody(message);
                    final attachmentType = safeString(attachment?['type']);
                    if (attachmentType == 'booking' ||
                        attachmentType == 'booking_payment_ticket' ||
                        attachmentType == 'booking_ticket') {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Column(
                          children: [
                            Center(child: MessagesBookingTicket(attachment!)),
                            if (_messageTime(message) case final time?)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  time,
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }
                    final bubble = Card(
                      color: mine ? AppColors.softOrange : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((attachment != null &&
                                safeString(attachment['type']) == 'image'))
                              MessagesImageAttachment(attachment),
                            if (body.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: AppText(body),
                              ),
                            if (_messageTime(message) case final time?)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      time,
                                      style: TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                    if (mine && _isSeen(message['isSeen'])) ...[
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.done_all_rounded,
                                        size: 14,
                                        color: AppColors.muted,
                                      ),
                                      const SizedBox(width: 4),
                                      AppText(
                                        'Seen',
                                        style: TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        localize: true,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: mine
                          ? GestureDetector(
                              onLongPress: () => onDeleteMessage(message),
                              child: bubble,
                            )
                          : bubble,
                    );
                  },
                ),
        ),
        if (blocked)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.softStatus,
            child: AppText(
              'You blocked this person. Unblock them from chat options to send messages.',
              style: TextStyle(color: AppColors.ink, fontSize: 12),
              localize: true,
            ),
          ),
        SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pendingImageData != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(pendingImageData!.split(',').last),
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: onRemovePendingImage,
                            icon: const Icon(Icons.close_rounded),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: messageNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  IconButton(
                    tooltip: appLanguageText('Attach image', 'Attach image'),
                    onPressed: sending || blocked ? null : onPickImage,
                    icon: const Icon(Icons.image_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: composer,
                      enabled: !blocked,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: InputDecoration(
                        hintText: appLanguageText(
                          'Write a message...',
                          'Write a message...',
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: sending || blocked ? null : onSend,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String? _messageTime(Map<String, dynamic> message) {
  final createdAt = DateTime.tryParse('${message['createdAt'] ?? ''}');
  if (createdAt == null) return null;

  final localTime = createdAt.toLocal();
  final hour = localTime.hour % 12 == 0 ? 12 : localTime.hour % 12;
  final minute = localTime.minute.toString().padLeft(2, '0');
  final period = localTime.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

bool _isSeen(dynamic value) => value == true || value == 1 || value == '1';
