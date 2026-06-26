import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../core/utils/dialog_utils.dart';
import '../services/category_service.dart';
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

  int get currentXpInLevel => totalXP.value % 1000;

  double get levelProgress => currentXpInLevel / 1000;

  int get xpToNextLevel => 1000 - currentXpInLevel;

  @override
  void onInit() {
    super.onInit();
    loadProgress();
  }

  Future<void> loadProgress() async {
    final user = _auth.currentUser;
    if (user == null) {
      totalXP.value = 0;
      return;
    }

    try {
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

      // Load per-category XP from UserModel
      final userModel = UserModel.fromJson(data, user.uid);
      categoryXp.value = Map<String, int>.from(userModel.categoryXp);
    } catch (e) {
      print('--- ERROR: Failed to load progression: $e ---');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> completeQuest({String? questId, int xpReward = 100, String? categoryName}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Determine category if not provided
    String? resolvedCategory = categoryName;
    if (resolvedCategory == null) {
      try {
        resolvedCategory = await _resolveCurrentCategory();
      } catch (_) {}
    }

    final userRef = _firestore.collection('users').doc(user.uid);

    int previousXP = totalXP.value;
    int updatedXP = previousXP;
    int updatedStreak = streak.value;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data();
      final currentXP = data == null ? 0 : _readTotalXP(data);
      previousXP = currentXP;
      updatedXP = currentXP + xpReward;

      // Handle streak calculation
      final currentStreak = data?['currentStreak'] as int? ?? 0;
      final lastStreakDateData = data?['lastStreakDate'];
      DateTime? lastStreakDate;
      
      if (lastStreakDateData != null) {
        if (lastStreakDateData is Timestamp) {
          lastStreakDate = lastStreakDateData.toDate();
        } else if (lastStreakDateData is String) {
          lastStreakDate = DateTime.parse(lastStreakDateData);
        }
      }

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      
      if (lastStreakDate == null) {
        updatedStreak = 1;
      } else {
        final lastStreakDateOnly = DateTime(lastStreakDate.year, lastStreakDate.month, lastStreakDate.day);
        final daysDifference = todayDate.difference(lastStreakDateOnly).inDays;

        if (daysDifference == 0) {
          updatedStreak = currentStreak;
        } else if (daysDifference == 1) {
          updatedStreak = currentStreak + 1;
        } else {
          updatedStreak = 1;
        }
      }

      // Build categoryXp map: read current, add xpReward to the right key
      final updatedCategoryXp = Map<String, int>.from(
        (data?['categoryXp'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ) ?? {},
      );
      if (resolvedCategory != null) {
        updatedCategoryXp[resolvedCategory] =
            (updatedCategoryXp[resolvedCategory] ?? 0) + xpReward;
      }

      transaction.set(
        userRef,
        {
          'totalXP': updatedXP,
          'currentStreak': updatedStreak,
          'lastStreakDate': today,
          'categoryXp': updatedCategoryXp,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    totalXP.value = updatedXP;
    streak.value = updatedStreak;

    // Update local category XP
    if (resolvedCategory != null) {
      categoryXp[resolvedCategory] =
          (categoryXp[resolvedCategory] ?? 0) + xpReward;
    }

    final previousLevel = (previousXP ~/ 1000) + 1;
    final newLevel = (updatedXP ~/ 1000) + 1;

    if (newLevel > previousLevel) {
      _pendingLevelUpLevel = newLevel;
    }

    for (var i = 0; i < _milestoneThresholds.length; i++) {
      final threshold = _milestoneThresholds[i];
      if (previousXP < threshold && updatedXP >= threshold) {
        showMilestoneUnlockedModal(i + 1, threshold);
      }
    }
  }

  /// Shows the pending level-up screen if one was triggered.
  void showPendingLevelUp() {
    final level = _pendingLevelUpLevel;
    if (level != null) {
      _pendingLevelUpLevel = null;
      showLevelUpModal(level);
    }
  }

  void showLevelUpModal(int newLevel) {
    Get.generalDialog(
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

  /// Directly sets category XP (used by map page tap-to-level-up).
  Future<void> setCategoryXp(String categoryName, int xp) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .update({'categoryXp.$categoryName': xp});

    categoryXp[categoryName] = xp;
  }

  /// Resolves the current hobby's category name from Firestore categories.
  Future<String?> _resolveCurrentCategory() async {
    try {
      final hobby = Get.find<HomeController>().hobby.value;
      if (hobby.isEmpty) return null;
      final cats = await _categoryService.getCategories();
      for (final cat in cats) {
        if (cat.hobbyNames.any((h) => h.toLowerCase() == hobby.toLowerCase())) {
          return cat.name;
        }
      }
      return null;
    } catch (_) {
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