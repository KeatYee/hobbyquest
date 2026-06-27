import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../models/quest_node_model.dart';
import '../models/quest_plan_model.dart';

class QuestService {
  /// Checks whether the quest pool needs replenishment (fewer than [minVisible]
  /// ready quests remain).
  bool needsReplenishment(QuestPlanModel plan, {int minVisible = 3}) {
    final completedIds =
        plan.quests.where((q) => q.isCompleted).map((q) => q.nodeId).toSet();
    final readyCount = plan.quests.where((q) =>
        !q.isCompleted &&
        (q.dependsOn.isEmpty || q.dependsOn.every(completedIds.contains))).length;
    return readyCount < minVisible;
  }

  /// Adds [newQuests] to the user's plan and persists to Firestore.
  /// Returns the updated [UserModel] on success, or `null` on failure.
  /// New quests are set as root quests (no dependencies) so they appear immediately.
  /// When [clearExisting] is true, replaces all current quests instead of merging.
  Future<UserModel?> addQuestsToPlan({
    required String uid,
    required List<QuestNodeModel> newQuests,
    int? currentMilestoneIndex,
    bool clearExisting = false,  // NEW: replace all quests instead of merging
  }) async {
    if (newQuests.isEmpty) return null;

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    UserModel? updatedUser;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        final data = snapshot.data();
        if (data == null) return;

        final loadedUser = UserModel.fromJson(data, uid);

        List<QuestNodeModel> questsToAdd;
        if (clearExisting) {
          // Replace all quests — clear existing, use new quests directly
          questsToAdd = newQuests
              .map((q) => q.copyWith(
                    dependsOn: const [],
                    isActive: true,
                    isCompleted: false,
                  ))
              .toList();
        } else {
          // Only add quests whose IDs don't already exist
          final existingIds =
              loadedUser.currentPlan.quests.map((q) => q.nodeId).toSet();
          questsToAdd = newQuests
              .where((q) => !existingIds.contains(q.nodeId))
              .map((q) => q.copyWith(
                    dependsOn: const [],
                    isActive: true,
                    isCompleted: false,
                  ))
              .toList();
          if (questsToAdd.isEmpty) return;
        }

        final mergedQuests = clearExisting
            ? questsToAdd
            : [...loadedUser.currentPlan.quests, ...questsToAdd];
        final updatedPlan =
            loadedUser.currentPlan.copyWith(
              quests: mergedQuests,
              currentMilestoneIndex: currentMilestoneIndex,  // null = no change
            );
        final normalizedUser = loadedUser.copyWith(
          currentPlan: updatedPlan,
          updatedAt: DateTime.now(),
        );

        transaction.set(userRef,
            normalizedUser.toJson(), SetOptions(merge: true));
        updatedUser = normalizedUser;
      });
    } catch (e) {
      return null;
    }

    return updatedUser;
  }

  /// Completes the quest with [questId] for the user document [uid].
  /// Returns the updated `UserModel` on success, or `null` on failure.
  Future<UserModel?> completeQuestTransaction({
    required String uid,
    required String questId,
    String reflectionNote = '',
    String? imageUrl,
    String? greeting,
    String? observation,
    String? tip,
  }) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    UserModel? updatedUser;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        final data = snapshot.data();
        if (data == null) return;

        final loadedUser = UserModel.fromJson(data, uid);
        final quests = loadedUser.currentPlan.quests;
        final questIndex = quests.indexWhere((q) => q.nodeId == questId);
        if (questIndex == -1) return;

        final targetQuest = quests[questIndex];
        if (targetQuest.isCompleted) return;

        // Determine completed IDs
        final completedIds = quests.where((q) => q.isCompleted).map((q) => q.nodeId).toSet();

        // Check readiness (all dependencies completed)
        final isReady = targetQuest.dependsOn.isEmpty ||
            targetQuest.dependsOn.every((dep) => completedIds.contains(dep));

        if (!isReady) return;

        final updatedQuests = List<QuestNodeModel>.from(quests);
        updatedQuests[questIndex] = targetQuest.copyWith(
          isCompleted: true,
          isActive: false,
          reflectionNote: reflectionNote,
          completedAt: DateTime.now(),
          imageUrl: imageUrl,
          greeting: greeting,
          observation: observation,
          tip: tip,
        );

        // Normalize: recompute active flags for ALL ready quests (no cap)
        final completedAfter = updatedQuests.where((q) => q.isCompleted).map((q) => q.nodeId).toSet();
        final ready = <String>{};
        for (final q in updatedQuests) {
          if (q.isCompleted) continue;
          final isReady = q.dependsOn.isEmpty || q.dependsOn.every((d) => completedAfter.contains(d));
          if (isReady) ready.add(q.nodeId);
        }

        final normalized = updatedQuests.map((q) {
          final shouldBeActive = ready.contains(q.nodeId) && !q.isCompleted;
          return q.copyWith(isActive: shouldBeActive);
        }).toList();

        final updatedPlan = loadedUser.currentPlan.copyWith(quests: normalized);
        final normalizedUser = loadedUser.copyWith(
          currentPlan: updatedPlan,
          updatedAt: DateTime.now(),
          lastQuestCompletionDate: DateTime.now(),
        );

        transaction.set(userRef, normalizedUser.toJson(), SetOptions(merge: true));
        updatedUser = normalizedUser;
      });
    } catch (e) {
      // bubble up as null
      return null;
    }

    return updatedUser;
  }
}
