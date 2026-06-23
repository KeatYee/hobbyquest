import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';
import '../../controllers/home_controller.dart';
import '../../services/category_service.dart';
import '../../models/category_model.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final CategoryService _categoryService = CategoryService();
  List<CategoryModel> _categories = [];
  int? _selectedIndex;
  bool _navExpanded = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _categoryService.getCategories();
      final currentHobby = Get.find<HomeController>().hobby.value;
      setState(() {
        _categories = cats.take(4).toList();
        // Default to the category containing the user's current hobby
        final hobbyIndex = _categories.indexWhere(
            (c) => c.hobbyNames.any((h) => h.toLowerCase() == currentHobby.toLowerCase()));
        _selectedIndex = hobbyIndex >= 0 ? hobbyIndex : 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full-screen background image
        Positioned.fill(
          child: Opacity(
            opacity: 0.75,
            child: Image.asset(
              'assets/images/forestBG.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Foreground content
        SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _categories.isEmpty
                  ? const Center(child: Text('No categories available'))
                  : Stack(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              width: _navExpanded ? 160 : 0,
                              child: _navExpanded ? _buildSideNav() : const SizedBox.shrink(),
                            ),
                            Expanded(child: _buildContent()),
                          ],
                        ),
                        // Floating expand button (only when collapsed)
                        if (!_navExpanded)
                          Positioned(
                            left: 8,
                            bottom: 12,
                            child: Material(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              elevation: 0,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => setState(() => _navExpanded = true),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────
  //  SIDE NAVIGATION — icons only, expandable with arrow
  // ────────────────────────────────────────────────────────
  Widget _buildSideNav() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            ...List.generate(_categories.length, (index) {
              final cat = _categories[index];
              final isSelected = _selectedIndex == index;
              return _buildNavItem(
                icon: cat.icon,
                label: cat.name,
                isSelected: isSelected,
                onTap: () => setState(() => _selectedIndex = index),
              );
            }),
            const Spacer(),
            // Collapse arrow
            IconButton(
              icon: const Icon(
                Icons.chevron_left_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() => _navExpanded = false),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: AppFonts.caption,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  //  CONTENT — Tree view
  // ────────────────────────────────────────────────────────
  Widget _buildContent() {
    if (_selectedIndex == null) {
      return const Center(child: Text('Select a category'));
    }

    final category = _categories[_selectedIndex!];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(category.icon, size: 28, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: AppFonts.titleLg,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category.description,
                      style: const TextStyle(
                        fontSize: AppFonts.caption,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
