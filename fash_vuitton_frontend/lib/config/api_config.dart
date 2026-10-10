class ApiConfig {
  static const String defaultBaseUrl = 'http://192.168.6.244:8000';
  static String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultBaseUrl,
  );

  static Uri get tryOnUri => Uri.parse('$baseUrl/tryon');
  static Uri get healthUri => Uri.parse('$baseUrl/');
  static Uri get chatSessionsUri => Uri.parse('$baseUrl/chat/sessions');
  static Uri sessionUri(String sessionId, String userId) =>
      Uri.parse('$baseUrl/chat/sessions/$sessionId?user_id=$userId');
  static Uri messagesUri(String sessionId, String userId) =>
      Uri.parse('$baseUrl/chat/sessions/$sessionId/messages?user_id=$userId');
  static Uri suggestionsUri(String sessionId, String userId) =>
      Uri.parse('$baseUrl/chat/sessions/$sessionId/suggestions?user_id=$userId');
  static Uri get wardrobeItemsUri => Uri.parse('$baseUrl/chat/wardrobe/items');
  static Uri get wardrobeUploadUri =>
      Uri.parse('$baseUrl/chat/wardrobe/items/upload');
  static Uri wardrobeItemUri(String itemId, String userId) =>
      Uri.parse('$baseUrl/chat/wardrobe/items/$itemId?user_id=$userId');
  static Uri userPhotosUri(String userId) =>
      Uri.parse('$baseUrl/users/$userId/photos');
  static Uri userPhotoUri(String userId, String photoId) =>
      Uri.parse('$baseUrl/users/$userId/photos/$photoId');
  static Uri tryOnJobsUri(String userId) =>
      Uri.parse('$baseUrl/users/$userId/tryon-jobs');
  static Uri tryOnJobUri(String userId, String jobId) =>
      Uri.parse('$baseUrl/users/$userId/tryon-jobs/$jobId');
  static Uri tryOnResultsUri(String userId) =>
      Uri.parse('$baseUrl/users/$userId/tryon-results');
}
