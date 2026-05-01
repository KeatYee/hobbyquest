import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------------------------
            // HEADER: THE GOAL
            // ------------------------------------
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(Icons.emoji_events_rounded, size: 40, color: AppColors.primaryDark),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    controller.generatedPlan.value.targetBoss, // Dynamic Data
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${controller.selectedLevel.value} • ${controller.selectedHobby.value}",
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // ------------------------------------
            // STATS GRID (Duration & Effort)
            // ------------------------------------
            Row(
              children: [
                _buildStatCard("Duration", controller.generatedPlan.value.duration, Icons.calendar_month_rounded),
                const SizedBox(width: 12),
                _buildStatCard("Effort", controller.generatedPlan.value.dailyCommitment, Icons.timer_rounded),
              ],
            ),
            const SizedBox(height: 30),

            // ------------------------------------
            // THE ROADMAP (List of Milestones)
            // ------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("QUEST MILESTONES", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textSecondary, letterSpacing: 1.0)),
                TextButton(
                  onPressed: () {
                    // "Edit Plan" Logic: Just show a snackbar for now or open a bottom sheet
                    Get.snackbar("Regenerate", "AI is tweaking your plan...");
                  },
                  child: const Text("Regenerate", style: TextStyle(color: AppColors.primary)),
                )
              ],
            ),
            const SizedBox(height: 10),
            
            // Dynamic List of Milestones
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: List.generate(controller.generatedPlan.value.milestones.length, (index) {
                  bool isLast = index == controller.generatedPlan.value.milestones.length - 1;
                  return _buildTimelineItem(
                    index + 1, 
                    controller.generatedPlan.value.milestones[index], 
                    isLast
                  );
                }),
              ),
            ),
            
            const SizedBox(height: 40),

            // ------------------------------------
            // ACTION BUTTONS
            // ------------------------------------
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => controller.confirmAndStart(), // ✅ Commit to DB here
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success, // Green for "Go"
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                child: const Text("ACCEPT & START ADVENTURE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Get.back(), // Go back to Step 5
                child: const Text("Choose a different Goal", style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(int week, String title, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24, height: 24,
              decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
              child: Center(child: Text("$week", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark))),
            ),
            if (!isLast)
              Container(width: 2, height: 40, color: AppColors.primaryLight.withOpacity(0.5)),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Phase $week", style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}