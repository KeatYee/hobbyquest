import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/progression_controller.dart';
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
    final ProgressionController progressionController = Get.put(
      ProgressionController(),
    );

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
              physics:
                  const BouncingScrollPhysics(), // "Game feel" bounce effect
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  // MENTOR BUBBLE
                  // Provides context/encouragement (Gamification: Relatedness)
                  Obx(() {
                    final message =
                        "Keep it up ${controller.nickname.value}! You're at Level ${progressionController.currentLevel}. ${progressionController.xpToNextLevel} XP to the next level.";
                    return _buildMascotContextBubble(message);
                  }),
                  const SizedBox(height: 20),

                  // NEXT SKILL TARGET
                  // Visualizes the immediate long-term goal.
                  _buildNextSkillTarget(controller),
                  const SizedBox(height: 30),

                  // MISSION LOG HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "MISSION LOG",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // DYNAMIC QUEST LIST
                  // We wrap this in Obx() so it updates instantly when
                  // the controller changes data (e.g., after a reroll).
                  Obx(
                    () => Column(
                      children: controller.dailyQuests.map((quest) {
                        return _buildQuestCard(
                          context,
                          controller: controller,
                          title: quest.title,
                          desc: quest.desc,
                          xp: quest.xpReward,
                          durationMinutes: quest.durationMinutes,
                          type: quest.type,
                          questId: quest.nodeId,
                          onTap: () {
                            Get.toNamed(
                              AppRoutes.QUEST_DETAIL,
                              arguments: quest,
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),

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
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // AVATAR & LEVEL BADGE
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: Obx(() {
                  final avatarSvg = controller.avatarSvg.value;

                  return CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.background,
                    child: avatarSvg.isNotEmpty
                        ? ClipOval(
                            child: SvgPicture.string(
                              avatarSvg,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            color: AppColors.textSecondary,
                          ),
                  );
                }),
              ),
              // Reactive Level Badge
              Obx(
                () => Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    "${progressionController.currentLevel}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // STATS COLUMN
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Dynamic User Nickname
                    Expanded(
                      child: Obx(
                        () => Text(
                          controller.nickname.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: AppColors.primaryDark,
                      size: 20,
                    ),
                    Flexible(
                      child: Obx(
                        () => Text(
                          " ${progressionController.streak.value} day${progressionController.streak.value == 1 ? '' : 's'}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Dynamic Hobby Display
                Obx(
                  () => Text(
                    "Learning: ${controller.hobby.value}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // REACTIVE XP BAR
                Obx(
                  () => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progressionController.levelProgress,
                      minHeight: 10,
                      backgroundColor: AppColors.background,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // REACTIVE XP TEXT
                Obx(
                  () => Text(
                    "${progressionController.currentXpInLevel} / 1000 XP to Level ${progressionController.currentLevel + 1}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
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
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sentiment_very_satisfied_rounded,
            size: 32,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextSkillTarget(HomeController controller) {
    final skillNames = {
      'Guitar': [
        'Open Chords',
        'Barre Chords',
        'Fingerpicking',
        'Sweep Picking',
      ],
      'Piano': [
        'C Major Scale',
        'Chord Progressions',
        'Two-Hand Coordination',
        'Improvisation',
      ],
      'Painting': [
        'Color Mixing',
        'Perspective',
        'Shadows & Highlights',
        'Composition',
      ],
      'Coding': [
        'Variables & Types',
        'Functions',
        'Objects & Classes',
        'Algorithms',
      ],
    };

    String getNextSkill() {
      final hobby = controller.hobby.value;
      final level = Get.find<ProgressionController>().currentLevel;
      final skills = skillNames[hobby] ?? ['Master $hobby'];
      return skills[(level - 1) % skills.length];
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.gold],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_open_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "NEXT SKILL UNLOCK",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Obx(
                    () => Text(
                      getNextSkill(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
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
    required VoidCallback onTap,
  }) {
    // Helper to get color based on type string
    Color getTypeColor() {
      switch (type) {
        case 'knowledge':
          return AppColors.accent; // Blue
        case 'practice':
          return AppColors.success; // Green
        case 'challenge':
          return Colors.purple;
        default:
          return Colors.grey;
      }
    }

    // Helper to get icon based on type string
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

    final color = getTypeColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                      color: AppColors.primary.withOpacity(0.5),
                      width: 2,
                    ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            desc,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // REWARD PILL
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "+$xp XP",
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$durationMinutes min',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Reroll this quest?'),
                            content: const Text(
                              'This will generate a new task for the same skill.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Reroll'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed != true) {
                          return;
                        }

                        final didReroll = await controller.rerollQuestWithGemini(
                          questId,
                        );

                        if (didReroll) {
                          Get.snackbar(
                            'Quest rerolled',
                            'The new quest version has been saved.',
                            backgroundColor: AppColors.success,
                            colorText: Colors.white,
                          );
                        } else {
                          Get.snackbar(
                            'Reroll unavailable',
                            'Unable to reroll this quest right now',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                        }
                      },
                      icon: const Icon(Icons.casino_rounded, size: 18),
                      label: const Text('Reroll'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
