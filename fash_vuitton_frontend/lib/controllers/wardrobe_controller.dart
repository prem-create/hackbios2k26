import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/garment_item.dart';
import '../../data/api/api_client.dart';
import '../../data/repositories/wardrobe_repository.dart';
import '../../services/local_storage_service.dart';

class WardrobeController extends GetxController {
  final RxList<GarmentItem> clothes = <GarmentItem>[].obs;
  final RxBool isLoading = false.obs;
  final RxSet<String> busyItemIds = <String>{}.obs;
  final WardrobeRepository _repository;
  final String userId;
  final LocalStorageService _localStorage = LocalStorageService();

  WardrobeController({
    WardrobeRepository? repository,
    this.userId = 'test-user-1',
  }) : _repository = repository ?? WardrobeRepository(ApiClient());

  @override
  void onInit() {
    super.onInit();
    loadItems();
  }

  Future<void> loadItems() async {
    isLoading.value = true;
    try {
      clothes.assignAll(await _repository.getItems(userId));
      final favouriteIds = await _localStorage.getFavouriteGarmentIds();
      for (final item in clothes) {
        item.isFavourite = favouriteIds.contains(item.id);
      }
      clothes.refresh();
    } on ApiException catch (error) {
      _showError(error);
    } catch (error) {
      debugPrint('Wardrobe load error: $error');
      _showError(null);
    } finally {
      isLoading.value = false;
    }
  }

  List<GarmentItem> get favouriteClothes =>
      clothes.where((item) => item.isFavourite).toList();

  Future<void> toggleFavourite(GarmentItem item) async {
    item.isFavourite = !item.isFavourite;
    clothes.refresh();
    update();
    try {
      await _localStorage.setFavouriteGarment(item.id, item.isFavourite);
    } catch (error) {
      item.isFavourite = !item.isFavourite;
      clothes.refresh();
      update();
      debugPrint('Favourite save error: $error');
      Get.snackbar(
        'Could not save favourite',
        'Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
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

  Future<void> addGarment({
    required String name,
    required String type,
    String? imagePath,
  }) async {
    final itemName = name.trim();
    if (itemName.isEmpty) return;
    try {
      final item = imagePath != null
          ? await _repository.uploadItem(
              userId: userId,
              name: itemName,
              category: type,
              description: '$itemName ($type)',
              filePath: imagePath,
            )
          : await _repository.createItem(
              userId: userId,
              name: itemName,
              category: type,
              description: '$itemName ($type)',
            );
      clothes.add(item);
      Get.snackbar(
        'New Collection Added',
        '${item.name} added to your wardrobe.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.yellow,
        colorText: AppColors.navy,
        margin: const EdgeInsets.all(16),
        borderRadius: 20,
      );
    } on ApiException catch (error) {
      _showError(error);
      rethrow;
    } catch (error) {
      debugPrint('Wardrobe add error: $error');
      _showError(null);
      rethrow;
    }
  }

  Future<void> removeGarment(String id) async {
    if (busyItemIds.contains(id)) return;
    busyItemIds.add(id);
    try {
      await _repository.deleteItem(id, userId);
      clothes.removeWhere((item) => item.id == id);
      Get.snackbar(
        'Removed',
        'Item removed from your wardrobe.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.coral,
        colorText: AppColors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 20,
      );
    } on ApiException catch (error) {
      _showError(error);
      await loadItems();
    } catch (error) {
      debugPrint('Wardrobe delete error: $error');
      _showError(null);
      await loadItems();
    } finally {
      busyItemIds.remove(id);
    }
  }

  void _showError(ApiException? error) {
    final message = error?.statusCode == 413
        ? 'That image is larger than 10 MB.'
        : error?.statusCode == 415
        ? 'Please choose a JPEG, PNG, or WebP image.'
        : 'The wardrobe could not be updated right now.';
    Get.snackbar(
      'Wardrobe error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.navy,
      colorText: AppColors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 20,
    );
  }
}
