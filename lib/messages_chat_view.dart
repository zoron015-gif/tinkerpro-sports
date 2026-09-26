import 'dart:convert';

import 'package:flutter/material.dart';

import 'messages_ui.dart';

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
              ? const Center(child: Text('Write the first message.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final mine = asInt(message['senderId']) == currentUserId;
                    final attachment = attachmentValue(message);
                    final body = messageBody(message);
                    final bubble = Card(
                      color: mine ? const Color(0xFFFFE8D2) : Colors.white,
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
                                child: Text(body),
                              ),
                            if (mine &&
                                (message['isSeen'] == true ||
                                    message['isSeen'] == 1 ||
                                    message['isSeen'] == '1'))
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.done_all_rounded,
                                      size: 14,
                                      color: Color(0xFF68748A),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Seen',
                                      style: TextStyle(
                                        color: Color(0xFF68748A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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
            color: const Color(0xFFFFF1E3),
            child: const Text(
              'You blocked this person. Unblock them from chat options to send messages.',
              style: TextStyle(color: Color(0xFF101B33), fontSize: 12),
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
                              backgroundColor: Colors.white,
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
                    tooltip: 'Attach image',
                    onPressed: sending || blocked ? null : onPickImage,
                    icon: const Icon(Icons.image_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: composer,
                      enabled: !blocked,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: const InputDecoration(
                        hintText: 'Write a message...',
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
