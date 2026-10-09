import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/theme/app_colors.dart';
import '../presentation/views/home_view.dart';
import '../presentation/views/wardrobe_view.dart';
import '../presentation/views/favourite_view.dart';

class AppDrawer extends StatelessWidget {
  final String selectedItem;

  const AppDrawer({
    super.key,
    this.selectedItem = 'Dressup Buddy',
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.blue,
      elevation: 16,
      child: Stack(
        children: [
          // Bottom-Left decorative pink circle
          Positioned(
            left: -40,
            bottom: 60,
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                color: AppColors.pink,
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Bottom-Right decorative yellow circle
          Positioned(
            right: -60,
            bottom: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                color: AppColors.yellow,
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Drawer Body Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Header Title
                  const Text(
                    'Neo Wardrobe',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Wardrobe Item
                  _DrawerItem(
                    title: 'Wardrobe',
                    isSelected: selectedItem == 'Wardrobe',
                    onTap: () {
                      Get.back(); // close drawer
                      if (selectedItem != 'Wardrobe') {
                        Get.to(() => const WardrobeView());
                      }
                    },
                  ),

                  // Favourite Item
                  _DrawerItem(
                    title: 'Favourite',
                    isSelected: selectedItem == 'Favourite',
                    onTap: () {
                      Get.back(); // close drawer
                      if (selectedItem != 'Favourite') {
                        Get.to(() => const FavouriteView());
                      }
                    },
                  ),

                  // Dressup Buddy Item
                  _DrawerItem(
                    title: 'Dressup Buddy',
                    isSelected: selectedItem == 'Dressup Buddy',
                    onTap: () {
                      Get.back(); // close drawer
                      if (selectedItem != 'Dressup Buddy') {
                        Get.offAll(() => const HomeView());
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.yellow : AppColors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
