import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../controllers/tryon_controller.dart';
import '../../widgets/jacket_illustration.dart';
import 'result_view.dart';

class ChoosePhotoView extends StatelessWidget {
  const ChoosePhotoView({super.key});

  @override
  Widget build(BuildContext context) {
    final TryOnController tryOnController = Get.find<TryOnController>();

    final List<Color> photoBgs = [
      AppColors.pastelYellow,
      AppColors.pastelPink,
      AppColors.pastelMint,
      AppColors.pastelBlue,
      AppColors.pastelYellow,
      AppColors.pastelPink,
    ];

    return Scaffold(
      backgroundColor: AppColors.blue,
      body: Stack(
        children: [
          // Decorative Top-Right circle
          Positioned(
            top: -70,
            right: -70,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: AppColors.yellow.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header with Back Button
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
                      const SizedBox(width: 16),
                      const Text(
                        'Choose your photo',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),

                        // Click a new photo button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.yellow,
                              foregroundColor: AppColors.navy,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: () => tryOnController.pickCustomPhoto(),
                            icon: const Icon(
                              Icons.camera_alt_rounded,
                              size: 20,
                            ),
                            label: const Text(
                              '📷 Click a new photo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        const Text(
                          'Or use an existing one',
                          style: TextStyle(
                            color: AppColors.lightBlueText,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 3x2 Grid of Sample Models
                        Expanded(
                          child: Obx(
                            () => GridView.builder(
                              physics: const BouncingScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 0.75,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              itemCount: tryOnController.savedPhotos.length,
                              itemBuilder: (context, index) {
                                final isSelected =
                                    tryOnController.selectedPhotoIndex.value ==
                                    index;

                                return GestureDetector(
                                  onTap: () =>
                                      tryOnController.selectPhotoIndex(index),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: photoBgs[index % photoBgs.length],
                                      borderRadius: BorderRadius.circular(24),
                                      border: isSelected
                                          ? Border.all(
                                              color: AppColors.navy,
                                              width: 3.5,
                                            )
                                          : null,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.navy.withOpacity(
                                            0.15,
                                          ),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (tryOnController
                                            .savedPhotos[index]
                                            .imageUrl
                                            .isNotEmpty)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            child: Image.network(
                                              tryOnController
                                                  .savedPhotos[index]
                                                  .imageUrl,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                              errorBuilder: (_, error, stack) =>
                                                  const JacketIllustration(
                                                    size: 80,
                                                  ),
                                            ),
                                          )
                                        else
                                          const JacketIllustration(size: 80),
                                        if (isSelected)
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: const BoxDecoration(
                                                color: AppColors.navy,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.check_rounded,
                                                color: AppColors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // Bottom Generate Action Button
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 20.0,
                            top: 10.0,
                          ),
                          child: Obx(() {
                            final canGen = tryOnController.canGenerate;
                            return SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.coral,
                                  disabledBackgroundColor: AppColors.coral
                                      .withOpacity(0.4),
                                  foregroundColor: AppColors.white,
                                  elevation: canGen ? 4 : 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onPressed: canGen
                                    ? () {
                                        tryOnController.startTryOn();
                                        Get.to(() => const ResultView());
                                      }
                                    : null,
                                child: const Text(
                                  'Generate',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
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
