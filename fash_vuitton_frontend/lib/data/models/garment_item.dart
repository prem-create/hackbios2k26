import 'dart:typed_data';
import 'package:flutter/material.dart';

class GarmentItem {
  final String id;
  final String name;
  final String description; // e.g. "Sky · Cotton"
  final Color color;
  final String type; // 'hood', 'jack', 'pant'
  final Color bgColor;
  final Uint8List? imageBytes;
  final String? imagePath;
  bool isFavourite;

  GarmentItem({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.type,
    required this.bgColor,
    this.imageBytes,
    this.imagePath,
    this.isFavourite = false,
  });
}
