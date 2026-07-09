import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/progression_controller.dart';
import '../../services/category_service.dart';
import '../../models/category_model.dart';
import '../../models/tree_model.dart';
import '../../routes/app_routes.dart';
import '../../../core/utils/dialog_utils.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final CategoryService _categoryService = CategoryService();
  List<CategoryModel> _allCategories = [];
  List<CategoryModel> _categories = [];
  int? _selectedIndex;
  bool _isLoading = true;
  Worker? _hobbyWorker;
  Worker? _tabWorker;
  int _speechIndex = -1;
  AnimationController? _floatController;
  Animation<double>? _floatAnimation;
  AnimationController? _shakeController;
  Animation<double>? _shakeAnimation;
  int _displayedStage = 0;
  String _displayedStageCategory = '';

  final List<String> _speechMessages = [
    "Oh, hello! Who's that? Are you my new gardener?",
    "I'm your new Creative Arts seed! Every time you practice your hobby, I earn XP to grow big and strong!",
    "Head over to your Quest Page to log your first session. I'll wait right here!",
  ];

  String _treeImageForStage(int stage) {
    const images = [
      'assets/images/seed.png',
      'assets/images/sprout.png',
      'assets/images/seedling.png',
      'assets/images/young_tree.png',
      'assets/images/mature_tree.png',
    ];
    return images[stage.clamp(0, 4)];
  }

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(
        parent: _floatController!,
        curve: Curves.easeInOutSine,
      ),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 5.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: -5.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 2.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 2.0, end: 0.0), weight: 1),
    ]).animate(_shakeController!);
    _checkTutorialStatus();
    _bindCurrentHobbySelection();
    _loadCategories();
  }

  @override
  void dispose() {
    _floatController?.stop();
    _shakeController?.stop();
    _floatController?.dispose();
    _shakeController?.dispose();
    _hobbyWorker?.dispose();
    _tabWorker?.dispose();
    super.dispose();
  }

  void _bindCurrentHobbySelection() {
    if (Get.isRegistered<HomeController>()) {
      _hobbyWorker = ever<String>(
        Get.find<HomeController>().hobby,
        (_) => _selectCurrentHobbyCategory(),
      );
    }

    if (Get.isRegistered<DashboardController>()) {
      _tabWorker = ever<int>(
        Get.find<DashboardController>().tabIndex,
        (index) {
          if (index == DashboardController.forestTabIndex) {
            _selectCurrentHobbyCategory();
          }
        },
      );
    }
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

  void _triggerShake() {
    _shakeController?.forward(from: 0.0);
  }

  Future<void> _saveTreeToForest(CategoryModel category, String treeName) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final progressionController = Get.find<ProgressionController>();

    try {
      // Find first free spot index
      final existingDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tree')
          .get();
      final usedIndices =
          existingDocs.docs.map((doc) => doc['treeIndex'] as int? ?? 0).toSet();
      int firstFree = 0;
      while (usedIndices.contains(firstFree) && firstFree < 6) {
        firstFree++;
      }

      // Count completed quests from current plan
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final rawPlan = userSnap.data()?['currentPlan'] as Map<String, dynamic>?;
      final rawQuests = rawPlan?['quests'] as List<dynamic>? ?? [];
      final completedCount = rawQuests
          .where((q) =>
              q is Map<String, dynamic> && q['isCompleted'] == true)
          .length;
      final totalMinutes = rawQuests
          .where((q) =>
              q is Map<String, dynamic> && q['isCompleted'] == true)
          .fold<int>(
        0,
        (acc, q) =>
            acc +
            ((q['durationMinutes'] as int?) ??
                (q['duration_minutes'] as int?) ??
                0),
      );

      final tree = TreeModel(
        treeName: treeName,
        categoryId: category.id,
        xpRequired: 800,
        treeIndex: firstFree,
        questsCompleted: completedCount,
        learningMinutes: totalMinutes,
        createdAt: DateTime.now(),
        grownAt: DateTime.now(),
      );

      // Save to tree subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tree')
          .add(tree.toJson());

      // Reset category XP to 0 so user can grow a new tree
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'categoryXp.${category.name}': 0});
      progressionController.categoryXp[category.name] = 0;

      print('--- Tree saved to forest: ${category.name} ---');
    } catch (e) {
      print('--- Error saving tree to forest: $e ---');
    }
  }

  Future<void> _showTreeNamingDialog(CategoryModel category) async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await AppDialogs.custom<bool>(
      barrierDismissible: false,
      builder: (context) => Form(
        key: formKey,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Congratulations!\nYour tree has grown!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppFonts.titleLg,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your ${category.name} tree has reached full maturity. Give it a name to save it in your forest!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppFonts.caption,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: 'Give your tree a name...',
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  if (value.trim().length > 30) {
                    return 'Name must be 30 characters or less';
                  }
                  return null;
                },
                maxLength: 30,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Get.back(result: true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Plant Tree',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: AppFonts.badge,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      await _saveTreeToForest(category, nameController.text.trim());
      // Navigate to the dedicated Forest page where the tree is displayed
      Get.toNamed(AppRoutes.FOREST);
    }
    nameController.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _categoryService.getCategories();
      final currentHobby = _currentHobbyName();
      final visibleCategories = _visibleCategoriesForHobby(cats, currentHobby);
      final hobbyIndex = _findCategoryIndexForHobby(
        visibleCategories,
        currentHobby,
      );
      if (!mounted) return;
      setState(() {
        _allCategories = cats.toList();
        _categories = visibleCategories;
        _selectedIndex = hobbyIndex >= 0 ? hobbyIndex : 0;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _selectCurrentHobbyCategory() {
    if (!mounted || _allCategories.isEmpty) return;

    final currentHobby = _currentHobbyName();
    if (currentHobby.isEmpty) return;

    final visibleCategories = _visibleCategoriesForHobby(
      _allCategories,
      currentHobby,
    );
    final hobbyIndex = _findCategoryIndexForHobby(
      visibleCategories,
      currentHobby,
    );
    if (hobbyIndex < 0) return;

    setState(() {
      _categories = visibleCategories;
      _selectedIndex = hobbyIndex;
    });
  }

  String _currentHobbyName() {
    if (!Get.isRegistered<HomeController>()) return '';

    final homeController = Get.find<HomeController>();
    final reactiveHobby = homeController.hobby.value.trim();
    if (reactiveHobby.isNotEmpty) return reactiveHobby;

    return homeController.user.value?.currentPlan.hobby.trim() ?? '';
  }

  List<CategoryModel> _visibleCategoriesForHobby(
    List<CategoryModel> categories,
    String hobby,
  ) {
    final visibleCategories = categories.toList();
    final hobbyIndex = _findCategoryIndexForHobby(visibleCategories, hobby);
    if (hobbyIndex >= 4) {
      final hobbyCategory = visibleCategories.removeAt(hobbyIndex);
      visibleCategories.insert(0, hobbyCategory);
    }

    return visibleCategories.take(4).toList();
  }

  int _findCategoryIndexForHobby(
    List<CategoryModel> categories,
    String hobby,
  ) {
    final normalizedHobby = hobby.trim().toLowerCase();
    if (normalizedHobby.isEmpty) return -1;

    return categories.indexWhere(
      (category) => category.hobbyNames.any(
        (name) => name.trim().toLowerCase() == normalizedHobby,
      ),
    );
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
              : Stack(
                  children: [
                    Column(
                      children: [
                        _buildCategoryTopBar(),
                        Expanded(child: _buildContent()),
                      ],
                    ),
                    // Floating forest button (always visible)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: FloatingActionButton(
                        onPressed: () => Get.toNamed(AppRoutes.FOREST),
                        child: const Icon(Icons.forest_rounded),
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        elevation: 0,
                        focusElevation: 0,
                        hoverElevation: 0,
                        highlightElevation: 0,
                      ),
                    ),
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
        child: Obx(() {
          final progressionController = Get.find<ProgressionController>();
          final xp = progressionController.categoryXp[category.name] ?? 0;
          final thresholds = [0, 100, 300, 500, 800];
          final labels = ['Seed', 'Sprout', 'Seedling', 'Young Tree', 'Mature Tree'];

          // Compute actual stage from XP
          int actualStage = 0;
          for (int i = thresholds.length - 1; i >= 0; i--) {
            if (xp >= thresholds[i]) { actualStage = i; break; }
          }

          // Reset displayed stage when switching categories
          if (category.name != _displayedStageCategory) {
            _displayedStageCategory = category.name;
            _displayedStage = actualStage;
          }

          // If XP regressed (tree saved), sync displayed stage down
          if (actualStage < _displayedStage) {
            _displayedStage = actualStage;
          }

          // Check if there's a pending stage to advance to
          final hasPending = actualStage > _displayedStage;

          final stage = _displayedStage;
          final currentMin = thresholds[stage];
          final nextMax = stage < thresholds.length - 1 ? thresholds[stage + 1] : thresholds[stage] + 1000;
          final progress = ((xp - currentMin) / (nextMax - currentMin)).clamp(0.0, 1.0);
          final xpToNext = stage < thresholds.length - 1 ? nextMax - xp : 0;

          return GestureDetector(
            onTap: _speechIndex >= 0 && _speechIndex < _speechMessages.length
                ? () {
                    if (_speechIndex < _speechMessages.length - 1) {
                      setState(() => _speechIndex++);
                    } else {
                      _finishTutorial();
                    }
                  }
                : hasPending
                    ? () {
                        setState(() {
                          _displayedStage++;
                          _triggerShake();
                        });
                        if (_displayedStage == 4) {
                          _showTreeNamingDialog(category);
                        }
                      }
                    : stage == 4
                        ? () => _showTreeNamingDialog(category)
                        : null,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Speech bubble (above the tree)
              if (_speechIndex >= 0 && _speechIndex < _speechMessages.length)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
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
                          painter: _TriangleDownPainter(),
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
              // Tree image with floating + shake animation
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([_floatAnimation!, _shakeAnimation!]),
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation!.value, _floatAnimation!.value),
                        child: child,
                      );
                    },
                    child: Image.asset(
                      _treeImageForStage(stage),
                      width: 200,
                      fit: BoxFit.contain,
                    ),
                  ),
                  // Speech bubble when next stage is pending or tree is fully grown
                  if (hasPending || stage == 4)
                    Positioned(
                      top: -56,
                      left: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: hasPending
                            ? () {
                                setState(() {
                                  _displayedStage++;
                                  _triggerShake();
                                });
                                if (_displayedStage == 4) {
                                  _showTreeNamingDialog(category);
                                }
                              }
                            : () => _showTreeNamingDialog(category),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              constraints: const BoxConstraints(maxWidth: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
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
                                hasPending ? 'Tap me to grow!' : 'Save me to forest!',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: AppFonts.badge,
                                  color: AppColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Triangle pointing down toward the tree
                            CustomPaint(
                              size: const Size(14, 8),
                              painter: _TriangleDownPainter(),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              hasPending ? 'Tap to level up' : 'Tap to name your tree',
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
              ),
          );
            }),
          ),
        );
  }
}

/// Paints a downward-pointing triangle for a speech bubble tail.
class _TriangleDownPainter extends CustomPainter {
  const _TriangleDownPainter({this.color = Colors.white});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TriangleDownPainter oldDelegate) =>
      oldDelegate.color != color;
}
