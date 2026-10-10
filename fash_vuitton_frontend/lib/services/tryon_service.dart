import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/picked_image.dart';

class TryOnException implements Exception {
  final String message;
  const TryOnException(this.message);

  @override
  String toString() => message;
}

class TryOnService {
  final http.Client _client = http.Client();

  Future<List<UserPhoto>> getUserPhotos(String userId) async {
    final response = await _client.get(ApiConfig.userPhotosUri(userId));
    final json = _decodeJson(response);
    return (json['photos'] as List? ?? [])
        .whereType<Map>()
        .map((item) => UserPhoto.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<UserPhoto> saveUserPhoto(String userId, PickedImage image) async {
    final request = http.MultipartRequest(
      'POST',
      ApiConfig.userPhotosUri(userId),
    );
    if (image.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          image.bytes!,
          filename: image.name,
        ),
      );
    } else {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }
    final response = await _client.send(request);
    return UserPhoto.fromJson(
      _decodeJson(await http.Response.fromStream(response)),
    );
  }

  Future<TryOnJob> createJob({
    required String userId,
    required String personPhotoId,
    required String wardrobeItemId,
  }) async {
    final request =
        http.MultipartRequest('POST', ApiConfig.tryOnJobsUri(userId))
          ..fields['person_photo_id'] = personPhotoId
          ..fields['wardrobe_item_id'] = wardrobeItemId;
    final response = await _client.send(request);
    return TryOnJob.fromJson(
      _decodeJson(await http.Response.fromStream(response)),
    );
  }

  Future<TryOnJob> getJob(String userId, String jobId) async {
    final response = await _client.get(ApiConfig.tryOnJobUri(userId, jobId));
    return TryOnJob.fromJson(_decodeJson(response));
  }

  Future<List<TryOnJob>> getJobs(String userId) async {
    final response = await _client.get(ApiConfig.tryOnJobsUri(userId));
    final json = _decodeJson(response);
    return (json['jobs'] as List? ?? [])
        .whereType<Map>()
        .map((item) => TryOnJob.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<TryOnResult>> getResults(String userId) async {
    final response = await _client.get(ApiConfig.tryOnResultsUri(userId));
    final json = _decodeJson(response);
    return (json['results'] as List? ?? [])
        .whereType<Map>()
        .map((item) => TryOnResult.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Uint8List> downloadResult(String url) async {
    return downloadImage(url, errorMessage: 'Could not download the completed try-on image.');
  }

  Future<Uint8List> downloadImage(
    String url, {
    String errorMessage = 'Could not download the image.',
  }) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TryOnException(errorMessage);
    }
    return response.bodyBytes;
  }

  Future<Uint8List> tryOn({
    required PickedImage person,
    required PickedImage garment,
    required String description,
    int denoiseSteps = 30,
    int seed = 42,
  }) async {
    try {
      final request = http.MultipartRequest('POST', ApiConfig.tryOnUri);
      request.files.add(
        person.bytes != null
            ? http.MultipartFile.fromBytes(
                'person_image',
                person.bytes!,
                filename: person.name,
              )
            : await http.MultipartFile.fromPath('person_image', person.path),
      );
      request.files.add(
        garment.bytes != null
            ? http.MultipartFile.fromBytes(
                'garment_image',
                garment.bytes!,
                filename: garment.name,
              )
            : await http.MultipartFile.fromPath('garment_image', garment.path),
      );
      request.fields['garment_description'] = description;
      request.fields['denoise_steps'] = denoiseSteps.toString();
      request.fields['seed'] = seed.toString();

      final response = await http.Response.fromStream(
        await _client.send(request),
      );
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw TryOnException(
          'Backend error (${response.statusCode}): ${response.body}',
        );
      }
      return response.bodyBytes;
    } catch (error) {
      if (error is TryOnException) rethrow;
      throw TryOnException('Connection error: $error');
    }
  }

  Map<String, dynamic> _decodeJson(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TryOnException(
        'Backend error (${response.statusCode}): ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const TryOnException('Unexpected backend response.');
    }
    return decoded;
  }

  void dispose() => _client.close();
}

class UserPhoto {
  final String id;
  final String imageUrl;
  final String filename;

  const UserPhoto({
    required this.id,
    required this.imageUrl,
    required this.filename,
  });

  factory UserPhoto.fromJson(Map<String, dynamic> json) => UserPhoto(
    id: json['id'] as String? ?? '',
    imageUrl: json['image_url'] as String? ?? '',
    filename: json['original_filename'] as String? ?? 'Photo',
  );
}

class TryOnJob {
  final String id;
  final String status;
  final String? error;
  final String? resultUrl;

  const TryOnJob({
    required this.id,
    required this.status,
    this.error,
    this.resultUrl,
  });

  factory TryOnJob.fromJson(Map<String, dynamic> json) {
    final result = json['result'] is Map
        ? Map<String, dynamic>.from(json['result'] as Map)
        : null;
    return TryOnJob(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'queued',
      error: json['error'] as String?,
      resultUrl: result?['image_url'] as String?,
    );
  }
}

class TryOnResult {
  final String id;
  final String imageUrl;

  const TryOnResult({required this.id, required this.imageUrl});

  factory TryOnResult.fromJson(Map<String, dynamic> json) => TryOnResult(
    id: json['id'] as String? ?? '',
    imageUrl: json['image_url'] as String? ?? '',
  );
}
