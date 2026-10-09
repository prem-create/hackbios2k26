import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../data/models/garment_item.dart';
import 'jacket_illustration.dart';

class GarmentCard extends StatelessWidget {
  final GarmentItem item;
  final VoidCallback? onTryOn;
  final VoidCallback? onRemove;
  final bool showRemove;

  const GarmentCard({
    super.key,
    required this.item,
    this.onTryOn,
    this.onRemove,
    this.showRemove = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Garment Image Container with Pastel Background
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: item.bgColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(32),
                    ),
                  ),
                  child: Center(
                    child: item.imageBytes != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(32),
                            ),
                            child: Image.memory(
                              item.imageBytes!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const JacketIllustration(size: 130),
                  ),
                ),

                // Fabric/Type Chip Top-Left
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.navy.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      item.description.split('·').last.trim(),
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                // Remove Button Top-Right of left container
                if (showRemove && onRemove != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.navy.withOpacity(0.12),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: AppColors.coral,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Right Content Details & Try On Action
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: const TextStyle(
                          color: AppColors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (onTryOn != null)
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.coral,
                          foregroundColor: AppColors.white,
                          elevation: 2,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: onTryOn,
                        child: const Text(
                          'Try on',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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
