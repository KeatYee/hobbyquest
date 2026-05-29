import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quest_node_model.dart';
import '../services/gemini_service.dart';
import '../services/quest_service.dart';
import '../models/user_model.dart';

class HomeController extends GetxController {
  final GeminiService _geminiService = GeminiService();
  final QuestService _questService = QuestService();
  // --- STATE VARIABLES (Reactivity) ---

  // User Profile Data (Typed Model)
  var user = Rx<UserModel?>(null);
  var nickname = "Hero".obs;
  var avatarSvg = "".obs;
  var hobby = "".obs;
  var goal = "".obs;
  var frequency = "15 mins/day".obs;
  var level = "Novice".obs;

  // Loading state
  var isLoadingProfile = true.obs;

  // Quest List (Backed by the user's saved current plan)
  var dailyQuests = <QuestNodeModel>[].obs;

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
        final currentPlan = loadedUser.currentPlan;

        // Update reactive variables from model
        nickname.value = loadedUser.nickname;
        avatarSvg.value = loadedUser.avatarSvg;
        hobby.value = currentPlan.hobby;
        goal.value = currentPlan.goal;
        frequency.value = currentPlan.frequency;
        level.value = currentPlan.level;
        dailyQuests.value = _buildVisibleQuestWindow(currentPlan.quests);

        print(
          "--- SUCCESS: Loaded user profile for ${loadedUser.nickname} ---",
        );
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

  void rerollDailyQuests() {
    print("--- LOGIC: Refreshing visible quest window from current plan... ---");
    _reloadCurrentPlanQuests();
  }

  void startQuest(String id) {
    print("--- LOGIC: Starting Quest $id ---");
  }

  Future<bool> completeQuest(
    String questId, {
    String reflectionNote = '',
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print("--- ERROR: User not logged in ---");
      return false;
    }

    final updatedUser = await _questService.completeQuestTransaction(
      uid: currentUser.uid,
      questId: questId,
      reflectionNote: reflectionNote,
    );

    if (updatedUser == null) return false;

    final updatedPlan = updatedUser.currentPlan;

    user.value = updatedUser;
    hobby.value = updatedPlan.hobby;
    goal.value = updatedPlan.goal;
    frequency.value = updatedPlan.frequency;
    level.value = updatedPlan.level;
    dailyQuests.value = _buildVisibleQuestWindow(updatedPlan.quests);

    return true;
  }

  Future<void> _reloadCurrentPlanQuests() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final data = userDoc.data();
      if (data == null) {
        return;
      }

      final loadedUser = UserModel.fromJson(data, currentUser.uid);
      user.value = loadedUser;

      nickname.value = loadedUser.nickname;
      avatarSvg.value = loadedUser.avatarSvg;
      hobby.value = loadedUser.currentPlan.hobby;
      goal.value = loadedUser.currentPlan.goal;
      frequency.value = loadedUser.currentPlan.frequency;
      level.value = loadedUser.currentPlan.level;
      dailyQuests.value = _buildVisibleQuestWindow(loadedUser.currentPlan.quests);
    } catch (e) {
      print("--- ERROR: Failed to reload current plan quests: $e ---");
    }
  }

  /// Ephemeral reroll using GeminiService. Does NOT persist to Firestore.
  Future<void> rerollWithGemini() async {
    if (!_geminiService.hasApiKey) {
      print('--- INFO: Gemini API key not set; cannot reroll with model ---');
      return;
    }

    try {
      final refreshed = <QuestNodeModel>[];
      for (final quest in dailyQuests) {
        final alternative = await _geminiService.generateAlternativeQuest(
          hobby: hobby.value,
          nodeTitle: quest.title,
          nodeDesc: quest.desc,
        );

        refreshed.add(
          quest.copyWith(
            title: alternative['title'] ?? quest.title,
            desc: alternative['desc'] ?? quest.desc,
          ),
        );
      }

      dailyQuests.value = refreshed;
      print('--- INFO: Ephemeral reroll applied (${dailyQuests.length} quests) ---');
    } catch (e) {
      print('--- ERROR: Gemini reroll failed: $e ---');
    }
  }

  /// Reroll a single quest card and persist the updated title/description.
  /// Keeps the same node, dependencies, and completion state.
  Future<bool> rerollQuestWithGemini(String questId) async {
    if (!_geminiService.hasApiKey) {
      print('--- INFO: Gemini API key not set; cannot reroll quest ---');
      return false;
    }

    try {
      final alternative = await _geminiService.generateAlternativeQuest(
        hobby: hobby.value,
        nodeTitle: dailyQuests
                .firstWhereOrNull((quest) => quest.nodeId == questId)
                ?.title ??
            '',
        nodeDesc: dailyQuests
                .firstWhereOrNull((quest) => quest.nodeId == questId)
                ?.desc ??
            '',
      );

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('--- ERROR: User not logged in ---');
        return false;
      }

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid);

      UserModel? updatedUser;
      bool didReroll = false;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        final data = snapshot.data();
        if (data == null) {
          print('--- ERROR: User profile not found ---');
          return;
        }

        final loadedUser = UserModel.fromJson(data, currentUser.uid);
        final quests = loadedUser.currentPlan.quests;
        final questIndex = quests.indexWhere((quest) => quest.nodeId == questId);

        if (questIndex == -1) {
          print('--- ERROR: Quest $questId not found in current plan ---');
          return;
        }

        final targetQuest = quests[questIndex];
        final updatedQuests = List<QuestNodeModel>.from(quests);
        updatedQuests[questIndex] = targetQuest.copyWith(
          title: alternative['title'] ?? targetQuest.title,
          desc: alternative['desc'] ?? targetQuest.desc,
        );

        final normalizedQuests = _buildNormalizedQuestGraph(updatedQuests);
        final updatedPlan = loadedUser.currentPlan.copyWith(quests: normalizedQuests);
        final normalizedUser = loadedUser.copyWith(
          currentPlan: updatedPlan,
          lastRerollDate: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        transaction.set(
          userRef,
          normalizedUser.toJson(),
          SetOptions(merge: true),
        );

        updatedUser = normalizedUser;
        didReroll = true;
      });

      if (!didReroll || updatedUser == null) {
        return false;
      }

      user.value = updatedUser;
      nickname.value = updatedUser!.nickname;
      avatarSvg.value = updatedUser!.avatarSvg;
      hobby.value = updatedUser!.currentPlan.hobby;
      goal.value = updatedUser!.currentPlan.goal;
      frequency.value = updatedUser!.currentPlan.frequency;
      level.value = updatedUser!.currentPlan.level;
      dailyQuests.value = _buildVisibleQuestWindow(updatedUser!.currentPlan.quests);

      print('--- INFO: Quest $questId rerolled successfully ---');
      return true;
    } catch (e) {
      print('--- ERROR: Failed to reroll quest $questId: $e ---');
      return false;
    }
  }

  List<QuestNodeModel> _buildVisibleQuestWindow(List<QuestNodeModel> quests) {
    final normalized = _buildNormalizedQuestGraph(quests);
    final readyQuests = normalized
        .where((quest) => !quest.isCompleted && _isQuestReady(quest, normalized))
        .toList();

    return readyQuests.take(3).toList();
  }

  List<QuestNodeModel> _buildNormalizedQuestGraph(
    List<QuestNodeModel> quests,
  ) {
    final completedIds = quests
        .where((quest) => quest.isCompleted)
        .map((quest) => quest.nodeId)
        .toSet();

    final visibleIds = _computeVisibleQuestIds(quests, completedIds);

    return quests.map((quest) {
      final shouldBeActive = visibleIds.contains(quest.nodeId) && !quest.isCompleted;
      return quest.copyWith(isActive: shouldBeActive);
    }).toList();
  }

  Set<String> _computeVisibleQuestIds(
    List<QuestNodeModel> quests,
    Set<String> completedIds,
  ) {
    final visible = <String>{};

    for (final quest in quests) {
      if (quest.isCompleted) {
        continue;
      }

      final isReady = _isQuestReady(quest, quests, completedIds: completedIds);
      if (isReady) {
        visible.add(quest.nodeId);
      }

      if (visible.length == 3) {
        break;
      }
    }

    return visible;
  }

  bool _isQuestReady(
    QuestNodeModel quest,
    List<QuestNodeModel> quests, {
    Set<String>? completedIds,
  }) {
    final completed = completedIds ??
        quests
            .where((item) => item.isCompleted)
            .map((item) => item.nodeId)
            .toSet();

    if (quest.dependsOn.isEmpty) {
      return true;
    }

    return quest.dependsOn.every(completed.contains);
  }
}
