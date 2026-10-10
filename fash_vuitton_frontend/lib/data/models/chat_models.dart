class ChatSession {
  final String id;
  final String userId;
  final bool isReadyForSuggestion;

  const ChatSession({
    required this.id,
    required this.userId,
    required this.isReadyForSuggestion,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      isReadyForSuggestion: json['is_ready_for_suggestion'] as bool? ?? false,
    );
  }
}

class ChatMessage {
  final String id;
  final String role;
  final String content;
  final List<String> missingInformation;
  final bool isReadyForSuggestion;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.missingInformation = const [],
    this.isReadyForSuggestion = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : <String, dynamic>{};
    return ChatMessage(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      missingInformation: _stringList(metadata['missing_information']),
      isReadyForSuggestion:
          metadata['is_ready_for_suggestion'] as bool? ?? false,
    );
  }
}

class ChatReply {
  final String message;
  final bool isReadyForSuggestion;
  final List<String> missingInformation;

  const ChatReply({
    required this.message,
    required this.isReadyForSuggestion,
    required this.missingInformation,
  });

  factory ChatReply.fromJson(Map<String, dynamic> json) {
    return ChatReply(
      message: json['message'] as String? ?? '',
      isReadyForSuggestion: json['is_ready_for_suggestion'] as bool? ?? false,
      missingInformation: _stringList(json['missing_information']),
    );
  }
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList();
}
