import 'package:image_picker/image_picker.dart';
import '../models/picked_image.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

  Future<PickedImage?> pickImage(ImageSource source) async {
    final file = await _picker.pickImage(source: source);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return PickedImage(
      path: file.path,
      name: file.name,
      bytes: bytes,
    );
  }
}
