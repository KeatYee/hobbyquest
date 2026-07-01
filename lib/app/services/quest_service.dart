import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../models/quest_node_model.dart';
import '../models/quest_plan_model.dart';
import '../models/milestone_model.dart';

class QuestService {
  // ──────────────────────────────────────────────
  //  Subcollection reference helpers
  // ──────────────────────────────────────────────

  static String _planDocPath(String uid, String planId) =>
      'users/$uid/plans/$planId';

  static String _milestoneDocPath(String uid, String planId, String mid) =>
      'users/$uid/plans/$planId/milestones/$mid';

  static String _questDocPath(String uid, String planId, String qid) =>
      'users/$uid/plans/$planId/quests/$qid';

  static DocumentReference<Map<String, dynamic>> _planRef(
          String uid, String planId) =>
      FirebaseFirestore.instance.doc(_planDocPath(uid, planId));

  static DocumentReference<Map<String, dynamic>> _milestoneRef(
          String uid, String planId, String mid) =>
      FirebaseFirestore.instance.doc(_milestoneDocPath(uid, planId, mid));

  static DocumentReference<Map<String, dynamic>> _questRef(
          String uid, String planId, String qid) =>
      FirebaseFirestore.instance.doc(_questDocPath(uid, planId, qid));

  static CollectionReference<Map<String, dynamic>> _milestonesCol(
          String uid, String planId) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('plans')
          .doc(planId)
          .collection('milestones');

  static CollectionReference<Map<String, dynamic>> _questsCol(
          String uid, String planId) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('plans')
          .doc(planId)
          .collection('quests');

  // ──────────────────────────────────────────────
  //  Read helpers
  // ──────────────────────────────────────────────

  /// Loads plan metadata document from `users/{uid}/plans/{planId}`.
  static Future<QuestPlanModel> loadPlan(
      String uid, String planId) async {
    final snapshot = await _planRef(uid, planId).get();
    if (!snapshot.exists) {
      throw Exception('Plan $planId not found for user $uid');
    }
    return QuestPlanModel.fromJson(
        snapshot.data()!, docId: planId);
  }

  /// Loads all milestones from `plans/{planId}/milestones/`, sorted by [order].
  static Future<List<MilestoneModel>> loadMilestones(
      String uid, String planId) async {
    final snapshot = await _milestonesCol(uid, planId)
        .orderBy('order')
        .get();
    return snapshot.docs.map((doc) {
      return MilestoneModel.fromJson(doc.data(), docId: doc.id);
    }).toList();
  }

  /// Loads all quests from `plans/{planId}/quests/`.
  static Future<List<QuestNodeModel>> loadQuests(
      String uid, String planId) async {
    final snapshot = await _questsCol(uid, planId).get();
    return snapshot.docs.map((doc) {
      return QuestNodeModel.fromJson(doc.data());
    }).toList();
  }

  // ──────────────────────────────────────────────
  //  Write helpers
  // ──────────────────────────────────────────────

  /// Saves/replaces plan metadata document.
  static Future<void> savePlan(
      String uid, String planId, QuestPlanModel plan) async {
    await _planRef(uid, planId).set(plan.toJson());
  }

  // ──────────────────────────────────────────────
  //  addQuestsToPlan — writes to subcollections
  // ──────────────────────────────────────────────

  /// Writes quests, milestones, and plan metadata to subcollections.
  /// Returns the updated [UserModel] with in-memory populated data, or null on failure.
  Future<UserModel?> addQuestsToPlan({
    required String uid,
    required String planId,
    required List<QuestNodeModel> newQuests,
    int? currentMilestoneIndex,
    required List<MilestoneModel> milestones,
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

        // Prepare quests: all start active with no dependencies cleared
        final questsToWrite = newQuests
            .map((q) => q.copyWith(
                  dependsOn: const [],
                  isActive: true,
                  isCompleted: false,
                ))
            .toList();

        // Write each quest to the quests subcollection
        for (final quest in questsToWrite) {
          transaction.set(
            _questRef(uid, planId, quest.nodeId),
            quest.toJson(),
          );
        }

        // Write each milestone to the milestones subcollection
        for (final milestone in milestones) {
          transaction.set(
            _milestoneRef(uid, planId, milestone.id),
            milestone.toJson(),
          );
        }

        // Write plan metadata
        final plan = loadedUser.currentPlan.copyWith(
          id: planId,
          currentMilestoneIndex: currentMilestoneIndex,
          milestones: milestones,
          quests: questsToWrite,
        );
        transaction.set(_planRef(uid, planId), plan.toJson());

        // Update user doc with activePlanId
        transaction.set(
          userRef,
          {
            'activePlanId': planId,
            'updatedAt': DateTime.now(),
          },
          SetOptions(merge: true),
        );

        // Build in-memory model
        final normalizedUser = loadedUser.copyWith(
          activePlanId: planId,
          currentPlan: plan,
          updatedAt: DateTime.now(),
        );
        updatedUser = normalizedUser;
      });
    } catch (e) {
      return null;
    }

    return updatedUser;
  }

  // ──────────────────────────────────────────────
  //  completeQuestTransaction
  // ──────────────────────────────────────────────

  /// Updates a single quest document in the subcollection + user doc timestamp.
  /// Returns the updated [UserModel] with in-memory data, or null on failure.
  Future<UserModel?> completeQuestTransaction({
    required String uid,
    required String planId,
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
        final resolvedPlanId = planId.isNotEmpty ? planId : loadedUser.activePlanId;
        if (resolvedPlanId.isEmpty) return;

        // Update the quest document in subcollection
        final questRef = _questRef(uid, resolvedPlanId, questId);
        transaction.set(
          questRef,
          {
            'isCompleted': true,
            'isActive': false,
            'reflectionNote': reflectionNote,
            'completedAt': DateTime.now(),
            if (imageUrl != null) 'imageUrl': imageUrl,
            if (greeting != null) 'greeting': greeting,
            if (observation != null) 'observation': observation,
            if (tip != null) 'tip': tip,
          },
          SetOptions(merge: true),
        );

        // Update user doc timestamp
        transaction.set(
          userRef,
          {
            'updatedAt': DateTime.now(),
            'lastQuestCompletionDate': DateTime.now(),
          },
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      return null;
    }

    // After transaction, reload all data to build the in-memory model
    try {
      final resolvedPlanId = planId.isNotEmpty
          ? planId
          : (await userRef.get()).data()?['activePlanId'] as String? ?? '';
      if (resolvedPlanId.isEmpty) return null;

      final planSnapshot = await _planRef(uid, resolvedPlanId).get();
      if (!planSnapshot.exists) return null;

      final plan = QuestPlanModel.fromJson(
          planSnapshot.data()!, docId: resolvedPlanId);
      final milestones = await loadMilestones(uid, resolvedPlanId);
      final quests = await loadQuests(uid, resolvedPlanId);

      final userSnapshot = await userRef.get();
      final userData = userSnapshot.data();
      if (userData == null) return null;

      final fullPlan = plan.copyWith(
        milestones: milestones,
        quests: quests,
      );
      updatedUser = UserModel.fromJson(userData, uid).copyWith(
        activePlanId: resolvedPlanId,
        currentPlan: fullPlan,
      );
    } catch (e) {
      return null;
    }

    return updatedUser;
  }

  // ──────────────────────────────────────────────
  //  Utility
  // ──────────────────────────────────────────────

  /// Checks whether the quest pool needs replenishment (fewer than [minVisible]
  /// ready quests remain).
  bool needsReplenishment(List<QuestNodeModel> quests, {int minVisible = 3}) {
    final completedIds =
        quests.where((q) => q.isCompleted).map((q) => q.nodeId).toSet();
    final readyCount = quests.where((q) =>
        !q.isCompleted &&
        (q.dependsOn.isEmpty || q.dependsOn.every(completedIds.contains))).length;
    return readyCount < minVisible;
  }
}
