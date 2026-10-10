import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

class LocalTryOnResult {
  final String id;
  final Uint8List bytes;
  final DateTime createdAt;

  const LocalTryOnResult({
    required this.id,
    required this.bytes,
    required this.createdAt,
  });
}

class LocalStorageService {
  static const _tryOnResultsKey = 'local_try_on_results';
  static const _favouriteGarmentsKey = 'favourite_garment_ids';

  Future<void> saveTryOnResult(Uint8List bytes) async {
    if (bytes.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    final entries = _readResultEntries(preferences);
    entries.insert(0, {
      'id': '${DateTime.now().microsecondsSinceEpoch}',
      'image': base64Encode(bytes),
      'created_at': DateTime.now().toIso8601String(),
    });
    await preferences.setString(_tryOnResultsKey, jsonEncode(entries));
  }

  Future<List<LocalTryOnResult>> getTryOnResults() async {
    final preferences = await SharedPreferences.getInstance();
    final entries = _readResultEntries(preferences);
    final results = <LocalTryOnResult>[];
    for (final entry in entries) {
      try {
        final encodedImage = entry['image'];
        final id = entry['id'];
        if (encodedImage is! String || encodedImage.isEmpty || id is! String) {
          continue;
        }
        final createdAtValue = entry['created_at'];
        results.add(
          LocalTryOnResult(
            id: id,
            bytes: base64Decode(encodedImage),
            createdAt:
                DateTime.tryParse(
                  createdAtValue is String ? createdAtValue : '',
                ) ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );
      } on FormatException {
        continue;
      }
    }
    return results;
  }

  Future<Set<String>> getFavouriteGarmentIds() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_favouriteGarmentsKey) ?? []).toSet();
  }

  Future<void> setFavouriteGarment(String garmentId, bool isFavourite) async {
    if (garmentId.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    final ids = await getFavouriteGarmentIds();
    if (isFavourite) {
      ids.add(garmentId);
    } else {
      ids.remove(garmentId);
    }
    await preferences.setStringList(_favouriteGarmentsKey, ids.toList());
  }

  List<Map<String, dynamic>> _readResultEntries(SharedPreferences preferences) {
    final encoded = preferences.getString(_tryOnResultsKey);
    if (encoded == null || encoded.isEmpty) return [];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } on FormatException {
      return [];
    }
  }
}
