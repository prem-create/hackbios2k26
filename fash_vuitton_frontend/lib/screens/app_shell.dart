import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/navigation_controller.dart';
import '../presentation/views/favourite_view.dart';
import '../presentation/views/home_view.dart';
import '../presentation/views/previously_tried_on_view.dart';
import '../presentation/views/wardrobe_view.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NavigationController());
    const pages = [
      HomeView(),
      WardrobeView(),
      FavouriteView(),
      PreviouslyTriedOnView(),
    ];

    return Obx(
      () => IndexedStack(
        index: controller.selectedIndex.value,
        children: pages,
      ),
    );
  }
}
