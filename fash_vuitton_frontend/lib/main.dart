import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/theme/app_theme.dart';
import 'screens/home_page.dart';

void main() {
  runApp(const DressupBuddyApp());
}

class DressupBuddyApp extends StatelessWidget {
  const DressupBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Dressup Buddy - Virtual Try-On',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomePage(),
    );
  }
}
