import 'package:flutter/material.dart';

class MessageUnreadCountScope extends InheritedNotifier<ValueNotifier<int>> {
  const MessageUnreadCountScope({
    super.key,
    required ValueNotifier<int> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static int? countOf(BuildContext context) {
    final count = context
        .dependOnInheritedWidgetOfExactType<MessageUnreadCountScope>()
        ?.notifier
        ?.value;
    return count == null || count < 0 ? null : count;
  }

  static void update(BuildContext context, int count) {
    final notifier = context
        .getInheritedWidgetOfExactType<MessageUnreadCountScope>()
        ?.notifier;
    if (notifier != null) notifier.value = count;
  }
}
