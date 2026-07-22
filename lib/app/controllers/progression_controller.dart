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

      final userModel = UserModel.fromJson(data, user.uid);
      categoryXp.value = Map<String, int>.from(userModel.categoryXp);
    } catch (e) {
      print('--- ERROR: Failed to load progression: $e ---');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> completeQuest({
    String? questId,
    int xpReward = 100,
    String? categoryName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    String? resolvedCategory = categoryName;
    if (resolvedCategory == null) {
      try {
        resolvedCategory = await _resolveCurrentCategory();
        print(
          '--- DEBUG: _resolveCurrentCategory returned: $resolvedCategory ---',
        );
      } catch (e) {
        print('--- ERROR: _resolveCurrentCategory threw: $e ---');
      }
    }
    print(
      '--- DEBUG: completeQuest resolvedCategory=$resolvedCategory, xpReward=$xpReward ---',
    );

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
        final lastStreakDateOnly = DateTime(
          lastStreakDate.year,
          lastStreakDate.month,
          lastStreakDate.day,
        );
        final daysDifference = todayDate.difference(lastStreakDateOnly).inDays;

        if (daysDifference == 0) {
          updatedStreak = currentStreak;
        } else if (daysDifference == 1) {
          updatedStreak = currentStreak + 1;
        } else {
          updatedStreak = 1;
        }
      }

      final updatedCategoryXp = Map<String, int>.from(
        (data?['categoryXp'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ) ??
            {},
      );
      if (resolvedCategory != null) {
        updatedCategoryXp[resolvedCategory] =
            (updatedCategoryXp[resolvedCategory] ?? 0) + xpReward;
      }

      transaction.set(userRef, {
        'totalXP': updatedXP,
        'currentStreak': updatedStreak,
        'lastStreakDate': today,
        'categoryXp': updatedCategoryXp,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    totalXP.value = updatedXP;
    streak.value = updatedStreak;

    if (resolvedCategory != null) {
      categoryXp[resolvedCategory] =
          (categoryXp[resolvedCategory] ?? 0) + xpReward;
      print(
        '--- DEBUG: categoryXp updated: [${resolvedCategory}] = ${categoryXp[resolvedCategory]} ---',
      );
    } else {
      print('--- WARN: resolvedCategory is null, categoryXp NOT updated ---');
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
  Future<String?> _resolveCurrentCategory() async {
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
