import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../../core/constants/color_constants.dart';
import '../../../../../../core/constants/font_constants.dart';
import '../../../../../../core/utils/validators.dart';
import '../../../../controllers/onboarding_controller.dart';

class Step1Profile extends StatefulWidget {
  const Step1Profile({super.key});

  @override
  State<Step1Profile> createState() => _Step1ProfileState();
}

class _Step1ProfileState extends State<Step1Profile> {
  final _formKey = GlobalKey<FormState>();
  bool showGenderError = false;
  bool showAvatarError = false;
  final PageController _avatarCarouselController = PageController(viewportFraction: 0.45);
  int _prevAvatarCount = -1;

  @override
  void dispose() {
    _avatarCarouselController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OnboardingController controller = Get.find();
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // --- AVATAR SECTION (TOP) ---
            _buildAvatarSection(controller, textTheme),

            const SizedBox(height: 20),

            // Nickname Input
            TextFormField(
              controller: controller.nickname,
              textCapitalization: TextCapitalization.words,
              maxLength: 12,
              decoration: const InputDecoration(
                labelText: "Hero Name (Nickname)",
                hintText: "e.g. DragonSlayer",
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: Validators.validateName,
            ),
            const SizedBox(height: 10),

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
                );
                if (pickedDate != null) {
                  controller.age.text = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                }
              },
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  bool isFormValid = _formKey.currentState!.validate();
                  bool isGenderValid = controller.gender.value.isNotEmpty;
                  bool isAvatarValid = controller.avatarSvg.value.isNotEmpty;

                  if (!isGenderValid) setState(() => showGenderError = true);
                  if (!isAvatarValid) setState(() => showAvatarError = true);

                  if (isFormValid && isGenderValid && isAvatarValid) {
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
            controller.clearAvatarIfGenderMismatch(label);
            if (showAvatarError) setState(() => showAvatarError = false);
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

  Widget _buildAvatarSection(OnboardingController controller, TextTheme textTheme) {
    return Obx(() {
      final avatars = controller.getFilteredAvatars(controller.gender.value);
      final selectedPath = controller.avatarSvg.value;

      // Reset carousel when avatar list changes (gender switch)
      if (_prevAvatarCount != -1 && _prevAvatarCount != avatars.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_avatarCarouselController.hasClients) {
            _avatarCarouselController.jumpToPage(0);
          }
        });
      }
      _prevAvatarCount = avatars.length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("CHOOSE YOUR CHARACTER", style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: AppFonts.title,
            letterSpacing: 1.0,
          )),
          const SizedBox(height: 16),
          SizedBox(
            height: 210,
            child: PageView.builder(
              controller: _avatarCarouselController,
              itemCount: avatars.length,
              onPageChanged: (index) {
                if (index >= 0 && index < avatars.length) {
                  final path = avatars[index]['assetPath']!;
                  if (controller.avatarSvg.value != path) {
                    if (showAvatarError) setState(() => showAvatarError = false);
                    controller.updateAvatar(path);
                  }
                }
              },
              itemBuilder: (context, index) {
                final avatar = avatars[index];
                final path = avatar['assetPath']!;
                final name = avatar['name']!;
                final description = avatar['description']!;
                final isSelected = selectedPath == path;

                return AnimatedBuilder(
                  animation: _avatarCarouselController,
                  builder: (context, child) {
                    double scale = 1.0;
                    if (_avatarCarouselController.hasClients) {
                      final page = _avatarCarouselController.page ?? index.toDouble();
                      final offset = (page - index).abs();
                      scale = (1 - offset * 0.3).clamp(0.65, 1.0);
                    }
                    return Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: scale,
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: GestureDetector(
                      onTap: () {
                        if (showAvatarError) setState(() => showAvatarError = false);
                        controller.updateAvatar(path);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final size = constraints.maxWidth - 16;
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: size,
                                      height: size,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.transparent,
                                        border: isSelected
                                            ? Border.all(color: AppColors.primary, width: 3)
                                            : Border.all(color: Colors.transparent, width: 3),
                                      ),
                                      child: ClipOval(
                                        child: Image.asset(
                                          path,
                                          width: size,
                                          height: size,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        bottom: 2,
                                        right: 2,
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: AppFonts.badge,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(name),
                                    content: Text(description),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text("OK"),
                                      ),
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.info_outline_rounded,
                                  size: 14,
                                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (showAvatarError && controller.avatarSvg.value.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                  const SizedBox(width: 5),
                  Text("Please select a character",
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.error, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }
}
