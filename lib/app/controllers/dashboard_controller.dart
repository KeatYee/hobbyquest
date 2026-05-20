import 'package:get/get.dart';
import 'progression_controller.dart';

class DashboardController extends GetxController {
  var tabIndex = 0.obs;
  final ProgressionController progressionController = Get.put(ProgressionController());

  void changeTabIndex(int index) {
    tabIndex.value = index;
  }
}