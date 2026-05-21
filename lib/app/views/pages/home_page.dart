import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/progression_controller.dart';
import '../../models/quest_model.dart';
import '../../routes/app_routes.dart';
import '../../../core/constants/color_constants.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // -------------------------------------------------------------------------
    // CONTROLLER INJECTION
    // We use Get.put() here to ensure the controller is created when this 
    // tab is first viewed. 
    // -------------------------------------------------------------------------
    final HomeController controller = Get.put(HomeController());
    final ProgressionController progressionController = Get.put(ProgressionController());

    // -------------------------------------------------------------------------
    // MAIN LAYOUT
    // Note: No Scaffold here. The Scaffold is provided by 'DashboardPage'.
    // We use SafeArea to ensure content doesn't hide behind the notch/status bar.
    // -------------------------------------------------------------------------
    return SafeArea(
      child: Column(
        children: [
          
          // ZONE 1: HERO'S HUD (Fixed at top)
          // Displays Level, Avatar, and XP Bar.
          _buildHeroHud(context, controller),

          // ZONE 2: SCROLLABLE CONTENT
          // Uses Expanded to fill the remaining space between the HUD 
          // and the Bottom Navigation Bar (which is in DashboardPage).
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(), // "Game feel" bounce effect
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  // MENTOR BUBBLE
                  // Provides context/encouragement (Gamification: Relatedness)
                  Obx(() {
                    if (!controller.showMentorBubble.value) {
                      return const SizedBox.shrink();
                    }

                    final message = "Keep it up ${controller.nickname.value}! 🔥 You're at Level ${progressionController.currentLevel}. ${progressionController.xpToNextLevel} XP to the next level.";
                    return GestureDetector(
                      onTap: () {
                        controller.dismissMentorBubbleForToday();
                      },
                      child: _buildMascotContextBubble(message),
                    );
                  }),
                  Obx(() => controller.showMentorBubble.value
                      ? const SizedBox(height: 20)
                      : const SizedBox.shrink()),

                  // NOTE: The `CURRENT GOAL` display was moved into the
                  // hero HUD so it remains visible while scrolling.
                  const SizedBox(height: 16),

                  // HORIZONTAL MILESTONES STRIP
                  Obx(() {
                    final milestones = controller.user.value?.currentPlan?.milestones ?? <dynamic>[];
                    final int currentIndex = milestones.indexWhere((m) => !(m.completed ?? false));
                    final int activeMilestoneIndex = currentIndex >= 0
                        ? currentIndex
                        : (milestones.isNotEmpty ? milestones.length - 1 : -1);
                    final List<int> otherMilestoneIndices = List<int>.generate(
                      milestones.length,
                      (i) => i,
                    ).where((i) => i != activeMilestoneIndex).toList();
                    final String currentTitle = controller.currentMilestoneTitle;

                    return SizedBox(
                      height: 104,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        itemCount: 1 + otherMilestoneIndices.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (ctx, idx) {
                          if (idx == 0) {
                            // Always-showing current milestone card
                            return Container(
                              width: 280,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primaryLight),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CURRENT MILESTONE',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Text(
                                      currentTitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final int mIdx = otherMilestoneIndices[idx - 1];
                          final milestone = milestones[mIdx];
                          final bool completed = (milestone.completed ?? false);

                          return Container(
                            width: 84,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: completed ? AppColors.primaryLight : AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primaryLight),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                completed
                                    ? const Icon(Icons.check_circle, color: AppColors.success, size: 22)
                                    : const Icon(Icons.lock, color: AppColors.textSecondary, size: 22),
                                const SizedBox(height: 8),
                                Text(
                                  'M${mIdx + 1}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  // MISSION LOG HEADER
                  Obx(() => Text(
                    "MISSION LOG (${controller.completedTodayCount}/3)",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: AppColors.textPrimary,
                    ),
                  )),
                  const SizedBox(height: 12),

                  // DYNAMIC QUEST LIST
                  // We wrap this in Obx() so it updates instantly when
                  // the controller changes data (e.g., after a reroll).
                  Obx(() {
                    if (controller.hasCompletedDailyLimit) {
                      return _buildDailySuccessState();
                    }

                    return Column(
                      children: controller.dailyQuests.map((quest) {
                        return _buildQuestCard(
                          context,
                          quest: quest,
                          title: quest.title,
                          desc: quest.desc,
                          xp: quest.xp,
                          type: quest.type, // 'practice', 'knowledge', 'challenge'
                          isPriority: quest.isPriority,
                          isCompleted: quest.isCompleted,
                          reflectionNote: quest.reflectionNote,
                          onTap: () {
                            Get.toNamed(
                              AppRoutes.QUEST_DETAIL,
                              arguments: quest,
                            );
                          },
                        );
                      }).toList(),
                    );
                  }),

                  // Bottom Padding to ensure scrolling clears the floating elements
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGET BUILDERS (Private helper methods for cleaner code)
  // ---------------------------------------------------------------------------

  Widget _buildHeroHud(BuildContext context, HomeController controller) {
    final progressionController = Get.find<ProgressionController>();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA500),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Obx(() {
            final hobbyTitle = controller.selectedHobby.value.trim().isNotEmpty
                ? controller.selectedHobby.value.trim()
                : 'Choose Hobby';

            final goalTitle = controller.userGoal.value.trim().isNotEmpty
                ? controller.userGoal.value.trim()
                : (controller.selectedHobby.value.isNotEmpty
                    ? 'Master ${controller.selectedHobby.value}'
                    : 'Your Current Goal');

            final streak = progressionController.streak.value;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildHeaderChip(
                              context,
                              value: hobbyTitle,
                              backgroundColor: AppColors.secondary,
                              foregroundColor: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildHeaderChip(
                              context,
                              value: goalTitle,
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progressionController.levelProgress,
                              minHeight: 10,
                              backgroundColor: AppColors.background,
                              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${progressionController.currentXpInLevel} / 1000 XP",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textOnPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'L${progressionController.currentLevel}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B35).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$streak',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderChip(
    BuildContext context, {
    required String value,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMascotContextBubble(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Using a very light tint of the primary color for harmony
        color: AppColors.primaryLight.withOpacity(0.2), 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3), 
          width: 1
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.sentiment_very_satisfied_rounded, 
            size: 32, 
            color: AppColors.primary
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary, 
                fontWeight: FontWeight.w600
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestCard(BuildContext context, {
    required QuestModel quest,
    required String title,
    required String desc,
    required int xp,
    required String type,
    required VoidCallback onTap,
    bool isPriority = false,
    bool isCompleted = false,
    String reflectionNote = '',
  }) {
    // Helper to get color based on type string
    Color getTypeColor() {
      switch (type) {
        case 'knowledge': return AppColors.accent; // Blue
        case 'practice': return AppColors.success; // Green
        case 'challenge': return Colors.purple;
        default: return Colors.grey;
      }
    }

    // Helper to get icon based on type string
    IconData getTypeIcon() {
      switch (type) {
        case 'knowledge': return Icons.menu_book_rounded;
        case 'practice': return Icons.timer_rounded;
        case 'challenge': return Icons.camera_alt_rounded;
        default: return Icons.task_alt_rounded;
      }
    }

    final color = getTypeColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isCompleted ? null : onTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.success.withOpacity(0.08) : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: isPriority
                      ? Border.all(color: AppColors.primary.withOpacity(0.5), width: 2)
                      : Border.all(color: AppColors.background), // Subtle border
                  boxShadow: [
                    BoxShadow(
                      color: isPriority 
                          ? AppColors.primary.withOpacity(0.1) 
                          : Colors.black.withOpacity(0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    // TYPE ICON
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(getTypeIcon(), color: color),
                    ),
                    const SizedBox(width: 16),

                    // TEXT CONTENT
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 16,
                              color: AppColors.textPrimary
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            desc,
                            style: const TextStyle(
                              color: AppColors.textSecondary, 
                              fontSize: 13
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isCompleted
                                ? (reflectionNote.isNotEmpty ? 'Reflection: $reflectionNote' : 'Completed')
                                : 'Tap to complete and add a reflection later.',
                            style: TextStyle(
                              color: isCompleted ? AppColors.success : AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // REWARD PILL
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "+$xp XP",
                        style: const TextStyle(
                          color: AppColors.primaryDark, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 12
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // REROLL BUTTON (Top-right corner)
          Positioned(
            top: 8,
            right: 8,
            child: Obx(() {
              final controller = Get.find<HomeController>();
              return Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (controller.hasUsedRerollToday || isCompleted)
                      ? AppColors.background
                      : AppColors.primaryLight.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (controller.hasUsedRerollToday || isCompleted)
                        ? AppColors.background
                        : AppColors.primary.withOpacity(0.3),
                  ),
                ),
                child: IconButton(
                  tooltip: controller.hasUsedRerollToday
                      ? 'Reroll already used today'
                      : isCompleted
                          ? 'Cannot reroll completed quest'
                          : 'Reroll this quest',
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: (controller.hasUsedRerollToday || isCompleted)
                      ? null
                      : () async {
                          final confirmed = await Get.dialog<bool>(
                                AlertDialog(
                                  title: const Text('Use Daily Reroll?'),
                                  content: const Text(
                                    'Are you sure? You can only swap out one quest per day!',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Get.back(result: false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => Get.back(result: true),
                                      icon: const Icon(Icons.casino_rounded, size: 16),
                                      label: const Text('Swap Quest'),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;

                          if (!confirmed) {
                            return;
                          }

                          final error = await controller.rerollOneQuestForToday(quest);
                          if (error != null) {
                            Get.snackbar(
                              'Reroll Failed',
                              error,
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          }
                        },
                  icon: Icon(
                    Icons.casino_rounded,
                    color: (controller.hasUsedRerollToday || isCompleted)
                        ? AppColors.textSecondary
                        : AppColors.primaryDark,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySuccessState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF5E6), Color(0xFFEFFAF1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.success.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: AppColors.primaryDark, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Incredible work today! 🌟',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            "Your brain needs time to absorb what you've learned. Review your past projects below, or come back tomorrow for your next 3 challenges.",
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}