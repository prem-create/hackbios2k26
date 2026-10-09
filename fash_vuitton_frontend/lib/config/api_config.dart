import 'package:flutter/foundation.dart';

/// Where the app finds the FastAPI backend.
///
/// You can override the URL without editing code:
///   flutter run --dart-define=API_BASE_URL=http://192.168.6.244:8000
class ApiConfig {
  ApiConfig._();

  // static const String _override = String.fromEnvironment('API_BASE_URL');
  static const String _override = '';

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;

    // Web and iOS simulator reach your computer through localhost.
    if (kIsWeb) return 'http://127.0.0.1:8000';

    // The Android emulator uses 10.0.2.2 to reach your computer.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.137.1:8000/';
    }

    return 'http://127.0.0.1:8000';
  }

  /// Diffusion try-on is slow, so allow plenty of time for a response.
  static const Duration tryOnTimeout = Duration(minutes: 3);
}
