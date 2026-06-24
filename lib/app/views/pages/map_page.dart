import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  int _speechIndex = -1;

  final List<String> _speechMessages = [
    "Oh, hello! Who's that? Are you my new gardener?",
    "I'm your new Creative Arts seed! Every time you practice your hobby, I earn XP to grow big and strong!",
    "Head over to your Quest Page to log your first session. I'll wait right here!",
  ];

  @override
  void initState() {
    super.initState();
    _checkTutorialStatus();
    _loadCategories();
  }

  Future<void> _checkTutorialStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final done = doc.data()?['mapTutorialDone'] as bool? ?? false;
      if (!mounted) return;
      setState(() => _speechIndex = done ? -1 : 0);
    } catch (_) {
      if (!mounted) return;
      setState(() => _speechIndex = 0);
    }
  }

  Future<void> _finishTutorial() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'mapTutorialDone': true}, SetOptions(merge: true));
    } catch (_) {}
    if (!mounted) return;
    setState(() => _speechIndex = -1);
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header with background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  category.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: AppFonts.titleLg,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Center image with speech bubble
          Expanded(
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/seed.png',
                    width: 200,
                    fit: BoxFit.contain,
                  ),
                ),
                // Speech bubble
                if (_speechIndex >= 0 && _speechIndex < _speechMessages.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: GestureDetector(
                      onTap: () {
                        if (_speechIndex < _speechMessages.length - 1) {
                          setState(() => _speechIndex++);
                        } else {
                          _finishTutorial();
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            constraints: const BoxConstraints(maxWidth: 260),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              _speechMessages[_speechIndex],
                              style: const TextStyle(
                                fontSize: AppFonts.bodyLg,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Speech bubble tail
                          CustomPaint(
                            size: const Size(16, 10),
                            painter: _TrianglePainter(),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap anywhere to continue',
                            style: TextStyle(
                              fontSize: AppFonts.micro,
                              color: AppColors.textSecondary
                                  .withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a downward-pointing triangle for the speech bubble tail.
class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
