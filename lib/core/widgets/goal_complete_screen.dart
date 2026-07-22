import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:get/get.dart';

import '../../app/controllers/home_controller.dart';
import '../../app/controllers/onboarding_controller.dart';
import '../../app/routes/app_routes.dart';
import '../constants/color_constants.dart';
import '../constants/font_constants.dart';
import '../constants/asset_constants.dart';
import 'video_loader.dart';

class GoalCompleteScreen extends StatefulWidget {
  const GoalCompleteScreen({super.key});

  @override
  State<GoalCompleteScreen> createState() => _GoalCompleteScreenState();
}

class _GoalCompleteScreenState extends State<GoalCompleteScreen> {
  late final List<ConfettiController> _confettiControllers;
  bool _isCelebrating = false;

  @override
  void initState() {
    super.initState();
    _confettiControllers = List.generate(
      4,
      (_) => ConfettiController(duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    for (final controller in _confettiControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeController = Get.find<HomeController>();
    final plan = homeController.user.value?.currentPlan;
    final uid = _safeString(() => homeController.user.value?.id);
    final hobby = _safeString(() => plan?.hobby);
    final storedCategory = _safeString(() => plan?.category);
    final category = storedCategory.isNotEmpty ? storedCategory : hobby;
    final learningPace = _safeString(() => plan?.learningPace);
    final goalLevel = _safeString(() => plan?.level);
    final goal = _safeString(() => plan?.goal);
    final planId = _safeString(() => plan?.id);
    final quests = plan?.quests ?? const [];
    final completedQuests = quests.where((quest) => quest.isCompleted).toList();
    final completionDates =
        completedQuests
            .map((quest) => quest.completedAt)
            .whereType<DateTime>()
            .toList()
          ..sort();
    final startedAt = completionDates.isEmpty ? null : completionDates.first;
    final completedAt = completionDates.isEmpty ? null : completionDates.last;
    final totalTime = startedAt == null || completedAt == null
        ? 'Unavailable'
        : _formatElapsed(completedAt.difference(startedAt));
    final earnedXP = completedQuests.fold<int>(
      0,
      (total, quest) =>
          total +
          (quest.awardedXP ??
              quest.xpReward +
                  ((quest.imageUrl?.trim().isNotEmpty ?? false) ? 50 : 0)),
    );
    final activeLearningDays = completionDates
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet()
        .length;
    final completedMilestones =
        plan?.milestones.where((milestone) => milestone.completed).length ?? 0;
    final totalMilestones = plan?.milestones.length ?? 0;
    final longestStreak = _calculateLongestStreak(completionDates);
    final startingXP = plan?.startingXP ?? 0;
    final startingLevel = (startingXP ~/ 1000) + 1;
    final finalLevel = ((startingXP + earnedXP) ~/ 1000) + 1;
    final photoSubmissions = completedQuests.where((quest) {
      return quest.imageUrl?.trim().isNotEmpty ?? false;
    }).length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Column(
                children: [
                  const VideoLoader(
                    size: 190,
                    videoAsset: AppAssets.foxJumpVideo,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Goal Complete!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppFonts.titlePage,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primaryLight),
                    ),
                    child: Column(
                      children: [
                        Text(
                          goal.isNotEmpty
                              ? goal
                              : hobby.isNotEmpty
                              ? 'Complete my $hobby learning plan'
                              : 'Complete my learning plan',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: AppFonts.title,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                        if (startedAt != null && completedAt != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            '${_formatDate(startedAt)} - ${_formatDate(completedAt)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: AppFonts.caption,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _PlanDetailChip(
                                label: category.isEmpty
                                    ? 'Uncategorized'
                                    : category,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 28,
                              color: AppColors.primaryLight,
                            ),
                            Expanded(
                              child: _PlanDetailChip(
                                label: learningPace.isEmpty
                                    ? 'Unavailable'
                                    : learningPace,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 28,
                              color: AppColors.primaryLight,
                            ),
                            Expanded(
                              child: _PlanDetailChip(
                                label: goalLevel.isEmpty
                                    ? 'Unavailable'
                                    : goalLevel,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                    children: [
                      _CompletionStat(
                        icon: Icons.timer_outlined,
                        value: totalTime,
                        label: 'Total time taken',
                      ),
                      _CompletionStat(
                        icon: Icons.task_alt_rounded,
                        value: '${completedQuests.length}',
                        label: 'Quests completed',
                      ),
                      _CompletionStat(
                        icon: Icons.bolt_rounded,
                        value: '$earnedXP',
                        label: 'XP earned',
                      ),
                      _CompletionStat(
                        icon: Icons.calendar_today_rounded,
                        value: '$activeLearningDays',
                        label: 'Active learning days',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _AchievementRow(
                          icon: Icons.emoji_events_outlined,
                          label: 'Milestones complete',
                          value: '$completedMilestones/$totalMilestones',
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _AchievementRow(
                          icon: Icons.local_fire_department_outlined,
                          label: 'Longest streak',
                          value:
                              '$longestStreak ${longestStreak == 1 ? 'day' : 'days'}',
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _AchievementRow(
                          icon: Icons.trending_up_rounded,
                          label: 'Levels gained',
                          value: 'Lvl $startingLevel -> Lvl $finalLevel',
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _AchievementRow(
                          icon: Icons.photo_camera_outlined,
                          label: 'Photo submissions',
                          value: '$photoSubmissions',
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _TreeOutcomeRow(
                          uid: uid,
                          planId: planId,
                          startedAt: startedAt,
                          completedAt: completedAt,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Choose a new goal to keep building your path.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppFonts.bodyLg,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isCelebrating ? null : _onChooseNewGoal,
                      icon: const Icon(Icons.flag_rounded, size: 20),
                      label: const Text('Choose New Goal'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: AppFonts.button,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildConfetti(Alignment.topLeft, _confettiControllers[0]),
          _buildConfetti(Alignment.topRight, _confettiControllers[1]),
          _buildConfetti(Alignment.bottomLeft, _confettiControllers[2]),
          _buildConfetti(Alignment.bottomRight, _confettiControllers[3]),
        ],
      ),
    );
  }

  Future<void> _onChooseNewGoal() async {
    setState(() => _isCelebrating = true);
    for (final controller in _confettiControllers) {
      controller.play();
    }
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    if (Get.isRegistered<OnboardingController>()) {
      Get.delete<OnboardingController>(force: true);
    }
    final currentUser = Get.find<HomeController>().user.value;
    Get.offAllNamed(
      AppRoutes.ONBOARDING,
      arguments: {
        'startPage': 1,
        'nickname': _safeString(() => currentUser?.nickname),
        'birthDate': _safeString(() => currentUser?.birthDate),
        'gender': _safeString(() => currentUser?.gender),
        'avatarSvg': _safeString(() => currentUser?.avatarSvg),
      },
    );
  }

  Widget _buildConfetti(Alignment alignment, ConfettiController controller) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: ConfettiWidget(
          confettiController: controller,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: AppColors.celebration,
          numberOfParticles: 20,
          gravity: 0.15,
        ),
      ),
    );
  }

  static String _safeString(Object? Function() read) {
    try {
      return read()?.toString().trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static String _formatElapsed(Duration duration) {
    final totalMinutes = duration.inMinutes;
    if (totalMinutes < 1) return '< 1 min';

    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = totalMinutes.remainder(60);
    if (days > 0) {
      return hours > 0 ? '${days}d ${hours}h' : '${days}d';
    }
    if (duration.inHours > 0) {
      return minutes > 0
          ? '${duration.inHours}h ${minutes}m'
          : '${duration.inHours}h';
    }
    return '${minutes}m';
  }

  static int _calculateLongestStreak(List<DateTime> dates) {
    final days =
        dates
            .map((date) => DateTime(date.year, date.month, date.day))
            .toSet()
            .toList()
          ..sort();
    if (days.isEmpty) return 0;

    var longest = 1;
    var current = 1;
    for (var index = 1; index < days.length; index++) {
      if (days[index].difference(days[index - 1]).inDays == 1) {
        current += 1;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }
}

class _PlanDetailChip extends StatelessWidget {
  final String label;

  const _PlanDetailChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                fontSize: AppFonts.micro,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _CompletionStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.softShadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryDark, size: 20),
          ),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: AppFonts.title,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppFonts.micro,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AchievementRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: AppFonts.caption,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: AppFonts.caption,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TreeOutcomeRow extends StatelessWidget {
  final String uid;
  final String planId;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const _TreeOutcomeRow({
    required this.uid,
    required this.planId,
    required this.startedAt,
    required this.completedAt,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _loadTreeCount(),
      builder: (context, snapshot) {
        final count = snapshot.data;
        return _AchievementRow(
          icon: Icons.park_outlined,
          label: 'Tree outcome',
          value: count == null
              ? 'Loading...'
              : '$count ${count == 1 ? 'tree' : 'trees'} planted',
        );
      },
    );
  }

  Future<int> _loadTreeCount() async {
    if (uid.isEmpty) return 0;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tree')
        .get();

    return snapshot.docs.where((doc) {
      final data = doc.data();
      final savedPlanId = data['planId'] as String? ?? '';
      if (planId.isNotEmpty && savedPlanId == planId) return true;
      if (savedPlanId.isNotEmpty || startedAt == null || completedAt == null) {
        return false;
      }

      final rawDate = data['grownAt'] ?? data['createdAt'];
      final grownAt = rawDate is Timestamp
          ? rawDate.toDate()
          : rawDate is DateTime
          ? rawDate
          : null;
      return grownAt != null &&
          !grownAt.isBefore(startedAt!) &&
          !grownAt.isAfter(completedAt!);
    }).length;
  }
}
