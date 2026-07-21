import 'dart:async';

import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/growth_letter_model.dart';
import '../models/quest_node_model.dart';
import '../services/gemini_service.dart';
import '../services/growth_letter_service.dart';
import '../services/quest_service.dart';
import '../models/user_model.dart';
import '../models/goal_history_model.dart';
import '../services/goal_history_service.dart';
import 'progression_controller.dart';

class HomeController extends GetxController {
  final GeminiService _geminiService = GeminiService();
  final GrowthLetterService _growthLetterService = GrowthLetterService();
  final QuestService _questService = QuestService();
  StreamSubscription<GrowthLetterModel?>? _growthLetterSubscription;
  Timer? _growthLetterAvailabilityTimer;

  var user = Rx<UserModel?>(null);
  var nickname = "Hero".obs;
  var avatarSvg = "".obs;
  var hobby = "".obs;
  var goal = "".obs;
  var learningPace = "Steady Learner".obs;
  var level = "Novice".obs;

  var isLoadingProfile = true.obs;
  var hasAvailableGrowthLetter = false.obs;
  var isSeedingGoalCompletionTest = false.obs;

  var dailyQuests = <QuestNodeModel>[].obs;
  var isCompletedExpanded = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadUserProfile();
  }

  @override
  void onClose() {
    _growthLetterSubscription?.cancel();
    _growthLetterAvailabilityTimer?.cancel();
    super.onClose();
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
    print(
      '--- DEBUG: getVisibleQuestWindow called with ${quests.length} total quests ---',
    );

    if (quests.isEmpty) {
      print('--- WARN: No quests available at all! ---');
      return [];
    }

    final normalized = _buildNormalizedQuestGraph(quests);
    print(
      '--- DEBUG: After normalization: ${normalized.length} quests, isActive flags computed ---',
    );

    final completed = normalized.where((q) => q.isCompleted).length;
    final incomplete = normalized.where((q) => !q.isCompleted).length;
    print('--- DEBUG: Completed: $completed, Incomplete: $incomplete ---');

    final rootQuests = normalized
        .where((q) => !q.isCompleted && q.dependsOn.isEmpty)
        .toList();
    print(
      '--- DEBUG: Root quests available (no deps): ${rootQuests.length} ---',
    );

    final readyQuests = normalized
        .where(
          (quest) => !quest.isCompleted && _isQuestReady(quest, normalized),
        )
        .toList();

    print(
      '--- DEBUG: Total ready quests (dependencies satisfied): ${readyQuests.length} ---',
    );
    for (int i = 0; i < readyQuests.length; i++) {
      final q = readyQuests[i];
      print(
        '  [$i] ${q.nodeId}: ${q.title} (deps: ${q.dependsOn.isEmpty ? "none" : q.dependsOn.join(", ")})',
      );
    }

    const maxVisibleQuests = 3;
    final visibleWindow = readyQuests.take(maxVisibleQuests).toList();

    print('--- DEBUG: Filling active quests (max $maxVisibleQuests) ---');
    print(
      '--- DEBUG: Total ready available: ${readyQuests.length}, Taking: ${visibleWindow.length} ---',
    );

    if (visibleWindow.isEmpty) {
      print('--- ALERT: NO NEW QUESTS TO SHOW! Reasons: ---');
      if (incomplete == 0) {
        print('  → All quests are completed! Milestone finished!');
      }
      if (rootQuests.isEmpty && incomplete > 0) {
        print(
          '  → No root quests available (all remaining quests have dependencies)',
        );
      }
      if (readyQuests.isEmpty && incomplete > 0 && rootQuests.isNotEmpty) {
        print(
          '  → All incomplete quests have missing or circular dependencies',
        );
      }
      final incompleteQuests = normalized.where((q) => !q.isCompleted).toList();
      print('  → Incomplete quests status:');
      for (final q in incompleteQuests) {
        final depsReady = q.dependsOn.every(
          (dep) => normalized.any((n) => n.nodeId == dep && n.isCompleted),
        );
        print(
          '    • ${q.nodeId}: deps=${q.dependsOn.isEmpty ? "[]" : q.dependsOn}, allDepsReady=$depsReady',
        );
      }
    } else {
      print(
        '--- SUCCESS: Found ${visibleWindow.length} active quest(s) to display ---',
      );
      for (int i = 0; i < visibleWindow.length; i++) {
        print(
          '  [${i + 1}] ${visibleWindow[i].nodeId}: ${visibleWindow[i].title}',
        );
      }

      if (visibleWindow.length < maxVisibleQuests &&
          readyQuests.length > visibleWindow.length) {
        print(
          '--- INFO: More quests available! Could add ${readyQuests.length - visibleWindow.length} more to reach $maxVisibleQuests ---',
        );
      }
    }

    return visibleWindow;
  }

  /// Load user profile data from Firestore
  /// Now loads plan, milestones, and quests from subcollections.
  Future<void> _loadUserProfile() async {
    try {
      isLoadingProfile.value = true;

      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("--- ERROR: No user logged in ---");
        return;
      }

      final uid = currentUser.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;

        var loadedUser = UserModel.fromJson(data, uid);

        final planId = loadedUser.activePlanId;

        if (planId.isNotEmpty) {
          try {
            final plan = await QuestService.loadPlan(uid, planId);
            final milestones = await QuestService.loadMilestones(uid, planId);
            final quests = await QuestService.loadQuests(uid, planId);

            final fullPlan = plan.copyWith(
              milestones: milestones,
              quests: quests,
            );

            loadedUser = loadedUser.copyWith(
              activePlanId: planId,
              currentPlan: fullPlan,
            );
          } catch (e) {
            print(
              '--- WARNING: Failed to load plan data from subcollections: $e ---',
            );
          }
        }

        user.value = loadedUser;
        final currentPlan = loadedUser.currentPlan;

        nickname.value = loadedUser.nickname;
        avatarSvg.value = loadedUser.avatarSvg;
        hobby.value = currentPlan.hobby;
        goal.value = currentPlan.goal;
        learningPace.value = currentPlan.learningPace;
        level.value = currentPlan.level;
        dailyQuests.value = getAllQuestNodes(currentPlan.quests);
        _watchGrowthLetterAvailability(uid);

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

  Future<void> refreshGrowthLetterAvailability() async {
    final uid = user.value?.id ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    final planId = user.value?.activePlanId ?? '';
    if (uid.isEmpty || planId.isEmpty) {
      hasAvailableGrowthLetter.value = false;
      _scheduleGrowthLetterAvailabilityRefresh(null);
      return;
    }

    try {
      final availability = await _growthLetterService
          .checkGrowthLetterAvailability(uid: uid, planId: planId);
      hasAvailableGrowthLetter.value = availability.isAvailable;
      _scheduleGrowthLetterAvailabilityRefresh(availability.nextCheckAt);
    } catch (e) {
      print('--- WARNING: Failed to check growth letter availability: $e ---');
      hasAvailableGrowthLetter.value = false;
      _scheduleGrowthLetterAvailabilityRefresh(null);
    }
  }

  void _watchGrowthLetterAvailability(String uid) {
    _growthLetterSubscription?.cancel();
    if (uid.isEmpty) {
      hasAvailableGrowthLetter.value = false;
      _scheduleGrowthLetterAvailabilityRefresh(null);
      return;
    }

    _growthLetterSubscription = _growthLetterService
        .watchLatestGrowthLetter(uid)
        .listen(
          (_) {
            unawaited(refreshGrowthLetterAvailability());
          },
          onError: (error) {
            print(
              '--- WARNING: Failed to watch growth letter availability: $error ---',
            );
            hasAvailableGrowthLetter.value = false;
            _scheduleGrowthLetterAvailabilityRefresh(null);
          },
        );
    unawaited(refreshGrowthLetterAvailability());
  }

  void _scheduleGrowthLetterAvailabilityRefresh(DateTime? nextCheckAt) {
    _growthLetterAvailabilityTimer?.cancel();
    _growthLetterAvailabilityTimer = null;
    if (nextCheckAt == null) return;

    final delay = nextCheckAt.difference(DateTime.now());
    if (delay <= Duration.zero) {
      unawaited(refreshGrowthLetterAvailability());
      return;
    }

    _growthLetterAvailabilityTimer = Timer(
      delay,
      () => unawaited(refreshGrowthLetterAvailability()),
    );
  }


  Future<GoalCompletionTestSeedResult> seedGoalCompletionTestState() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('User not logged in.');
    if (isSeedingGoalCompletionTest.value) {
      throw Exception('The test plan is already being prepared.');
    }

    try {
      isSeedingGoalCompletionTest.value = true;
      final result = await QuestService.seedGoalCompletionTestState(
        currentUser.uid,
      );
      await _loadUserProfile();
      if (Get.isRegistered<ProgressionController>()) {
        await Get.find<ProgressionController>().loadProgress();
      }
      return result;
    } finally {
      isSeedingGoalCompletionTest.value = false;
    }
  }

  void rerollDailyQuests() {
    print(
      "--- LOGIC: Refreshing visible quest window from current plan... ---",
    );
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

    final planId = user.value?.activePlanId ?? '';
    if (planId.isEmpty) {
      print("--- ERROR: No active plan ---");
      return false;
    }

    final updatedUser = await _questService.completeQuestTransaction(
      uid: currentUser.uid,
      planId: planId,
      questId: questId,
      reflectionNote: reflectionNote,
    );

    if (updatedUser == null) return false;

    final updatedPlan = updatedUser.currentPlan;

    user.value = updatedUser;
    hobby.value = updatedPlan.hobby;
    goal.value = updatedPlan.goal;
    learningPace.value = updatedPlan.learningPace;
    level.value = updatedPlan.level;

    dailyQuests.value = getAllQuestNodes(updatedPlan.quests);
    await refreshGrowthLetterAvailability();

    print('--- INFO: Quest $questId completed via HomeController ---');

    return true;
  }

  Future<void> _reloadCurrentPlanQuests() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return;
      }

      final uid = currentUser.uid;
      final planId = user.value?.activePlanId ?? '';
      if (planId.isEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        final data = userDoc.data();
        if (data == null) return;

        final loadedUser = UserModel.fromJson(data, uid);
        user.value = loadedUser;

        nickname.value = loadedUser.nickname;
        avatarSvg.value = loadedUser.avatarSvg;
        hobby.value = loadedUser.currentPlan.hobby;
        goal.value = loadedUser.currentPlan.goal;
        learningPace.value = loadedUser.currentPlan.learningPace;
        level.value = loadedUser.currentPlan.level;
        dailyQuests.value = getAllQuestNodes(loadedUser.currentPlan.quests);
        return;
      }

      final plan = await QuestService.loadPlan(uid, planId);
      final milestones = await QuestService.loadMilestones(uid, planId);
      final quests = await QuestService.loadQuests(uid, planId);

      final fullPlan = plan.copyWith(milestones: milestones, quests: quests);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = userDoc.data();
      if (data == null) return;

      final loadedUser = UserModel.fromJson(
        data,
        uid,
      ).copyWith(activePlanId: planId, currentPlan: fullPlan);
      user.value = loadedUser;

      nickname.value = loadedUser.nickname;
      avatarSvg.value = loadedUser.avatarSvg;
      hobby.value = loadedUser.currentPlan.hobby;
      goal.value = loadedUser.currentPlan.goal;
      learningPace.value = loadedUser.currentPlan.learningPace;
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
          learningPace: learningPace.value,
          milestoneTitle: _currentMilestoneTitle(),
          questType: quest.type,
          durationMinutes: quest.durationMinutes,
        );

        final altSteps = (alternative['steps'] is List)
            ? (alternative['steps'] as List).map((e) => e.toString()).toList()
            : null;
        final altYoutube =
            (alternative['youtube_search_query']
                    ?.toString()
                    .trim()
                    .isNotEmpty ??
                false)
            ? alternative['youtube_search_query'].toString().trim()
            : (alternative['youtubeSearchQuery']?.toString().trim() ??
                  quest.youtubeSearchQuery ??
                  '');

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
      print(
        '--- INFO: Ephemeral reroll applied (${dailyQuests.length} quests) ---',
      );
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
        nodeTitle:
            dailyQuests
                .firstWhereOrNull((quest) => quest.nodeId == questId)
                ?.title ??
            '',
        nodeDesc:
            dailyQuests
                .firstWhereOrNull((quest) => quest.nodeId == questId)
                ?.desc ??
            '',
        learningPace: learningPace.value,
        milestoneTitle: _currentMilestoneTitle(),
        questType:
            dailyQuests
                .firstWhereOrNull((quest) => quest.nodeId == questId)
                ?.type ??
            'practice',
        durationMinutes:
            dailyQuests
                .firstWhereOrNull((quest) => quest.nodeId == questId)
                ?.durationMinutes ??
            15,
      );

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('--- ERROR: User not logged in ---');
        return false;
      }

      final uid = currentUser.uid;
      final planId = user.value?.activePlanId ?? '';
      if (planId.isEmpty) {
        print('--- ERROR: No active plan for reroll ---');
        return false;
      }

      final altSteps = (alternative['steps'] is List)
          ? (alternative['steps'] as List).map((e) => e.toString()).toList()
          : null;
      final altYoutube =
          (alternative['youtube_search_query']?.toString().trim().isNotEmpty ??
              false)
          ? alternative['youtube_search_query'].toString().trim()
          : (alternative['youtubeSearchQuery']?.toString().trim() ?? '');

      final questRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('plans')
          .doc(planId)
          .collection('quests')
          .doc(questId);

      await questRef.update({
        'title': alternative['title'] ?? '',
        'desc': alternative['desc'] ?? '',
        'steps': altSteps ?? [],
        'youtube_search_query': altYoutube,
      });

      final quests = await QuestService.loadQuests(uid, planId);
      final plan = await QuestService.loadPlan(uid, planId);
      final milestones = await QuestService.loadMilestones(uid, planId);

      final fullPlan = plan.copyWith(milestones: milestones, quests: quests);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = userDoc.data();
      if (data == null) return false;

      final updatedUser = UserModel.fromJson(
        data,
        uid,
      ).copyWith(activePlanId: planId, currentPlan: fullPlan);

      user.value = updatedUser;
      nickname.value = updatedUser.nickname;
      avatarSvg.value = updatedUser.avatarSvg;
      hobby.value = updatedUser.currentPlan.hobby;
      goal.value = updatedUser.currentPlan.goal;
      learningPace.value = updatedUser.currentPlan.learningPace;
      level.value = updatedUser.currentPlan.level;
      dailyQuests.value = getAllQuestNodes(updatedUser.currentPlan.quests);

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'lastRerollDate': DateTime.now(),
      });

      print('--- INFO: Quest $questId rerolled successfully ---');
      return true;
    } catch (e) {
      print('--- ERROR: Failed to reroll quest $questId: $e ---');
      return false;
    }
  }

  List<QuestNodeModel> _buildNormalizedQuestGraph(List<QuestNodeModel> quests) {
    final completedIds = quests
        .where((quest) => quest.isCompleted)
        .map((quest) => quest.nodeId)
        .toSet();

    final visibleIds = _computeVisibleQuestIds(quests, completedIds);

    return quests.map((quest) {
      final shouldBeActive =
          visibleIds.contains(quest.nodeId) && !quest.isCompleted;
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
    final completed =
        completedIds ??
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

  /// Returns `true` when all quests in the final milestone are complete.
  /// This is the terminal state for the current learning goal.
  bool hasCompletedFinalMilestone() {
    final plan = user.value?.currentPlan;
    if (plan == null || plan.milestones.isEmpty) return false;
    if (!plan.quests.every((q) => q.isCompleted)) return false;
    return plan.currentMilestoneIndex >= plan.milestones.length - 1;
  }

  /// Marks the active learning goal as complete without creating another phase.
  Future<void> completeCurrentGoal() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final current = user.value;
    final plan = current?.currentPlan;
    final uid = currentUser.uid;
    final planId = current?.activePlanId ?? '';
    if (current == null || plan == null || planId.isEmpty) return;
    if (plan.milestones.isEmpty) return;

    final currentIndex = plan.currentMilestoneIndex;
    if (currentIndex < 0 || currentIndex >= plan.milestones.length) return;

    final completedMilestones = plan.milestones.asMap().entries.map((entry) {
      final shouldBeComplete = entry.key <= currentIndex;
      return shouldBeComplete
          ? entry.value.copyWith(completed: true)
          : entry.value;
    }).toList();

    final completedPlan = plan.copyWith(
      isActive: false,
      progress: completedMilestones.length,
      milestones: completedMilestones,
    );

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);
    final planRef = userRef.collection('plans').doc(planId);
    final batch = firestore.batch();

    batch.set(planRef, completedPlan.toJson(), SetOptions(merge: true));
    for (final milestone in completedMilestones) {
      if (milestone.id.isEmpty) continue;
      batch.set(
        planRef.collection('milestones').doc(milestone.id),
        milestone.toJson(),
        SetOptions(merge: true),
      );
    }
    batch.set(userRef, {
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();

    final completionDates = completedPlan.quests
        .map((quest) => quest.completedAt)
        .whereType<DateTime>()
        .toList()
      ..sort();
    await GoalHistoryService.markGoalCompleted(
      uid,
      GoalHistoryModel(
        planId: planId,
        status: 'completed',
        hobby: completedPlan.hobby,
        level: completedPlan.level,
        goal: completedPlan.goal,
        learningPace: completedPlan.learningPace,
        category: completedPlan.category?.trim().isNotEmpty == true
            ? completedPlan.category!.trim()
            : completedPlan.hobby,
        createdAt:
            completionDates.isEmpty ? DateTime.now() : completionDates.first,
        completedAt:
            completionDates.isEmpty ? DateTime.now() : completionDates.last,
      ),
    );

    final updatedUser = current.copyWith(
      currentPlan: completedPlan,
      updatedAt: DateTime.now(),
    );
    user.value = updatedUser;
    dailyQuests.value = getAllQuestNodes(completedPlan.quests);
  }

  /// Generates the next milestone's quests, replaces the old quests in Firestore,
  /// and refreshes the local state. Should be called after the user confirms on
  /// the milestone-complete screen.
  Future<void> advanceToNextMilestone() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final plan = user.value?.currentPlan;
    final uid = currentUser.uid;
    final planId = user.value?.activePlanId ?? '';
    if (plan == null || planId.isEmpty) return;

    final nextIndex = plan.currentMilestoneIndex + 1;
    if (nextIndex >= plan.milestones.length) return;

    final nextMilestone = plan.milestones[nextIndex];
    final milestoneNumber = (nextIndex + 1).toString();

    final updatedMilestones = plan.milestones
        .asMap()
        .map((i, m) {
          if (i == plan.currentMilestoneIndex) {
            return MapEntry(i, m.copyWith(completed: true));
          }
          return MapEntry(i, m);
        })
        .values
        .toList();

    if (!_geminiService.hasApiKey) {
      print(
        '--- WARNING: No Gemini API key configured — using fallback quests ---',
      );
    }

    List<QuestNodeModel> newQuests;
    try {
      newQuests = await _geminiService.generatePhaseDAG(
        hobby: hobby.value,
        level: level.value,
        goal: goal.value,
        learningPace: learningPace.value,
        milestoneTitle: nextMilestone.title,
        milestoneNumber: milestoneNumber,
      );
    } catch (e) {
      print(
        '--- ERROR: Gemini API failed during milestone advancement: $e ---',
      );
      print('--- WARNING: Using fallback quests ---');
      rethrow;
    }

    final updatedUser = await _questService.addQuestsToPlan(
      uid: uid,
      planId: planId,
      newQuests: newQuests,
      currentMilestoneIndex: nextIndex,
      milestones: updatedMilestones,
    );

    if (updatedUser == null) return;

    user.value = updatedUser;
    dailyQuests.value = getAllQuestNodes(updatedUser.currentPlan.quests);
  }
}
