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
  var isCompletedExpanded = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadUserProfile();
  }

  /// Returns ALL quest nodes with recomputed isActive flags based on DAG.
  /// Completed quests are included but marked as inactive.
  /// Quest whose dependencies aren't met are marked as inactive (locked).
  /// Use this to display the full milestone quest tree on the home page.
  List<QuestNodeModel> getAllQuestNodes(List<QuestNodeModel> quests) {
    if (quests.isEmpty) return [];

    final completedIds = quests
        .where((quest) => quest.isCompleted)
        .map((quest) => quest.nodeId)
        .toSet();

    final readyIds = _computeAllReadyQuestIds(quests, completedIds);

    final mapped = quests.map((quest) {
      final isReady = readyIds.contains(quest.nodeId);
      final shouldBeActive = isReady && !quest.isCompleted;
      return quest.copyWith(isActive: shouldBeActive);
    }).toList();

    // Sort: completed first, then active, then locked/inactive
    mapped.sort((a, b) {
      final aCompleted = a.isCompleted ? 0 : 1;
      final bCompleted = b.isCompleted ? 0 : 1;
      if (aCompleted != bCompleted) return aCompleted.compareTo(bCompleted);

      final aActive = a.isActive ? 0 : 1;
      final bActive = b.isActive ? 0 : 1;
      return aActive.compareTo(bActive);
    });

    return mapped;
  }

  /// Legacy method: returns only up to 3 ready quests.
  /// Used by QuestDetailController after quest completion for backward compat.
  List<QuestNodeModel> getVisibleQuestWindow(List<QuestNodeModel> quests) {
    print('--- DEBUG: getVisibleQuestWindow called with ${quests.length} total quests ---');
    
    // Situation 1: No quests at all
    if (quests.isEmpty) {
      print('--- WARN: No quests available at all! ---');
      return [];
    }

    final normalized = _buildNormalizedQuestGraph(quests);
    print('--- DEBUG: After normalization: ${normalized.length} quests, isActive flags computed ---');
    
    // Situation 2: Check completed vs incomplete
    final completed = normalized.where((q) => q.isCompleted).length;
    final incomplete = normalized.where((q) => !q.isCompleted).length;
    print('--- DEBUG: Completed: $completed, Incomplete: $incomplete ---');
    
    // Situation 3: Check for root quests (no dependencies)
    final rootQuests = normalized.where((q) => !q.isCompleted && q.dependsOn.isEmpty).toList();
    print('--- DEBUG: Root quests available (no deps): ${rootQuests.length} ---');
    
    // Get ALL ready quests (not just the first 3)
    final readyQuests = normalized
        .where((quest) => !quest.isCompleted && _isQuestReady(quest, normalized))
        .toList();
    
    print('--- DEBUG: Total ready quests (dependencies satisfied): ${readyQuests.length} ---');
    for (int i = 0; i < readyQuests.length; i++) {
      final q = readyQuests[i];
      print('  [$i] ${q.nodeId}: ${q.title} (deps: ${q.dependsOn.isEmpty ? "none" : q.dependsOn.join(", ")})');
    }
    
    // Fill up to 3 active quests
    const maxVisibleQuests = 3;
    final visibleWindow = readyQuests.take(maxVisibleQuests).toList();
    
    print('--- DEBUG: Filling active quests (max $maxVisibleQuests) ---');
    print('--- DEBUG: Total ready available: ${readyQuests.length}, Taking: ${visibleWindow.length} ---');
    
    if (visibleWindow.isEmpty) {
      print('--- ALERT: NO NEW QUESTS TO SHOW! Reasons: ---');
      if (incomplete == 0) {
        print('  → All quests are completed! Milestone finished!');
      }
      if (rootQuests.isEmpty && incomplete > 0) {
        print('  → No root quests available (all remaining quests have dependencies)');
      }
      if (readyQuests.isEmpty && incomplete > 0 && rootQuests.isNotEmpty) {
        print('  → All incomplete quests have missing or circular dependencies');
      }
      // List all incomplete quests and their dependencies
      final incompleteQuests = normalized.where((q) => !q.isCompleted).toList();
      print('  → Incomplete quests status:');
      for (final q in incompleteQuests) {
        final depsReady = q.dependsOn.every((dep) => normalized.any((n) => n.nodeId == dep && n.isCompleted));
        print('    • ${q.nodeId}: deps=${q.dependsOn.isEmpty ? "[]" : q.dependsOn}, allDepsReady=$depsReady');
      }
    } else {
      print('--- SUCCESS: Found ${visibleWindow.length} active quest(s) to display ---');
      for (int i = 0; i < visibleWindow.length; i++) {
        print('  [${i + 1}] ${visibleWindow[i].nodeId}: ${visibleWindow[i].title}');
      }
      
      // Show if we could add more
      if (visibleWindow.length < maxVisibleQuests && readyQuests.length > visibleWindow.length) {
        print('--- INFO: More quests available! Could add ${readyQuests.length - visibleWindow.length} more to reach $maxVisibleQuests ---');
      }
    }
    
    return visibleWindow;
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
        dailyQuests.value = getAllQuestNodes(currentPlan.quests);

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
    
    dailyQuests.value = getAllQuestNodes(updatedPlan.quests);
    
    print('--- INFO: Quest $questId completed via HomeController ---');

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
      dailyQuests.value = getAllQuestNodes(loadedUser.currentPlan.quests);
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
          frequency: frequency.value,
          milestoneTitle: _currentMilestoneTitle(),
          questType: quest.type,
          durationMinutes: quest.durationMinutes,
        );

        final altSteps = (alternative['steps'] is List)
            ? (alternative['steps'] as List).map((e) => e.toString()).toList()
            : null;
        final altYoutube = (alternative['youtube_search_query']?.toString().trim().isNotEmpty ?? false)
            ? alternative['youtube_search_query'].toString().trim()
            : (alternative['youtubeSearchQuery']?.toString().trim() ?? quest.youtubeSearchQuery ?? '');

        refreshed.add(
          quest.copyWith(
            title: alternative['title'] ?? quest.title,
            desc: alternative['desc'] ?? quest.desc,
            steps: altSteps ?? quest.steps,
            youtubeSearchQuery: altYoutube,
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
        frequency: frequency.value,
        milestoneTitle: _currentMilestoneTitle(),
        questType: dailyQuests
            .firstWhereOrNull((quest) => quest.nodeId == questId)
            ?.type ??
          'practice',
        durationMinutes: dailyQuests
            .firstWhereOrNull((quest) => quest.nodeId == questId)
            ?.durationMinutes ??
          15,
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

        final altSteps = (alternative['steps'] is List)
            ? (alternative['steps'] as List).map((e) => e.toString()).toList()
            : null;
        final altYoutube = (alternative['youtube_search_query']?.toString().trim().isNotEmpty ?? false)
            ? alternative['youtube_search_query'].toString().trim()
            : (alternative['youtubeSearchQuery']?.toString().trim() ?? targetQuest.youtubeSearchQuery ?? '');

        updatedQuests[questIndex] = targetQuest.copyWith(
          title: alternative['title'] ?? targetQuest.title,
          desc: alternative['desc'] ?? targetQuest.desc,
          steps: altSteps ?? targetQuest.steps,
          youtubeSearchQuery: altYoutube,
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
      dailyQuests.value = getAllQuestNodes(updatedUser!.currentPlan.quests);

      print('--- INFO: Quest $questId rerolled successfully ---');
      return true;
    } catch (e) {
      print('--- ERROR: Failed to reroll quest $questId: $e ---');
      return false;
    }
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

  /// Finds ALL ready (dependencies satisfied) quest IDs — no cap.
  Set<String> _computeAllReadyQuestIds(
    List<QuestNodeModel> quests,
    Set<String> completedIds,
  ) {
    final ready = <String>{};

    for (final quest in quests) {
      if (quest.isCompleted) continue;
      if (_isQuestReady(quest, quests, completedIds: completedIds)) {
        ready.add(quest.nodeId);
      }
    }

    return ready;
  }

  /// Legacy: returns only up to 3 ready quest IDs.
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

  String _currentMilestoneTitle() {
    final currentPlan = user.value?.currentPlan;
    if (currentPlan == null || currentPlan.milestones.isEmpty) {
      return goal.value.isNotEmpty ? goal.value : hobby.value;
    }

    final index = currentPlan.currentMilestoneIndex;
    if (index >= 0 && index < currentPlan.milestones.length) {
      final title = currentPlan.milestones[index].title.trim();
      if (title.isNotEmpty) {
        return title;
      }
    }

    return currentPlan.milestones.first.title;
  }

  /// Returns `true` if all current quests are completed and a next milestone exists.
  /// The caller (e.g. quest detail page) should show a milestone-complete screen,
  /// then call [advanceToNextMilestone] when the user confirms.
  bool hasCompletedMilestone() {
    final plan = user.value?.currentPlan;
    if (plan == null) return false;
    if (!plan.quests.every((q) => q.isCompleted)) return false;
    final nextIndex = plan.currentMilestoneIndex + 1;
    return nextIndex < plan.milestones.length;
  }

  /// Generates the next milestone's quests, replaces the old quests in Firestore,
  /// and refreshes the local state. Should be called after the user confirms on
  /// the milestone-complete screen.
  Future<void> advanceToNextMilestone() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final plan = user.value?.currentPlan;
    if (plan == null) return;

    final nextIndex = plan.currentMilestoneIndex + 1;
    if (nextIndex >= plan.milestones.length) return;

    final nextMilestone = plan.milestones[nextIndex];
    final milestoneNumber = (nextIndex + 1).toString();

    // Mark current milestone as completed
    final updatedMilestones = plan.milestones.asMap().map((i, m) {
      if (i == plan.currentMilestoneIndex) {
        return MapEntry(i, m.copyWith(completed: true));
      }
      return MapEntry(i, m);
    }).values.toList();

    final newQuests = await _geminiService.generatePhaseDAG(
      hobby: hobby.value,
      level: level.value,
      goal: goal.value,
      frequency: frequency.value,
      milestoneTitle: nextMilestone.title,
      milestoneNumber: milestoneNumber,
    );

    final updatedUser = await _questService.addQuestsToPlan(
      uid: currentUser.uid,
      newQuests: newQuests,
      currentMilestoneIndex: nextIndex,
      clearExisting: true,
      milestones: updatedMilestones,
    );

    if (updatedUser == null) return;

    user.value = updatedUser;
    dailyQuests.value = getAllQuestNodes(updatedUser.currentPlan.quests);
  }
}
