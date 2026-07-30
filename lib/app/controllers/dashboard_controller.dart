import 'package:get/get.dart';
import 'progression_controller.dart';

class DashboardController extends GetxController {
  static const int forestTabIndex = 1;

  var tabIndex = 0.obs;
  final ProgressionController progressionController = Get.put(
    ProgressionController(),
  );
  String? _lastAppliedArgumentsKey;

  @override
  void onInit() {
    super.onInit();
  }

  void changeTabIndex(int index) {
    if (tabIndex.value == index) {
      tabIndex.refresh();
      return;
    }

    tabIndex.value = index;
  }

  void applyRouteArguments(dynamic arguments) {
    if (arguments is! Map) return;

    final key = arguments.toString();
    if (key == _lastAppliedArgumentsKey) return;
    _lastAppliedArgumentsKey = key;

    final rawTabIndex = arguments['tabIndex'];
    final parsedTabIndex = rawTabIndex is int
        ? rawTabIndex
        : int.tryParse(rawTabIndex?.toString() ?? '');

    if (parsedTabIndex == null || parsedTabIndex < 0 || parsedTabIndex > 3) {
      return;
    }

    tabIndex.value = parsedTabIndex;
  }
}
