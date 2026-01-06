import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/onboarding_controller.dart';
import 'steps/step_1_profile.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize the Logic Controller here
    final controller = Get.put(OnboardingController());

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text("Step ${controller.currentPage.value + 1} of 5")),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // If on page 1, go back to login. Else, go back 1 page.
            if (controller.currentPage.value == 0) {
              Get.back();
            } else {
              controller.previousPage();
            }
          },
        ),
      ),
      body: PageView(
        controller: controller.pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swiping (must use buttons)
        onPageChanged: (index) => controller.currentPage.value = index,
        children: const [
          Step1Profile(),
          // We will add Step2Category() here next!
          Scaffold(body: Center(child: Text("Step 2 Coming Soon..."))), 
        ],
      ),
    );
  }
}