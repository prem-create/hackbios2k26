import 'package:flutter/material.dart';

class AppColors {
  // Main palette
  static const cream = Color(0xFFFFF4D9); // app background
  static const yellow = Color(0xFFFFB81F); // main buttons, highlights
  static const blue = Color(0xFF3F6DF2); // greeting card, photo/result screens, drawer
  static const coral = Color(0xFFFF4D57); // Try on, Send, Generate, Remove, Like
  static const pink = Color(0xFFFF9EC0); // decorative circles
  static const mint = Color(0xFF7FE0B4); // decorative circles
  static const navy = Color(0xFF1B1F3B); // text, icons
  static const grey = Color(0xFF6B6F8F); // secondary text
  static const white = Color(0xFFFFFFFF); // cards, chips, input bar
  static const lightBlueText = Color(0xFFDFE7FF);

  // Overlays and shadows
  static const overlay = Color(0x801B1F3B); // 50% navy behind popups
  static const shadow = Color(0x331B1F3B); // 20% navy button shadow

  // Card pastels
  static const pastelYellow = Color(0xFFFFE08A);
  static const pastelBlue = Color(0xFFBFE3FF);
  static const pastelPink = Color(0xFFFFC9DC);
  static const pastelMint = Color(0xFFC8F0D8);
  static const cardBgs = [pastelYellow, pastelBlue, pastelPink, pastelMint];

  // Clothing colours (for the "New collection" picker)
  static const clothingColors = {
    'Coral': Color(0xFFFF5A4F),
    'Sky': Color(0xFF6FA8FF),
    'Green': Color(0xFF2FBF8A),
    'Yellow': Color(0xFFFFB81F),
    'Pink': Color(0xFFFF8FB8),
    'Violet': Color(0xFF9B7BFF),
  };
}
