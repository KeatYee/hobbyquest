import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/constants/color_constants.dart';
import '../../../../controllers/onboarding_controller.dart';
import '../../../widgets/mascot_widget.dart';

class Step2Category extends StatefulWidget {
  const Step2Category({super.key});

  @override
  State<Step2Category> createState() => _Step2CategoryState();
}

class _Step2CategoryState extends State<Step2Category> {
  // Local state to track if we should show the inline error message
  bool showError = false;

  @override
  Widget build(BuildContext context) {
    final OnboardingController controller = Get.find();

    final List<Map<String, dynamic>> categories = [
      {"label": "Creative Arts", "icon": Icons.palette_rounded},
      {"label": "Music & Performing", "icon": Icons.mic_external_on_rounded},
      {"label": "Lifestyle & Wellness", "icon": Icons.self_improvement_rounded},
      {"label": "Skill & Strategy", "icon": Icons.psychology_rounded},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MascotWidget(
            emotion: 'happy', 
            message: "Exciting! What kind of skill do you want to master?",
          ),
          const SizedBox(height: 30),

          Text(
            "CHOOSE A PATH",
            style: GoogleFonts.openSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: 1.0,
            ),
          ),
          
          // INLINE ERROR MESSAGE (Replaces Snackbar)
          // Only visible if showError is true AND no category is selected
          if (showError && controller.selectedCategory.value.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                  const SizedBox(width: 5),
                  Text(
                    "Please select a path to continue",
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 15),

          Obx(() => GridView.builder(
            shrinkWrap: true, 
            physics: const NeverScrollableScrollPhysics(), 
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.3, 
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = controller.selectedCategory.value == cat['label'];

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    controller.selectedCategory.value = cat['label'];
                    // Hide error immediately when user selects something
                    if (showError) setState(() => showError = false);
                  },
                  borderRadius: BorderRadius.circular(16), 
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        // If error exists, show Red border, otherwise Primary or Transparent
                        color: (showError && controller.selectedCategory.value.isEmpty) 
                            ? AppColors.error 
                            : (isSelected ? AppColors.primary : Colors.transparent),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected 
                            ? AppColors.primary.withOpacity(0.2) 
                            : Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          cat['icon'],
                          size: 36,
                          color: isSelected ? AppColors.primary : Colors.grey,
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            cat['label'],
                            textAlign: TextAlign.center, 
                            style: GoogleFonts.openSans(
                              fontSize: 15, 
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          )),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () {
                if (controller.selectedCategory.value.isEmpty) {
                  // Trigger Inline Error
                  setState(() => showError = true);
                } else {
                  controller.nextPage();
                }
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text("NEXT STEP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}