import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../models/picked_image.dart';

/// A readable error the UI can show directly to the user.
class TryOnException implements Exception {
  final String message;
  const TryOnException(this.message);

  @override
  String toString() => message;
}

/// Talks to the FastAPI backend. Nothing in here touches the UI.
class TryOnService {
  TryOnService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  /// Sends the two images to POST /tryon and returns the result image bytes.
  Future<Uint8List> tryOn({
    required PickedImage person,
    required PickedImage garment,
    String description = 'a piece of clothing',
    bool autoMask = true,
    bool autoCrop = false,
    int denoiseSteps = 30,
    int seed = 42,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/tryon'))
      ..fields['garment_description'] = description
      ..fields['auto_mask'] = autoMask.toString()
      ..fields['auto_crop'] = autoCrop.toString()
      ..fields['denoise_steps'] = denoiseSteps.toString()
      ..fields['seed'] = seed.toString()
      ..files.add(http.MultipartFile.fromBytes(
        'person_image',
        person.bytes,
        filename: person.name,
      ))
      ..files.add(http.MultipartFile.fromBytes(
        'garment_image',
        garment.bytes,
        filename: garment.name,
      ));

    try {
      final streamed =
          await _client.send(request).timeout(ApiConfig.tryOnTimeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      throw TryOnException(_errorMessage(response));
    } on TryOnException {
      rethrow;
    } on TimeoutException {
      throw const TryOnException(
        'The request took too long. The server may be busy, please try again.',
      );
    } catch (_) {
      throw TryOnException('Could not reach the server at $_baseUrl.');
    }
  }

  /// FastAPI errors look like {"detail": "..."}; pull that text out.
  String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] != null) {
        return body['detail'].toString();
      }
    } catch (_) {}
    return 'Server error (${response.statusCode}).';
  }

  void dispose() => _client.close();
}
