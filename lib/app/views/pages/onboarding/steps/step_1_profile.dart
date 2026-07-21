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

  bool get _hasSingleAvatarCarouselClient =>
      _avatarCarouselController.hasClients &&
      _avatarCarouselController.positions.length == 1;

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

            _buildAvatarSection(controller, textTheme),

            const SizedBox(height: 20),

            TextFormField(
              controller: controller.nickname,
              textCapitalization: TextCapitalization.words,
              maxLength: 12,
              decoration: InputDecoration(
                labelText: "Hero Name (Nickname)",
                hintText: "e.g. DragonSlayer",
                prefixIcon: const Icon(Icons.person_outline_rounded),
                counterText: "",
                suffixIconConstraints: const BoxConstraints(minWidth: 54),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller.nickname,
                  builder: (_, value, __) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          "${value.text.length}/12",
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppFonts.micro,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
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

      if (_prevAvatarCount != -1 && _prevAvatarCount != avatars.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_hasSingleAvatarCarouselClient) {
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
          const SizedBox(height: 6),
          Text(
            "Pick the adventurer that feels like your learning style.",
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontSize: AppFonts.caption,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
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
                final isSelected = selectedPath == path;

                return AnimatedBuilder(
                  animation: _avatarCarouselController,
                  builder: (context, child) {
                    double scale = isSelected ? 1.0 : 0.82;
                    if (_hasSingleAvatarCarouselClient) {
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
                                onTap: () => _showAvatarMeaningDialog(
                                  context,
                                  avatar,
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
          _buildSelectedAvatarMeaning(
            _findAvatarByPath(avatars, selectedPath),
            textTheme,
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

  Map<String, String>? _findAvatarByPath(
    List<Map<String, String>> avatars,
    String selectedPath,
  ) {
    if (selectedPath.isEmpty) return null;
    for (final avatar in avatars) {
      if (avatar['assetPath'] == selectedPath) {
        return avatar;
      }
    }
    return null;
  }

  Widget _buildSelectedAvatarMeaning(
    Map<String, String>? avatar,
    TextTheme textTheme,
  ) {
    if (avatar == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          "Select a character to see what their learning style means.",
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontSize: AppFonts.caption,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final traits = avatar['traits']!.split('|');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.textShadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  avatar['name']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: AppFonts.bodyLg,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: AppColors.secondary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            avatar['description']!,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontSize: AppFonts.caption,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: traits.map(_buildTraitChip).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            "This shapes your profile identity only. Your quests still adapt to your hobby and goal.",
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.82),
              fontSize: AppFonts.micro,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTraitChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: AppFonts.micro,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  void _showAvatarMeaningDialog(
    BuildContext context,
    Map<String, String> avatar,
  ) {
    final traits = avatar['traits']!.split('|');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(avatar['name']!),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(avatar['description']!),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: traits.map(_buildTraitChip).toList(),
            ),
            const SizedBox(height: 14),
            const Text(
              "This choice is your profile identity, not your quest difficulty.",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFonts.caption,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
