import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/constants/color_constants.dart';
import '../../../../controllers/onboarding_controller.dart';
import '../../../widgets/mascot_widget.dart';

class Step3Hobby extends StatefulWidget {
  const Step3Hobby({super.key});

  @override
  State<Step3Hobby> createState() => _Step3HobbyState();
}

class _Step3HobbyState extends State<Step3Hobby> {
  bool showError = false;

  // 1. Define the specific hobbies for each Category
  final Map<String, List<Map<String, dynamic>>> hobbyMap = {
    "Creative Arts": [
      {"label": "Painting", "icon": Icons.brush_rounded},
      {"label": "Digital Art", "icon": Icons.monitor_rounded},
      {"label": "Photography", "icon": Icons.camera_alt_rounded},
      {"label": "Calligraphy", "icon": Icons.auto_stories_rounded},
    ],
    "Music & Performing": [
      {"label": "Guitar", "icon": Icons.library_music_rounded},
      {"label": "Piano", "icon": Icons.piano_rounded},
      {"label": "Singing", "icon": Icons.mic_rounded},
      {"label": "Dance", "icon": Icons.emoji_people_rounded},
    ],
    "Lifestyle & Wellness": [
      {"label": "Yoga", "icon": Icons.self_improvement_rounded},
      {"label": "Fitness/Gym", "icon": Icons.fitness_center_rounded},
      {"label": "Meditation", "icon": Icons.spa_rounded},
      {"label": "Cooking", "icon": Icons.restaurant_menu_rounded},
    ],
    "Skill & Strategy": [
      {"label": "Coding", "icon": Icons.terminal_rounded},
      {"label": "Chess", "icon": Icons.grid_on_rounded},
      {"label": "Language", "icon": Icons.translate_rounded},
      {"label": "Public Speaking", "icon": Icons.record_voice_over_rounded},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final OnboardingController controller = Get.find();

    return Obx(() {
      // 2. Listen to the category selected in Step 2
      String parentCategory = controller.selectedCategory.value;
      
      // 3. Get the list of hobbies (Default to empty list if something goes wrong)
      List<Map<String, dynamic>> currentHobbies = hobbyMap[parentCategory] ?? [];

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dynamic Mascot Message based on Category
            MascotWidget(
              emotion: 'surprised',
              message: "Ooh, $parentCategory! I love that. What specifically are we focusing on?",
            ),
            const SizedBox(height: 30),

            Text(
              "NARROW IT DOWN",
              style: GoogleFonts.openSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 1.0,
              ),
            ),

            // Inline Error
            if (showError && controller.selectedHobby.value.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                    const SizedBox(width: 5),
                    const Text(
                      "Please select a hobby to continue",
                      style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 15),

            // 4. Render the Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.3,
              ),
              itemCount: currentHobbies.length,
              itemBuilder: (context, index) {
                final hobby = currentHobbies[index];
                return _buildHobbyCard(controller, hobby);
              },
            ),

            const SizedBox(height: 30),

            // Next Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  if (controller.selectedHobby.value.isEmpty) {
                    setState(() => showError = true);
                  } else {
                    controller.nextPage();
                  }
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("NEXT STEP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // Extracted widget for cleaner code
  Widget _buildHobbyCard(OnboardingController controller, Map<String, dynamic> hobby) {
    return Obx(() {
      final isSelected = controller.selectedHobby.value == hobby['label'];

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            controller.selectedHobby.value = hobby['label'];
            if (showError) setState(() => showError = false);
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (showError && controller.selectedHobby.value.isEmpty)
                    ? AppColors.error
                    : (isSelected ? AppColors.primary : Colors.transparent),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hobby['icon'],
                  size: 36,
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
                const SizedBox(height: 10),
                Text(
                  hobby['label'],
                  style: GoogleFonts.openSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}