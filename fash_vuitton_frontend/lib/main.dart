import 'package:flutter/material.dart';

import 'screens/tryon_screen.dart';

void main() {
  runApp(const TryOnApp());
}

class TryOnApp extends StatelessWidget {
  const TryOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Try-On',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const TryOnScreen(),
    );
  }
}
