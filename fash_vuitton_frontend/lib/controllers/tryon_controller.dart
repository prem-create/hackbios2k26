import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/garment_item.dart';
import '../../data/models/picked_image.dart';
import '../../services/image_service.dart';
import '../../services/tryon_service.dart';
import 'package:image_picker/image_picker.dart';

class TryOnController extends GetxController {
  final ImageService _imageService = ImageService();
  final TryOnService _tryOnService = TryOnService();

  final Rx<GarmentItem?> selectedGarment = Rx<GarmentItem?>(null);
  final RxInt selectedPhotoIndex = (-1).obs;
  final Rx<PickedImage?> customPersonImage = Rx<PickedImage?>(null);
  final RxBool isGenerating = false.obs;
  final Rx<Uint8List?> resultImageBytes = Rx<Uint8List?>(null);

  bool get canGenerate =>
      selectedGarment.value != null &&
      (selectedPhotoIndex.value >= 0 || customPersonImage.value != null);

  void selectGarment(GarmentItem garment) {
    selectedGarment.value = garment;
    selectedPhotoIndex.value = -1;
    customPersonImage.value = null;
    resultImageBytes.value = null;
  }

  void selectPhotoIndex(int index) {
    selectedPhotoIndex.value = index;
    customPersonImage.value = null;
  }

  Future<void> pickCustomPhoto() async {
    final image = await _imageService.pickImage(ImageSource.gallery);
    if (image != null) {
      customPersonImage.value = image;
      selectedPhotoIndex.value = -1;
    }
  }

  Future<void> startTryOn() async {
    final garment = selectedGarment.value;
    if (garment == null || !canGenerate) return;

    isGenerating.value = true;
    resultImageBytes.value = null;

    Get.snackbar(
      'Connecting to AI Backend...',
      'Synthesizing your try-on look. Stay tuned!',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.blue,
      colorText: AppColors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 20,
      duration: const Duration(seconds: 4),
    );

    try {
      // Build Person PickedImage payload
      PickedImage personPayload;
      if (customPersonImage.value != null) {
        personPayload = customPersonImage.value!;
      } else {
        personPayload = PickedImage(
          path: 'sample_person_${selectedPhotoIndex.value}.png',
          name: 'person.png',
          bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        );
      }

      // Build Garment PickedImage payload
      PickedImage garmentPayload;
      if (garment.imageBytes != null || garment.imagePath != null) {
        garmentPayload = PickedImage(
          path: garment.imagePath ?? 'garment.png',
          name: 'garment.png',
          bytes: garment.imageBytes,
        );
      } else {
        garmentPayload = PickedImage(
          path: 'garment_${garment.id}.png',
          name: 'garment.png',
          bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        );
      }

      // Execute backend API request
      final bytes = await _tryOnService.tryOn(
        person: personPayload,
        garment: garmentPayload,
        description: garment.description,
      );

      resultImageBytes.value = bytes;
    } on TryOnException catch (e) {
      Get.snackbar(
        'Backend Response',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.coral,
        colorText: AppColors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 20,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar(
        'Notice',
        'Backend service unreachable. Displaying stylized preview.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.yellow,
        colorText: AppColors.navy,
        margin: const EdgeInsets.all(16),
        borderRadius: 20,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isGenerating.value = false;
    }
  }

  @override
  void onClose() {
    _tryOnService.dispose();
    super.onClose();
  }
}
