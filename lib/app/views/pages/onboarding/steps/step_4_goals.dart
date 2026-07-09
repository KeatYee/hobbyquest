import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../../core/constants/color_constants.dart';
import '../../../../../../core/constants/font_constants.dart';
import '../../../../controllers/onboarding_controller.dart';

class Step4Goals extends StatefulWidget {
  const Step4Goals({super.key});

  @override
  State<Step4Goals> createState() => _Step4GoalsState();
}

class _Step4GoalsState extends State<Step4Goals> {
  // GlobalKey for Form Validation (Text Input)
  final _formKey = GlobalKey<FormState>();

  // Local state to track learning pace validation error.
  bool showLearningPaceError = false;

  String? selectedPredefinedGoal;

  final List<String> learningPaceOptions = [
    "Casual Explorer",
    "Steady Learner",
    "Hardcore Grinder",
  ];

  /// Get predefined goals based on selected hobby and skill level
  List<String> _getPredefinedGoals(String hobby, String level) {
    if (hobby == "Drawing") {
      if (level == "Novice") {
        return [
          "Learn basic shading",
          "Sketch a coffee cup",
          "Draw a simple cartoon",
        ];
      } else if (level == "Intermediate") {
        return [
          "Draw a realistic portrait",
          "Master 2-point perspective",
          "Learn to draw hands",
        ];
      } else if (level == "Expert") {
        return [
          "Design dynamic action poses",
          "Complete a full anatomy study",
          "Master hyper-realistic lighting",
        ];
      }
    }
    // Fallback for other hobbies (currently all locked except Drawing)
    return [
      "Master the fundamentals",
      "Complete a challenging project",
      "Teach someone else",
    ];
  }

  @override
  Widget build(BuildContext context) {
    print("--- STEP 5: Goals View Rebuilt ---");

    final OnboardingController controller = Get.find();
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      // Padding matches previous steps for consistency
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),

            // Section 1: The Main Goal
            Text(
              "YOUR MAIN QUEST",
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: AppFonts.title,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 15),

            // Predefined Goals Dropdown
            Obx(() {
              final hobby = controller.hobby.value.isNotEmpty
                  ? controller.hobby.value
                  : "Drawing";
              final level = controller.level.value;
              final dynamicGoals = _getPredefinedGoals(hobby, level);

              return DropdownButtonFormField<String>(
                initialValue: selectedPredefinedGoal,
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
                  setState(() {
                    selectedPredefinedGoal = value;
                    controller.isPredefinedGoal.value = value != null;
                    if (value != null) {
                      controller.goalController.text = value;
                      controller.goalValidationError.value = '';
                    }
                  });
                },
              );
            }),
            const SizedBox(height: 20),

            // Custom Goal Input
            // Uses AppTheme styles automatically
            TextFormField(
              controller: controller.goalController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: "Or write your own goal...",
                hintText: "e.g. Learn to draw Doraemon",
                prefixIcon: Icon(Icons.flag_rounded),
              ),
              onChanged: (_) {
                controller.isPredefinedGoal.value = false;
                controller.goalValidationError.value = '';
              },
              // Simple validation: Goal cannot be empty
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Please define your quest!";
                }
                return null;
              },
            ),

            // Goal validation error
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

            // Section 2: Learning Pace
            Text(
              "LEARNING PACE",
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: AppFonts.title,
                letterSpacing: 1.0,
              ),
            ),

            // Inline Error for Learning Pace
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

            // Learning pace chips
            Obx(
              () => Wrap(
                spacing: 12, // Horizontal gap
                runSpacing: 12, // Vertical gap
                children: learningPaceOptions.map((option) {
                  return _buildLearningPaceChip(controller, option, textTheme);
                }).toList(),
              ),
            ),

            const SizedBox(height: 40),

            // Final Action Button
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

                          // 1. Validate Text Input
                          bool isTextValid = _formKey.currentState!.validate();

                          // 2. Validate learning pace selection
                          bool isLearningPaceValid =
                              controller.learningPace.value.isNotEmpty;

                          if (!isLearningPaceValid) {
                            print("--- ERROR: Learning pace not selected ---");
                            setState(() => showLearningPaceError = true);
                          }

                          // 3. Execute
                          if (isTextValid && isLearningPaceValid) {
                            print(
                              "--- SUCCESS: All Steps Complete. Generating Plan... ---",
                            );
                            // Dismiss keyboard
                            FocusManager.instance.primaryFocus?.unfocus();

                            // Trigger the Final Logic in Controller
                            controller.nextPage();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
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
                                color: Colors.white,
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
    bool isError = showLearningPaceError && controller.learningPace.value.isEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          controller.learningPace.value = label;
          print("--- DATA: Learning pace selected: $label ---");
          if (showLearningPaceError) setState(() => showLearningPaceError = false);
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isError
                  ? AppColors.error
                  : (isSelected ? AppColors.primary : Colors.grey.shade300),
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
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
