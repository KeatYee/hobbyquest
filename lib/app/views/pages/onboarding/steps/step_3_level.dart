import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../../core/constants/color_constants.dart';
import '../../../../../../core/constants/font_constants.dart';
import '../../../../controllers/onboarding_controller.dart';
import '../../../widgets/mascot_widget.dart';

class Step3Level extends StatefulWidget {
  const Step3Level({super.key});

  @override
  State<Step3Level> createState() => _Step3LevelState();
}

class _Step3LevelState extends State<Step3Level> {
  // Local state to track validation error
  bool showError = false;

  @override
  Widget build(BuildContext context) {
    // Debug: View Rebuilt
    print("--- STEP 4: Level View Rebuilt ---");

    final OnboardingController controller = Get.find();
    // Access Global App Theme
    final textTheme = Theme.of(context).textTheme;

    final List<Map<String, dynamic>> levels = [
      {
        "label": "Novice",
        "desc": "I'm brand new to this!",
        "icon": Icons.star_border_rounded
      },
      {
        "label": "Intermediate",
        "desc": "I know the basics, but want to improve.",
        "icon": Icons.trending_up_rounded
      },
      {
        "label": "Expert",
        "desc": "I'm already skilled, challenge me!",
        "icon": Icons.military_tech_rounded 
      },
    ];

    return SingleChildScrollView(
      // Padding matches previous steps for consistency
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mascot Greeting
          const MascotWidget(
            emotion: 'happy',
            message: "Got it! And how much experience do you have with this?",
          ),
          const SizedBox(height: 30),

          // Section Title using Theme
          Text("YOUR CURRENT LEVEL", style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900, 
              fontSize: AppFonts.title,
              letterSpacing: 1.0
          )),

          // Inline Error Message
          if (showError && controller.level.value.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                  const SizedBox(width: 5),
                  Text("Please select your experience level",
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.error, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            ),

          const SizedBox(height: 15),

          // Level Selection List
          // Using ListView.separated for clean spacing
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: levels.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _buildLevelCard(controller, levels[index], textTheme);
            },
          ),

          const SizedBox(height: 30),

          // Next Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                print("--- ACTION: Next Button Clicked (Step 4) ---");

                // Validation Logic
                if (controller.level.value.isEmpty) {
                  print("--- ERROR: No Level Selected ---");
                  setState(() => showError = true);
                } else {
                  print("--- SUCCESS: Proceeding to Step 5 ---");
                  controller.nextPage();
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text("NEXT STEP"),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget for Level Cards
  Widget _buildLevelCard(OnboardingController controller, Map<String, dynamic> level, TextTheme textTheme) {
    return Obx(() {
      final isSelected = controller.level.value == level['label'];
      
      // Error State: Show Red border if error is active and nothing selected
      // Otherwise: Show Primary color if selected, Transparent if not
      final borderColor = (showError && controller.level.value.isEmpty) 
          ? AppColors.error 
          : (isSelected ? AppColors.primary : Colors.transparent);

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            controller.level.value = level['label'];
            print("--- DATA: Level Selected: ${level['label']} ---");
            
            // Clear error on selection
            if (showError) setState(() => showError = false);
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.grey.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    level['icon'],
                    color: isSelected ? Colors.white : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level['label'],
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        level['desc'],
                        style: textTheme.bodyMedium, // Uses Theme color automatically
                      ),
                    ],
                  ),
                ),
                
                // Checkmark Indicator
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 24),
              ],
            ),
          ),
        ),
      );
    });
  }
}