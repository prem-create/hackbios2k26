import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Displays the generated try-on image.
class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Result', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(imageBytes, width: double.infinity),
        ),
      ],
    );
  }
}
