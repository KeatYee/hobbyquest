import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../controllers/onboarding_controller.dart';
import '../../../routes/app_routes.dart'; // Import Routes
import 'steps/step_1_profile.dart';
import 'steps/step_2_category.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(OnboardingController());
    
    const int totalSteps = 5; 

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            // ✅ FIX: If on Step 1, Go back to Welcome Screen (Exit Wizard)
            if (controller.currentPage.value == 0) {
              Get.offAllNamed(AppRoutes.WELCOME);
            } else {
              // Otherwise, just go to previous step
              controller.previousPage();
            }
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 📊 PROGRESS BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
            child: Column(
              children: [
                Obx(() => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Step ${controller.currentPage.value + 1}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                    ),
                    const Text("of $totalSteps", style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ],
                )),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  child: Obx(() {
                    double percent = (controller.currentPage.value + 1) / totalSteps;
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: percent,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // 📖 PAGES
          Expanded(
            child: PageView(
              controller: controller.pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => controller.currentPage.value = index,
              children: const [
                Step1Profile(),
                Step2Category(),
                Scaffold(backgroundColor: Colors.transparent, body: Center(child: Text("Step 3: Hobby"))),
                Scaffold(backgroundColor: Colors.transparent, body: Center(child: Text("Step 4: Level"))),
                Scaffold(backgroundColor: Colors.transparent, body: Center(child: Text("Step 5: Goals"))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}