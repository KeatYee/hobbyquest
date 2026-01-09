import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/constants/color_constants.dart';
import '../../../../controllers/onboarding_controller.dart';
import '../../../widgets/mascot_widget.dart';

class Step1Profile extends StatelessWidget {
  const Step1Profile({super.key});

  @override
  Widget build(BuildContext context) {
    // Find the controller created in the parent view
    final OnboardingController controller = Get.find();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🦊 1. MASCOT GREETING (Game Explanation merged here)
          const MascotWidget(
            emotion: 'happy',
            message: "Hi! I'm Hobie. Before we start your adventure, I need to know who you are!",
          ),
          const SizedBox(height: 30),

          // 📝 2. IDENTITY FORM
          Text(
            "YOUR IDENTITY",
            style: GoogleFonts.openSans( // Changed from Fredoka
              fontSize: 18,
              fontWeight: FontWeight.w800, // Extra Bold for hierarchy
              color: AppColors.textPrimary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 15),

          // Name Input
          TextField(
            controller: controller.nickname,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              labelText: "Hero Name (Nickname)",
              hintText: "e.g. DragonSlayer",
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 20),

          // Birth Date Input (Replaces Age)
          TextField(
            controller: controller.age, // Reusing 'age' controller to store date string
            readOnly: true, // Prevent manual typing
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              labelText: "Birth Date",
              hintText: "YYYY-MM-DD",
              prefixIcon: Icon(Icons.calendar_month_rounded),
            ),
            onTap: () async {
              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), // Default ~18 years old
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppColors.primary, // Orange Header
                        onPrimary: Colors.white, 
                        onSurface: AppColors.textPrimary,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              
              if (pickedDate != null) {
                // Format: YYYY-MM-DD
                String formattedDate = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                controller.age.text = formattedDate;
              }
            },
          ),
          const SizedBox(height: 30),

          // ⚧ 3. GENDER SELECTION (Gamified Cards)
          Text(
            "CHARACTER TYPE",
            style: GoogleFonts.openSans( // Changed from Fredoka
              fontSize: 18,
              fontWeight: FontWeight.w800, // Extra Bold for hierarchy
              color: AppColors.textPrimary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 15),

          Obx(() => Row(
            children: [
              _buildGenderCard(controller, "Male", Icons.male_rounded),
              const SizedBox(width: 12),
              _buildGenderCard(controller, "Female", Icons.female_rounded),
              const SizedBox(width: 12),
              _buildGenderCard(controller, "Other", Icons.person_rounded),
            ],
          )),
          
          const SizedBox(height: 40),

          // 🚀 4. ACTION BUTTON
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () {
                // Validation Feedback
                if (controller.nickname.text.isEmpty || controller.age.text.isEmpty) {
                  Get.snackbar(
                    "Missing Info",
                    "Every Hero needs a name and birth date!",
                    backgroundColor: AppColors.error,
                    colorText: Colors.white,
                    icon: const Icon(Icons.error_outline, color: Colors.white),
                    snackPosition: SnackPosition.BOTTOM,
                    margin: const EdgeInsets.all(20),
                  );
                } else {
                  // Go to Next Page
                  controller.nextPage();
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text("CONTINUE"),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
          // Extra space for scrolling on small screens
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // 🃏 Helper to build the selectable Gender Cards
  Widget _buildGenderCard(OnboardingController controller, String label, IconData icon) {
    bool isSelected = controller.selectedGender.value == label;

    return Expanded(
      child: GestureDetector(
        onTap: () => controller.selectedGender.value = label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 100,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected ? AppColors.primary : Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.openSans(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}