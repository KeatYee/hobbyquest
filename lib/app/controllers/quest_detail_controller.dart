import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../models/quest_node_model.dart';
import 'home_controller.dart';
import 'progression_controller.dart';
import '../services/quest_service.dart';
import '../services/imgbb_service.dart';
import '../services/gemini_service.dart';
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
    print('--- DEBUG: completeQuest() called for quest ${currentQuest.value.nodeId} ---');
    
    if (currentQuest.value.isCompleted) {
      print('--- DEBUG: Quest already completed, returning true ---');
      return true;
    }

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

      print('--- DEBUG: imageFile is ${imageFile == null ? 'NULL' : 'NOT NULL'} ---');
      
      if (imageFile != null) {
        print('--- DEBUG: Processing image evidence ---');
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
        print('--- DEBUG: Gemini feedback received. Approved: $isApproved ---');
        
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

        print('--- DEBUG: Dialog closed. isApproved: $isApproved ---');
        
        if (!isApproved) {
          print('--- DEBUG: Quest not approved, returning false ---');
          return false;
        }

        print('--- DEBUG: Uploading image to ImgBB ---');
        imageUrl = await imageUploadService.uploadImage(imageFile.path);
        print('--- DEBUG: Image uploaded. URL: ${imageUrl ?? 'NULL'} ---');
      } else {
        print('--- DEBUG: No image file provided ---');
      }

      print('--- DEBUG: Starting quest completion transaction for $questId ---');
      
      final updatedUser = await questService.completeQuestTransaction(
        uid: homeController.user.value?.id ?? '',
        questId: questId,
        reflectionNote: reflectionNote,
        imageUrl: imageUrl,
        greeting: greeting,
        observation: observation,
        tip: tip,
      );

      print('--- DEBUG: completeQuestTransaction returned. updatedUser is ${updatedUser == null ? 'NULL' : 'NOT NULL'} ---');

      if (updatedUser == null) {
        print('--- ERROR: updatedUser is null, returning false ---');
        isSubmitting.value = false;
        return false;
      }

      print('--- DEBUG: Calling progressionController.completeQuest ---');
      await progressionController.completeQuest(
        questId: questId,
        xpReward: currentQuest.value.xpReward,
      );
      print('--- DEBUG: progressionController.completeQuest completed ---');

      // Refresh local UI state from updated user
      print('--- DEBUG: Updating homeController.user ---');
      homeController.user.value = updatedUser;
      print('--- DEBUG: homeController.user updated. currentPlan quests count: ${updatedUser.currentPlan.quests.length} ---');
      
      // Rebuild the visible quest window using HomeController's method for consistency
      print('--- DEBUG: Calling getVisibleQuestWindow ---');
      final visibleWindow = homeController.getVisibleQuestWindow(updatedUser.currentPlan.quests);
      print('--- DEBUG: getVisibleQuestWindow returned ${visibleWindow.length} visible quests ---');
      
      homeController.dailyQuests.value = visibleWindow;
      print('--- DEBUG: homeController.dailyQuests updated ---');

      print('--- INFO: Quest $questId completed. New visible quests: ${visibleWindow.length} ---');
      for (final q in visibleWindow) {
        print('  - ${q.nodeId}: ${q.title}');
      }

      final updated = updatedUser.currentPlan.quests.firstWhere(
        (q) => q.nodeId == questId,
        orElse: () => currentQuest.value,
      );
      currentQuest.value = updated;

      await Future.delayed(const Duration(milliseconds: 300));
      Get.back();

      return true;
    } catch (e) {
      print('--- ERROR: Exception in completeQuest: $e ---');
      print(e);
      Get.snackbar(
        'Failed to complete quest',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      print('--- DEBUG: completeQuest finally block - setting isSubmitting to false ---');
      isSubmitting.value = false;
    }
  }
}
