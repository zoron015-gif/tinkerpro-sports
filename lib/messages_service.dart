                              import 'auth_api.dart';

class MessagesService {
  MessagesService({AuthApi? api}) : _api = api ?? AuthApi();

  final AuthApi _api;

  Future<List<Map<String, dynamic>>> fetchConversations(String token) =>
      _api.conversations(token);

  Future<List<Map<String, dynamic>>> fetchContacts(String token) =>
      _api.messageContacts(token);

  Future<Map<String, dynamic>> fetchCurrentUser(String token) =>
      _api.me(token);

  Future<int> openConversation({
    required String token,
    int? recipientId,
    List<int>? participantIds,
    String? title,
    bool group = false,
  }) =>
      _api.openConversation(
        token: token,
        recipientId: recipientId,
        participantIds: participantIds,
        title: title,
        group: group,
      );

  Future<List<Map<String, dynamic>>> fetchMessages({
    required String token,
    required int conversationId,
  }) =>
      _api.conversationMessages(
        token: token,
        conversationId: conversationId,
      );

  Future<void> sendMessage({
    required String token,
    required int conversationId,
    required String body,
    Map<String, dynamic>? attachment,
  }) =>
      _api.sendConversationMessage(
        token: token,
        conversationId: conversationId,
        body: body,
        attachment: attachment,
      );

  Future<void> deleteMessage({
    required String token,
    required int conversationId,
    required int messageId,
  }) =>
      _api.deleteConversationMessage(
        token: token,
        conversationId: conversationId,
        messageId: messageId,
      );

  Future<void> setConversationState({
    required String token,
    required int conversationId,
    bool? archived,
    bool? unread,
  }) =>
      _api.setConversationState(
        token: token,
        conversationId: conversationId,
        archived: archived,
        unread: unread,
      );

  Future<void> deleteConversation({
    required String token,
    required int conversationId,
  }) =>
      _api.deleteConversation(token: token, conversationId: conversationId);

  Future<void> blockUser({required String token, required int userId}) =>
      _api.blockMessageUser(token: token, userId: userId);

  Future<void> unblockUser({required String token, required int userId}) =>
      _api.unblockMessageUser(token: token, userId: userId);
}
