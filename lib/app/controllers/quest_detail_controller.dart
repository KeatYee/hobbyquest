import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../models/quest_node_model.dart';
import 'home_controller.dart';
import 'progression_controller.dart';
import '../services/quest_service.dart';
import '../services/imgbb_service.dart';
import '../services/gemini_service.dart';
import '../routes/app_routes.dart';
import '../../core/constants/color_constants.dart';

class QuestDetailController extends GetxController {
  final Rx<QuestNodeModel> currentQuest;
  final isSubmitting = false.obs;

  QuestDetailController({required QuestNodeModel initialQuest})
      : currentQuest = Rx<QuestNodeModel>(initialQuest);

  /// Completes the quest using `HomeController.completeQuest` then
  /// awards XP via `ProgressionController.completeQuest`.
  /// Returns true when successful.
  Future<bool> completeQuest(
    String reflectionNote, {
    XFile? imageFile,
  }) async {
    if (currentQuest.value.isCompleted) return true;

    isSubmitting.value = true;
    final questService = QuestService();
    final imageUploadService = ImgBBService();
    final geminiService = GeminiService();
    final progressionController = Get.find<ProgressionController>();
    final homeController = Get.find<HomeController>();
    final questId = currentQuest.value.nodeId;

    try {
      String? imageUrl;
      String? greeting;
      String? observation;
      String? tip;

      if (imageFile != null) {
        final feedbackResult = await geminiService.generateQuestImageFeedback(
          imageFile: imageFile,
          questTitle: currentQuest.value.title,
          questDescription: currentQuest.value.desc,
          questSteps: currentQuest.value.steps.join('\n  - '),
          questType: currentQuest.value.type,
          reflectionNote: reflectionNote,
          hobby: homeController.user.value?.currentPlan.hobby ?? '',
        );

        if (feedbackResult == null) {
          throw Exception('Failed to review image evidence');
        }

        final isApproved = feedbackResult['is_approved'] as bool? ?? false;
        greeting = feedbackResult['greeting'] as String? ?? '';
        observation = feedbackResult['observation'] as String? ?? '';
        tip = feedbackResult['tip'] as String? ?? '';

        await Get.dialog(
          isApproved
              ? AlertDialog(
                  title: const Text('Quest Approved'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (greeting.isNotEmpty) ...[
                        Text(
                          greeting,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (observation.isNotEmpty) ...[
                        Text(observation),
                        const SizedBox(height: 8),
                      ],
                      if (tip.isNotEmpty) Text(tip),
                      if (greeting.isEmpty && observation.isEmpty && tip.isEmpty)
                        const Text('Your submission was approved.'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(result: true),
                      child: const Text('OK'),
                    ),
                  ],
                )
              : AlertDialog(
                  title: const Text(
                    'Oops!',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      if (greeting.isNotEmpty) ...[
                        Text(
                          greeting,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (observation.isNotEmpty) ...[
                        Text(observation),
                        const SizedBox(height: 8),
                      ],
                      if (tip.isNotEmpty) Text(tip),
                      if (greeting.isEmpty && observation.isEmpty && tip.isEmpty)
                        const Text('Retake the photo and make the completed quest easier to see.'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(result: false),
                      child: const Text(
                        'Retake Photo',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
          barrierDismissible: false,
        );

        if (!isApproved) {
          return false;
        }

        imageUrl = await imageUploadService.uploadImage(imageFile.path);
      }

      final updatedUser = await questService.completeQuestTransaction(
        uid: homeController.user.value?.id ?? '',
        questId: questId,
        reflectionNote: reflectionNote,
        imageUrl: imageUrl,
        greeting: greeting,
        observation: observation,
        tip: tip,
      );

      if (updatedUser == null) {
        isSubmitting.value = false;
        return false;
      }

      await progressionController.completeQuest(questId: questId);

      // Refresh local UI state from updated user
      homeController.user.value = updatedUser;
      homeController.dailyQuests.value = _buildVisibleQuestWindow(updatedUser.currentPlan.quests);

      final updated = updatedUser.currentPlan.quests.firstWhere(
        (q) => q.nodeId == questId,
        orElse: () => currentQuest.value,
      );
      currentQuest.value = updated;

      await Future.delayed(const Duration(milliseconds: 300));
      Get.back();

      return true;
    } catch (e) {
      Get.snackbar(
        'Failed to complete quest',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  List<QuestNodeModel> _buildVisibleQuestWindow(List<QuestNodeModel> quests) {
    final normalized = _buildNormalizedQuestGraph(quests);
    final readyQuests = normalized
        .where((quest) => !quest.isCompleted && _isQuestReady(quest, normalized))
        .toList();

    return readyQuests.take(3).toList();
  }

  List<QuestNodeModel> _buildNormalizedQuestGraph(List<QuestNodeModel> quests) {
    final completedIds = quests.where((quest) => quest.isCompleted).map((quest) => quest.nodeId).toSet();

    final visibleIds = _computeVisibleQuestIds(quests, completedIds);

    return quests.map((quest) {
      final shouldBeActive = visibleIds.contains(quest.nodeId) && !quest.isCompleted;
      return quest.copyWith(isActive: shouldBeActive);
    }).toList();
  }

  Set<String> _computeVisibleQuestIds(List<QuestNodeModel> quests, Set<String> completedIds) {
    final visible = <String>{};

    for (final quest in quests) {
      if (quest.isCompleted) continue;

      final isReady = _isQuestReady(quest, quests, completedIds: completedIds);
      if (isReady) visible.add(quest.nodeId);
      if (visible.length == 3) break;
    }

    return visible;
  }

  bool _isQuestReady(QuestNodeModel quest, List<QuestNodeModel> quests, {Set<String>? completedIds}) {
    final completed = completedIds ?? quests.where((item) => item.isCompleted).map((item) => item.nodeId).toSet();

    if (quest.dependsOn.isEmpty) return true;

    return quest.dependsOn.every(completed.contains);
  }
}
