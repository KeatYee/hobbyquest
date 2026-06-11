import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../core/utils/dialog_utils.dart';

class ProgressionController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final totalXP = 0.obs;
  final streak = 0.obs;
  final isLoading = false.obs;

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
    } catch (e) {
      print('--- ERROR: Failed to load progression: $e ---');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> completeQuest({String? questId, int xpReward = 100}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
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
        // First quest completion
        updatedStreak = 1;
      } else {
        final lastStreakDateOnly = DateTime(lastStreakDate.year, lastStreakDate.month, lastStreakDate.day);
        final daysDifference = todayDate.difference(lastStreakDateOnly).inDays;

        if (daysDifference == 0) {
          // Quest already completed today, don't change streak
          updatedStreak = currentStreak;
        } else if (daysDifference == 1) {
          // Consecutive day, increment streak
          updatedStreak = currentStreak + 1;
        } else {
          // Streak broken, reset to 1
          updatedStreak = 1;
        }
      }

      transaction.set(
        userRef,
        {
          'totalXP': updatedXP,
          'currentStreak': updatedStreak,
          'lastStreakDate': today,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    totalXP.value = updatedXP;
    streak.value = updatedStreak;

    final previousLevel = (previousXP ~/ 1000) + 1;
    final newLevel = (updatedXP ~/ 1000) + 1;

    if (newLevel > previousLevel) {
      showLevelUpModal(newLevel);
    }

    for (var i = 0; i < _milestoneThresholds.length; i++) {
      final threshold = _milestoneThresholds[i];
      if (previousXP < threshold && updatedXP >= threshold) {
        showMilestoneUnlockedModal(i + 1, threshold);
      }
    }
  }

  void showLevelUpModal(int newLevel) {
    AppDialogs.success(
      'Level Up!',
      'You reached Level $newLevel',
    );
  }

  void showMilestoneUnlockedModal(int milestoneNumber, int thresholdXP) {
    AppDialogs.warning(
      'Milestone Unlocked',
      'Milestone $milestoneNumber unlocked at $thresholdXP XP',
    );
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