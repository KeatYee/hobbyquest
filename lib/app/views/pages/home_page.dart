import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/progression_controller.dart';
import '../../routes/app_routes.dart';
import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../models/quest_plan_model.dart';
import '../../models/milestone_model.dart';
import '../../models/quest_node_model.dart';
import '../widgets/shaking_mailbox_button.dart';
import '../../../core/widgets/milestone_complete_screen.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.put(HomeController());
    Get.put(ProgressionController());

    return Column(
      children: [
        _buildHeroHud(controller),

        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),

                _buildPrimaryAction(controller),

                const SizedBox(height: 16),
                _buildMilestoneProgress(controller),

                const SizedBox(height: 22),

                Obx(() {
                  final activeQuests = controller.dailyQuests
                      .where((q) => q.isActive && !q.isCompleted)
                      .toList();
                  final supportingQuests = activeQuests.skip(1).toList();
                  if (supportingQuests.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        'ALSO AVAILABLE',
                        onInfoTap: _showQuestInfoDialog,
                      ),
                      const SizedBox(height: 10),
                      ...supportingQuests.map(_buildSecondaryQuestCard),
                    ],
                  );
                }),

                _buildViewFullMilestoneMapButton(controller),

                _buildCompletedSection(context, controller),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneRecoveryButton(HomeController controller) {
    if (!controller.hasCompletedMilestone()) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const Key('milestone-recovery-cta'),
        onPressed: () => Get.generalDialog(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MilestoneCompleteScreen(),
          barrierDismissible: false,
          barrierLabel: 'Continue to Next Milestone',
        ),
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('CONTINUE TO NEXT MILESTONE'),
      ),
    );
  }

  Widget _buildPrimaryAction(HomeController controller) {
    return Obx(() {
      if (controller.isLoadingProfile.value) {
        return _buildQuestGuidance(
          title: 'Preparing your next win',
          message: 'We are getting your learning path ready.',
          icon: Icons.auto_awesome_rounded,
          showMapAction: false,
        );
      }

      if (controller.hasCompletedMilestone()) {
        return _buildMilestoneRecoveryButton(controller);
      }

      final activeQuests = controller.dailyQuests
          .where((quest) => quest.isActive && !quest.isCompleted)
          .toList();
      if (activeQuests.isEmpty) {
        return _buildQuestGuidance(
          title: 'Your next step is taking shape',
          message:
              'Review your milestone map to see your path and what unlocks next.',
          icon: Icons.map_rounded,
          showMapAction: true,
          controller: controller,
        );
      }

      return _buildFeaturedQuestCard(activeQuests.first);
    });
  }

  Widget _buildFeaturedQuestCard(QuestNodeModel quest) {
    void openQuest() {
      Get.toNamed(AppRoutes.QUEST_DETAIL, arguments: quest);
    }

    return Semantics(
      button: true,
      label: 'Start next quest: ${quest.title}',
      child: Material(
        key: const Key('featured-quest-card'),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: openQuest,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.textShadow,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.textOnPrimary.withValues(
                            alpha: 0.22,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _questTypeIcon(quest.type),
                            size: 14,
                            color: AppColors.textOnPrimary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _questTypeLabel(quest.type),
                            style: const TextStyle(
                              color: AppColors.textOnPrimary,
                              fontSize: AppFonts.label,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'NEXT QUEST',
                      style: TextStyle(
                        color: AppColors.textOnPrimary,
                        fontSize: AppFonts.label,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  quest.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: AppFonts.title,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                if (quest.desc.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    quest.desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textOnPrimary.withValues(alpha: 0.88),
                      fontSize: AppFonts.caption,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    _featuredQuestMeta(
                      Icons.access_time_rounded,
                      '${quest.durationMinutes} min',
                    ),
                    const SizedBox(width: 8),
                    _featuredQuestMeta(
                      Icons.flash_on_rounded,
                      '+${quest.xpReward} XP',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('featured-quest-cta'),
                    onPressed: openQuest,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    label: const Text('START QUEST'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _featuredQuestMeta(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.textOnPrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textOnPrimary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textOnPrimary,
              fontSize: AppFonts.badge,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestGuidance({
    required String title,
    required String message,
    required IconData icon,
    required bool showMapAction,
    HomeController? controller,
  }) {
    return Container(
      key: const Key('quest-guidance'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppFonts.bodyLg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFonts.caption,
                    height: 1.35,
                  ),
                ),
                if (showMapAction && controller != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      final plan = controller.user.value?.currentPlan;
                      if (plan != null) {
                        _showFullMilestoneMap(controller, plan);
                      }
                    },
                    icon: const Icon(Icons.map_rounded, size: 17),
                    label: const Text('VIEW MILESTONE MAP'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 40),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryQuestCard(QuestNodeModel quest) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        key: Key('secondary-quest-${quest.nodeId}'),
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Get.toNamed(AppRoutes.QUEST_DETAIL, arguments: quest),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    _questTypeIcon(quest.type),
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppFonts.caption,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${quest.durationMinutes} min  •  +${quest.xpReward} XP',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppFonts.badge,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _questTypeIcon(String type) {
    switch (type) {
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

  String _questTypeLabel(String type) {
    switch (type) {
      case 'knowledge':
        return 'KNOWLEDGE';
      case 'practice':
        return 'PRACTICE';
      case 'challenge':
        return 'CHALLENGE';
      default:
        return 'QUEST';
    }
  }

  Widget _buildHeroHud(HomeController controller) {
    final progressionController = Get.find<ProgressionController>();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 18),
      decoration: const BoxDecoration(color: AppColors.background),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildHeaderAvatar(controller, progressionController),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(() {
                      final nickname = controller.nickname.value.trim();
                      return Text(
                        nickname.isEmpty ? 'Hero' : 'Hi, $nickname',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: AppFonts.title,
                          color: AppColors.textPrimary,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildGrowthLetterButton(controller),
            ],
          ),
          Obx(() {
            const xpPerLevel = 1000;
            final totalXp = progressionController.totalXP.value;
            final xpIntoLevel = totalXp % xpPerLevel;
            final level = progressionController.currentLevel;

            return Semantics(
              label:
                  'Level $level progress: $xpIntoLevel of $xpPerLevel experience points',
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'LEVEL $level PROGRESS',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppFonts.label,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$xpIntoLevel / $xpPerLevel XP',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppFonts.badge,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: xpIntoLevel / xpPerLevel,
                      minHeight: 8,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderAvatar(
    HomeController controller,
    ProgressionController progressionController,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 60,
          height: 60,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderStrong, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.softShadow,
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Obx(() {
            final avatarPath = controller.avatarSvg.value;
            return CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primaryLight,
              child: avatarPath.isNotEmpty
                  ? ClipOval(
                      child: Image.asset(
                        avatarPath,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    )
                  : const Icon(
                      Icons.person_rounded,
                      color: AppColors.primaryDark,
                      size: 26,
                    ),
            );
          }),
        ),
        Positioned(
          right: -3,
          bottom: -2,
          child: Obx(
            () => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: Text(
                'LV ${progressionController.currentLevel}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: AppFonts.label,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrowthLetterButton(HomeController controller) {
    return Obx(
      () => ShakingMailboxButton(
        isShaking: controller.hasAvailableGrowthLetter.value,
        onTap: () => Get.toNamed(AppRoutes.GROWTH_LETTER),
      ),
    );
  }

  Widget _buildViewFullMilestoneMapButton(HomeController controller) {
    return Obx(() {
      final plan = controller.user.value?.currentPlan;
      if (plan == null || plan.quests.isEmpty) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showFullMilestoneMap(controller, plan),
            icon: const Icon(Icons.map_rounded, size: 18),
            label: const Text('View Full Milestone Map'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildMilestoneProgress(HomeController controller) {
    return Obx(() {
      final plan = controller.user.value?.currentPlan;
      if (plan == null || plan.milestones.isEmpty)
        return const SizedBox.shrink();

      final index = plan.currentMilestoneIndex;
      final total = plan.milestones.length;
      final milestone = plan.milestones[index];
      final progress = ((index + 1) / total);
      final progressPercent = (progress * 100).round();

      final quests = plan.quests;
      final completedQuests = quests.where((q) => q.isCompleted).length;
      final totalQuests = quests.length;

      return Semantics(
        button: true,
        label:
            'Current goal: ${plan.goal}. Phase ${index + 1} of $total: ${milestone.title}. $completedQuests of $totalQuests quests completed.',
        child: InkWell(
          onTap: () => _showGoalInfo(controller, plan),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.softShadow,
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.flag_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'YOUR CURRENT GOAL',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: AppFonts.label,
                          letterSpacing: 0.8,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  plan.goal,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: AppFonts.title,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CURRENT PHASE · ${index + 1} OF $total',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: AppFonts.label,
                                letterSpacing: 0.7,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              milestone.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: AppFonts.bodyLg,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.route_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      'JOURNEY PROGRESS',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: AppFonts.label,
                        letterSpacing: 0.7,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$progressPercent%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: AppFonts.badge,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 17,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$completedQuests of $totalQuests quests complete',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: AppFonts.caption,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'View details',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: AppFonts.micro,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _showGoalInfo(HomeController controller, QuestPlanModel plan) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Goal',
                style: TextStyle(
                  fontSize: AppFonts.title,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                plan.goal,
                style: const TextStyle(
                  fontSize: AppFonts.bodyLg,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _infoChip(Icons.auto_awesome_rounded, plan.hobby),
                  const SizedBox(width: 8),
                  _infoChip(Icons.trending_up_rounded, plan.level),
                ],
              ),
              const SizedBox(height: 8),
              _infoChip(
                Icons.speed_rounded,
                'Learning Pace: ${plan.learningPace}',
              ),
              const SizedBox(height: 20),
              const Text(
                'Milestones',
                style: TextStyle(
                  fontSize: AppFonts.bodyLg,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              ...plan.milestones.map((m) => _milestoneRow(m, plan)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Get.back();
                    _showFullMilestoneMap(controller, plan);
                  },
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: const Text('View Full Milestone Map'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppFonts.badge,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _milestoneRow(MilestoneModel m, QuestPlanModel plan) {
    final index = plan.milestones.indexOf(m);
    final isCurrent = index == plan.currentMilestoneIndex;
    final isCompleted = m.completed || index < plan.currentMilestoneIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? AppColors.success
                  : (isCurrent ? AppColors.primary : AppColors.border),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: AppColors.textOnPrimary,
                    )
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: AppFonts.badge,
                        fontWeight: FontWeight.w700,
                        color: isCurrent
                            ? AppColors.textOnPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              m.title,
              style: TextStyle(
                fontSize: AppFonts.caption,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: isCompleted
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Current',
                style: TextStyle(
                  fontSize: AppFonts.label,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showFullMilestoneMap(HomeController controller, QuestPlanModel plan) {
    final currentIndex = plan.currentMilestoneIndex;
    final currentMilestone =
        currentIndex >= 0 && currentIndex < plan.milestones.length
        ? plan.milestones[currentIndex]
        : null;

    Get.bottomSheet(
      SafeArea(
        top: false,
        child: Container(
          height: Get.height * 0.86,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Full Milestone Map',
                      style: TextStyle(
                        fontSize: AppFonts.title,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textSecondary,
                    tooltip: 'Close',
                  ),
                ],
              ),
              if (currentMilestone != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Phase ${currentIndex + 1}: ${currentMilestone.title}',
                  style: const TextStyle(
                    fontSize: AppFonts.caption,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: plan.milestones
                      .map((milestone) => _milestoneRow(milestone, plan))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Quest Path',
                style: TextStyle(
                  fontSize: AppFonts.bodyLg,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Obx(() {
                  final quests = controller.dailyQuests.isNotEmpty
                      ? controller.dailyQuests.toList()
                      : controller.getAllQuestNodes(plan.quests);

                  if (quests.isEmpty) {
                    return const Center(
                      child: Text(
                        'No quests yet.',
                        style: TextStyle(
                          fontSize: AppFonts.caption,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: quests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) =>
                        _buildMilestoneQuestRow(quests[index]),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildMilestoneQuestRow(QuestNodeModel quest) {
    final isCompleted = quest.isCompleted;
    final isLocked = !quest.isActive && !isCompleted;
    final statusColor = isCompleted
        ? AppColors.success
        : (isLocked ? AppColors.textSecondary : AppColors.primary);
    final statusIcon = isCompleted
        ? Icons.check_rounded
        : (isLocked ? Icons.lock_rounded : Icons.flag_rounded);
    final statusLabel = isCompleted ? 'Done' : (isLocked ? 'Locked' : 'Active');

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: isLocked || isCompleted
            ? null
            : () {
                Get.back();
                Get.toNamed(AppRoutes.QUEST_DETAIL, arguments: quest);
              },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, size: 18, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      style: TextStyle(
                        fontSize: AppFonts.caption,
                        fontWeight: FontWeight.w800,
                        color: isLocked
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (quest.desc.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        quest.desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppFonts.badge,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _mapMetaChip(
                          Icons.access_time_rounded,
                          '${quest.durationMinutes} min',
                        ),
                        _mapMetaChip(
                          Icons.flash_on_rounded,
                          '${quest.xpReward} XP',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: AppFonts.micro,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppFonts.micro,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedSection(
    BuildContext context,
    HomeController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => controller.isCompletedExpanded.toggle(),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Obx(() {
                  final count = controller.dailyQuests
                      .where((q) => q.isCompleted)
                      .length;
                  return Text(
                    "COMPLETED ($count)",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: AppFonts.bodyLg,
                      letterSpacing: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  );
                }),
                const Spacer(),
                Obx(
                  () => AnimatedRotation(
                    turns: controller.isCompletedExpanded.value ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Obx(() {
          if (!controller.isCompletedExpanded.value) {
            return const SizedBox.shrink();
          }
          return Column(
            children: controller.dailyQuests
                .where((q) => q.isCompleted)
                .map(
                  (quest) => _buildQuestCard(
                    context,
                    controller: controller,
                    title: quest.title,
                    desc: quest.desc,
                    xp: quest.xpReward,
                    durationMinutes: quest.durationMinutes,
                    type: quest.type,
                    questId: quest.nodeId,
                    isActive: quest.isActive,
                    isCompleted: quest.isCompleted,
                    onTap: null,
                  ),
                )
                .toList(),
          );
        }),
      ],
    );
  }

  void _showQuestInfoDialog() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How quests work',
                style: TextStyle(
                  fontSize: AppFonts.title,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _questInfoRow(
                Icons.flag_rounded,
                'Active quests are ready now. Tap one to see the task, steps, and reflection.',
              ),
              _questInfoRow(
                Icons.lock_rounded,
                'Locked quests stay hidden here until earlier quests are completed.',
              ),
              _questInfoRow(
                Icons.map_rounded,
                'Use View Full Milestone Map to preview the full path, including locked quests.',
              ),
              _questInfoRow(
                Icons.check_circle_rounded,
                'Completed quests move into the Completed section below.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _questInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: AppFonts.caption,
                height: 1.4,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String label, {
    VoidCallback? onInfoTap,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: AppFonts.bodyLg,
            letterSpacing: 1.5,
            color: AppColors.textPrimary,
          ),
        ),
        if (onInfoTap != null) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: 'How quests work',
            child: InkWell(
              onTap: onInfoTap,
              borderRadius: BorderRadius.circular(999),
              child: const SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
        if (trailing != null) ...[const Spacer(), trailing],
      ],
    );
  }

  Widget _buildQuestCard(
    BuildContext context, {
    required HomeController controller,
    required String title,
    required String desc,
    required int xp,
    required int durationMinutes,
    required String type,
    required String questId,
    required bool isActive,
    required bool isCompleted,
    required VoidCallback? onTap,
  }) {
    final isLocked = !isActive && !isCompleted;

    Color getTypeColor() {
      return AppColors.primary;
    }

    IconData getTypeIcon() {
      switch (type) {
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
      switch (type) {
        case 'knowledge':
          return 'KNOWLEDGE';
        case 'practice':
          return 'PRACTICE';
        case 'challenge':
          return 'CHALLENGE';
        default:
          return 'QUEST';
      }
    }

    final color = getTypeColor();
    final cardOpacity = isLocked ? 0.45 : (isCompleted ? 0.7 : 1.0);
    final completedColor = AppColors.success;

    return Opacity(
      opacity: cardOpacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isCompleted
                          ? completedColor.withOpacity(0.3)
                          : (isLocked
                                ? AppColors.textSecondary.withOpacity(0.2)
                                : AppColors.border),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 4,
                            color: isCompleted
                                ? completedColor
                                : (isLocked
                                      ? AppColors.textSecondary.withOpacity(0.3)
                                      : color),
                          ),

                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: isCompleted
                                        ? [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: completedColor
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.check_circle_rounded,
                                                    color: completedColor,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'COMPLETED',
                                                    style: TextStyle(
                                                      color: completedColor,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: AppFonts.label,
                                                      letterSpacing: 0.8,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: completedColor
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.flash_on_rounded,
                                                    size: 13,
                                                    color:
                                                        AppColors.primaryDark,
                                                  ),
                                                  Text(
                                                    '+$xp XP',
                                                    style: TextStyle(
                                                      color:
                                                          AppColors.primaryDark,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: AppFonts.badge,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ]
                                        : [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    getTypeIcon(),
                                                    color: color,
                                                    size: 12,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    getTypeLabel(),
                                                    style: TextStyle(
                                                      color: color,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: AppFonts.label,
                                                      letterSpacing: 0.8,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryLight,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.flash_on_rounded,
                                                    size: 13,
                                                    color:
                                                        AppColors.primaryDark,
                                                  ),
                                                  Text(
                                                    "+$xp XP",
                                                    style: TextStyle(
                                                      color:
                                                          AppColors.primaryDark,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: AppFonts.badge,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                  ),
                                  const SizedBox(height: 10),

                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: AppFonts.button,
                                      color: AppColors.textPrimary,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  Text(
                                    desc,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: AppFonts.caption,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  Row(
                                    children: isCompleted
                                        ? [
                                            const Spacer(),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: completedColor
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.check_circle_rounded,
                                                    size: 14,
                                                    color: completedColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Done',
                                                    style: TextStyle(
                                                      color: completedColor,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: AppFonts.badge,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ]
                                        : [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.background,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.access_time_rounded,
                                                    size: 13,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '$durationMinutes min',
                                                    style: TextStyle(
                                                      color: AppColors
                                                          .textSecondary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: AppFonts.badge,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Spacer(),
                                            TextButton.icon(
                                              onPressed: () async {
                                                final confirmed =
                                                    await AppDialogs.confirm(
                                                      title:
                                                          'Reroll this quest?',
                                                      message:
                                                          'This will generate a new task for the same skill.',
                                                      confirmLabel: 'Reroll',
                                                    );

                                                if (confirmed != true) return;

                                                final didReroll =
                                                    await controller
                                                        .rerollQuestWithGemini(
                                                          questId,
                                                        );

                                                if (didReroll) {
                                                  AppDialogs.success(
                                                    'Quest rerolled',
                                                    'The new quest version has been saved.',
                                                  );
                                                } else {
                                                  AppDialogs.error(
                                                    'Reroll unavailable',
                                                    'Unable to reroll this quest right now',
                                                  );
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.casino_rounded,
                                                size: 16,
                                              ),
                                              label: Text(
                                                'Reroll',
                                                style: TextStyle(
                                                  fontSize: AppFonts.caption,
                                                ),
                                              ),
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.textSecondary,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                            ),
                                          ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
