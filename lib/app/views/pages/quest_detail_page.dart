import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/progression_controller.dart';
import '../../models/quest_model.dart';
import '../../../core/constants/color_constants.dart';

class QuestDetailPage extends StatefulWidget {
  final QuestModel quest;
  
  const QuestDetailPage({
    super.key,
    required this.quest,
  });

  @override
  State<QuestDetailPage> createState() => _QuestDetailPageState();
}

class _QuestDetailPageState extends State<QuestDetailPage> {
  late TextEditingController reflectionController;
  late QuestModel currentQuest;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    reflectionController = TextEditingController();
    currentQuest = widget.quest;
    
    // Pre-fill reflection note if it exists
    if (currentQuest.reflectionNote.isNotEmpty) {
      reflectionController.text = currentQuest.reflectionNote;
    }
  }

  @override
  void dispose() {
    reflectionController.dispose();
    super.dispose();
  }

  Color getTypeColor() {
    switch (currentQuest.type) {
      case 'knowledge': return AppColors.accent; // Blue
      case 'practice': return AppColors.success; // Green
      case 'challenge': return Colors.purple;
      default: return Colors.grey;
    }
  }

  IconData getTypeIcon() {
    switch (currentQuest.type) {
      case 'knowledge': return Icons.menu_book_rounded;
      case 'practice': return Icons.timer_rounded;
      case 'challenge': return Icons.camera_alt_rounded;
      default: return Icons.task_alt_rounded;
    }
  }

  String getTypeLabel() {
    switch (currentQuest.type) {
      case 'knowledge': return 'Knowledge Quest';
      case 'practice': return 'Practice Quest';
      case 'challenge': return 'Challenge Quest';
      default: return 'Quest';
    }
  }

  Future<void> _completeQuest() async {
    if (currentQuest.isCompleted) {
      Get.back();
      return;
    }

    final homeController = Get.find<HomeController>();
    final progressionController = Get.find<ProgressionController>();

    setState(() => isSubmitting = true);

    // Complete the quest
    final didComplete = homeController.completeQuest(
      currentQuest.id,
      reflectionNote: reflectionController.text.trim(),
    );

    if (didComplete) {
      progressionController.completeQuest(questId: currentQuest.id);

      // Show success feedback
      Get.snackbar(
        'Quest Completed! 🎉',
        '+${currentQuest.xp} XP earned',
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      await Future.delayed(const Duration(milliseconds: 500));
      Get.back();
    } else {
      Get.snackbar(
        'Error',
        'Failed to complete quest',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = getTypeColor();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Quest Details',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TYPE BADGE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: typeColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(getTypeIcon(), color: typeColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    getTypeLabel(),
                    style: TextStyle(
                      color: typeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // TITLE
            Text(
              currentQuest.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // DESCRIPTION
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currentQuest.desc,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),

            // QUEST INFO CARDS
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Reward',
                    value: '+${currentQuest.xp} XP',
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.star_rounded,
                    label: 'Priority',
                    value: currentQuest.isPriority ? 'Yes' : 'No',
                    color: currentQuest.isPriority ? Colors.orange : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // STATUS
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: currentQuest.isCompleted
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: currentQuest.isCompleted
                      ? AppColors.success.withOpacity(0.3)
                      : AppColors.accent.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    currentQuest.isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.pending_actions_rounded,
                    color: currentQuest.isCompleted
                        ? AppColors.success
                        : AppColors.accent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentQuest.isCompleted ? 'Completed' : 'Not Started',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (currentQuest.isCompleted && currentQuest.completedAt != null)
                          Text(
                            'Completed on ${_formatDate(currentQuest.completedAt!)}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // REFLECTION NOTE SECTION
            if (!currentQuest.isCompleted || reflectionController.text.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reflection Note',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reflectionController,
                    readOnly: currentQuest.isCompleted,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: currentQuest.isCompleted
                          ? 'No reflection note added'
                          : 'Add a reflection note about this quest (optional)',
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.background,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.background,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.background,
                        ),
                      ),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 24),
                ],
              ),

            // ACTION BUTTON
            if (!currentQuest.isCompleted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _completeQuest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Complete Quest',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  child: Text(
                    'Back to Quests',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.background),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final questDate = DateTime(date.year, date.month, date.day);

    if (questDate == today) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (questDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}
