import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/wardrobe_controller.dart';
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
    final text = _thoughtController.text.trim();
    if (text.isEmpty) return;
    Get.snackbar(
      'Processing',
      'Processing: "$text"',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.navy,
      colorText: AppColors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 20,
    );
    _thoughtController.clear();
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
                const CustomAppBar(
                  title: 'Dressup Buddy',
                ),

                // Scrollable Content Body
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Greeting Card connected to UserController
                        Obx(() => GreetingCard(
                              userName: userController.userName.value,
                              greetingText: 'Greetings! How do you want to dress today?',
                              temperatureText: '✳ 24°C',
                              tagText: 'Casual day',
                            )),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Bottom Input Bar
                BottomInputBar(
                  controller: _thoughtController,
                  hintText: 'Type your thought...',
                  onSend: _handleSend,
                  onSubmitted: (_) => _handleSend(),
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
