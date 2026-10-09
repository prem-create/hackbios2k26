import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/garment_item.dart';

class WardrobeController extends GetxController {
  final RxList<GarmentItem> clothes = <GarmentItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadDefaultClothes();
  }

  void _loadDefaultClothes() {
    clothes.assignAll([
      GarmentItem(
        id: '1',
        name: 'Light hooded tracksuit',
        description: 'Sky · Cotton',
        color: const Color(0xFF6FA8FF),
        type: 'hood',
        bgColor: AppColors.pastelYellow,
      ),
      GarmentItem(
        id: '2',
        name: 'Neo jacket',
        description: 'Coral · Puffer',
        color: const Color(0xFFFF5A4F),
        type: 'jack',
        bgColor: AppColors.pastelBlue,
      ),
      GarmentItem(
        id: '3',
        name: 'Cargo trousers',
        description: 'Green · Relaxed',
        color: const Color(0xFF2FBF8A),
        type: 'pant',
        bgColor: AppColors.pastelPink,
      ),
      GarmentItem(
        id: '4',
        name: 'Sunny hoodie',
        description: 'Yellow · Fleece',
        color: const Color(0xFFFFB81F),
        type: 'hood',
        bgColor: AppColors.pastelMint,
      ),
    ]);
  }

  List<GarmentItem> get favouriteClothes =>
      clothes.where((item) => item.isFavourite).toList();

  void toggleFavourite(GarmentItem item) {
    item.isFavourite = !item.isFavourite;
    clothes.refresh();
    Get.snackbar(
      item.isFavourite ? 'Added to Favourites' : 'Removed from Favourites',
      '${item.name} is now ${item.isFavourite ? "in" : "removed from"} your favourites.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.yellow,
      colorText: AppColors.navy,
      margin: const EdgeInsets.all(16),
      borderRadius: 20,
      duration: const Duration(seconds: 2),
    );
  }

  void addGarment({
    required String name,
    required String type,
    required Color color,
    required String colorName,
    Uint8List? imageBytes,
    String? imagePath,
  }) {
    final typeName = type == 'hood'
        ? 'Hoodie'
        : (type == 'jack' ? 'Jacket' : 'Trousers');

    final bgColors = AppColors.cardBgs;
    final nextBg = bgColors[clothes.length % bgColors.length];

    final newItem = GarmentItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? '$colorName $typeName' : name.trim(),
      description: '$colorName · $typeName',
      color: color,
      type: type,
      bgColor: nextBg,
      imageBytes: imageBytes,
      imagePath: imagePath,
    );

    clothes.add(newItem);
    Get.snackbar(
      'New Collection Added',
      '${newItem.name} added to your wardrobe.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.yellow,
      colorText: AppColors.navy,
      margin: const EdgeInsets.all(16),
      borderRadius: 20,
      duration: const Duration(seconds: 2),
    );
  }

  void removeGarment(String id) {
    clothes.removeWhere((item) => item.id == id);
    Get.snackbar(
      'Removed',
      'Item removed from your wardrobe.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.coral,
      colorText: AppColors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 20,
      duration: const Duration(seconds: 2),
    );
  }
}
