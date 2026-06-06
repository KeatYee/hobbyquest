import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/progression_controller.dart';
import '../../routes/app_routes.dart';
import '../../../core/constants/color_constants.dart';

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

    return SafeArea(
      child: Column(
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

                  // MENTOR BUBBLE
                  Obx(() {
                    final message =
                        "Keep it up ${controller.nickname.value}! You're at Level ${progressionController.currentLevel}. ${progressionController.xpToNextLevel} XP to the next level.";
                    return _buildMascotContextBubble(message);
                  }),
                  const SizedBox(height: 20),

                  // NEXT SKILL TARGET
                  _buildNextSkillTarget(controller),
                  const SizedBox(height: 28),

                  // MISSION LOG HEADER
                  _buildSectionHeader("MISSION LOG"),
                  const SizedBox(height: 14),

                  // DYNAMIC QUEST LIST
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

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  HERO HUD
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeroHud(BuildContext context, HomeController controller) {
    final progressionController = Get.find<ProgressionController>();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
          // Decorative background circles
          Positioned(
            right: -8,
            top: -4,
            child: _HudCircle(size: 88, opacity: 0.08),
          ),
          Positioned(
            right: 52,
            bottom: 0,
            child: _HudCircle(size: 44, opacity: 0.05),
          ),

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
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textShadow,
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Obx(() {
                      final avatarSvg = controller.avatarSvg.value;
                      return CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.primaryLight,
                        child: avatarSvg.isNotEmpty
                            ? ClipOval(
                                child: SvgPicture.string(
                                  avatarSvg,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
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
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: AppColors.textOnPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
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
                                size: 14,
                              ),
                              const SizedBox(width: 3),
                              Obx(
                                () => Text(
                                  "${progressionController.streak.value} day${progressionController.streak.value == 1 ? '' : 's'}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
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
                      () => Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 13,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "Learning: ${controller.hobby.value}",
                            style: TextStyle(
                              color: AppColors.textOnPrimary.withOpacity(0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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
                        "${progressionController.currentXpInLevel} / 1000 XP  ·  Level ${progressionController.currentLevel + 1} soon",
                        style: TextStyle(
                          color: AppColors.textOnPrimary.withOpacity(0.78),
                          fontSize: 11,
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
  //  MASCOT BUBBLE
  // ─────────────────────────────────────────────────────────────
  Widget _buildMascotContextBubble(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 22,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "MENTOR",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
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

  // ─────────────────────────────────────────────────────────────
  //  NEXT SKILL TARGET — UNCHANGED logic, refined UI
  // ─────────────────────────────────────────────────────────────
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
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.gold],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lock_open_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "NEXT SKILL UNLOCK",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Obx(
                    () => Text(
                      getNextSkill(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
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
              size: 15,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  SECTION HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String label) {
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
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.5,
            color: AppColors.textPrimary,
          ),
        ),
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
    required VoidCallback onTap,
  }) {
    // Helper to get color based on type string — UNCHANGED logic
    Color getTypeColor() {
      switch (type) {
        case 'knowledge':
          return AppColors.accent;
        case 'practice':
          return AppColors.success;
        case 'challenge':
          return AppColors.info; // original Colors.purple, no AppColors purple
        default:
          return AppColors.textSecondary;
      }
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textShadow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            // ClipRRect so the left accent bar respects rounded corners
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Coloured left accent bar ───────────
                    Container(width: 4, color: color),

                    // ── Card body ─────────────────────────
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 14, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // TOP ROW: type chip + XP pill
                            Row(
                              children: [
                                // Type chip
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
                                          fontSize: 10,
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
                                        style: const TextStyle(
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // DESCRIPTION
                            Text(
                              desc,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // BOTTOM ROW: duration chip + reroll
                            Row(
                              children: [
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
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                // REROLL BUTTON — UNCHANGED logic
                                TextButton.icon(
                                  onPressed: () async {
                                    final confirmed =
                                        await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        title: const Text(
                                            'Reroll this quest?'),
                                        content: const Text(
                                          'This will generate a new task for the same skill.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx)
                                                    .pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(true),
                                            child: const Text('Reroll'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed != true) return;

                                    final didReroll = await controller
                                        .rerollQuestWithGemini(questId);

                                    if (didReroll) {
                                      Get.snackbar(
                                        'Quest rerolled',
                                        'The new quest version has been saved.',
                                        backgroundColor: AppColors.success,
                                        colorText: AppColors.textOnPrimary,
                                      );
                                    } else {
                                      Get.snackbar(
                                        'Reroll unavailable',
                                        'Unable to reroll this quest right now',
                                        backgroundColor: AppColors.error,
                                        colorText: AppColors.textOnPrimary,
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.casino_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Reroll',
                                    style: TextStyle(fontSize: 13),
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
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  Helper widget: decorative circle in the HUD
// ═══════════════════════════════════════════════
class _HudCircle extends StatelessWidget {
  final double size;
  final double opacity;
  const _HudCircle({required this.size, required this.opacity});

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