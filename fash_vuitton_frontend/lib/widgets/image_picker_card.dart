import 'package:flutter/material.dart';

import '../../models/picked_image.dart';

/// A tappable box that shows a placeholder, or the chosen image once picked.
class ImagePickerCard extends StatelessWidget {
  const ImagePickerCard({
    super.key,
    required this.label,
    required this.icon,
    required this.image,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final PickedImage? image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: image == null
                  ? Icon(icon, size: 48, color: colors.outline)
                  : Image.memory(
                      image!.bytes,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}
