import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String detail;

  const ApiException(this.statusCode, this.detail);

  @override
  String toString() => 'API request failed ($statusCode): $detail';
}

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> postJson(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> getJson(Uri uri) async {
    final response = await _client.get(uri);
    return _decode(response);
  }

  Future<Map<String, dynamic>> patchJson(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<void> delete(Uri uri) async {
    final response = await _client.delete(uri);
    if (response.statusCode != 204) {
      _throwApiException(response);
    }
  }

  Future<Map<String, dynamic>> uploadFile(
    Uri uri, {
    required Map<String, String> fields,
    required String filePath,
  }) async {
    final request = http.MultipartRequest('POST', uri)..fields.addAll(fields);
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        filePath,
        contentType: _imageMediaType(filePath),
      ),
    );
    final response = await http.Response.fromStream(await request.send());
    return _decode(response);
  }

  MediaType _imageMediaType(String path) {
    final extension = path.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiException(response);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(500, 'Unexpected backend response.');
    }
    return decoded;
  }

  Never _throwApiException(http.Response response) {
      String detail = 'Unable to reach the fashion assistant.';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['detail'] is String) {
          detail = body['detail'] as String;
        }
      } catch (_) {
        debugPrint('Backend returned status ${response.statusCode}.');
      }
      debugPrint('Backend request failed: ${response.statusCode} $detail');
      throw ApiException(response.statusCode, detail);
  }
}
