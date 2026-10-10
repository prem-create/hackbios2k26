import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../models/garment_item.dart';
import '../../config/api_config.dart';
import '../../core/theme/app_colors.dart';

class WardrobeRepository {
  final ApiClient _apiClient;

  WardrobeRepository(this._apiClient);

  Future<List<GarmentItem>> getItems(String userId) async {
    final json = await _apiClient.getJson(
      ApiConfig.wardrobeItemsUri.replace(queryParameters: {'user_id': userId}),
    );
    final items = json['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => _fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<GarmentItem> createItem({
    required String userId,
    required String name,
    required String category,
    required String description,
    String? imagePath,
  }) async {
    final json = await _retry(
      () => _apiClient.postJson(ApiConfig.wardrobeItemsUri, {
        'user_id': userId,
        'name': name,
        'category': category,
        'description': description,
        if (imagePath != null) 'image_path': imagePath,
      }),
    );
    return _fromJson(json);
  }

  Future<GarmentItem> uploadItem({
    required String userId,
    required String name,
    required String category,
    required String description,
    required String filePath,
  }) async {
    final json = await _retry(
      () => _apiClient.uploadFile(
        ApiConfig.wardrobeUploadUri,
        fields: {
          'user_id': userId,
          'name': name,
          'category': category,
          'description': description,
        },
        filePath: filePath,
      ),
    );
    return _fromJson(json);
  }

  Future<GarmentItem> updateItem(
    String itemId,
    String userId,
    Map<String, String> changes,
  ) async {
    final json = await _apiClient.patchJson(
      ApiConfig.wardrobeItemUri(itemId, userId),
      changes,
    );
    return _fromJson(json);
  }

  Future<void> deleteItem(String itemId, String userId) {
    return _apiClient.delete(ApiConfig.wardrobeItemUri(itemId, userId));
  }

  GarmentItem _fromJson(Map<String, dynamic> json) {
    final category = json['category'] as String? ?? 'item';
    return GarmentItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Wardrobe item',
      description: json['description'] as String? ?? category,
      color: _colorForCategory(category),
      type: category,
      bgColor: AppColors
          .cardBgs[json['id'].hashCode.abs() % AppColors.cardBgs.length],
      imagePath: json['image_path'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }

  Color _colorForCategory(String category) {
    final value = category.toLowerCase();
    if (value.contains('shirt') || value.contains('top')) {
      return const Color(0xFF6FA8FF);
    }
    if (value.contains('trouser') || value.contains('pant')) {
      return const Color(0xFF2FBF8A);
    }
    if (value.contains('shoe')) return AppColors.coral;
    if (value.contains('dress')) return AppColors.pink;
    return AppColors.yellow;
  }

  Future<T> _retry<T>(Future<T> Function() operation) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await operation();
      } catch (error) {
        final shouldRetry = attempt < maxAttempts && _isTransient(error);
        if (!shouldRetry) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    throw StateError('Wardrobe request retry limit reached.');
  }

  bool _isTransient(Object error) {
    if (error is! ApiException) return true;
    return error.statusCode == 408 ||
        error.statusCode == 429 ||
        error.statusCode >= 500;
  }
}
