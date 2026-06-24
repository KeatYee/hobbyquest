import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/progression_controller.dart';
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
  bool _isLoading = true;
  int _speechIndex = -1;

  final List<String> _speechMessages = [
    "Oh, hello! Who's that? Are you my new gardener?",
    "I'm your new Creative Arts seed! Every time you practice your hobby, I earn XP to grow big and strong!",
    "Head over to your Quest Page to log your first session. I'll wait right here!",
  ];

  /// Returns the tree image path based on XP value.
  String _treeImageForXp(int xp) {
    if (xp >= 7000) return 'assets/images/mature_tree.png';
    if (xp >= 5000) return 'assets/images/young_tree.png';
    if (xp >= 2500) return 'assets/images/seedling.png';
    if (xp >= 800) return 'assets/images/sprout.png';
    return 'assets/images/seed.png';
  }

  @override
  void initState() {
    super.initState();
    _checkTutorialStatus();
    _loadCategories();
  }

  Future<void> _checkTutorialStatus() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final done = (doc.data()?['mapTutorialDone'] as bool?) ?? false;
      if (!mounted) return;
      setState(() => _speechIndex = done ? -1 : 0);
      print('--- Map tutorial status: $done ---');
    } catch (e) {
      print('--- ERROR checking tutorial status: $e ---');
      if (!mounted) return;
      setState(() => _speechIndex = 0);
    }
  }

  Future<void> _finishTutorial() async {
    try {
      final homeCtrl = Get.find<HomeController>();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'mapTutorialDone': true});
      if (homeCtrl.user.value != null) {
        homeCtrl.user.value = homeCtrl.user.value!.copyWith(mapTutorialDone: true);
      }
      print('--- SUCCESS: Map tutorial completed and saved to Firestore ---');
    } catch (e) {
      print('--- ERROR: Failed to save map tutorial status: $e ---');
    }
    if (!mounted) return;
    setState(() => _speechIndex = -1);
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _categoryService.getCategories();
      final currentHobby = Get.find<HomeController>().hobby.value;
      setState(() {
        _categories = cats.take(4).toList();
        final hobbyIndex = _categories.indexWhere(
            (c) => c.hobbyNames.any((h) => h.toLowerCase() == currentHobby.toLowerCase()));
        _selectedIndex = hobbyIndex >= 0 ? hobbyIndex : 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _previousCategory() {
    if (_categories.isEmpty || _selectedIndex == null) return;
    setState(() {
      _selectedIndex = (_selectedIndex! - 1 + _categories.length) % _categories.length;
    });
  }

  void _nextCategory() {
    if (_categories.isEmpty || _selectedIndex == null) return;
    setState(() {
      _selectedIndex = (_selectedIndex! + 1) % _categories.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const Center(child: Text('No categories available'))
              : Column(
                  children: [
                    _buildCategoryTopBar(),
                    Expanded(child: _buildContent()),
                  ],
                ),
    );
  }

  // ────────────────────────────────────────────────────────
  //  TOP BAR — arrows + category name
  // ────────────────────────────────────────────────────────
  Widget _buildCategoryTopBar() {
    final category = _categories[_selectedIndex!];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Left arrow
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            color: AppColors.primary,
            onPressed: _previousCategory,
          ),
          const SizedBox(width: 4),
          // Category icon + name
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(category.icon, size: 22, color: AppColors.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    category.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: AppFonts.titleLg,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Right arrow
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            color: AppColors.primary,
            onPressed: _nextCategory,
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────
  //  CONTENT — tree image + XP bar + speech bubble
  // ────────────────────────────────────────────────────────
  Widget _buildContent() {
    if (_selectedIndex == null) {
      return const Center(child: Text('Select a category'));
    }

    final category = _categories[_selectedIndex!];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 20, 20),
      child: Center(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Tree image + XP bar
            Obx(() {
              final progressionController = Get.find<ProgressionController>();
              final xp = progressionController.categoryXp[category.name] ?? 0;
              final thresholds = [0, 800, 2500, 5000, 7000];
              final labels = ['Seed', 'Sprout', 'Seedling', 'Young Tree', 'Mature Tree'];

              int stage = 0;
              for (int i = thresholds.length - 1; i >= 0; i--) {
                if (xp >= thresholds[i]) { stage = i; break; }
              }

              final currentMin = thresholds[stage];
              final nextMax = stage < thresholds.length - 1 ? thresholds[stage + 1] : thresholds[stage] + 1000;
              final progress = ((xp - currentMin) / (nextMax - currentMin)).clamp(0.0, 1.0);
              final xpToNext = stage < thresholds.length - 1 ? nextMax - xp : 0;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    _treeImageForXp(xp),
                    width: 200,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 220,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              labels[stage],
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: AppFonts.badge,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (stage < thresholds.length - 1)
                              Text(
                                '$xp / $nextMax XP',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: AppFonts.micro,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            else
                              Text(
                                '$xp XP',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: AppFonts.micro,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: AppColors.border,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (stage < thresholds.length - 1)
                          Text(
                            '$xpToNext XP to ${labels[stage + 1]}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: AppFonts.micro,
                              color: AppColors.textSecondary,
                            ),
                          )
                        else
                          const Text(
                            'Fully grown!',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: AppFonts.micro,
                              color: AppColors.success,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }),
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
                      CustomPaint(
                        size: const Size(16, 10),
                        painter: _TrianglePainter(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap anywhere to continue',
                        style: TextStyle(
                          fontSize: AppFonts.micro,
                          color: AppColors.textSecondary.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
