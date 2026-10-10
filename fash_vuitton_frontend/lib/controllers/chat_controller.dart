import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/api/api_client.dart';
import '../data/models/chat_models.dart';
import '../data/repositories/chat_repository.dart';
import '../core/theme/app_colors.dart';

class ChatController extends GetxController {
  final ChatRepository _repository;
  final String userId;
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxBool isSending = false.obs;
  final RxBool isReadyForSuggestion = false.obs;
  final RxList<String> missingInformation = <String>[].obs;
  final RxBool showSuggestionPopup = false.obs;
  final RxBool isLoadingHistory = true.obs;

  String? sessionId;
  static const _sessionKeyPrefix = 'chat_session_';

  ChatController({ChatRepository? repository, this.userId = 'test-user-1'})
    : _repository = repository ?? ChatRepository(ApiClient());

  @override
  void onInit() {
    super.onInit();
    _restoreOrStartSession();
  }

  Future<void> _restoreOrStartSession() async {
    final preferences = await SharedPreferences.getInstance();  
    final savedSessionId = preferences.getString(_sessionKeyPrefix + userId);
    try {
      if (savedSessionId != null && savedSessionId.isNotEmpty) {
        final session = await _repository.getSession(savedSessionId, userId);
        sessionId = session.id;
        final history = await _repository.getMessages(session.id, userId);
        messages.assignAll(history);
        isReadyForSuggestion.value =
            session.isReadyForSuggestion ||
            history.any((message) => message.isReadyForSuggestion);
        return;
      }
      await startNewChat();
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        await startNewChat();
      } else {
        _showError(error);
      }
    } catch (error) {
      debugPrint('Chat history error: $error');
      _showError(null);
    } finally {
      isLoadingHistory.value = false;
    }
  }

  Future<void> startNewChat() async {
    try {
      final session = await _repository.createSession(userId);
      sessionId = session.id;
      messages.clear();
      missingInformation.clear();
      isReadyForSuggestion.value = false;
      showSuggestionPopup.value = false;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_sessionKeyPrefix + userId, session.id);
    } on ApiException catch (error) {
      _showError(error);
    } catch (error) {
      debugPrint('New chat error: $error');
      _showError(null);
    }
  }

  Future<void> send(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty || isSending.value || isLoadingHistory.value) return;
    if (sessionId == null) {
      await startNewChat();
      if (sessionId == null) return;
    }

    messages.add(
      ChatMessage(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        role: 'user',
        content: trimmed,
      ),
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionKeyPrefix + userId, sessionId!);
    isSending.value = true;
    try {
      final reply = await _repository.sendMessage(sessionId!, userId, trimmed);
      messages.add(
        ChatMessage(
          id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
          role: 'assistant',
          content: reply.message,
          missingInformation: reply.missingInformation,
          isReadyForSuggestion: reply.isReadyForSuggestion,
        ),
      );
      missingInformation.assignAll(reply.missingInformation);
      isReadyForSuggestion.value = reply.isReadyForSuggestion;
      if (reply.isReadyForSuggestion) {
        showSuggestionPopup.value = true;
      }
    } on ApiException catch (error) {
      _showError(error);
    } catch (error) {
      debugPrint('Chat message error: $error');
      _showError(null);
    } finally {
      isSending.value = false;
    }
  }

  void dismissSuggestionPopup() => showSuggestionPopup.value = false;

  void _showError(ApiException? error) {
    final message = error?.statusCode == 404
        ? 'This chat session is no longer available.'
        : 'The fashion assistant is unavailable right now.';
    Get.snackbar(
      'Could not connect',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.navy,
      colorText: AppColors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 20,
    );
  }
}
