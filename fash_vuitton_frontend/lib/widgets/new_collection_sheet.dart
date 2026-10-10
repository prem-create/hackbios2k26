import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import '../core/theme/app_colors.dart';
import '../controllers/wardrobe_controller.dart';
import '../data/models/picked_image.dart';
import '../services/image_service.dart';

class NewCollectionSheet extends StatefulWidget {
  const NewCollectionSheet({super.key});

  @override
  State<NewCollectionSheet> createState() => _NewCollectionSheetState();
}

class _NewCollectionSheetState extends State<NewCollectionSheet> {
  final TextEditingController _nameController = TextEditingController();
  final WardrobeController _wardrobeController = Get.find<WardrobeController>();
  final ImageService _imageService = ImageService();

  PickedImage? _pickedGarmentImage;
  bool _isSubmitting = false;
  String _selectedType = 'hood'; // 'hood', 'jack', 'pant'
  int _selectedColorIndex = 0;

  final List<Map<String, String>> _types = [
    {'id': 'upper', 'name': 'Upper'},
    {'id': 'lower', 'name': 'Lower'},
    {'id': 'overall', 'name': 'Overall'},
  ];

  final List<Map<String, dynamic>> _colors = [
    {'name': 'Coral', 'color': const Color(0xFFFF5A4F)},
    {'name': 'Sky', 'color': const Color(0xFF6FA8FF)},
    {'name': 'Green', 'color': const Color(0xFF2FBF8A)},
    {'name': 'Yellow', 'color': const Color(0xFFFFB81F)},
    {'name': 'Pink', 'color': const Color(0xFFFF8FB8)},
    {'name': 'Violet', 'color': const Color(0xFF9B7BFF)},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _imageService.pickImage(ImageSource.gallery);
    if (image != null) {
      setState(() => _pickedGarmentImage = image);
    }
  }

  Future<void> _handleAdd() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await _wardrobeController.addGarment(
        name: _nameController.text,
        type: _selectedType,
        imagePath: _pickedGarmentImage?.path,
      );
      if (mounted) Get.back();
    } catch (_) {
      // The controller displays the backend error and keeps the sheet open.
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxHeightConstraint(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New collection',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 18),

            // Garment Image Picker Card
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.yellow, width: 2),
                ),
                child: _pickedGarmentImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _pickedGarmentImage!.bytes != null
                                ? Image.memory(
                                    _pickedGarmentImage!.bytes!,
                                    fit: BoxFit.cover,
                                  )
                                : Image.asset(
                                    _pickedGarmentImage!.path,
                                    fit: BoxFit.cover,
                                  ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.navy,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: AppColors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.add_a_photo_rounded,
                            color: AppColors.coral,
                            size: 36,
                          ),
                          SizedBox(height: 8),
                          Text(
                            '📷 Upload Actual Cloth Photo',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Optional (Used for AI Try-On backend)',
                            style: TextStyle(
                              color: AppColors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 18),

            // Name Input
            TextField(
              controller: _nameController,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: 'Name (e.g. Beach shirt)',
                hintStyle: const TextStyle(
                  color: AppColors.grey,
                  fontWeight: FontWeight.w500,
                ),
                filled: true,
                fillColor: AppColors.cream,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(
                    color: AppColors.yellow,
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(
                    color: AppColors.yellow,
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: AppColors.blue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Type Chips
            const Text(
              'Category',
              style: TextStyle(
                color: AppColors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _types.map((typeObj) {
                final isSelected = typeObj['id'] == _selectedType;
                return ChoiceChip(
                  label: Text(typeObj['name']!),
                  selected: isSelected,
                  selectedColor: AppColors.yellow,
                  backgroundColor: AppColors.cream,
                  labelStyle: TextStyle(
                    color: AppColors.navy,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide.none,
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() => _selectedType = typeObj['id']!);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Color Swatches
            const Text(
              'Color',
              style: TextStyle(
                color: AppColors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_colors.length, (index) {
                final isSelected = index == _selectedColorIndex;
                final color = _colors[index]['color'] as Color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColorIndex = index),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: AppColors.navy, width: 3)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: AppColors.white,
                            size: 18,
                          )
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Submit Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _isSubmitting ? null : _handleAdd,
                child: _isSubmitting
                    ? Lottie.asset(
                        'assets/animation/loadingscreen.json',
                        width: 34,
                        height: 34,
                      )
                    : const Text(
                        'Add to wardrobe',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BoxHeightConstraint extends BoxConstraints {
  const BoxHeightConstraint({required double maxHeight})
    : super(maxHeight: maxHeight);
}
