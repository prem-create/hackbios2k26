import 'package:get/get.dart';

class UserController extends GetxController {
  final RxString userName = 'there'.obs;
  final RxBool hasPromptedName = false.obs;

  void setUserName(String name) {
    if (name.trim().isNotEmpty) {
      userName.value = name.trim();
    }
    hasPromptedName.value = true;
  }
}
