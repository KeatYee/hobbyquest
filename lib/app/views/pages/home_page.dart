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
import '../widgets/shaking_mailbox_button.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // ─────────────────────────────────────────────────────────────
  //  ROOT
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // ── Controller injection — UNCHANGED ──────────────────────
    final HomeController controller = Get.put(HomeController());
    final ProgressionController progressionController = Get.put(
      ProgressionController(),
    );

    return Column(
        children: [
          // ZONE 1: HERO HUD (fixed at top)
          _buildHeroHud(context, controller),

          // ZONE 2: SCROLLABLE CONTENT
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // MILESTONE PROGRESS
                  _buildMilestoneProgress(controller),

                  const SizedBox(height: 24),

                  // MISSION LOG HEADER
                  _buildSectionHeader(
                    "MISSION LOG",
                    trailing: _buildGrowthLetterButton(controller),
                  ),
                  const SizedBox(height: 14),

                  // ACTIVE / LOCKED QUESTS (non-completed)
                  Obx(
                    () => Column(
                      children: controller.dailyQuests
                          .where((q) => !q.isCompleted)
                          .map((quest) {
                        final isLocked = !quest.isActive && !quest.isCompleted;
                        final isCompleted = quest.isCompleted;
                        return _buildQuestCard(
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
                          onTap: isLocked || isCompleted
                              ? null
                              : () {
                                  Get.toNamed(
                                    AppRoutes.QUEST_DETAIL,
                                    arguments: quest,
                                  );
                                },
                        );
                      }).toList(),
                    ),
                  ),

                  // COMPLETED QUESTS (collapsible)
                  _buildCompletedSection(context, controller),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      );
  }

  // ─────────────────────────────────────────────────────────────
  //  HERO HUD
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeroHud(BuildContext context, HomeController controller) {
    final progressionController = Get.find<ProgressionController>();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.accent],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main content
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── AVATAR + LEVEL BADGE ──────────────────────
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.textOnPrimary,
                        width: 2.5,
                      ),
                    ),
                      child: Obx(() {
                      final avatarPath = controller.avatarSvg.value;
                      return CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.primaryLight,
                        child: avatarPath.isNotEmpty
                            ? ClipOval(
                                child: Image.asset(
                                  avatarPath,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                ),
                              )
                            : const Icon(
                                Icons.person_rounded,
                                color: AppColors.textOnPrimary,
                                size: 30,
                              ),
                      );
                    }),
                  ),
                  // Level badge — uses secondary (gold) so it pops on orange
                  Obx(
                    () => Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.textOnPrimary,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        "${progressionController.currentLevel}",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: AppFonts.micro,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // ── STATS COLUMN ──────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nickname + streak pill
                    Row(
                      children: [
                        Expanded(
                          child: Obx(
                            () => Text(
                              controller.nickname.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: AppFonts.title,
                                color: AppColors.textOnPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textOnPrimary.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department_rounded,
                                color: AppColors.secondary,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Obx(
                                () => Text(
                                  "${progressionController.streak.value} day${progressionController.streak.value == 1 ? '' : 's'}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: AppFonts.caption,
                                    color: AppColors.textOnPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Hobby label
                    Obx(
                      () => Text(
                        controller.hobby.value,
                        style: TextStyle(
                          color: AppColors.textOnPrimary.withOpacity(0.85),
                          fontSize: AppFonts.badge,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // XP BAR — uses secondary (gold) fill on semi-transparent track
                    Obx(
                      () => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progressionController.levelProgress,
                          minHeight: 8,
                          backgroundColor:
                              AppColors.textOnPrimary.withOpacity(0.25),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.secondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),

                    // XP TEXT
                    Obx(
                      () => Text(
                        "${progressionController.currentXpInLevel} / 1000 XP",
                        style: TextStyle(
                          color: AppColors.textOnPrimary.withOpacity(0.78),
                          fontSize: AppFonts.micro,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  MILESTONE PROGRESS
  // ─────────────────────────────────────────────────────────────
  Widget _buildGrowthLetterButton(HomeController controller) {
    return Obx(
      () => ShakingMailboxButton(
        isShaking: controller.hasAvailableGrowthLetter.value,
        onTap: () => Get.toNamed(AppRoutes.GROWTH_LETTER),
      ),
    );
  }

  Widget _buildMilestoneProgress(HomeController controller) {
    return Obx(() {
      final plan = controller.user.value?.currentPlan;
      if (plan == null || plan.milestones.isEmpty) return const SizedBox.shrink();

      final index = plan.currentMilestoneIndex;
      final total = plan.milestones.length;
      final milestone = plan.milestones[index];
      final progress = ((index + 1) / total);

      // Calculate quest completion ratio for this milestone
      final quests = plan.quests;
      final completedQuests = quests.where((q) => q.isCompleted).length;
      final totalQuests = quests.length;

      return InkWell(
        onTap: () => _showGoalInfo(plan),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
          children: [
            // Milestone icon
            Container(
              width: 40,
              height: 40,
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row: milestone name + fraction
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Phase ${index + 1}: ${milestone.title}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: AppFonts.caption,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${index + 1}/$total',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: AppFonts.micro,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completedQuests/$totalQuests quests completed',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: AppFonts.micro,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      );
    });
  }

  void _showGoalInfo(QuestPlanModel plan) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Goal title
              const Text(
                'My Goal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                plan.goal,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              // Hobby & Level
              Row(
                children: [
                  _infoChip(
                    Icons.auto_awesome_rounded,
                    plan.hobby,
                  ),
                  const SizedBox(width: 8),
                  _infoChip(
                    Icons.trending_up_rounded,
                    plan.level,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _infoChip(
                Icons.schedule_rounded,
                plan.frequency,
              ),
              const SizedBox(height: 20),
              // Milestones header
              const Text(
                'Milestones',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              ...plan.milestones.map((m) => _milestoneRow(m, plan)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
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
              fontSize: 12,
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
                  : (isCurrent
                      ? AppColors.primary
                      : AppColors.border),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isCurrent ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              m.title,
              style: TextStyle(
                fontSize: 13,
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
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  COMPLETED QUESTS SECTION (collapsible)
  // ─────────────────────────────────────────────────────────────
  Widget _buildCompletedSection(BuildContext context, HomeController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tappable header
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
                Obx(() => AnimatedRotation(
                  turns: controller.isCompletedExpanded.value ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                )),
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
                .map((quest) => _buildQuestCard(
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
                )).toList(),
          );
        }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  SECTION HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String label, {Widget? trailing}) {
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
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  QUEST CARD — UNCHANGED logic, redesigned layout
  // ─────────────────────────────────────────────────────────────
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

    // Consistent card accent color regardless of quest type
    Color getTypeColor() {
      return AppColors.primary;
    }

    // Helper to get icon based on type string — UNCHANGED
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
    final cardOpacity = isLocked
        ? 0.45
        : (isCompleted ? 0.7 : 1.0);
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
                  // ClipRRect so the left accent bar respects rounded corners
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Coloured left accent bar ───────────
                          Container(
                            width: 4,
                            color: isCompleted
                                ? completedColor
                                : (isLocked
                                    ? AppColors.textSecondary.withOpacity(0.3)
                                    : color),
                          ),

                          // ── Card body ─────────────────────────
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 14, 16, 12),
                              child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // TOP ROW: type chip + XP pill (or completed badge)
                            Row(
                              children: isCompleted
                                  ? [
                                      // Completed badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: completedColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
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
                                                fontWeight: FontWeight.w800,
                                                fontSize: AppFonts.label,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      // XP earned pill
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: completedColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.flash_on_rounded,
                                              size: 13,
                                              color: AppColors.primaryDark,
                                            ),
                                            Text(
                                              '+$xp XP',
                                              style: TextStyle(
                                                color: AppColors.primaryDark,
                                                fontWeight: FontWeight.w800,
                                                fontSize: AppFonts.badge,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ]
                                  : [
                                      // Type chip (normal or locked)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
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
                                          fontWeight: FontWeight.w800,
                                          fontSize: AppFonts.label,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                // XP reward pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.flash_on_rounded,
                                        size: 13,
                                        color: AppColors.primaryDark,
                                      ),
                                      Text(
                                        "+$xp XP",
                                        style: TextStyle(
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.w800,
                                          fontSize: AppFonts.badge,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // TITLE
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

                            // DESCRIPTION
                            Text(
                              desc,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: AppFonts.caption,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // BOTTOM ROW: duration chip + reroll (or done badge)
                            Row(
                              children: isCompleted
                                  ? [
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: completedColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
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
                                                fontWeight: FontWeight.w700,
                                                fontSize: AppFonts.badge,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ]
                                  : [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.access_time_rounded,
                                              size: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$durationMinutes min',
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: AppFonts.badge,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      // REROLL BUTTON — unchanged except hidden when locked
                                      TextButton.icon(
                                  onPressed: () async {
                                    final confirmed = await AppDialogs.confirm(
                                      title: 'Reroll this quest?',
                                      message: 'This will generate a new task for the same skill.',
                                      confirmLabel: 'Reroll',
                                    );

                                    if (confirmed != true) return;

                                    final didReroll = await controller
                                        .rerollQuestWithGemini(questId);

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
                                    style: TextStyle(fontSize: AppFonts.caption),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.textSecondary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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

// ═══════════════════════════════════════════════
// ═══════════════════════════════════════════════
