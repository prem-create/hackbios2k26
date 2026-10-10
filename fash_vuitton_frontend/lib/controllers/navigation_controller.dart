import 'package:get/get.dart';

class NavigationController extends GetxController {
  final RxInt selectedIndex = 0.obs;

  void selectIndex(int index) {
    if (index < 0 || index > 3) return;
    selectedIndex.value = index;
  }
}
