import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../../core/constants/color_constants.dart';
import '../../../../../../core/constants/font_constants.dart';
import '../../../../controllers/onboarding_controller.dart';
import '../../../../data/onboarding_catalog.dart';

class Step4Goals extends StatefulWidget {
  const Step4Goals({super.key});

  @override
  State<Step4Goals> createState() => _Step4GoalsState();
}

class _Step4GoalsState extends State<Step4Goals> {
  final _formKey = GlobalKey<FormState>();

  bool showLearningPaceError = false;

  final List<String> learningPaceOptions = [
    "Casual Explorer",
    "Steady Learner",
    "Hardcore Grinder",
  ];

  @override
  Widget build(BuildContext context) {
    print("--- STEP 5: Goals View Rebuilt ---");

    final OnboardingController controller = Get.find();
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),

            Text(
              "YOUR MAIN QUEST",
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: AppFonts.title,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 15),

            Obx(() {
              final hobby = controller.hobby.value.isNotEmpty
                  ? controller.hobby.value
                  : "Drawing";
              final level = controller.level.value;
              final dynamicGoals = OnboardingCatalog.goalsFor(hobby, level);
              final currentGoal = controller.goalController.text.trim();
              final selectedGoal =
                  controller.isPredefinedGoal.value &&
                      dynamicGoals.contains(currentGoal)
                  ? currentGoal
                  : null;

              return DropdownButtonFormField<String>(
                key: ValueKey('$hobby-$level-$selectedGoal'),
                isExpanded: true,
                initialValue: selectedGoal,
                hint: const Text("Pick a goal template..."),
                decoration: const InputDecoration(
                  labelText: "Quick Start Goals",
                  prefixIcon: Icon(Icons.lightbulb_rounded),
                ),
                items: dynamicGoals.map((goal) {
                  return DropdownMenuItem<String>(
                    value: goal,
                    child: Text(goal),
                  );
                }).toList(),
                onChanged: (value) {
                  controller.isPredefinedGoal.value = value != null;
                  if (value != null) {
                    controller.goalController.text = value;
                    controller.goalValidationError.value = '';
                  }
                },
              );
            }),
            const SizedBox(height: 20),

            Obx(
              () => TextFormField(
                controller: controller.goalController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: "Or write your own goal...",
                  hintText: OnboardingCatalog.customGoalHintFor(
                    controller.hobby.value,
                  ),
                  prefixIcon: const Icon(Icons.flag_rounded),
                ),
                onChanged: (_) {
                  controller.isPredefinedGoal.value = false;
                  controller.goalValidationError.value = '';
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please define your quest!";
                  }
                  return null;
                },
              ),
            ),

            Obx(() {
              final error = controller.goalValidationError.value;
              if (error.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        error,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: AppFonts.micro,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 30),

            Text(
              "LEARNING PACE",
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: AppFonts.title,
                letterSpacing: 1.0,
              ),
            ),

            if (showLearningPaceError && controller.learningPace.value.isEmpty)
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
                      "Choose your learning pace",
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 15),

            Obx(
              () => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: learningPaceOptions.map((option) {
                  return _buildLearningPaceChip(controller, option, textTheme);
                }).toList(),
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: Obx(() {
                final isValidating = controller.isGoalValidating.value;
                return ElevatedButton(
                  onPressed: isValidating
                      ? null
                      : () {
                          print(
                            "--- ACTION: Final Button Clicked (Step 5) ---",
                          );

                          bool isTextValid = _formKey.currentState!.validate();

                          bool isLearningPaceValid =
                              controller.learningPace.value.isNotEmpty;

                          if (!isLearningPaceValid) {
                            print("--- ERROR: Learning pace not selected ---");
                            setState(() => showLearningPaceError = true);
                          }

                          if (isTextValid && isLearningPaceValid) {
                            print(
                              "--- SUCCESS: All Steps Complete. Generating Plan... ---",
                            );
                            FocusManager.instance.primaryFocus?.unfocus();

                            controller.nextPage();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                  ),
                  child: isValidating
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textOnPrimary,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text("Checking your goal..."),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("START ADVENTURE"),
                            SizedBox(width: 8),
                            Icon(Icons.rocket_launch_rounded, size: 20),
                          ],
                        ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningPaceChip(
    OnboardingController controller,
    String label,
    TextTheme textTheme,
  ) {
    bool isSelected = controller.learningPace.value == label;
    bool isError =
        showLearningPaceError && controller.learningPace.value.isEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          controller.learningPace.value = label;
          print("--- DATA: Learning pace selected: $label ---");
          if (showLearningPaceError)
            setState(() => showLearningPaceError = false);
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isError
                  ? AppColors.error
                  : (isSelected ? AppColors.primary : AppColors.borderStrong),
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? AppColors.textOnPrimary
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
