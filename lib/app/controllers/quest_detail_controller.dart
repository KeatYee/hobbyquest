import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../models/quest_node_model.dart';
import '../views/dialogs/add_guild_post_dialog.dart';
import 'guild_controller.dart';
import 'home_controller.dart';
import 'progression_controller.dart';
import '../services/quest_service.dart';
import '../services/imgbb_service.dart';
import '../../core/constants/font_constants.dart';
import '../services/gemini_service.dart';
import '../../core/constants/color_constants.dart';
import '../../core/utils/dialog_utils.dart';

class QuestDetailController extends GetxController {
  /// Extra XP awarded when a reflection is completed with an image.
  static const int reflectionImageBonusXp = 50;

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

        await AppDialogs.custom<void>(
          builder: (context) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: isApproved
                  ? [
                      const Text(
                        'Quest Approved',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: AppFonts.title),
                      ),
                      const SizedBox(height: 12),
                      if (greeting!.isNotEmpty) ...[
                        Text(greeting!, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                      ],
                      if (observation!.isNotEmpty) ...[
                        Text(observation!),
                        const SizedBox(height: 8),
                      ],
                      if (tip!.isNotEmpty) Text(tip!),
                      if (greeting!.isEmpty && observation!.isEmpty && tip!.isEmpty)
                        const Text('Your submission was approved.'),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FilledButton(
                            onPressed: () => Get.back(),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ]
                  : [
                      const Text(
                        'Oops!',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: AppFonts.title,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (greeting!.isNotEmpty) ...[
                        Text(
                          greeting!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (observation!.isNotEmpty) ...[
                        Text(observation!),
                        const SizedBox(height: 8),
                      ],
                      if (tip!.isNotEmpty) Text(tip!),
                      if (greeting!.isEmpty && observation!.isEmpty && tip!.isEmpty)
                        const Text('Retake the photo and make the completed quest easier to see.'),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: const Text(
                              'Retake Photo',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ],
            ),
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

      final int totalXpReward = currentQuest.value.xpReward +
          (imageUrl != null ? reflectionImageBonusXp : 0);
      print('--- DEBUG: Calling progressionController.completeQuest with xpReward=$totalXpReward (base: ${currentQuest.value.xpReward}, bonus: ${imageUrl != null ? reflectionImageBonusXp : 0}) ---');
      await progressionController.completeQuest(
        questId: questId,
        xpReward: totalXpReward,
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

      // Ask user if they want to share this achievement to the guild
      await _promptShareToGuild(
        questTitle: currentQuest.value.title,
        reflectionNote: reflectionNote,
        hobby: homeController.user.value?.currentPlan.hobby ?? '',
        imageUrl: imageUrl,
        imageFile: imageFile,
      );

      await Future.delayed(const Duration(milliseconds: 300));
      Get.back();

      return true;
    } catch (e) {
      print('--- ERROR: Exception in completeQuest: $e ---');
      print(e);
      AppDialogs.error('Failed to complete quest', e.toString());
      return false;
    } finally {
      print('--- DEBUG: completeQuest finally block - setting isSubmitting to false ---');
      isSubmitting.value = false;
    }
  }

  /// Prompt the user to share their completed quest to the guild.
  /// Shows a confirmation dialog first, then opens the full AddGuildPostDialog
  /// with pre-filled data so the user can review before posting.
  Future<void> _promptShareToGuild({
    required String questTitle,
    required String reflectionNote,
    required String hobby,
    required String? imageUrl,
    required XFile? imageFile,
  }) async {
    // Step 1: Ask if they want to share
    final shouldShare = await AppDialogs.custom<bool>(
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Share Your Achievement?',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: AppFonts.title),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'You just completed "$questTitle"!',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Want to share this achievement with the guild? You can review and edit before posting.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Get.back(result: false),
                  child: const Text(
                    'Not Now',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 0),
                Flexible(
                  child: FilledButton(
                    onPressed: () => Get.back(result: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Share to Guild'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );

    if (shouldShare != true) return;

    // Step 2: Resolve category and hobby for pre-filling
    try {
      final guildController = Get.find<GuildController>();

      String? categoryId;
      for (final category in guildController.categories) {
        if (category.hobbies.any((h) => h.toLowerCase() == hobby.toLowerCase())) {
          categoryId = category.id;
          break;
        }
      }

      // Step 3: Open the full AddGuildPostDialog with pre-filled data
      await Get.bottomSheet<void>(
        Padding(
          padding: EdgeInsets.only(
            bottom: Get.mediaQuery.viewInsets.bottom,
          ),
          child: AddGuildPostDialog(
            hobby: hobby,
            categoryId: categoryId ?? '',
            initialTitle: 'Completed: $questTitle',
            initialBody: reflectionNote,
            initialImageFile: imageFile,
          ),
        ),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: true,
        enableDrag: true,
      );
    } catch (e) {
      print('--- ERROR: Failed to open guild post dialog: $e ---');
    }
  }
}
