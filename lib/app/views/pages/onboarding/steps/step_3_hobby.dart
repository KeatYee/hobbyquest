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

  @override
  Widget build(BuildContext context) {
    final OnboardingController controller = Get.find();

    return Obx(() {
      // Get selected category name
      String parentCategory = controller.selectedCategory.value;
      
      // Find the category model from fetched data
      final selectedCategoryModel = controller.categories.value
          .firstWhereOrNull((cat) => cat.name == parentCategory);
      
      // Get hobbies from the category, or empty list as fallback
      List<String> currentHobbies = selectedCategoryModel?.hobbies ?? [];

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
                final hobbyName = currentHobbies[index];
                return _buildHobbyCard(controller, hobbyName);
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
  Widget _buildHobbyCard(OnboardingController controller, String hobbyName) {
    return Obx(() {
      final isSelected = controller.selectedHobby.value == hobbyName;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            controller.selectedHobby.value = hobbyName;
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
                  Icons.star_rounded,
                  size: 36,
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
                const SizedBox(height: 10),
                Text(
                  hobbyName,
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