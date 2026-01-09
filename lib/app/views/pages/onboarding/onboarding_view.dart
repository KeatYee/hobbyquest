import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/color_constants.dart'; // Import Colors
import '../../../controllers/onboarding_controller.dart';
import 'steps/step_1_profile.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(OnboardingController());
    
    // Define the total number of steps here so we can calculate percentage
    const int totalSteps = 5; 

    return Scaffold(
      backgroundColor: AppColors.background, // Cool Grey Background
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (controller.currentPage.value == 0) {
              Get.back();
            } else {
              controller.previousPage();
            }
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        // We remove the text title to make room for the bar
      ),
      body: Column(
        children: [
          // 📊 1. THE GAMIFIED PROGRESS BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
            child: Column(
              children: [
                // Step Counter Text (e.g., "Step 1 of 5")
                Obx(() => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Step ${controller.currentPage.value + 1}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary, // Orange Text
                        fontSize: 16,
                      ),
                    ),
                    const Text(
                      "of $totalSteps",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                )),
                const SizedBox(height: 8),
                
                // The Bar Itself
                Container(
                  height: 12, // Thick and chunky like a game UI
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300, // Empty Track
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Obx(() {
                    // Calculate percentage (0.0 to 1.0)
                    // We add +1 because currentPage starts at 0
                    double percent = (controller.currentPage.value + 1) / totalSteps;
                    
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: percent, // How much to fill
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300), // Smooth slide
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          color: AppColors.primary, // Fox Orange Fill
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // 📖 2. THE PAGES (The Content)
          Expanded(
            child: PageView(
              controller: controller.pageController,
              physics: const NeverScrollableScrollPhysics(), // User must use buttons
              onPageChanged: (index) => controller.currentPage.value = index,
              children: const [
                Step1Profile(),
                // Placeholders for future steps
                Scaffold(backgroundColor: Colors.transparent, body: Center(child: Text("Step 2: Category"))),
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