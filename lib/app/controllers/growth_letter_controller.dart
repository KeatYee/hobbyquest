import 'package:get/get.dart';

import '../../core/utils/dialog_utils.dart';
import 'home_controller.dart';
import '../models/growth_letter_model.dart';
import '../models/user_model.dart';
import '../services/growth_letter_service.dart';

class GrowthLetterController extends GetxController {
  GrowthLetterController({required this.user});

  final UserModel user;
  final GrowthLetterService _service = GrowthLetterService();

  final isLoading = true.obs;
  final isGenerating = false.obs;
  final letter = Rxn<GrowthLetterModel>();

  @override
  void onInit() {
    super.onInit();
    loadOrWriteLetter();
  }

  Future<void> loadOrWriteLetter() async {
    try {
      isLoading.value = true;
      final loadedLetter = await _service.generateWeeklyGrowthLetter(user: user);
      letter.value = loadedLetter;
      await _markCurrentLetterRead(loadedLetter);
    } catch (e) {
      AppDialogs.error('Growth Letter', 'Failed to load growth letter: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> writeLetter() async {
    if (isGenerating.value) return;

    try {
      isGenerating.value = true;
      final generated = await _service.generateWeeklyGrowthLetter(
        user: user,
      );

      if (generated == null) {
        _syncDashboardUnread(null);
        AppDialogs.info(
          'Not Enough Growth Yet',
          'Complete a quest, then come back for your letter.',
          durationSeconds: 3,
        );
        return;
      }

      letter.value = generated;
      await _markCurrentLetterRead(generated);
      AppDialogs.success('Growth Letter Ready', 'Your weekly letter is here.');
    } catch (e) {
      AppDialogs.error('Growth Letter', 'Failed to write letter: $e');
    } finally {
      isGenerating.value = false;
    }
  }

  void showDemoLetter() {
    final now = DateTime.now();
    final nickname = user.nickname.trim().isEmpty ? 'Hero' : user.nickname;

    letter.value = GrowthLetterModel(
      id: 'demo',
      uid: user.id,
      planId: user.activePlanId,
      hobby: 'Creativity',
      nickname: nickname,
      letter: 'Dear $nickname,\n\n'
          'This week, your Creativity tree grew through 6 quests. '
          'Your reflections showed that you struggled with shading at first, '
          'but later you started noticing improvement in your line control.\n\n'
          'Your strongest growth this week: you kept going even when the task felt unclear.\n\n'
          'Next week, your path will focus more on guided shading practice.',
      questCount: 6,
      reflectionCount: 4,
      questIds: const ['demo_quest_1', 'demo_quest_2', 'demo_quest_3'],
      periodStart: now.subtract(const Duration(days: 7)),
      periodEnd: now,
      createdAt: now,
    );
  }

  Future<void> _markCurrentLetterRead(GrowthLetterModel? currentLetter) async {
    if (currentLetter == null ||
        currentLetter.id.isEmpty ||
        currentLetter.id == 'demo' ||
        currentLetter.readAt != null) {
      _syncDashboardUnread(null);
      return;
    }

    try {
      await _service.markGrowthLetterRead(
        uid: currentLetter.uid,
        letterId: currentLetter.id,
      );
      _syncDashboardUnread(null);
    } catch (e) {
      print('--- WARNING: Failed to mark growth letter read: $e ---');
      _syncDashboardUnread(currentLetter);
    }
  }

  void _syncDashboardUnread(GrowthLetterModel? unreadLetter) {
    if (!Get.isRegistered<HomeController>()) return;
    Get.find<HomeController>().hasUnreadGrowthLetter.value =
        unreadLetter != null &&
        unreadLetter.id != 'demo' &&
        unreadLetter.readAt == null;
  }
}
