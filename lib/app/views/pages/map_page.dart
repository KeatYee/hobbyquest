import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/color_constants.dart';
import '../../../core/constants/font_constants.dart';
import '../../../core/constants/asset_constants.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/progression_controller.dart';
import '../../services/category_service.dart';
import '../../models/category_model.dart';
import '../../models/tree_model.dart';
import '../../routes/app_routes.dart';
import '../../../core/utils/dialog_utils.dart';
import '../widgets/grove_complete_screen.dart';

class GrovePlantingResult {
  final int plantedGroveIndex;
  final bool completedGrove;
  final int groveTreeCount;
  final int totalQuestXp;
  final List<int> occupiedSlots;

  const GrovePlantingResult({
    required this.plantedGroveIndex,
    required this.completedGrove,
    required this.groveTreeCount,
    required this.totalQuestXp,
    required this.occupiedSlots,
  });
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final CategoryService _categoryService = CategoryService();
  final AudioPlayer _revealAudioPlayer = AudioPlayer();
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
  bool _isSavingTree = false;
  bool _isTreeNamingDialogOpen = false;

  final List<String> _speechMessages = [
    "Oh, hello! Who's that? Are you my new gardener?",
    "I'm your new Creative Arts seed! Every time you practice your hobby, I earn XP to grow big and strong!",
    "Head over to your Quest Page to log your first session. I'll wait right here!",
  ];

  String _treeImageForStage(int stage) {
    const images = [
      AppAssets.treeSeed,
      AppAssets.treeSprout,
      AppAssets.treeSeedling,
      AppAssets.treeYoung,
      AppAssets.treeMature,
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
      CurvedAnimation(parent: _floatController!, curve: Curves.easeInOutSine),
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
    _revealAudioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playRevealSound() async {
    if (!mounted) return;

    try {
      await _revealAudioPlayer.play(AssetSource('audio/reveal.mp3'));
    } catch (_) {
      // Ignore sound failures so the naming popup still opens cleanly.
    }
  }

  void _bindCurrentHobbySelection() {
    if (Get.isRegistered<HomeController>()) {
      _hobbyWorker = ever<String>(
        Get.find<HomeController>().hobby,
        (_) => _selectCurrentHobbyCategory(),
      );
    }

    if (Get.isRegistered<DashboardController>()) {
      _tabWorker = ever<int>(Get.find<DashboardController>().tabIndex, (index) {
        if (index == DashboardController.forestTabIndex) {
          _selectCurrentHobbyCategory();
        }
      });
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
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'mapTutorialDone': true,
      });
      if (homeCtrl.user.value != null) {
        homeCtrl.user.value = homeCtrl.user.value!.copyWith(
          mapTutorialDone: true,
        );
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

  int _readGroveIndex(dynamic value) {
    final index = (value as num?)?.toInt() ?? 1;
    return index < 1 ? 1 : index;
  }

  Set<int> _readGroveIndexes(dynamic value) {
    if (value is! List) return <int>{};
    return value
        .whereType<num>()
        .map((item) => item.toInt())
        .where((index) => index > 0)
        .toSet();
  }

  Map<int, Set<int>> _readGroveSlots(
    Map<String, dynamic> userData,
    Map<int, Set<int>> existingSlotsByGrove,
  ) {
    final slots = <int, Set<int>>{
      for (final entry in existingSlotsByGrove.entries)
        entry.key: <int>{...entry.value},
    };
    final stored = userData['occupiedTreeSlotsByGrove'];
    if (stored is Map) {
      for (final entry in stored.entries) {
        final groveIndex = int.tryParse(entry.key.toString()) ?? 0;
        if (groveIndex < 1 || entry.value is! List) continue;
        slots
            .putIfAbsent(groveIndex, () => <int>{})
            .addAll(
              entry.value
                  .whereType<num>()
                  .map((item) => item.toInt())
                  .where(
                    (index) => index >= 0 && index < TreeModel.forestSpotCount,
                  ),
            );
      }
    }
    final legacySlots = userData['occupiedTreeSlots'];
    if (legacySlots is List) {
      slots
          .putIfAbsent(1, () => <int>{})
          .addAll(
            legacySlots
                .whereType<num>()
                .map((item) => item.toInt())
                .where(
                  (index) => index >= 0 && index < TreeModel.forestSpotCount,
                ),
          );
    }
    return slots;
  }

  Future<GrovePlantingResult?> _saveTreeToForest(
    CategoryModel category,
    String treeName,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _isSavingTree) return null;
    _isSavingTree = true;

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);
    final treeCollection = userRef.collection('tree');
    final progressionController = Get.find<ProgressionController>();
    final homeController = Get.find<HomeController>();

    try {
      final userSnapshot = await userRef.get();
      final userData = userSnapshot.data();
      if (userData == null) {
        throw StateError('User profile not found.');
      }
      final planId = userData['activePlanId']?.toString().trim() ?? '';
      if (planId.isEmpty) {
        throw StateError('No active learning plan was found.');
      }

      final existingDocs = await treeCollection.get();
      final existingSlotsByGrove = <int, Set<int>>{};
      for (final doc in existingDocs.docs) {
        final data = doc.data();
        final groveIndex = (((data['groveIndex'] as num?)?.toInt() ?? 1).clamp(
          1,
          999999,
        )).toInt();
        final treeIndex = (data['treeIndex'] as num?)?.toInt() ?? -1;
        if (treeIndex < 0 || treeIndex >= TreeModel.forestSpotCount) continue;
        existingSlotsByGrove
            .putIfAbsent(groveIndex, () => <int>{})
            .add(treeIndex);
      }
      var completedCount = 0;
      var totalMinutes = 0;
      if (planId.isNotEmpty) {
        final questSnapshot = await userRef
            .collection('plans')
            .doc(planId)
            .collection('quests')
            .get();
        for (final quest in questSnapshot.docs) {
          final data = quest.data();
          if (data['isCompleted'] != true) continue;
          completedCount += 1;
          totalMinutes +=
              (data['durationMinutes'] as num?)?.toInt() ??
              (data['duration_minutes'] as num?)?.toInt() ??
              0;
        }
      }

      final treeRef = treeCollection.doc();
      late GrovePlantingResult plantingResult;
      await firestore.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        final userData = userSnapshot.data();
        if (userData == null) {
          throw StateError('User profile not found.');
        }
        final storedPlanId = userData['activePlanId']?.toString().trim() ?? '';
        if (storedPlanId != planId) {
          throw StateError('The active learning plan changed. Please retry.');
        }

        final categoryXp = <String, dynamic>{};
        final storedCategoryXp = userData['categoryXp'];
        if (storedCategoryXp is Map) {
          categoryXp.addAll(Map<String, dynamic>.from(storedCategoryXp));
        }
        final currentXp =
            (categoryXp[category.name] as num?)?.toInt() ??
            (userData['categoryXp.${category.name}'] as num?)?.toInt() ??
            0;
        if (currentXp < TreeModel.maturityXp) {
          throw StateError('This tree has not reached maturity yet.');
        }

        final slotsByGrove = _readGroveSlots(userData, existingSlotsByGrove);
        final completedGroves = _readGroveIndexes(
          userData['completedGroveIndexes'],
        );
        var currentGroveIndex = _readGroveIndex(userData['currentGroveIndex']);
        var occupiedSlots = slotsByGrove[currentGroveIndex] ?? <int>{};

        // Existing users may already have a full legacy Grove 1. Move their
        // next planting action into Grove 2 instead of blocking progression.
        while (occupiedSlots.length >= TreeModel.forestSpotCount) {
          completedGroves.add(currentGroveIndex);
          currentGroveIndex += 1;
          occupiedSlots = slotsByGrove[currentGroveIndex] ?? <int>{};
        }

        int? firstFree;
        for (var index = 0; index < TreeModel.forestSpotCount; index++) {
          if (!occupiedSlots.contains(index)) {
            firstFree = index;
            break;
          }
        }
        if (firstFree == null) throw StateError('No grove space is available.');

        final tree = TreeModel(
          treeName: treeName,
          categoryId: category.id,
          planId: planId,
          xpRequired: TreeModel.maturityXp,
          groveIndex: currentGroveIndex,
          treeIndex: firstFree,
          questsCompleted: completedCount,
          learningMinutes: totalMinutes,
          createdAt: DateTime.now(),
          grownAt: DateTime.now(),
        );
        final treeData = tree.toJson()
          ..['createdAt'] = FieldValue.serverTimestamp()
          ..['grownAt'] = FieldValue.serverTimestamp();

        occupiedSlots.add(firstFree);
        slotsByGrove[currentGroveIndex] = occupiedSlots;
        final completedGrove =
            occupiedSlots.length == TreeModel.forestSpotCount;
        if (completedGrove) {
          completedGroves.add(currentGroveIndex);
        }
        final nextGroveIndex = completedGrove
            ? currentGroveIndex + 1
            : currentGroveIndex;
        categoryXp[category.name] = 0;
        transaction.set(treeRef, treeData);
        final updatedUser = <String, dynamic>{
          'categoryXp': categoryXp,
          'currentGroveIndex': nextGroveIndex,
          'completedGroveIndexes': completedGroves.toList()..sort(),
          'occupiedTreeSlotsByGrove': {
            for (final entry in slotsByGrove.entries)
              entry.key.toString(): entry.value.toList()..sort(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (currentGroveIndex == 1) {
          updatedUser['occupiedTreeSlots'] = occupiedSlots.toList()..sort();
        }
        transaction.update(userRef, updatedUser);
        plantingResult = GrovePlantingResult(
          plantedGroveIndex: currentGroveIndex,
          completedGrove: completedGrove,
          groveTreeCount: occupiedSlots.length,
          totalQuestXp: occupiedSlots.length * TreeModel.maturityXp,
          occupiedSlots: occupiedSlots.toList()..sort(),
        );
      }).timeout(const Duration(seconds: 30), onTimeout: () {
        throw TimeoutException('Tree planting timed out. Please try again.');
      });

      progressionController.categoryXp[category.name] = 0;
      final currentUser = homeController.user.value;
      if (currentUser != null) {
        homeController.user.value = currentUser.copyWith(
          categoryXp: {...currentUser.categoryXp, category.name: 0},
          currentGroveIndex: plantingResult.completedGrove
              ? plantingResult.plantedGroveIndex + 1
              : plantingResult.plantedGroveIndex,
          completedGroveIndexes: {
            ...currentUser.completedGroveIndexes,
            if (plantingResult.completedGrove) plantingResult.plantedGroveIndex,
          }.toList()..sort(),
          occupiedTreeSlotsByGrove: {
            ...currentUser.occupiedTreeSlotsByGrove,
            plantingResult.plantedGroveIndex: plantingResult.occupiedSlots,
          },
        );
      }

      print(
        '--- Tree saved to Grove ${plantingResult.plantedGroveIndex}: ${category.name} ---',
      );
      return plantingResult;
    } catch (e) {
      print('--- Error saving tree to forest: $e ---');
      AppDialogs.error('Could not plant tree', e.toString());
      return null;
    } finally {
      _isSavingTree = false;
    }
  }

  Future<void> _showTreeNamingDialog(CategoryModel category) async {
    if (!mounted || _isTreeNamingDialogOpen) return;
    _isTreeNamingDialogOpen = true;

    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_playRevealSound());
    });

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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                    foregroundColor: AppColors.textOnPrimary,
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

    try {
      if (result == true && nameController.text.trim().isNotEmpty) {
        AppDialogs.showLoading(message: 'Planting tree...');
        GrovePlantingResult? plantingResult;
        try {
          plantingResult = await _saveTreeToForest(
            category,
            nameController.text.trim(),
          );
        } finally {
          AppDialogs.dismissLoading();
        }

        if (plantingResult != null) {
          if (!mounted) return;
          if (plantingResult.completedGrove) {
            await GroveCompleteScreen.show(
              context: context,
              completedGroveIndex: plantingResult.plantedGroveIndex,
              treeCount: plantingResult.groveTreeCount,
              totalQuestXp: plantingResult.totalQuestXp,
              onExploreNextGrove: Get.back,
            );
          }
          if (!mounted) return;
          Get.toNamed(
            AppRoutes.FOREST,
            arguments: {
              'groveIndex': plantingResult.completedGrove
                  ? plantingResult.plantedGroveIndex + 1
                  : plantingResult.plantedGroveIndex,
            },
          );
        }
      }
    } finally {
      _isTreeNamingDialogOpen = false;
      nameController.dispose();
    }
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

  int _findCategoryIndexForHobby(List<CategoryModel> categories, String hobby) {
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
      _selectedIndex =
          (_selectedIndex! - 1 + _categories.length) % _categories.length;
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
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            color: AppColors.primary,
            onPressed: _previousCategory,
          ),
          const SizedBox(width: 4),
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
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            color: AppColors.primary,
            onPressed: _nextCategory,
          ),
        ],
      ),
    );
  }

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
          const thresholds = TreeModel.growthThresholds;
          const labels = TreeModel.growthStageLabels;
          final actualStage = TreeModel.stageForXp(xp);

          if (category.name != _displayedStageCategory) {
            _displayedStageCategory = category.name;
            _displayedStage = actualStage;
          }

          if (actualStage < _displayedStage) {
            _displayedStage = actualStage;
          }

          final hasPending = actualStage > _displayedStage;

          final stage = _displayedStage;
          final currentMin = thresholds[stage];
          final nextMax = stage < thresholds.length - 1
              ? thresholds[stage + 1]
              : thresholds[stage] + 1000;
          final progress = ((xp - currentMin) / (nextMax - currentMin)).clamp(
            0.0,
            1.0,
          );
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
                if (_speechIndex >= 0 && _speechIndex < _speechMessages.length)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          constraints: const BoxConstraints(maxWidth: 260),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textOnPrimary,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.1,
                                ),
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
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _floatAnimation!,
                        _shakeAnimation!,
                      ]),
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(
                            _shakeAnimation!.value,
                            _floatAnimation!.value,
                          ),
                          child: child,
                        );
                      },
                      child: Image.asset(
                        _treeImageForStage(stage),
                        width: 200,
                        fit: BoxFit.contain,
                      ),
                    ),
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
                                constraints: const BoxConstraints(
                                  maxWidth: 200,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.textOnPrimary,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.textPrimary.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  hasPending
                                      ? 'Tap me to grow!'
                                      : 'Save me to forest!',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: AppFonts.badge,
                                    color: AppColors.textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 6),
                              CustomPaint(
                                size: const Size(14, 8),
                                painter: _TriangleDownPainter(),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                hasPending
                                    ? 'Tap to level up'
                                    : 'Tap to name your tree',
                                style: TextStyle(
                                  fontSize: AppFonts.micro,
                                  color: AppColors.textSecondary.withOpacity(
                                    0.6,
                                  ),
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
                            AppColors.primary,
                          ),
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
  const _TriangleDownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textOnPrimary
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TriangleDownPainter oldDelegate) => false;
}
