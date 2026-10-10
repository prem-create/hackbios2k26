import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../controllers/tryon_controller.dart';
import '../../controllers/wardrobe_controller.dart';
import '../../widgets/jacket_illustration.dart';

class ResultView extends StatelessWidget {
  const ResultView({super.key});

  @override
  Widget build(BuildContext context) {
    final TryOnController tryOnController = Get.find<TryOnController>();
    final WardrobeController wardrobeController =
        Get.find<WardrobeController>();

    final garment = tryOnController.selectedGarment.value;
    final garmentName = garment?.name ?? 'Try-On Look';

    return Scaffold(
      backgroundColor: AppColors.blue,
      body: Stack(
        children: [
          // Background Decorative Sun Yellow Disk
          Positioned(
            top: MediaQuery.of(context).size.height * 0.2,
            left: MediaQuery.of(context).size.width * 0.15,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                color: AppColors.yellow,
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Pink top right decorative circle
          Positioned(
            top: 60,
            right: 20,
            child: Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: AppColors.pink,
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Mint bottom left decorative circle
          Positioned(
            bottom: 220,
            left: 20,
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Header with Back Option
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.navy,
                          ),
                          onPressed: () => Get.back(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Result Center Graphic View
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ghost Text Watermark (Fixed: removed conflicting color argument)
                      Text(
                        garmentName.split(' ').first.toUpperCase(),
                        style: TextStyle(
                          fontSize: 84,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -3,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 2
                            ..color = AppColors.white.withOpacity(0.35),
                        ),
                      ),

                      // Result Graphic or Image
                      Obx(() {
                        if (tryOnController.resultImageBytes.value != null) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.memory(
                              tryOnController.resultImageBytes.value!,
                              width: 260,
                              fit: BoxFit.cover,
                            ),
                          );
                        }
                        if (tryOnController.isGenerating.value) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 180,
                                height: 180,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 12,
                                  color: AppColors.coral,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Generating your look...',
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Generating your look. You can explore the app '
                                'while it finishes.',
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        }
                        return const JacketIllustration(size: 260);
                      }),

                      // Top Left Chip: ✨ AI look
                      Positioned(
                        left: 20,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.navy.withOpacity(0.12),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Text(
                            '✨ AI look',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                      // Top Right Chip: Fit 96%
                      Positioned(
                        right: 20,
                        bottom: 40,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.navy.withOpacity(0.12),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Text(
                            'Fit 96%',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Actions Panel Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(36),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        garmentName,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.yellow,
                                  foregroundColor: AppColors.navy,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onPressed: () {
                                  Get.snackbar(
                                    'Saved',
                                    'Look saved to your wardrobe.',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: AppColors.yellow,
                                    colorText: AppColors.navy,
                                    margin: const EdgeInsets.all(16),
                                    borderRadius: 20,
                                  );
                                },
                                child: const Text(
                                  'Save',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          GetBuilder<WardrobeController>(
                            builder: (_) {
                              final isFav = garment?.isFavourite ?? false;
                              return GestureDetector(
                                onTap: () {
                                  if (garment != null) {
                                    wardrobeController.toggleFavourite(garment);
                                  }
                                },
                                child: Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: isFav
                                        ? AppColors.coral
                                        : AppColors.cream,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isFav
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: isFav
                                        ? AppColors.white
                                        : AppColors.coral,
                                    size: 26,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
