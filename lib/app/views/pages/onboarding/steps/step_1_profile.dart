import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:avatar_maker/avatar_maker.dart';
import '../../../../../../core/constants/color_constants.dart';
import '../../../../../../core/constants/font_constants.dart';
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
  final NonPersistentAvatarMakerController _avatarController =
      NonPersistentAvatarMakerController();

  String _avatarSvg = '';

  @override
  void initState() {
    super.initState();

    _avatarController.initController().then((_) {
      if (!mounted) return;

      final avatarSvg = _avatarController.getAvatarSVGSync();
      setState(() {
        _avatarSvg = avatarSvg;
      });

      final controller = Get.find<OnboardingController>();
      controller.updateAvatar(avatarSvg);
    });
  }

  @override
  void dispose() {
    _avatarController.dispose();
    super.dispose();
  }

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

            Text(
              "YOUR AVATAR",
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: AppFonts.title,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 15),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  AvatarMakerAvatar(
                    radius: 62,
                    backgroundColor: AppColors.primaryLight,
                    controller: _avatarController,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AvatarMakerRandomWidget(
                      controller: _avatarController,
                      radius: 24,
                      splashColor: AppColors.primary,
                      onTap: () {
                        if (!mounted) return;
                        final avatarSvg = _avatarController.getAvatarSVGSync();
                        setState(() {
                          _avatarSvg = avatarSvg;
                        });
                        final controller = Get.find<OnboardingController>();
                        controller.updateAvatar(avatarSvg);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Customize your hero look",
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 260,
                    child: AvatarMakerCustomizer(
                      controller: _avatarController,
                      scaffoldHeight: 260,
                      scaffoldWidth: MediaQuery.sizeOf(context).width - 48,
                      autosave: false,
                      onChange: (avatarSvg) {
                        if (!mounted) return;

                        setState(() {
                          _avatarSvg = avatarSvg;
                        });

                        final controller = Get.find<OnboardingController>();
                        controller.updateAvatar(avatarSvg);
                      },
                    ),
                  ),
                  if (_avatarSvg.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      "Avatar ready",
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ✅ Section Title using Theme
            // We use .copyWith to add the specific color/weight if the theme default isn't exact
            Text("Your Identity", style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900, 
              fontSize: AppFonts.title,
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

            Text("Character Type", style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900, 
              fontSize: AppFonts.title,
              letterSpacing: 1.0
            )),
            
            if (showGenderError && controller.gender.value.isEmpty)
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

            Row(
              children: [
                _buildGenderCard(controller, "Male", Icons.male_rounded, textTheme),
                const SizedBox(width: 12),
                _buildGenderCard(controller, "Female", Icons.female_rounded, textTheme),
                const SizedBox(width: 12),
                _buildGenderCard(controller, "Other", Icons.person_rounded, textTheme),
              ],
            ),

            const SizedBox(height: 30),

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
                );
                if (pickedDate != null) {
                  controller.age.text = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                }
              },
            ),
            
            const SizedBox(height: 40),

            // ✂️ Button is minimal now because AppTheme handles the style
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  print("--- VIEW: Continue Button Pressed ---");
                  //FocusManager.instance.primaryFocus?.unfocus();
                  bool isFormValid = _formKey.currentState!.validate();
                  bool isGenderValid = controller.gender.value.isNotEmpty;

                  print("--- VIEW: Form Valid? $isFormValid ---");
                  print("--- VIEW: Gender Valid? $isGenderValid (${controller.gender.value}) ---");

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
    return Obx(() {
      bool isSelected = controller.gender.value == label;
      bool isError = showGenderError && controller.gender.value.isEmpty;

      return Expanded(
      child: Material(
        color: Colors.transparent, 
        child: InkWell(
          onTap: () {
            controller.gender.value = label;
            if (showGenderError) setState(() => showGenderError = false); 
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 100,
            decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isError ? AppColors.error : (isSelected ? AppColors.primary : Colors.transparent),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: isSelected ? Colors.white : Colors.grey),
                const SizedBox(height: 8),
                Text(
                  label,
                  // ✅ Use Theme body text
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold, 
                    fontSize: AppFonts.bodyLg,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      );
    });
  }
}