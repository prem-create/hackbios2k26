import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/garment_item.dart';
import '../../data/models/picked_image.dart';
import '../../services/image_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/tryon_service.dart';
import 'package:image_picker/image_picker.dart';

class TryOnController extends GetxController {
  final ImageService _imageService = ImageService();
  final LocalStorageService _localStorage = LocalStorageService();
  final TryOnService _tryOnService = TryOnService();

  final Rx<GarmentItem?> selectedGarment = Rx<GarmentItem?>(null);
  final RxInt selectedPhotoIndex = (-1).obs;
  final Rx<PickedImage?> customPersonImage = Rx<PickedImage?>(null);
  final RxList<UserPhoto> savedPhotos = <UserPhoto>[].obs;
  final RxString selectedPhotoId = ''.obs;
  final RxBool isGenerating = false.obs;
  final Rx<Uint8List?> resultImageBytes = Rx<Uint8List?>(null);

  bool get canGenerate =>
      selectedGarment.value != null && selectedPhotoId.value.isNotEmpty;

  void selectGarment(GarmentItem garment) {
    selectedGarment.value = garment;
    selectedPhotoIndex.value = -1;
    customPersonImage.value = null;
    selectedPhotoId.value = '';
    resultImageBytes.value = null;
  }

  void selectPhotoIndex(int index) {
    selectedPhotoIndex.value = index;
    customPersonImage.value = null;
    selectedPhotoId.value = index >= 0 && index < savedPhotos.length
        ? savedPhotos[index].id
        : '';
  }

  Future<void> pickCustomPhoto() async {
    final image = await _imageService.pickImage(ImageSource.gallery);
    if (image != null) {
      try {
        final saved = await _tryOnService.saveUserPhoto('test-user-1', image);
        savedPhotos.insert(0, saved);
        customPersonImage.value = image;
        selectedPhotoIndex.value = 0;
        selectedPhotoId.value = saved.id;
      } on TryOnException catch (error) {
        Get.snackbar('Photo upload failed', error.message);
      }
    }
  }

  Future<void> startTryOn() async {
    final garment = selectedGarment.value;
    if (garment == null || !canGenerate || isGenerating.value) return;

    resultImageBytes.value = null;
    isGenerating.value = true;

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
      final person = await _personImage();
      final garmentImage = await _garmentImage(garment);
      final image = await _tryOnService.tryOn(
        person: person,
        garment: garmentImage,
        description: garment.description,
      );

      resultImageBytes.value = image;
      try {
        await _localStorage.saveTryOnResult(image);
      } catch (error) {
        debugPrint('Local try-on result save error: $error');
      }
      Get.snackbar(
        'Try-on ready',
        'Your generated look is ready to view.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.blue,
        colorText: AppColors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 20,
        duration: const Duration(seconds: 5),
      );
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
        'Try-on unavailable',
        'The try-on service could not be reached. Please try again.',
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

  Future<PickedImage> _personImage() async {
    if (customPersonImage.value != null) return customPersonImage.value!;
    final index = selectedPhotoIndex.value;
    if (index < 0 || index >= savedPhotos.length) {
      throw const TryOnException(
        'Please select or upload a person photo before starting the AI try-on.',
      );
    }
    final photo = savedPhotos[index];
    if (photo.imageUrl.isEmpty) {
      throw const TryOnException('The selected person photo has no image URL.');
    }
    return PickedImage(
      path: photo.imageUrl,
      name: photo.filename,
      bytes: await _tryOnService.downloadImage(
        photo.imageUrl,
        errorMessage: 'Could not download the selected person photo.',
      ),
    );
  }

  Future<PickedImage> _garmentImage(GarmentItem garment) async {
    if (garment.imageBytes != null) {
      return PickedImage(
        path: garment.imagePath ?? garment.name,
        name: garment.name,
        bytes: garment.imageBytes,
      );
    }
    if (garment.imageUrl != null && garment.imageUrl!.isNotEmpty) {
      return PickedImage(
        path: garment.imageUrl!,
        name: garment.name,
        bytes: await _tryOnService.downloadImage(
          garment.imageUrl!,
          errorMessage: 'Could not download the selected garment image.',
        ),
      );
    }
    if (garment.imagePath != null && garment.imagePath!.isNotEmpty) {
      return PickedImage(path: garment.imagePath!, name: garment.name);
    }
    throw const TryOnException(
      'The selected garment does not have an image to use for try-on.',
    );
  }

  @override
  void onInit() {
    super.onInit();
    loadSavedPhotos();
  }

  Future<void> loadSavedPhotos() async {
    try {
      savedPhotos.assignAll(await _tryOnService.getUserPhotos('test-user-1'));
    } catch (error) {
      debugPrint('Saved photo load error: $error');
    }
  }

  @override
  void onClose() {
    _tryOnService.dispose();
    super.onClose();
  }
}
