import 'package:image_picker/image_picker.dart';

import '../../models/picked_image.dart';

/// Lets the user choose a photo from the gallery or camera.
class ImageService {
  final ImagePicker _picker = ImagePicker();

  Future<PickedImage?> pick({ImageSource source = ImageSource.gallery}) async {
    final file = await _picker.pickImage(
      source: source,
      // Shrinking the photo makes the upload faster and the backend happier.
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    if (file == null) return null; // user cancelled

    // The backend decides the file type from the extension, so make sure one exists.
    final name = file.name.contains('.') ? file.name : '${file.name}.jpg';

    return PickedImage(name: name, bytes: await file.readAsBytes());
  }
}
