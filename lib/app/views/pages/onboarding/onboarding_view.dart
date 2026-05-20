import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/color_constants.dart';
import '../../../controllers/onboarding_controller.dart';
import 'steps/step_1_profile.dart';
import 'steps/step_2_category.dart';
import 'steps/step_3_level.dart';
import 'steps/step_4_goals.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(OnboardingController());
    
    const int totalSteps = 4; 

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: Obx(() {
          if (controller.currentPage.value == 0) {
            return const SizedBox.shrink();
          }

          return IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: controller.previousPage,
          );
        }),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Obx(() => Text(
                      "Step ${controller.currentPage.value + 1}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                    )),
                    const Text("of $totalSteps", style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ],
                ),
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
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))],
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
              physics: const NeverScrollableScrollPhysics(), // Disable swiping - navigation only via buttons
              onPageChanged: (index) => controller.currentPage.value = index,
              children: const [
                Step1Profile(),
                Step2Category(),
                Step3Level(),
                Step4Goals(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}