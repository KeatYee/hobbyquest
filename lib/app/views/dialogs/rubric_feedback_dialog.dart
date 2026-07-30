import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/quest_node_model.dart';
import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';

enum RubricFeedbackAction { continueQuest, retakePhoto }

class RubricFeedbackDialog extends StatelessWidget {
  final bool isEvidenceRelevant;
  final bool isApproved;
  final bool isChallenge;
  final List<RubricAssessmentModel> assessments;
  final String nextStep;

  const RubricFeedbackDialog({
    super.key,
    required this.isEvidenceRelevant,
    required this.isApproved,
    required this.isChallenge,
    required this.assessments,
    required this.nextStep,
  });

  @override
  Widget build(BuildContext context) {
    final metAssessments = assessments
        .where((assessment) => assessment.met)
        .toList(growable: false);
    final unmetAssessments = assessments
        .where((assessment) => !assessment.met)
        .toList(growable: false);
    final outcomeColor = _outcomeColor;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOutcomeHeader(outcomeColor),
            if (!isEvidenceRelevant)
              const SizedBox(height: 20),
            if (!isEvidenceRelevant)
              _buildPhotoMismatchSection()
            else ...[
              const SizedBox(height: 20),
              _buildScoreSummary(
                metCount: metAssessments.length,
                color: outcomeColor,
              ),
              if (isApproved && metAssessments.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildAssessmentSection(
                  title: 'WHAT YOU DID WELL',
                  icon: Icons.emoji_events_rounded,
                  color: AppColors.success,
                  assessments: metAssessments,
                ),
              ],
              if (unmetAssessments.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildAssessmentSection(
                  title: 'WHAT TO IMPROVE',
                  icon: Icons.tips_and_updates_rounded,
                  color: AppColors.warning,
                  assessments: unmetAssessments,
                ),
              ],
            ],
            const SizedBox(height: 24),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Color get _outcomeColor {
    if (!isEvidenceRelevant) return AppColors.error;
    if (isApproved) return AppColors.success;
    return AppColors.warning;
  }

  String get _title {
    if (!isEvidenceRelevant) return 'Photo Inrelevant';
    if (isApproved) return 'Quest Passed';
    return isChallenge ? 'Needs Work' : 'Photo Feedback';
  }

  IconData get _outcomeIcon {
    if (!isEvidenceRelevant) return Icons.image_not_supported_rounded;
    if (isApproved) return Icons.workspace_premium_rounded;
    return Icons.auto_fix_high_rounded;
  }

  String get _displayNextStep {
    if (nextStep.trim().isNotEmpty) return nextStep.trim();
    return isEvidenceRelevant
        ? 'Use the feedback for your next attempt.'
        : 'Retake with the quest work clearly visible.';
  }

  Widget _buildOutcomeHeader(Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_outcomeIcon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _title,
              style: TextStyle(
                color: color,
                fontSize: AppFonts.body,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSummary({required int metCount, required Color color}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Hobie checked each visible criterion in your photo.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.4,
              fontSize: AppFonts.badge,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$metCount of ${assessments.length} met',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: AppFonts.badge,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoMismatchSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This photo does not clearly show the work requested by this quest.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.4,
              fontSize: AppFonts.badge,
            ),
          ),
          const SizedBox(height: 10),
          _buildInlineNextStep(AppColors.warning),
        ],
      ),
    );
  }

  Widget _buildInlineNextStep(Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lightbulb_rounded, color: color, size: 17),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Next step: $_displayNextStep',
            style: const TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
              height: 1.35,
              fontSize: AppFonts.badge,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssessmentSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<RubricAssessmentModel> assessments,
  }) {
    return _FeedbackSection(
      title: title,
      icon: icon,
      color: color,
      children: assessments
          .map(
            (assessment) =>
                _AssessmentRow(assessment: assessment, color: color),
          )
          .toList(growable: false),
    );
  }

  Widget _buildActions() {
    final canContinue = !isChallenge || isApproved;
    final canRetake =
        !isEvidenceRelevant ||
        !isApproved ||
        assessments.any((assessment) => !assessment.met);
    final continueLabel = !isEvidenceRelevant
        ? 'Continue without photo'
        : 'Continue';

    return Column(
      children: [
        if (canRetake)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  Get.back(result: RubricFeedbackAction.retakePhoto),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Retake Photo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                fixedSize: const Size.fromHeight(48),
              ),
            ),
          ),
        if (canRetake && canContinue) const SizedBox(height: 12),
        if (canContinue)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  Get.back(result: RubricFeedbackAction.continueQuest),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(continueLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                fixedSize: const Size.fromHeight(48),
              ),
            ),
          ),
      ],
    );
  }
}

class OptionalPhotoRecoveryDialog extends StatelessWidget {
  final bool uploadFailed;
  final bool canContinueWithoutPhoto;

  const OptionalPhotoRecoveryDialog({
    super.key,
    required this.uploadFailed,
    this.canContinueWithoutPhoto = true,
  });

  @override
  Widget build(BuildContext context) {
    final message = uploadFailed
        ? 'Your feedback is ready, but the photo could not be uploaded.'
        : 'Hobie could not check this photo right now.';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Photo Couldn’t Be Used',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: AppFonts.body,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.4,
              fontSize: AppFonts.badge,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  Get.back(result: RubricFeedbackAction.retakePhoto),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Retake Photo'),
            ),
          ),
          if (canContinueWithoutPhoto) const SizedBox(height: 10),
          if (canContinueWithoutPhoto)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Get.back(result: RubricFeedbackAction.continueQuest),
                child: const Text('Continue without photo'),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeedbackSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _FeedbackSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: AppFonts.caption,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _AssessmentRow extends StatelessWidget {
  final RubricAssessmentModel assessment;
  final Color color;

  const _AssessmentRow({required this.assessment, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            assessment.met
                ? Icons.check_circle_rounded
                : Icons.error_outline_rounded,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assessment.criterion,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    fontSize: AppFonts.badge,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  assessment.feedback,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.35,
                    fontSize: AppFonts.badge,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
