import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/chat_models.dart';
import '../../config/api_config.dart';

class ChatRepository {
  final ApiClient _apiClient;

  ChatRepository(this._apiClient);

  Future<ChatSession> createSession(String userId) async {
    final json = await _apiClient.postJson(ApiConfig.chatSessionsUri, {
      'user_id': userId,
    });
    return ChatSession.fromJson(json);
  }

  Future<List<ChatMessage>> getMessages(String sessionId, String userId) async {
    final json = await _apiClient.getJson(
      ApiConfig.messagesUri(sessionId, userId),
    );
    final messages = json['messages'];
    if (messages is! List) return const [];
    return messages
        .whereType<Map>()
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<ChatSession> getSession(String sessionId, String userId) async {
    final json = await _apiClient.getJson(
      ApiConfig.sessionUri(sessionId, userId),
    );
    return ChatSession.fromJson(json);
  }

  Future<ChatReply> sendMessage(
    String sessionId,
    String userId,
    String content,
  ) async {
    final json = await _apiClient
        .postJson(
          ApiConfig.messagesUri(sessionId, userId),
          {'content': content},
        )
        .timeout(
          const Duration(seconds: 90),
          onTimeout: () => throw TimeoutException(
            'The chatbot did not respond within 90 seconds.',
          ),
        );
    debugPrint('Chat backend response: $json');
    return ChatReply.fromJson(json);
  }
}
