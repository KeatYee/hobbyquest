import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/gemini_service.dart';
import '../models/quest_model.dart';
import '../models/user_model.dart';

class HomeController extends GetxController {
  final GeminiService _geminiService = GeminiService();
  static const int maxDailyQuests = 3;

  // --- STATE VARIABLES (Reactivity) ---
  
  // User Profile Data (Typed Model)
  var user = Rx<UserModel?>(null);
  var nickname = "Hero".obs;
  var avatarSvg = "".obs;
  var selectedHobby = "".obs;
  var userGoal = "".obs;
  var selectedLevel = "Novice".obs;
  
  // Loading state
  var isLoadingProfile = true.obs;

  // Quest List (Mock Data)
  var dailyQuests = <QuestModel>[
    const QuestModel(
      id: "q1",
      title: "Chord Mastery",
      desc: "Practice transitions for 15 mins.",
      xp: 100,
      type: "practice",
      isPriority: true,
    ),
    const QuestModel(
      id: "q2",
      title: "Theory Check",
      desc: "Identify the G-Major scale.",
      xp: 100,
      type: "knowledge",
    ),
    const QuestModel(
      id: "q3",
      title: "Creative Flow",
      desc: "Upload a photo of your practice setup.",
      xp: 100,
      type: "challenge",
    ),
  ].obs;

  @override
  void onInit() {
    super.onInit();
    _loadUserProfile();
  }

  /// Load user profile data from Firestore
  Future<void> _loadUserProfile() async {
    try {
      isLoadingProfile.value = true;
      
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("--- ERROR: No user logged in ---");
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        
        // Parse user data into typed model
        final loadedUser = UserModel.fromJson(data, currentUser.uid);
        user.value = loadedUser;
        
        // Update reactive variables from model
        nickname.value = loadedUser.nickname;
        avatarSvg.value = loadedUser.avatarSvg;
        selectedHobby.value = loadedUser.currentPlan.hobbyName;
        userGoal.value = loadedUser.currentPlan.customGoal;
        selectedLevel.value = loadedUser.currentPlan.skillLevel;

        final planQuests = loadedUser.currentPlan.quests.take(maxDailyQuests).toList();
        final completedQuestCount = planQuests.where((quest) => quest.isCompleted).length;

        if (planQuests.isEmpty || completedQuestCount == 0) {
          dailyQuests.value = planQuests;
        } else {
          final remainingQuests = planQuests.where((quest) => !quest.isCompleted).toList();
          final generatedQuests = await _geminiService.generateDailyQuests(
            hobby: loadedUser.currentPlan.hobbyName,
            level: loadedUser.currentPlan.skillLevel,
            goal: loadedUser.currentPlan.customGoal,
            frequency: loadedUser.currentPlan.frequency,
            currentMilestoneTitle: remainingQuests.isNotEmpty
                ? remainingQuests.first.title
                : (loadedUser.currentPlan.milestones.isNotEmpty
                    ? loadedUser.currentPlan.milestones.first.task
                    : loadedUser.currentPlan.customGoal),
            activeQuestsCount: completedQuestCount,
            focus: loadedUser.currentPlan.customGoal,
          );

          dailyQuests.value = [...remainingQuests, ...generatedQuests]
              .take(maxDailyQuests)
              .toList();
          user.value = loadedUser.copyWith(
            currentPlan: loadedUser.currentPlan.copyWith(quests: dailyQuests.toList()),
          );
        }
        
        print("--- SUCCESS: Loaded user profile for ${loadedUser.nickname} ---");
      } else {
        print("--- WARNING: User profile not found ---");
      }
    } catch (e) {
      print("--- ERROR: Failed to load user profile: $e ---");
    } finally {
      isLoadingProfile.value = false;
    }
  }

  // --- ACTIONS ---

  bool get hasUsedRerollToday {
    final rerollDate = user.value?.lastRerollDate;
    if (rerollDate == null) {
      return false;
    }

    final now = DateTime.now();
    return rerollDate.year == now.year &&
        rerollDate.month == now.month &&
        rerollDate.day == now.day;
  }

  Future<String?> rerollOneQuestForToday(QuestModel currentQuest) async {
    if (hasUsedRerollToday) {
      return 'You already used your reroll for today.';
    }

    if (currentQuest.isCompleted) {
      return 'Cannot reroll a completed quest.';
    }

    try {
      final newTitle = await _geminiService.generateAlternativeQuestTitle(
        hobby: selectedHobby.value,
        currentTask: currentQuest.title,
      );

      if (newTitle.trim().isEmpty) {
        return 'Failed to generate alternative task.';
      }

      final replaceIndex = dailyQuests.indexWhere((quest) => quest.id == currentQuest.id);
      if (replaceIndex == -1) {
        return 'No available quest to swap.';
      }

      final replacement = currentQuest.copyWith(
        title: newTitle.trim(),
        completedAt: null,
        isCompleted: false,
        reflectionNote: '',
      );

      dailyQuests[replaceIndex] = replacement;

      final currentUser = user.value;
      if (currentUser != null) {
        final now = DateTime.now();
        final updatedUser = currentUser.copyWith(
          currentPlan: currentUser.currentPlan.copyWith(quests: dailyQuests.toList()),
          lastRerollDate: now,
          updatedAt: now,
        );
        user.value = updatedUser;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.id)
            .set({
              'currentPlan': updatedUser.currentPlan.toJson(),
              'lastRerollDate': now,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }

      return null;
    } catch (e) {
      print("--- ERROR: Failed to reroll one quest: $e ---");
      return 'Failed to reroll quest. Please try again.';
    }
  }

  void startQuest(QuestModel quest) {
    print("--- LOGIC: Starting Quest ${quest.id} ---");
  }

  int get completedTodayCount {
    return dailyQuests.where((quest) => _isCompletedToday(quest.completedAt)).length;
  }

  bool get hasCompletedAnyQuestToday => completedTodayCount > 0;

  bool get hasCompletedDailyLimit => completedTodayCount >= maxDailyQuests;

  bool canCompleteQuest(QuestModel quest) {
    if (quest.isCompleted) {
      return false;
    }

    if (hasCompletedDailyLimit) {
      return false;
    }

    return true;
  }

  bool completeQuest(String id, {String reflectionNote = ''}) {
    final index = dailyQuests.indexWhere((quest) => quest.id == id);
    if (index == -1) {
      return false;
    }

    final quest = dailyQuests[index];
    if (!canCompleteQuest(quest)) {
      return false;
    }

    dailyQuests[index] = quest.copyWith(
      isCompleted: true,
      reflectionNote: reflectionNote,
      completedAt: DateTime.now(),
    );

    final currentUser = user.value;
    if (currentUser != null) {
      final updatedQuests = dailyQuests.toList();
      final newTotalXP = currentUser.totalXP + quest.xp;
      final now = DateTime.now();
      
      // Determine if streak should be incremented (first completion of the day)
      final hasCompletedAnyToday = updatedQuests.any((q) => 
        _isCompletedToday(q.completedAt) && q.id != quest.id);
      final lastStreakDate = currentUser.lastStreakDate;
      final isNewDay = lastStreakDate == null || 
          lastStreakDate.year != now.year ||
          lastStreakDate.month != now.month ||
          lastStreakDate.day != now.day;
      
      // Increment streak only on the first completion of a new day
      int newStreak = currentUser.currentStreak;
      DateTime? newStreakDate = lastStreakDate;
      if (isNewDay && !hasCompletedAnyToday) {
        newStreak = currentUser.currentStreak + 1;
        newStreakDate = now;
      }
      
      final updatedUser = currentUser.copyWith(
        totalXP: newTotalXP,
        currentStreak: newStreak,
        lastStreakDate: newStreakDate,
        currentPlan: currentUser.currentPlan.copyWith(quests: updatedQuests),
        updatedAt: now,
      );
      user.value = updatedUser;

      // Save updated values to Firestore
      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.id)
          .set({
            'totalXP': newTotalXP,
            'currentStreak': newStreak,
            'lastStreakDate': newStreakDate,
            'currentPlan': updatedUser.currentPlan.toJson(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).catchError((e) {
            print("--- ERROR: Failed to save quest completion: $e ---");
          });
    }

    return true;
  }

  bool _isCompletedToday(DateTime? completedAt) {
    if (completedAt == null) {
      return false;
    }

    final now = DateTime.now();
    return completedAt.year == now.year &&
        completedAt.month == now.month &&
        completedAt.day == now.day;
  }
}