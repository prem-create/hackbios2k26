import 'package:flutter/material.dart';
import '../models/picked_image.dart';

class ImagePickerCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final PickedImage? image;
  final VoidCallback? onTap;

  const ImagePickerCard({
    super.key,
    required this.label,
    required this.icon,
    this.image,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 180,
          child: image != null
              ? (image!.bytes != null
                  ? Image.memory(image!.bytes!, fit: BoxFit.cover)
                  : Image.asset(image!.path, fit: BoxFit.cover))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 8),
                    Text(label, style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
        ),
      ),
    );
  }
}
