import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../../core/constants/color_constants.dart';
import '../../../../../../core/constants/font_constants.dart';
import '../../../../controllers/onboarding_controller.dart';

class Step3Level extends StatefulWidget {
  const Step3Level({super.key});

  @override
  State<Step3Level> createState() => _Step3LevelState();
}

class _Step3LevelState extends State<Step3Level> {
  bool showError = false;

  @override
  Widget build(BuildContext context) {
    print("--- STEP 4: Level View Rebuilt ---");

    final OnboardingController controller = Get.find();
    final textTheme = Theme.of(context).textTheme;

    final List<Map<String, dynamic>> levels = [
      {
        "label": "Novice",
        "desc": "I'm brand new to this!",
        "icon": Icons.star_border_rounded,
      },
      {
        "label": "Intermediate",
        "desc": "I know the basics, but want to improve.",
        "icon": Icons.trending_up_rounded,
      },
      {
        "label": "Expert",
        "desc": "I'm already skilled, challenge me!",
        "icon": Icons.military_tech_rounded,
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),

          Text(
            "YOUR CURRENT LEVEL",
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: AppFonts.title,
              letterSpacing: 1.0,
            ),
          ),

          if (showError && controller.level.value.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "Please select your experience level",
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 15),

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

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                print("--- ACTION: Next Button Clicked (Step 4) ---");

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

  Widget _buildLevelCard(
    OnboardingController controller,
    Map<String, dynamic> level,
    TextTheme textTheme,
  ) {
    return Obx(() {
      final isSelected = controller.level.value == level['label'];

      final borderColor = (showError && controller.level.value.isEmpty)
          ? AppColors.error
          : (isSelected ? AppColors.primary : Colors.transparent);

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            controller.level.value = level['label'];
            print("--- DATA: Level Selected: ${level['label']} ---");

            if (showError) setState(() => showError = false);
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.textSecondary.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    level['icon'],
                    color: isSelected
                        ? AppColors.textOnPrimary
                        : AppColors.textSecondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level['label'],
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.textOnPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        level['desc'],
                        style: textTheme.bodyMedium?.copyWith(
                          color: isSelected ? AppColors.textOnPrimary : null,
                        ),
                      ),
                    ],
                  ),
                ),

                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.textOnPrimary,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
