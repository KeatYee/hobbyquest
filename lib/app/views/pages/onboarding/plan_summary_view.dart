import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../core/constants/color_constants.dart';
import '../../../controllers/onboarding_controller.dart';

class PlanSummaryView extends StatelessWidget {
  const PlanSummaryView({super.key});

  @override
  Widget build(BuildContext context) {
    final OnboardingController controller = Get.find();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Your Quest Blueprint", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Get.back(), // Allows them to go back to Step 5
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ------------------------------------
            // TOP: USER AVATAR & TITLE
            // ------------------------------------
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.primaryLight,
                child: controller.avatarSvg.value.isNotEmpty
                    ? ClipOval(
                        child: SvgPicture.string(
                          controller.avatarSvg.value,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.person_rounded, size: 40, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title: Name, Level, Hobby (e.g., "Alex, Level 1 Novice Sketcher")
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.textPrimary),
                children: [
                  TextSpan(text: controller.nickname.text),
                  const TextSpan(text: ", "),
                  TextSpan(
                    text: "Level 1 ${controller.selectedLevel.value} ${controller.generatedPlan.value.hobbyName.isNotEmpty ? controller.generatedPlan.value.hobbyName : controller.selectedHobby.value}",
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // XP Badge: 0 / 8,000 XP
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.2),
                    AppColors.accent.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flash_on_rounded, color: AppColors.accent, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    "0 / 8,000 XP",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // ------------------------------------
            // MIDDLE: MISSION PARAMETERS
            // ------------------------------------
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "YOUR MISSION",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Main Goal
                  _buildMissionRow(
                    icon: Icons.flag_rounded,
                    label: "Main Quest",
                    value: controller.generatedPlan.value.targetBoss,
                  ),
                  const SizedBox(height: 16),
                  
                  // Time Budget
                  _buildMissionRow(
                    icon: Icons.timer_rounded,
                    label: "Daily Commitment",
                    value: controller.frequency.value,
                  ),
                  const SizedBox(height: 16),
                  
                  // Daily Routine
                  _buildMissionRow(
                    icon: Icons.checklist_rounded,
                    label: "Daily Routine",
                    value: "You will receive 3 Quests per day",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // ------------------------------------
            // BOTTOM: MILESTONES WITH XP THRESHOLDS
            // ------------------------------------
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "QUEST MILESTONES",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Milestone Timeline with XP Thresholds
            ..._buildMilestonesList(controller),

            const SizedBox(height: 40),

            // ------------------------------------
            // BUTTON: ACCEPT & START ADVENTURE
            // ------------------------------------
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => controller.confirmAndStart(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("ACCEPT QUEST", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(width: 8),
                    Icon(Icons.rocket_launch_rounded, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Get.back(),
                child: const Text("Choose a different Goal", style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMilestonesList(OnboardingController controller) {
    final milestones = controller.generatedPlan.value.milestones;
    final xpThresholds = [2000, 4000, 6000, 8000];
    final labels = ["Milestone 1", "Milestone 2", "Milestone 3", "Final Boss"];

    return List.generate(milestones.length, (index) {
      final isFinal = index == milestones.length - 1;
      
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isFinal ? AppColors.accent.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFinal ? AppColors.accent.withOpacity(0.3) : Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: isFinal
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isFinal ? AppColors.accent : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "${index + 1}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labels[index],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isFinal ? AppColors.accent : AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        milestones[index].task,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Unlocks at ${xpThresholds[index].toString()} XP",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        milestones[index].completed ? 'Completed' : 'Not completed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: milestones[index].completed ? AppColors.success : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isFinal)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                width: 2,
                height: 20,
                color: AppColors.primary.withOpacity(0.3),
              ),
            ),
          if (!isFinal) const SizedBox(height: 8),
        ],
      );
    });
  }

}