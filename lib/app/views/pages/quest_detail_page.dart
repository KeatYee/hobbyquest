import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/quest_detail_controller.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/progression_controller.dart';
import '../../models/quest_node_model.dart';
import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';
import '../../../core/widgets/goal_complete_screen.dart';
import '../../../core/widgets/milestone_complete_screen.dart';
import '../widgets/quest_completion_result_sheet.dart';

class QuestDetailPage extends StatefulWidget {
  final QuestNodeModel quest;

  const QuestDetailPage({super.key, required this.quest});

  @override
  State<QuestDetailPage> createState() => _QuestDetailPageState();
}

class _QuestDetailPageState extends State<QuestDetailPage> {
  late TextEditingController reflectionController;
  late QuestNodeModel currentQuest;
  late QuestDetailController _controller;
  XFile? selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  bool get _canCompleteQuest =>
      currentQuest.isActive &&
      !currentQuest.isCompleted &&
      reflectionController.text.trim().length >= 15 &&
      (currentQuest.type != 'challenge' || selectedImage != null);

  @override
  void initState() {
    super.initState();
    reflectionController = TextEditingController();
    reflectionController.addListener(_handleReflectionChanged);
    currentQuest = widget.quest;
    _controller = Get.put(QuestDetailController(initialQuest: currentQuest));
    if (currentQuest.reflectionNote.isNotEmpty) {
      reflectionController.text = currentQuest.reflectionNote;
    }
  }

  @override
  void dispose() {
    reflectionController.removeListener(_handleReflectionChanged);
    reflectionController.dispose();
    super.dispose();
  }

  void _handleReflectionChanged() {
    if (mounted) setState(() {});
  }

  Color getTypeColor() {
    switch (currentQuest.type) {
      case 'knowledge':
        return AppColors.accent;
      case 'practice':
        return AppColors.success;
      case 'challenge':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData getTypeIcon() {
    switch (currentQuest.type) {
      case 'knowledge':
        return Icons.menu_book_rounded;
      case 'practice':
        return Icons.timer_rounded;
      case 'challenge':
        return Icons.camera_alt_rounded;
      default:
        return Icons.task_alt_rounded;
    }
  }

  String getTypeLabel() {
    switch (currentQuest.type) {
      case 'knowledge':
        return 'Knowledge Quest';
      case 'practice':
        return 'Practice Quest';
      case 'challenge':
        return 'Challenge Quest';
      default:
        return 'Quest';
    }
  }

  Future<void> _completeQuest() async {
    if (currentQuest.isCompleted) {
      Get.back();
      return;
    }
    final outcome = await _controller.completeQuest(
      reflectionController.text.trim(),
      imageFile: selectedImage,
    );
    if (outcome == null) {
      if (mounted && _controller.currentQuest.value.isCompleted) {
        Navigator.of(context).pop();
      }
      return;
    }

    final homeController = Get.find<HomeController>();
    final hasCompletedMilestone = outcome.completedMilestone;
    final hasCompletedFinalMilestone = outcome.completedFinalMilestone;
    if (hasCompletedFinalMilestone) {
      await homeController.completeCurrentGoal();
    }

    if (!mounted) return;
    await QuestCompletionResultSheet.show(
      context: context,
      outcome: outcome,
      onShare: () => _controller.promptShareToGuild(
        reflectionNote: reflectionController.text.trim(),
        imageFile: selectedImage,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) Navigator.of(context).pop();
    await Future.delayed(const Duration(milliseconds: 400));
    await Get.find<ProgressionController>().showPendingLevelUp();
    if (hasCompletedMilestone) {
      await Get.generalDialog(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MilestoneCompleteScreen(),
        barrierDismissible: false,
        barrierLabel: 'Milestone Complete',
      );
    } else if (hasCompletedFinalMilestone) {
      await Get.generalDialog(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const GoalCompleteScreen(),
        barrierDismissible: false,
        barrierLabel: 'Goal Complete',
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) setState(() => selectedImage = image);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick image: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textOnPrimary,
      );
    }
  }

  Future<void> _captureImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (image != null) setState(() => selectedImage = image);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to capture image: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textOnPrimary,
      );
    }
  }

  Future<void> _watchTutorial() async {
    final query = (currentQuest.youtubeSearchQuery ?? currentQuest.title)
        .trim();
    if (query.isEmpty) {
      Get.snackbar(
        'Tutorial unavailable',
        'No YouTube search query was generated for this quest.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final uri = Uri.https('www.youtube.com', '/results', {
      'search_query': query,
    });
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      Get.snackbar(
        'Could not open tutorial',
        'Please try again or open the search manually.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = getTypeColor();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeroHeader(typeColor)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (currentQuest.isCompleted) ...[
                  _buildCompletedBanner(),
                  const SizedBox(height: 20),
                ],
                if ((currentQuest.youtubeSearchQuery ?? '')
                    .trim()
                    .isNotEmpty) ...[
                  _buildTutorialButton(),
                  const SizedBox(height: 20),
                ],
                _buildDescriptionCard(),
                const SizedBox(height: 20),

                if (currentQuest.steps.isNotEmpty) ...[
                  _buildStepsCard(typeColor),
                  const SizedBox(height: 20),
                ],
                if (!currentQuest.isCompleted ||
                    reflectionController.text.isNotEmpty) ...[
                  _buildReflectionCard(),
                  const SizedBox(height: 20),
                ],
                _buildActionButton(context),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(Color typeColor) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.accent],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: 20,
              top: -10,
              child: _DecorCircle(size: 120, opacity: 0.06),
            ),
            Positioned(
              left: -20,
              bottom: 30,
              child: _DecorCircle(size: 80, opacity: 0.04),
            ),

            Positioned(
              right: -18,
              top: 18,
              child: Icon(
                getTypeIcon(),
                size: 148,
                color: AppColors.textOnPrimary.withOpacity(0.07),
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textOnPrimary,
                          size: 20,
                        ),
                        onPressed: () => Get.back(),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.textOnPrimary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppColors.textOnPrimary.withOpacity(0.28),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              getTypeIcon(),
                              color: AppColors.textOnPrimary,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              getTypeLabel(),
                              style: TextStyle(
                                color: AppColors.textOnPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: AppFonts.badge,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentQuest.title,
                        style: TextStyle(
                          fontSize: AppFonts.titlePage,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textOnPrimary,
                          height: 1.2,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _HeroPill(
                            icon: Icons.flash_on_rounded,
                            label: '+${currentQuest.xpReward} XP',
                            accentColor: AppColors.secondary,
                          ),
                          const SizedBox(width: 8),
                          _HeroPill(
                            icon: Icons.access_time_rounded,
                            label: '${currentQuest.durationMinutes} min',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.success.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QUEST COMPLETED',
                  style: TextStyle(
                    fontSize: AppFonts.label,
                    fontWeight: FontWeight.w900,
                    color: AppColors.success,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "You've already conquered this quest.",
                  style: TextStyle(
                    fontSize: AppFonts.caption,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                color: AppColors.textOnPrimary.withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _watchTutorial,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.textOnPrimary.withOpacity(0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: AppColors.textOnPrimary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Watch Tutorial',
                            style: TextStyle(
                              color: AppColors.textOnPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: AppFonts.button,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Open a YouTube search for this quest',
                            style: TextStyle(
                              color: AppColors.textOnPrimary.withOpacity(0.82),
                              fontWeight: FontWeight.w500,
                              fontSize: AppFonts.badge,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      color: AppColors.textOnPrimary.withOpacity(0.85),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return _SectionCard(
      label: 'DESCRIPTION',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
        child: Text(
          currentQuest.desc,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppFonts.bodyLg,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildStepsCard(Color typeColor) {
    return _SectionCard(
      label: 'STEPS',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        child: Column(
          children: currentQuest.steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final number = index + 1;
            final isLast = index == currentQuest.steps.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 34,
                    child: Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: typeColor.withOpacity(0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: typeColor.withOpacity(0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$number',
                            style: TextStyle(
                              color: typeColor,
                              fontWeight: FontWeight.w800,
                              fontSize: AppFonts.caption,
                            ),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    typeColor.withOpacity(0.35),
                                    typeColor.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 18, top: 5),
                      child: Text(
                        step,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppFonts.bodyLg,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildReflectionCard() {
    final charCount = reflectionController.text.trim().length;
    final isReady = charCount >= 15;

    return _SectionCard(
      label: 'REFLECTION & EVIDENCE',
      trailing: !currentQuest.isCompleted
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isReady
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isReady
                      ? AppColors.success.withOpacity(0.4)
                      : AppColors.border,
                  width: 1,
                ),
              ),
              child: Text(
                isReady ? '✓ Ready' : '$charCount / 15 chars',
                style: TextStyle(
                  fontSize: AppFonts.micro,
                  fontWeight: FontWeight.w700,
                  color: isReady ? AppColors.success : AppColors.textSecondary,
                ),
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRect(
              child: CustomPaint(
                painter: _JournalLinesPainter(),
                child: TextField(
                  controller: reflectionController,
                  readOnly: currentQuest.isCompleted,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: currentQuest.isCompleted
                        ? 'No reflection note added.'
                        : 'What did you learn or notice? (15 chars minimum)',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFonts.caption,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppFonts.bodyLg,
                  ),
                ),
              ),
            ),

            if (selectedImage != null) ...[
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 190,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.background,
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(selectedImage!.path),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => selectedImage = null),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textOnPrimary,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flash_on_rounded,
                      size: 14,
                      color: AppColors.success,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '+${QuestDetailController.reflectionImageBonusXp} XP bonus for adding a photo!',
                      style: TextStyle(
                        fontSize: AppFonts.micro,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (!currentQuest.isCompleted) ...[
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MediaButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      color: AppColors.accent,
                      onTap: _pickImage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MediaButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: AppColors.primaryDark,
                      onTap: _captureImage,
                    ),
                  ),
                ],
              ),
              if (currentQuest.type == 'challenge')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Photo is required for challenge quest',
                    style: TextStyle(
                      fontSize: AppFonts.micro,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      color: selectedImage == null ? AppColors.error : null,
                    ),
                  ),
                ),
              if (currentQuest.type != 'challenge')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Image is optional for this quest type',
                    style: TextStyle(
                      fontSize: AppFonts.micro,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (currentQuest.isActive && !currentQuest.isCompleted) {
      return Obx(
        () => SizedBox(
          width: double.infinity,
          height: 58,
          child: _controller.isSubmitting.value
              ? _GradientButton(
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.textOnPrimary,
                      ),
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              : _canCompleteQuest
              ? _GradientButton(
                  onTap: _completeQuest,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.textOnPrimary,
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Complete Quest',
                        style: TextStyle(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: AppFonts.button,
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Add a reflection to complete',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: AppFonts.caption,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    if (!currentQuest.isCompleted && !currentQuest.isActive) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_rounded,
              color: AppColors.textSecondary.withOpacity(0.55),
              size: 18,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'This quest is locked until its prerequisites are finished.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: AppFonts.caption,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: () => Get.back(),
        icon: const Icon(Icons.arrow_back_rounded, size: 20),
        label: Text(
          'Back to Quests',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: AppFonts.bodyLg,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 2),
          backgroundColor: AppColors.primaryLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Section card with architectural header (left bar + extending rule)
class _SectionCard extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({required this.label, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 15,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppFonts.label,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 1, color: AppColors.border)),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.textShadow,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

/// Gradient CTA button with inner highlight stripe for depth
class _GradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _GradientButton({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.32),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                color: AppColors.textOnPrimary.withOpacity(0.22),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Center(child: child),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill info badge in the hero header
class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accentColor;

  const _HeroPill({required this.icon, required this.label, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final iconColor = accentColor ?? AppColors.textOnPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.textOnPrimary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.textOnPrimary.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: iconColor,
              fontWeight: FontWeight.w700,
              fontSize: AppFonts.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// Decorative circle for the gradient hero
class _DecorCircle extends StatelessWidget {
  final double size;
  final double opacity;
  const _DecorCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.textOnPrimary.withOpacity(opacity),
      ),
    );
  }
}

/// Gallery / Camera button
class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MediaButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.09),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: AppFonts.caption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws faint horizontal ruling lines behind the reflection TextField.
/// Line spacing matches the TextField's line-height (24 dp ≈ 14 × 1.71).
class _JournalLinesPainter extends CustomPainter {
  static const double _lineSpacing = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withOpacity(0.55)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    double y = _lineSpacing;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += _lineSpacing;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
