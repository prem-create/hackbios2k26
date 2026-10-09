import 'dart:typed_data';
import 'package:flutter/material.dart';

class ResultCard extends StatelessWidget {
  final Uint8List imageBytes;

  const ResultCard({
    super.key,
    required this.imageBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.memory(imageBytes, fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              'Virtual Try-On Result',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
