import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../../core/theme/app_colors.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/wardrobe_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../data/models/chat_models.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/bottom_input_bar.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/greeting_card.dart';
import '../../widgets/name_modal.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final TextEditingController _thoughtController = TextEditingController();

  final UserController userController = Get.put(UserController());
  final WardrobeController wardrobeController = Get.put(WardrobeController());
  final ChatController chatController = Get.put(ChatController());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!userController.hasPromptedName.value) {
        NameModal.show(context);
      }
    });
  }

  @override
  void dispose() {
    _thoughtController.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (chatController.isSending.value) return;
    final text = _thoughtController.text.trim();
    if (text.isEmpty) return;
    chatController.send(text);
    _thoughtController.clear();
  }

  Widget _messageList() {
    return Obx(
      () => Column(
        children: [
          ...chatController.messages
              .map((message) => _ChatMessageBubble(message: message)),
          if (chatController.isSending.value) const _TypingIndicator(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      drawer: const AppDrawer(selectedItem: 'Dressup Buddy'),
      body: Stack(
        children: [
          // Top-right decorative yellow circle background accent
          Positioned(
            top: -70,
            right: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                color: AppColors.yellow,
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                CustomAppBar(
                  title: 'Dressup Buddy',
                  actionWidget: IconButton(
                    tooltip: 'New chat',
                    onPressed: chatController.isSending.value
                        ? null
                        : () => chatController.startNewChat(),
                    icon: const Icon(
                      Icons.add_comment_rounded,
                      color: AppColors.navy,
                    ),
                  ),
                ),

                // Scrollable Content Body
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 12.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Greeting Card connected to UserController
                        Obx(
                          () => GreetingCard(
                            userName: userController.userName.value,
                            greetingText:
                                'Greetings! How do you want to dress today?',
                            temperatureText: '✳ 24°C',
                            tagText: 'Casual day',
                          ),
                        ),
                        Obx(() {
                          if (chatController.isLoadingHistory.value) {
                            return const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.coral,
                                ),
                              ),
                            );
                          }
                          return _messageList();
                        }),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Bottom Input Bar
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Obx(
                      () => BottomInputBar(
                        controller: _thoughtController,
                        hintText: chatController.isSending.value
                            ? 'Waiting for response...'
                            : 'Type your thought...',
                        enabled: !chatController.isSending.value,
                        onSend: _handleSend,
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                    Obx(() {
                      if (!chatController.showSuggestionPopup.value) {
                        return const SizedBox.shrink();
                      }
                      return Positioned(
                        right: 24,
                        bottom: 78,
                        child: GestureDetector(
                          onTap: chatController.dismissSuggestionPopup,
                          child: Material(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(18),
                            elevation: 5,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Text(
                                'Ready to suggest dresses ✨',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),

                // Bottom Edge Accent Strip
                Container(
                  height: 10,
                  width: double.infinity,
                  color: AppColors.yellow,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.coral : AppColors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? AppColors.white : AppColors.navy,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/animation/loadingscreen.json',
              width: 34,
              height: 34,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 6),
            const Text(
              'Typing...',
              style: TextStyle(
                color: AppColors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
