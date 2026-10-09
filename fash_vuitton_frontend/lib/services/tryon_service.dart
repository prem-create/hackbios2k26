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

  Future<Uint8List> tryOn({
    required PickedImage person,
    required PickedImage garment,
    required String description,
    int denoiseSteps = 30,
    int seed = 42,
  }) async {
    try {
      final request = http.MultipartRequest('POST', ApiConfig.tryOnUri);

      if (person.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes('person_image', person.bytes!, filename: person.name),
        );
      } else {
        request.files.add(await http.MultipartFile.fromPath('person_image', person.path));
      }

      if (garment.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes('garment_image', garment.bytes!, filename: garment.name),
        );
      } else {
        request.files.add(await http.MultipartFile.fromPath('garment_image', garment.path));
      }

      request.fields['garment_description'] = description;
      request.fields['denoise_steps'] = denoiseSteps.toString();
      request.fields['seed'] = seed.toString();

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw TryOnException('Backend error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      if (e is TryOnException) rethrow;
      throw TryOnException('Connection error: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
