import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../models/quest_node_model.dart';

class QuestService {
  /// Completes the quest with [questId] for the user document [uid].
  /// Returns the updated `UserModel` on success, or `null` on failure.
  Future<UserModel?> completeQuestTransaction({
    required String uid,
    required String questId,
    String reflectionNote = '',
    String? imageUrl,
    String? aiFeedback,
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
          aiFeedback: aiFeedback,
        );

        // Normalize: recompute active flags (simple pass)
        final completedAfter = updatedQuests.where((q) => q.isCompleted).map((q) => q.nodeId).toSet();
        final visible = <String>{};
        for (final q in updatedQuests) {
          if (q.isCompleted) continue;
          final ready = q.dependsOn.isEmpty || q.dependsOn.every((d) => completedAfter.contains(d));
          if (ready) visible.add(q.nodeId);
          if (visible.length == 3) break;
        }

        final normalized = updatedQuests.map((q) {
          final shouldBeActive = visible.contains(q.nodeId) && !q.isCompleted;
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
