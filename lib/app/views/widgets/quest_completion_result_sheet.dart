import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';
import '../../controllers/quest_detail_controller.dart';
import '../../models/tree_model.dart';

class QuestCompletionResultSheet extends StatefulWidget {
  final QuestCompletionOutcome outcome;
  final Future<void> Function() onShare;

  const QuestCompletionResultSheet({
    super.key,
    required this.outcome,
    required this.onShare,
  });

  static Future<void> show({
    required BuildContext context,
    required QuestCompletionOutcome outcome,
    required Future<void> Function() onShare,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Quest completion result',
      pageBuilder: (_, _, _) =>
          QuestCompletionResultSheet(outcome: outcome, onShare: onShare),
    );
  }

  @override
  State<QuestCompletionResultSheet> createState() =>
      _QuestCompletionResultSheetState();
}

class _QuestCompletionResultSheetState
    extends State<QuestCompletionResultSheet> {
  bool _isSharing = false;

  QuestCompletionOutcome get _outcome => widget.outcome;

  Future<void> _share() async {
    setState(() => _isSharing = true);
    try {
      await widget.onShare();
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocks = _buildUnlocks();

    return Semantics(
      label: 'Quest completion result',
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: AppColors.background,
          systemNavigationBarColor: AppColors.background,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'QUEST COMPLETE',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: AppFonts.label,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _outcome.completion.quest.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: AppFonts.title,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildXpCard(),
                  const SizedBox(height: 12),
                  _buildStreakRow(),
                  if (_outcome.hasCategoryProgress) ...[
                    const SizedBox(height: 12),
                    _buildTreeProgress(),
                  ],
                  const SizedBox(height: 22),
                  const Text(
                    'WHAT UNLOCKED',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFonts.label,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (unlocks.isEmpty)
                    _buildEmptyUnlockState()
                  else
                    ...unlocks.map(_buildUnlockRow),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSharing ? null : _share,
                      icon: _isSharing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.groups_rounded, size: 19),
                      label: Text(
                        _isSharing ? 'OPENING GUILD' : 'SHARE TO GUILD',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.borderStrong),
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: const Text('CONTINUE'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildXpCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.flash_on_rounded,
            color: AppColors.textOnPrimary,
            size: 29,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+${_outcome.completion.awardedXP} XP',
                  style: const TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: AppFonts.titleLg,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${_outcome.completion.updatedTotalXP} total XP',
                  style: TextStyle(
                    color: AppColors.textOnPrimary.withValues(alpha: 0.86),
                    fontSize: AppFonts.caption,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'EARNED',
            style: TextStyle(
              color: AppColors.textOnPrimary,
              fontSize: AppFonts.label,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakRow() {
    final streak = _outcome.completion.updatedStreak;
    final status = streak > _outcome.previousStreak
        ? _outcome.previousStreak == 0
              ? 'New streak started'
              : 'Streak extended'
        : 'Streak maintained today';

    return _buildInfoCard(
      icon: Icons.local_fire_department_rounded,
      iconColor: AppColors.secondary,
      title: '$streak-day streak',
      subtitle: status,
    );
  }

  Widget _buildTreeProgress() {
    final stage = _outcome.updatedCategoryStage;
    final stageLabel = TreeModel.growthStageLabels[stage];
    final progress = (_outcome.updatedCategoryXp / TreeModel.maturityXp).clamp(
      0.0,
      1.0,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.park_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_outcome.categoryName} tree',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppFonts.bodyLg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                stageLabel,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: AppFonts.badge,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${_outcome.updatedCategoryXp} / ${TreeModel.maturityXp} XP to mature tree',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFonts.micro,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 25),
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
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFonts.caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyUnlockState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Your progress is saved. Keep building your tree.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppFonts.caption,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildUnlockRow(_UnlockItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppFonts.caption,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_UnlockItem> _buildUnlocks() {
    final unlocks = <_UnlockItem>[];

    for (final quest in _outcome.newlyUnlockedQuests.take(3)) {
      unlocks.add(
        _UnlockItem(
          icon: Icons.task_alt_rounded,
          label: 'New quest: ${quest.title}',
        ),
      );
    }
    if (_outcome.didReachTreeMaturity) {
      unlocks.add(
        const _UnlockItem(
          icon: Icons.forest_rounded,
          label: 'Your mature tree is ready to plant in the forest.',
        ),
      );
    } else if (_outcome.didAdvanceTreeStage) {
      unlocks.add(
        _UnlockItem(
          icon: Icons.park_rounded,
          label:
              'Your tree can grow to ${TreeModel.growthStageLabels[_outcome.updatedCategoryStage]}.',
        ),
      );
    }
    if (_outcome.didLevelUp) {
      final level = (_outcome.completion.updatedTotalXP ~/ 1000) + 1;
      unlocks.add(
        _UnlockItem(
          icon: Icons.workspace_premium_rounded,
          label: 'Level $level unlocked.',
        ),
      );
    }
    for (final milestone in _outcome.unlockedProgressionMilestones) {
      unlocks.add(
        _UnlockItem(
          icon: Icons.stars_rounded,
          label: 'Progress milestone $milestone unlocked.',
        ),
      );
    }
    if (_outcome.completedFinalMilestone) {
      unlocks.add(
        const _UnlockItem(
          icon: Icons.emoji_events_rounded,
          label: 'Your learning goal is complete.',
        ),
      );
    } else if (_outcome.completedMilestone) {
      unlocks.add(
        const _UnlockItem(
          icon: Icons.flag_rounded,
          label: 'Your next milestone is ready.',
        ),
      );
    }

    return unlocks;
  }
}

class _UnlockItem {
  final IconData icon;
  final String label;

  const _UnlockItem({required this.icon, required this.label});
}
