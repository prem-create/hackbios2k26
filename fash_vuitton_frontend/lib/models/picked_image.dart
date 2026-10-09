import 'dart:typed_data';

/// An image chosen by the user, kept in memory as bytes.
/// Using bytes (not File) makes the same code work on Android, iOS and web.
class PickedImage {
  final String name;
  final Uint8List bytes;

  const PickedImage({required this.name, required this.bytes});
}
