import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../../core/constants/color_constants.dart';
import '../../../../../../core/utils/validators.dart'; 
import '../../../../controllers/onboarding_controller.dart';
import '../../../widgets/mascot_widget.dart';

class Step1Profile extends StatefulWidget {
  const Step1Profile({super.key});

  @override
  State<Step1Profile> createState() => _Step1ProfileState();
}

class _Step1ProfileState extends State<Step1Profile> {
  final _formKey = GlobalKey<FormState>();
  bool showGenderError = false; 

  @override
  Widget build(BuildContext context) {
    final OnboardingController controller = Get.find();
    // ✅ Access your AppTheme text styles here
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 100), 
      child: Form(
        key: _formKey, 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MascotWidget(
              emotion: 'happy',
              message: "Hi! I'm Hobie. Before we start your adventure, I need to know who you are!",
            ),
            const SizedBox(height: 30),

            // ✅ Section Title using Theme
            // We use .copyWith to add the specific color/weight if the theme default isn't exact
            Text("Your Identity", style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900, 
              fontSize: 18,
              letterSpacing: 1.0
            )),
            
            const SizedBox(height: 15),

            // Nickname Input
            // ✂️ Look how clean this is! No border code needed.
            TextFormField(
              controller: controller.nickname,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Hero Name (Nickname)",
                hintText: "e.g. DragonSlayer",
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: Validators.validateName, 
            ),
            const SizedBox(height: 20),

            // Birth Date Input
            TextFormField(
              controller: controller.age,
              readOnly: true, 
              decoration: const InputDecoration(
                labelText: "Birth Date",
                hintText: "YYYY-MM-DD",
                prefixIcon: Icon(Icons.calendar_month_rounded),
              ),
              validator: Validators.validateDate,
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), 
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  // Theme data is inherited automatically
                );
                if (pickedDate != null) {
                  controller.age.text = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                }
              },
            ),
            const SizedBox(height: 30),

            Text("Character Type", style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900, 
              fontSize: 18,
              letterSpacing: 1.0
            )),
            
            // Inline Error
            if (showGenderError && controller.selectedGender.value.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5.0),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                    const SizedBox(width: 5),
                    Text("Please select a character type", 
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.error, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 15),

            Obx(() => Row(
              children: [
                _buildGenderCard(controller, "Male", Icons.male_rounded, textTheme),
                const SizedBox(width: 12),
                _buildGenderCard(controller, "Female", Icons.female_rounded, textTheme),
                const SizedBox(width: 12),
                _buildGenderCard(controller, "Other", Icons.person_rounded, textTheme),
              ],
            )),
            
            const SizedBox(height: 40),

            // ✂️ Button is minimal now because AppTheme handles the style
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  print("--- VIEW: Continue Button Pressed ---");
                  FocusManager.instance.primaryFocus?.unfocus();
                  bool isFormValid = _formKey.currentState!.validate();
                  bool isGenderValid = controller.selectedGender.value.isNotEmpty;

                  print("--- VIEW: Form Valid? $isFormValid ---");
                  print("--- VIEW: Gender Valid? $isGenderValid (${controller.selectedGender.value}) ---");

                  if (!isGenderValid) setState(() => showGenderError = true);

                  if (isFormValid && isGenderValid) {
                    print("--- VIEW: All Checks Passed. Calling controller.nextPage() ---");
                    controller.nextPage();
                  } else {
                    print("--- VIEW: Validation Failed. Aborting. ---");
                  }

                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text("CONTINUE"), // Font style comes from Theme!
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderCard(OnboardingController controller, String label, IconData icon, TextTheme textTheme) {
    bool isSelected = controller.selectedGender.value == label;
    bool isError = showGenderError && controller.selectedGender.value.isEmpty;

    return Expanded(
      child: Material(
        color: Colors.transparent, 
        child: InkWell(
          onTap: () {
            controller.selectedGender.value = label;
            if (showGenderError) setState(() => showGenderError = false); 
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 100,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isError ? AppColors.error : (isSelected ? AppColors.primary : Colors.transparent),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: isSelected ? AppColors.primary : Colors.grey),
                const SizedBox(height: 8),
                Text(
                  label,
                  // ✅ Use Theme body text
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold, 
                    fontSize: 14,
                    color: isSelected ? AppColors.primary : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}