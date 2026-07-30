import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../core/utils/dialog_utils.dart';
import '../services/category_service.dart';
import '../services/quest_service.dart';
import '../models/user_model.dart';
import 'home_controller.dart';
import '../../core/widgets/level_up_screen.dart';

class ProgressionController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CategoryService _categoryService = CategoryService();

  final totalXP = 0.obs;
  final streak = 0.obs;
  final categoryXp = <String, int>{}.obs;
  final isLoading = false.obs;

  int? _pendingLevelUpLevel;

  static const List<int> _milestoneThresholds = [2000, 4000, 6000, 8000];

  int get currentLevel => (totalXP.value ~/ 1000) + 1;

  @override
  void onInit() {
    super.onInit();
    loadProgress();
  }

  Future<void> loadProgress() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        totalXP.value = 0;
        return;
      }

      isLoading.value = true;
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();

      if (data == null) {
        totalXP.value = 0;
        streak.value = 0;
        return;
      }

      totalXP.value = _readTotalXP(data);
      streak.value = data['currentStreak'] as int? ?? 0;

      final userModel = UserModel.fromJson(data, user.uid);
      categoryXp.value = Map<String, int>.from(userModel.categoryXp);
    } catch (e) {
      print('--- ERROR: Failed to load progression: $e ---');
    } finally {
      isLoading.value = false;
    }
  }

  List<int> applyQuestCompletion(
    QuestCompletionResult result, {
    bool showMilestoneUnlockModal = true,
  }) {
    totalXP.value = result.updatedTotalXP;
    streak.value = result.updatedStreak;
    categoryXp.value = Map<String, int>.from(result.updatedCategoryXp);

    if (!result.didComplete) return const [];

    final previousLevel = (result.previousTotalXP ~/ 1000) + 1;
    final newLevel = (result.updatedTotalXP ~/ 1000) + 1;

    if (newLevel > previousLevel) {
      _pendingLevelUpLevel = newLevel;
    }

    final unlockedMilestones = <int>[];
    for (var i = 0; i < _milestoneThresholds.length; i++) {
      final threshold = _milestoneThresholds[i];
      if (result.previousTotalXP < threshold &&
          result.updatedTotalXP >= threshold) {
        final milestoneNumber = i + 1;
        unlockedMilestones.add(milestoneNumber);
        if (showMilestoneUnlockModal) {
          showMilestoneUnlockedModal(milestoneNumber, threshold);
        }
      }
    }

    return unlockedMilestones;
  }

  /// Shows the pending level-up screen if one was triggered.
  /// Returns when the modal is dismissed.
  Future<void> showPendingLevelUp() async {
    final level = _pendingLevelUpLevel;
    if (level != null) {
      _pendingLevelUpLevel = null;
      await showLevelUpModal(level);
    }
  }

  Future<void> showLevelUpModal(int newLevel) async {
    await Get.generalDialog(
      pageBuilder: (context, animation, secondaryAnimation) =>
          LevelUpScreen(newLevel: newLevel),
      barrierDismissible: false,
      barrierLabel: 'Level Up',
    );
  }

  void showMilestoneUnlockedModal(int milestoneNumber, int thresholdXP) {
    AppDialogs.warning(
      'Milestone Unlocked',
      'Milestone $milestoneNumber unlocked at $thresholdXP XP',
    );
  }

  /// Resolves the current hobby's category name from Firestore categories.
  Future<String?> resolveCurrentCategoryName() async {
    try {
      final hobby = Get.find<HomeController>().hobby.value;
      print('--- DEBUG _resolveCurrentCategory: hobby="$hobby" ---');
      if (hobby.isEmpty) {
        print(
          '--- DEBUG _resolveCurrentCategory: hobby is EMPTY, returning null ---',
        );
        return null;
      }
      final cats = await _categoryService.getCategories();
      print(
        '--- DEBUG _resolveCurrentCategory: loaded ${cats.length} categories ---',
      );
      if (cats.isEmpty) return null;

      for (final cat in cats) {
        print(
          '--- DEBUG _resolveCurrentCategory: checking category "${cat.name}" with hobbies: ${cat.hobbyNames} ---',
        );
        if (cat.hobbyNames.any((h) => h.toLowerCase() == hobby.toLowerCase())) {
          print(
            '--- DEBUG _resolveCurrentCategory: MATCHED category "${cat.name}" ---',
          );
          return cat.name;
        }
      }

      final hobbyLower = hobby.toLowerCase();
      for (final cat in cats) {
        final catName = cat.name.toLowerCase();
        if (catName.contains(hobbyLower) ||
            hobbyLower.contains(catName) ||
            cat.hobbyNames.any(
              (h) =>
                  h.toLowerCase().contains(hobbyLower) ||
                  hobbyLower.contains(h.toLowerCase()),
            )) {
          print(
            '--- DEBUG _resolveCurrentCategory: PARTIAL MATCHED category "${cat.name}" for hobby="$hobby" ---',
          );
          return cat.name;
        }
      }

      print(
        '--- DEBUG _resolveCurrentCategory: NO match, falling back to first category "${cats.first.name}" ---',
      );
      return cats.first.name;
    } catch (e) {
      print('--- ERROR _resolveCurrentCategory: exception: $e ---');
      return null;
    }
  }

  int _readTotalXP(Map<String, dynamic> data) {
    if (data['totalXP'] is int) {
      return data['totalXP'] as int;
    }

    final legacyLevel = data['level'] as int? ?? 1;
    final legacyCurrentXp = data['currentXp'] as int? ?? 0;
    return ((legacyLevel - 1) * 1000) + legacyCurrentXp;
  }
}
