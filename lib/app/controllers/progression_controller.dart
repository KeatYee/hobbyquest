import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

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
      streak.value = data['streak'] as int? ?? 0;
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

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data();
      final currentXP = data == null ? 0 : _readTotalXP(data);
      previousXP = currentXP;
      updatedXP = currentXP + xpReward;

      transaction.set(
        userRef,
        {
          'totalXP': updatedXP,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    totalXP.value = updatedXP;

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
    Get.snackbar(
      'Level Up!',
      'You reached Level $newLevel',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void showMilestoneUnlockedModal(int milestoneNumber, int thresholdXP) {
    Get.snackbar(
      'Milestone Unlocked',
      'Milestone $milestoneNumber unlocked at $thresholdXP XP',
      snackPosition: SnackPosition.BOTTOM,
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