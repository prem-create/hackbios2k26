import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../controllers/wardrobe_controller.dart';
import '../../controllers/tryon_controller.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/garment_card.dart';
import '../../widgets/app_drawer.dart';
import 'choose_photo_view.dart';

class FavouriteView extends StatelessWidget {
  const FavouriteView({super.key});

  @override
  Widget build(BuildContext context) {
    final WardrobeController wardrobeController = Get.find<WardrobeController>();
    final TryOnController tryOnController = Get.put(TryOnController());

    return Scaffold(
      backgroundColor: AppColors.cream,
      drawer: const AppDrawer(selectedItem: 'Favourite'),
      body: Stack(
        children: [
          // Top-Right decorative mint circle
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Shared drawer app bar
                const CustomAppBar(
                  title: 'Favourite',
                ),

                // Favourites List
                Expanded(
                  child: Obx(() {
                    final favourites = wardrobeController.favouriteClothes;
                    if (favourites.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'Tap ♡ on a generated look to keep it here.',
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
                      itemCount: favourites.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final item = favourites[index];
                        return GarmentCard(
                          item: item,
                          showRemove: false,
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
