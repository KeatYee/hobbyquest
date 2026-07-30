import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../models/quest_node_model.dart';
import '../models/tree_model.dart';
import '../views/dialogs/add_guild_post_dialog.dart';
import '../views/dialogs/rubric_feedback_dialog.dart';
import 'guild_controller.dart';
import 'home_controller.dart';
import 'progression_controller.dart';
import '../services/quest_service.dart';
import '../services/user_image_upload_service.dart';
import '../../core/constants/font_constants.dart';
import '../services/gemini_service.dart';
import '../../core/constants/color_constants.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/quest_rubric_utils.dart';

class QuestCompletionOutcome {
  final QuestCompletionResult completion;
  final String categoryName;
  final int previousCategoryXp;
  final int updatedCategoryXp;
  final int previousCategoryStage;
  final int updatedCategoryStage;
  final int previousStreak;
  final List<QuestNodeModel> newlyUnlockedQuests;
  final bool didLevelUp;
  final List<int> unlockedProgressionMilestones;
  final bool completedMilestone;
  final bool completedFinalMilestone;

  const QuestCompletionOutcome({
    required this.completion,
    required this.categoryName,
    required this.previousCategoryXp,
    required this.updatedCategoryXp,
    required this.previousCategoryStage,
    required this.updatedCategoryStage,
    required this.previousStreak,
    required this.newlyUnlockedQuests,
    required this.didLevelUp,
    required this.unlockedProgressionMilestones,
    required this.completedMilestone,
    required this.completedFinalMilestone,
  });

  bool get hasCategoryProgress => categoryName.isNotEmpty;

  bool get didAdvanceTreeStage => updatedCategoryStage > previousCategoryStage;

  bool get didReachTreeMaturity =>
      previousCategoryXp < TreeModel.maturityXp &&
      updatedCategoryXp >= TreeModel.maturityXp;
}

typedef QuestImageFeedbackGenerator =
    Future<Map<String, dynamic>?> Function({
      required XFile imageFile,
      required String hobby,
      required String questTitle,
      required String questDescription,
      required String questSteps,
      required String questType,
      required String reflectionNote,
      required List<String> imageRubric,
    });

typedef QuestImageUploader = Future<String> Function(String imagePath);

typedef OptionalPhotoRecoveryPresenter =
    Future<RubricFeedbackAction?> Function({required bool uploadFailed});

typedef RubricFeedbackPresenter =
    Future<RubricFeedbackAction?> Function({
      required bool isEvidenceRelevant,
      required bool isApproved,
      required bool isChallenge,
      required String greeting,
      required List<RubricAssessmentModel> assessments,
      required String nextStep,
    });

abstract class QuestDetailHomeContext {
  String get uid;
  String get activePlanId;
  String get hobby;
  String get category;
  int get currentStreak;
  Map<String, int> get categoryXp;
  List<QuestNodeModel> get dailyQuests;

  void applyQuestCompletion(QuestCompletionResult completion);
  Future<void> refreshGrowthLetterAvailability();
  bool hasCompletedMilestone();
  bool hasCompletedFinalMilestone();
}

abstract class QuestDetailProgressionContext {
  Future<String?> resolveCurrentCategoryName();
  List<int> applyQuestCompletion(QuestCompletionResult completion);
}

class _HomeControllerQuestDetailContext implements QuestDetailHomeContext {
  final HomeController controller;

  const _HomeControllerQuestDetailContext(this.controller);

  @override
  String get uid => controller.user.value?.id ?? '';

  @override
  String get activePlanId => controller.user.value?.activePlanId ?? '';

  @override
  String get hobby => controller.user.value?.currentPlan.hobby ?? '';

  @override
  String get category =>
      controller.user.value?.currentPlan.category?.trim() ?? '';

  @override
  int get currentStreak => controller.user.value?.currentStreak ?? 0;

  @override
  Map<String, int> get categoryXp =>
      controller.user.value?.categoryXp ?? const <String, int>{};

  @override
  List<QuestNodeModel> get dailyQuests => controller.dailyQuests;

  @override
  void applyQuestCompletion(QuestCompletionResult completion) {
    controller.applyQuestCompletion(completion);
  }

  @override
  Future<void> refreshGrowthLetterAvailability() {
    return controller.refreshGrowthLetterAvailability();
  }

  @override
  bool hasCompletedMilestone() => controller.hasCompletedMilestone();

  @override
  bool hasCompletedFinalMilestone() => controller.hasCompletedFinalMilestone();
}

class _ProgressionControllerQuestDetailContext
    implements QuestDetailProgressionContext {
  final ProgressionController controller;

  const _ProgressionControllerQuestDetailContext(this.controller);

  @override
  Future<String?> resolveCurrentCategoryName() {
    return controller.resolveCurrentCategoryName();
  }

  @override
  List<int> applyQuestCompletion(QuestCompletionResult completion) {
    return controller.applyQuestCompletion(
      completion,
      showMilestoneUnlockModal: false,
    );
  }
}

class QuestDetailController extends GetxController {
  /// Extra XP awarded when a reflection is completed with an image.
  static const int reflectionImageBonusXp = QuestService.reflectionImageBonusXP;

  final Rx<QuestNodeModel> currentQuest;
  final isSubmitting = false.obs;
  QuestService? _questServiceInstance;
  UserImageUploadService? _imageUploadServiceInstance;
  GeminiService? _geminiServiceInstance;
  final QuestDetailProgressionContext? _progressionContext;
  final QuestDetailHomeContext? _homeContext;
  final QuestImageFeedbackGenerator? _feedbackGenerator;
  final QuestImageUploader? _imageUploader;
  final OptionalPhotoRecoveryPresenter? _optionalRecoveryPresenter;
  final RubricFeedbackPresenter? _rubricFeedbackPresenter;
  final void Function(String title, String message)? _errorPresenter;
  bool _retakeImageRequested = false;

  QuestDetailController({
    required QuestNodeModel initialQuest,
    QuestService? questService,
    UserImageUploadService? imageUploadService,
    GeminiService? geminiService,
    ProgressionController? progressionController,
    HomeController? homeController,
    QuestDetailProgressionContext? progressionContext,
    QuestDetailHomeContext? homeContext,
    QuestImageFeedbackGenerator? feedbackGenerator,
    QuestImageUploader? imageUploader,
    OptionalPhotoRecoveryPresenter? optionalRecoveryPresenter,
    RubricFeedbackPresenter? rubricFeedbackPresenter,
    void Function(String title, String message)? errorPresenter,
  }) : currentQuest = Rx<QuestNodeModel>(initialQuest),
       _questServiceInstance = questService,
       _imageUploadServiceInstance = imageUploadService,
       _geminiServiceInstance = geminiService,
       _progressionContext =
           progressionContext ??
           (progressionController == null
               ? null
               : _ProgressionControllerQuestDetailContext(
                   progressionController,
                 )),
       _homeContext =
           homeContext ??
           (homeController == null
               ? null
               : _HomeControllerQuestDetailContext(homeController)),
       _feedbackGenerator = feedbackGenerator,
       _imageUploader = imageUploader,
       _optionalRecoveryPresenter = optionalRecoveryPresenter,
       _rubricFeedbackPresenter = rubricFeedbackPresenter,
       _errorPresenter = errorPresenter;

  QuestService get _questService => _questServiceInstance ??= QuestService();

  UserImageUploadService get _imageUploadService =>
      _imageUploadServiceInstance ??= UserImageUploadService();

  GeminiService get _geminiService =>
      _geminiServiceInstance ??= GeminiService();

  bool consumeRetakeImageRequest() {
    final requested = _retakeImageRequested;
    _retakeImageRequested = false;
    return requested;
  }

  /// Completes a quest and returns the UI-ready result of the idempotent
  /// transaction. A duplicate completion returns null and shows no reward UI.
  Future<QuestCompletionOutcome?> completeQuest(
    String reflectionNote, {
    XFile? imageFile,
  }) async {
    print(
      '--- DEBUG: completeQuest() called for quest ${currentQuest.value.nodeId} ---',
    );

    if (currentQuest.value.isCompleted) {
      print('--- DEBUG: Quest already completed, skipping result sheet ---');
      return null;
    }

    _retakeImageRequested = false;
    isSubmitting.value = true;
    final progressionContext =
        _progressionContext ??
        _ProgressionControllerQuestDetailContext(
          Get.find<ProgressionController>(),
        );
    final homeContext =
        _homeContext ??
        _HomeControllerQuestDetailContext(Get.find<HomeController>());
    final questId = currentQuest.value.nodeId;
    final activeQuestIdsBefore = homeContext.dailyQuests
        .where((quest) => quest.isActive && !quest.isCompleted)
        .map((quest) => quest.nodeId)
        .toSet();
    final previousStreak = homeContext.currentStreak;
    final categoryXpBefore = Map<String, int>.from(homeContext.categoryXp);

    try {
      String? imageUrl;
      String greeting = '';
      String observation = '';
      String tip = '';
      var rubricAssessments = <RubricAssessmentModel>[];
      print(
        '--- DEBUG: imageFile is ${imageFile == null ? 'NULL' : 'NOT NULL'} ---',
      );

      if (imageFile != null) {
        print('--- DEBUG: Processing image evidence ---');
        final rubric = currentQuest.value.imageRubric;
        final isChallenge = currentQuest.value.type == 'challenge';
        final feedbackResult = await _generateImageFeedback(
          imageFile: imageFile,
          questTitle: currentQuest.value.title,
          questDescription: currentQuest.value.desc,
          questSteps: currentQuest.value.steps.join('\n  - '),
          questType: currentQuest.value.type,
          reflectionNote: reflectionNote,
          hobby: homeContext.hobby,
          imageRubric: rubric,
        );
        

        if (feedbackResult == null) {
          if (isChallenge) {
            throw Exception('Failed to review image evidence');
          }

          final recoveryAction = await _showOptionalPhotoRecovery(
            uploadFailed: false,
          );
          if (recoveryAction == RubricFeedbackAction.retakePhoto) {
            _retakeImageRequested = true;
            return null;
          }
          if (recoveryAction != RubricFeedbackAction.continueQuest) {
            return null;
          }
        } else {
          greeting = feedbackResult['greeting'] as String? ?? '';

          if (rubric.length == questRubricSize) {
            final isRelevant =
                feedbackResult['is_evidence_relevant'] as bool? ?? false;
            final rawAssessments = feedbackResult['rubric_assessments'];
            if (rawAssessments is! List<RubricAssessmentModel>) {
              throw const FormatException('Invalid rubric feedback');
            }
            rubricAssessments = rawAssessments;
            tip = feedbackResult['next_step'] as String? ?? '';
            final isApproved = rubricChallengeApproved(
              isEvidenceRelevant: isRelevant,
              assessments: rubricAssessments,
            );

            final feedbackAction = await _showRubricFeedback(
              isEvidenceRelevant: isRelevant,
              isApproved: isApproved,
              isChallenge: isChallenge,
              greeting: greeting,
              assessments: rubricAssessments,
              nextStep: tip,
            );

            if (feedbackAction == RubricFeedbackAction.retakePhoto) {
              _retakeImageRequested = true;
              return null;
            }
            if (feedbackAction != RubricFeedbackAction.continueQuest) {
              return null;
            }
            if (isRelevant) {
              try {
                imageUrl = await _uploadImage(imageFile.path);
              } catch (_) {
                if (isChallenge) rethrow;
                final recoveryAction = await _showOptionalPhotoRecovery(
                  uploadFailed: true,
                );
                if (recoveryAction == RubricFeedbackAction.retakePhoto) {
                  _retakeImageRequested = true;
                  return null;
                }
                if (recoveryAction != RubricFeedbackAction.continueQuest) {
                  return null;
                }
                imageUrl = null;
              }
            } else {
              rubricAssessments = <RubricAssessmentModel>[];
            }
          } else {
            final isApproved = feedbackResult['is_approved'] as bool? ?? false;
            observation = feedbackResult['observation'] as String? ?? '';
            tip = feedbackResult['tip'] as String? ?? '';
            final legacyAction = await _showLegacyImageFeedback(
              isApproved: isApproved,
              greeting: greeting,
              observation: observation,
              tip: tip,
            );
            if (!isApproved) {
              if (legacyAction == RubricFeedbackAction.retakePhoto) {
                _retakeImageRequested = true;
              }
              return null;
            }
            try {
              imageUrl = await _uploadImage(imageFile.path);
            } catch (_) {
              if (isChallenge) rethrow;
              final recoveryAction = await _showOptionalPhotoRecovery(
                uploadFailed: true,
              );
              if (recoveryAction == RubricFeedbackAction.retakePhoto) {
                _retakeImageRequested = true;
                return null;
              }
              if (recoveryAction != RubricFeedbackAction.continueQuest) {
                return null;
              }
              imageUrl = null;
            }
          }
        }
      } else {
        print('--- DEBUG: No image file provided ---');
      }

      print(
        '--- DEBUG: Starting quest completion transaction for $questId ---',
      );

      final storedCategory = homeContext.category;
      final fallbackCategory = storedCategory.isNotEmpty
          ? storedCategory
          : await progressionContext.resolveCurrentCategoryName();
      final categoryName = storedCategory.isNotEmpty
          ? storedCategory
          : fallbackCategory?.trim() ?? '';
      final completion = await _questService.completeQuestTransaction(
        uid: homeContext.uid,
        planId: homeContext.activePlanId,
        questId: questId,
        reflectionNote: reflectionNote,
        imageUrl: imageUrl,
        greeting: greeting,
        observation: observation,
        tip: tip,
        rubricAssessments: rubricAssessments,
        fallbackCategoryName: fallbackCategory,
      );

      print(
        '--- DEBUG: completeQuestTransaction returned. didComplete=${completion.didComplete}, awardedXP=${completion.awardedXP} ---',
      );

      final unlockedProgressionMilestones = progressionContext
          .applyQuestCompletion(completion);
      homeContext.applyQuestCompletion(completion);
      unawaited(homeContext.refreshGrowthLetterAvailability());

      print(
        '--- INFO: Quest $questId synchronized. Total quest nodes: ${homeContext.dailyQuests.length} ---',
      );
      for (final q in homeContext.dailyQuests) {
        print('  - ${q.nodeId}: ${q.title}');
      }

      final updated = homeContext.dailyQuests.firstWhere(
        (q) => q.nodeId == questId,
        orElse: () => completion.quest,
      );
      currentQuest.value = updated;

      if (!completion.didComplete) return null;

      final previousCategoryXp = categoryXpBefore[categoryName] ?? 0;
      final updatedCategoryXp = completion.updatedCategoryXp[categoryName] ?? 0;
      final newlyUnlockedQuests = homeContext.dailyQuests
          .where(
            (quest) =>
                quest.isActive &&
                !quest.isCompleted &&
                !activeQuestIdsBefore.contains(quest.nodeId),
          )
          .toList();

      return QuestCompletionOutcome(
        completion: completion,
        categoryName: categoryName,
        previousCategoryXp: previousCategoryXp,
        updatedCategoryXp: updatedCategoryXp,
        previousCategoryStage: TreeModel.stageForXp(previousCategoryXp),
        updatedCategoryStage: TreeModel.stageForXp(updatedCategoryXp),
        previousStreak: previousStreak,
        newlyUnlockedQuests: newlyUnlockedQuests,
        didLevelUp:
            (completion.updatedTotalXP ~/ 1000) >
            (completion.previousTotalXP ~/ 1000),
        unlockedProgressionMilestones: unlockedProgressionMilestones,
        completedMilestone: homeContext.hasCompletedMilestone(),
        completedFinalMilestone: homeContext.hasCompletedFinalMilestone(),
      );
    } catch (e) {
      print('--- ERROR: Exception in completeQuest: $e ---');
      print(e);
      final errorPresenter = _errorPresenter;
      if (errorPresenter != null) {
        errorPresenter('Failed to complete quest', e.toString());
      } else {
        AppDialogs.error('Failed to complete quest', e.toString());
      }
      return null;
    } finally {
      print(
        '--- DEBUG: completeQuest finally block - setting isSubmitting to false ---',
      );
      isSubmitting.value = false;
    }
  }

  Future<Map<String, dynamic>?> _generateImageFeedback({
    required XFile imageFile,
    required String hobby,
    required String questTitle,
    required String questDescription,
    required String questSteps,
    required String questType,
    required String reflectionNote,
    required List<String> imageRubric,
  }) {
    final generator = _feedbackGenerator;
    if (generator != null) {
      return generator(
        imageFile: imageFile,
        hobby: hobby,
        questTitle: questTitle,
        questDescription: questDescription,
        questSteps: questSteps,
        questType: questType,
        reflectionNote: reflectionNote,
        imageRubric: imageRubric,
      );
    }
    return _geminiService.generateQuestImageFeedback(
      imageFile: imageFile,
      hobby: hobby,
      questTitle: questTitle,
      questDescription: questDescription,
      questSteps: questSteps,
      questType: questType,
      reflectionNote: reflectionNote,
      imageRubric: imageRubric,
    );
  }

  Future<String> _uploadImage(String imagePath) {
    final uploader = _imageUploader;
    if (uploader != null) return uploader(imagePath);
    return _imageUploadService.uploadImage(imagePath);
  }

  Future<RubricFeedbackAction?> _showRubricFeedback({
    required bool isEvidenceRelevant,
    required bool isApproved,
    required bool isChallenge,
    required String greeting,
    required List<RubricAssessmentModel> assessments,
    required String nextStep,
  }) {
    final presenter = _rubricFeedbackPresenter;
    if (presenter != null) {
      return presenter(
        isEvidenceRelevant: isEvidenceRelevant,
        isApproved: isApproved,
        isChallenge: isChallenge,
        greeting: greeting,
        assessments: assessments,
        nextStep: nextStep,
      );
    }
    return AppDialogs.custom<RubricFeedbackAction>(
      builder: (context) => RubricFeedbackDialog(
        isEvidenceRelevant: isEvidenceRelevant,
        isApproved: isApproved,
        isChallenge: isChallenge,
        greeting: greeting,
        assessments: assessments,
        nextStep: nextStep,
      ),
      barrierDismissible: false,
    );
  }

  Future<RubricFeedbackAction?> _showOptionalPhotoRecovery({
    required bool uploadFailed,
  }) {
    final presenter = _optionalRecoveryPresenter;
    if (presenter != null) {
      return presenter(uploadFailed: uploadFailed);
    }
    return AppDialogs.custom<RubricFeedbackAction>(
      builder: (context) =>
          OptionalPhotoRecoveryDialog(uploadFailed: uploadFailed),
      barrierDismissible: false,
    );
  }

  Future<RubricFeedbackAction?> _showLegacyImageFeedback({
    required bool isApproved,
    required String greeting,
    required String observation,
    required String tip,
  }) {
    return AppDialogs.custom<RubricFeedbackAction>(
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isApproved ? 'Quest Approved' : 'Oops!',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: AppFonts.title,
                color: isApproved ? AppColors.success : AppColors.error,
              ),
            ),
            if (greeting.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(greeting),
            ],
            if (observation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(observation),
            ],
            if (tip.isNotEmpty) ...[const SizedBox(height: 8), Text(tip)],
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: isApproved
                  ? FilledButton(
                      onPressed: () =>
                          Get.back(result: RubricFeedbackAction.continueQuest),
                      child: const Text('OK'),
                    )
                  : TextButton(
                      onPressed: () =>
                          Get.back(result: RubricFeedbackAction.retakePhoto),
                      child: const Text(
                        'Retake Photo',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> promptShareToGuild({
    required String reflectionNote,
    XFile? imageFile,
  }) async {
    if (!currentQuest.value.isCompleted) return;

    try {
      await _promptShareToGuild(
        questTitle: currentQuest.value.title,
        reflectionNote: reflectionNote,
        hobby: Get.find<HomeController>().user.value?.currentPlan.hobby ?? '',
        imageUrl: currentQuest.value.imageUrl,
        imageFile: imageFile,
      );
    } catch (e) {
      print('--- WARNING: Quest sharing failed: $e ---');
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
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Share Your Achievement?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: AppFonts.title,
                    ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

    try {
      final guildController = Get.find<GuildController>();

      String? categoryId;
      for (final category in guildController.categories) {
        if (category.hobbyNames.any(
          (h) => h.toLowerCase() == hobby.toLowerCase(),
        )) {
          categoryId = category.id;
          break;
        }
      }

      await Get.bottomSheet<void>(
        Padding(
          padding: EdgeInsets.only(bottom: Get.mediaQuery.viewInsets.bottom),
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
