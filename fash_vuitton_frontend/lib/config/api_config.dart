class ApiConfig {
  static const String defaultBaseUrl = 'http://10.0.2.2:8000'; // Default for Android emulator / local testing
  static String baseUrl = defaultBaseUrl;

  static Uri get tryOnUri => Uri.parse('$baseUrl/tryon');
  static Uri get healthUri => Uri.parse('$baseUrl/');
}
