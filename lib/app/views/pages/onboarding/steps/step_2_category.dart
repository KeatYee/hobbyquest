import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/constants/color_constants.dart';
import '../../../../../../core/constants/font_constants.dart';
import '../../../../controllers/onboarding_controller.dart';
import '../../../../data/onboarding_catalog.dart';

class Step2Category extends StatefulWidget {
  const Step2Category({super.key});

  @override
  State<Step2Category> createState() => _Step2CategoryState();
}

class _Step2CategoryState extends State<Step2Category> {
  bool showError = false;

  @override
  Widget build(BuildContext context) {
    final OnboardingController controller = Get.find();
    final textTheme = Theme.of(context).textTheme;

    return Obx(() {
      final categoryList = OnboardingCatalog.filterSupportedCategories(
        controller.categories.value,
      );
      final isLoading = controller.isLoadingCategories.value;

      final activeCategoryName = controller.category.value.isNotEmpty
          ? controller.category.value
          : (categoryList.isNotEmpty ? categoryList.first.name : "");

      final activeCategoryModel = categoryList.firstWhereOrNull(
        (cat) => cat.name == activeCategoryName,
      );
      final currentHobbies = activeCategoryModel?.hobbyNames ?? <String>[];

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            Text(
              "CHOOSE YOUR PATH",
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: AppFonts.title,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            if (showError && controller.hobby.value.isEmpty)
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
                      "Select a hobby to continue",
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: AppFonts.badge,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 15),
            if (isLoading)
              Center(
                child: Column(
                  children: const [
                    SizedBox(height: 40),
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text("Loading paths..."),
                    SizedBox(height: 40),
                  ],
                ),
              )
            else ...[
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categoryList.length > 4 ? 4 : categoryList.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final category = categoryList[index];
                    final categoryName = category.name;
                    final isSelected = activeCategoryName == categoryName;

                    return ChoiceChip(
                      selected: isSelected,
                      showCheckmark: false,
                      label: Text(
                        categoryName,
                        style: GoogleFonts.openSans(
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.textOnPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      avatar: Icon(
                        category.icon,
                        size: 20,
                        color: isSelected
                            ? AppColors.textOnPrimary
                            : AppColors.textSecondary,
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.borderStrong,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      onSelected: (_) {
                        controller.category.value = categoryName;
                        controller.hobby.value = "";
                        if (showError) {
                          setState(() => showError = false);
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
              const SizedBox(height: 12),
              GridView.builder(
                key: ValueKey("$activeCategoryName-${controller.hobby.value}"),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.0,
                ),
                itemCount: currentHobbies.length,
                itemBuilder: (context, index) {
                  final hobby = currentHobbies[index];
                  final isSelected = controller.hobby.value == hobby;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        controller.selectHobby(activeCategoryName, hobby);
                        if (showError) {
                          setState(() => showError = false);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary.withValues(
                                    alpha: 0.2,
                                  ),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.25)
                                  : AppColors.textPrimary.withValues(
                                      alpha: 0.05,
                                    ),
                              blurRadius: isSelected ? 14 : 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_fire_department_rounded,
                              size: 30,
                              color: isSelected
                                  ? AppColors.textOnPrimary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                hobby,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.openSans(
                                  fontSize: AppFonts.bodyLg,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? AppColors.textOnPrimary
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  if (controller.category.value.isEmpty &&
                      activeCategoryName.isNotEmpty) {
                    controller.category.value = activeCategoryName;
                  }
                  if (controller.hobby.value.isEmpty) {
                    setState(() => showError = true);
                  } else {
                    controller.nextPage();
                  }
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "NEXT STEP",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppFonts.body,
                      ),
                    ),
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
}
