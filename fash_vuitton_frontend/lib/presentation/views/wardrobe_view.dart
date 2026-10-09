import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../controllers/wardrobe_controller.dart';
import '../../controllers/tryon_controller.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/garment_card.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/new_collection_sheet.dart';
import 'choose_photo_view.dart';

class WardrobeView extends StatelessWidget {
  const WardrobeView({super.key});

  @override
  Widget build(BuildContext context) {
    final WardrobeController wardrobeController = Get.find<WardrobeController>();
    final TryOnController tryOnController = Get.put(TryOnController());

    return Scaffold(
      backgroundColor: AppColors.cream,
      drawer: const AppDrawer(selectedItem: 'Wardrobe'),
      body: Stack(
        children: [
          // Top-Right decorative pink circle
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                color: AppColors.pink,
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom App Bar with Back Option & Menu Button
                CustomAppBar(
                  title: 'Wardrobe',
                  showBackButton: true,
                  actionWidget: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      Get.bottomSheet(
                        const NewCollectionSheet(),
                        isScrollControlled: true,
                      );
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'New collection',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

                // Clothes List
                Expanded(
                  child: Obx(() {
                    if (wardrobeController.clothes.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'Your wardrobe is empty.\nTap + New collection to add a piece.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.grey,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(18),
                      physics: const BouncingScrollPhysics(),
                      itemCount: wardrobeController.clothes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final item = wardrobeController.clothes[index];
                        return GarmentCard(
                          item: item,
                          onRemove: () => wardrobeController.removeGarment(item.id),
                          onTryOn: () {
                            tryOnController.selectGarment(item);
                            Get.to(() => const ChoosePhotoView());
                          },
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
