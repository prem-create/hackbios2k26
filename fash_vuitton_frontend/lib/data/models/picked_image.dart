import 'dart:typed_data';

class PickedImage {
  final String path;
  final String name;
  final Uint8List? bytes;

  const PickedImage({
    required this.path,
    required this.name,
    this.bytes,
  });
}
