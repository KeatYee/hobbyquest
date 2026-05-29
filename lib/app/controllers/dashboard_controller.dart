import 'package:get/get.dart';
import '../models/quest_node_model.dart';
import 'progression_controller.dart';

class DashboardController extends GetxController {
  static const int maxVisibleQuestSlots = 3;

  var tabIndex = 0.obs;
  final ProgressionController progressionController = Get.put(ProgressionController());

  void changeTabIndex(int index) {
    tabIndex.value = index;
  }

  int getActiveQuestsCount(List<QuestNodeModel> quests) {
    return quests.where((quest) => quest.isActive && !quest.isCompleted).length;
  }

  int getRemainingQuestCount(List<QuestNodeModel> quests) {
    final activeQuestsCount = getActiveQuestsCount(quests);
    final remaining = maxVisibleQuestSlots - activeQuestsCount;
    return remaining <= 0 ? 0 : remaining;
  }
}