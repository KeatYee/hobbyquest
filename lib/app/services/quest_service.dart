import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../models/quest_node_model.dart';
import '../models/quest_plan_model.dart';
import '../models/milestone_model.dart';
import 'gemini_service.dart';

class GoalCompletionTestSeedResult {
  final String planId;
  final QuestNodeModel finalQuest;
  final int completedQuestCount;
  final int totalXP;

  const GoalCompletionTestSeedResult({
    required this.planId,
    required this.finalQuest,
    required this.completedQuestCount,
    required this.totalXP,
  });
}

class QuestService {
  static String _planDocPath(String uid, String planId) =>
      'users/$uid/plans/$planId';

  static String _milestoneDocPath(String uid, String planId, String mid) =>
      'users/$uid/plans/$planId/milestones/$mid';

  static String _questDocPath(String uid, String planId, String qid) =>
      'users/$uid/plans/$planId/quests/$qid';

  static DocumentReference<Map<String, dynamic>> _planRef(
    String uid,
    String planId,
  ) => FirebaseFirestore.instance.doc(_planDocPath(uid, planId));

  static DocumentReference<Map<String, dynamic>> _milestoneRef(
    String uid,
    String planId,
    String mid,
  ) => FirebaseFirestore.instance.doc(_milestoneDocPath(uid, planId, mid));

  static DocumentReference<Map<String, dynamic>> _questRef(
    String uid,
    String planId,
    String qid,
  ) => FirebaseFirestore.instance.doc(_questDocPath(uid, planId, qid));

  static CollectionReference<Map<String, dynamic>> _milestonesCol(
    String uid,
    String planId,
  ) => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('plans')
      .doc(planId)
      .collection('milestones');

  static CollectionReference<Map<String, dynamic>> _questsCol(
    String uid,
    String planId,
  ) => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('plans')
      .doc(planId)
      .collection('quests');

  /// Loads plan metadata document from `users/{uid}/plans/{planId}`.
  static Future<QuestPlanModel> loadPlan(String uid, String planId) async {
    final snapshot = await _planRef(uid, planId).get();
    if (!snapshot.exists) {
      throw Exception('Plan $planId not found for user $uid');
    }
    return QuestPlanModel.fromJson(snapshot.data()!, docId: planId);
  }

  /// Loads all milestones from `plans/{planId}/milestones/`, sorted by [order].
  static Future<List<MilestoneModel>> loadMilestones(
    String uid,
    String planId,
  ) async {
    final snapshot = await _milestonesCol(uid, planId).orderBy('order').get();
    return snapshot.docs.map((doc) {
      return MilestoneModel.fromJson(doc.data(), docId: doc.id);
    }).toList();
  }

  /// Loads all quests from `plans/{planId}/quests/`.
  static Future<List<QuestNodeModel>> loadQuests(
    String uid,
    String planId,
  ) async {
    final snapshot = await _questsCol(uid, planId).get();
    return snapshot.docs.map((doc) {
      return QuestNodeModel.fromJson(doc.data());
    }).toList();
  }

  /// Seeds the current plan so only Milestone 4's final quest remains.
  /// Intended solely for manually testing the goal-completion flow.
  static Future<GoalCompletionTestSeedResult> seedGoalCompletionTestState(
    String uid,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);
    final userSnapshot = await userRef.get();
    final userData = userSnapshot.data();
    if (userData == null) throw Exception('User profile not found.');

    var planId = userData['activePlanId'] as String? ?? '';
    if (planId.isEmpty) {
      final activePlans = await userRef
          .collection('plans')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      if (activePlans.docs.isEmpty) {
        throw Exception('No current test plan was found.');
      }
      planId = activePlans.docs.first.id;
    }

    final plan = await loadPlan(uid, planId);
    final milestones = await loadMilestones(uid, planId);
    var questSnapshot = await _questsCol(uid, planId).get();
    if (milestones.length < 4) {
      throw Exception('The test plan must contain at least four milestones.');
    }

    final generatedQuests = <QuestNodeModel>[];
    final geminiService = GeminiService();
    for (var index = 0; index < 4; index++) {
      final milestoneNumber = (index + 1).toString();
      final hasQuests = questSnapshot.docs.any((doc) {
        final nodeId = QuestNodeModel.fromJson(doc.data()).nodeId;
        return RegExp('^$milestoneNumber(?:_|\\b)').hasMatch(nodeId);
      });
      if (hasQuests) continue;

      final milestoneQuests = await geminiService.generatePhaseDAG(
        hobby: plan.hobby,
        level: plan.level,
        goal: plan.goal,
        learningPace: plan.learningPace,
        milestoneTitle: milestones[index].title,
        milestoneNumber: milestoneNumber,
      );
      if (milestoneQuests.isEmpty) {
        throw Exception('AI could not generate Milestone ${index + 1} quests.');
      }
      generatedQuests.addAll(milestoneQuests);
    }

    if (generatedQuests.isNotEmpty) {
      final generationBatch = firestore.batch();
      for (final quest in generatedQuests) {
        generationBatch.set(
          _questRef(uid, planId, quest.nodeId),
          quest.copyWith(isCompleted: false, isActive: false).toJson(),
        );
      }
      await generationBatch.commit();
      questSnapshot = await _questsCol(uid, planId).get();
    }

    final milestoneFourQuests = questSnapshot.docs.where((doc) {
      final nodeId = QuestNodeModel.fromJson(doc.data()).nodeId;
      return RegExp(r'^4(?:_|\b)').hasMatch(nodeId);
    }).toList();
    if (milestoneFourQuests.isEmpty) {
      throw Exception('Generated Milestone 4 quests could not be saved.');
    }

    final terminalQuests = milestoneFourQuests.where((candidate) {
      final candidateId = QuestNodeModel.fromJson(candidate.data()).nodeId;
      return !milestoneFourQuests.any((other) {
        final otherQuest = QuestNodeModel.fromJson(other.data());
        return otherQuest.dependsOn.contains(candidateId);
      });
    }).toList();
    final finalCandidates = terminalQuests.isEmpty
        ? milestoneFourQuests
        : terminalQuests;
    finalCandidates.sort((a, b) {
      final aQuest = QuestNodeModel.fromJson(a.data());
      final bQuest = QuestNodeModel.fromJson(b.data());
      final challengeComparison = (aQuest.type == 'challenge' ? 1 : 0)
          .compareTo(bQuest.type == 'challenge' ? 1 : 0);
      if (challengeComparison != 0) return challengeComparison;
      return _questSequence(
        aQuest.nodeId,
      ).compareTo(_questSequence(bQuest.nodeId));
    });
    final finalQuestDoc = finalCandidates.last;
    final finalQuest = QuestNodeModel.fromJson(
      finalQuestDoc.data(),
    ).copyWith(isCompleted: false, isActive: true);

    final completedAt = DateTime.now();
    var seededXP = 0;
    var completedQuestCount = 0;
    final batch = firestore.batch();

    for (final doc in questSnapshot.docs) {
      final quest = QuestNodeModel.fromJson(doc.data());
      final belongsToFirstFourMilestones = RegExp(
        r'^[1-4](?:_|\b)',
      ).hasMatch(quest.nodeId);
      final shouldComplete =
          belongsToFirstFourMilestones && quest.nodeId != finalQuest.nodeId;

      if (shouldComplete) {
        seededXP += quest.xpReward;
        completedQuestCount += 1;
      }

      batch.set(doc.reference, {
        'isCompleted': shouldComplete,
        'isActive': quest.nodeId == finalQuest.nodeId,
        'completedAt': shouldComplete ? completedAt : null,
        'awardedXP': shouldComplete ? quest.xpReward : null,
        if (!shouldComplete) 'reflectionNote': '',
        if (!shouldComplete) 'imageUrl': null,
        if (!shouldComplete) 'greeting': null,
        if (!shouldComplete) 'observation': null,
        if (!shouldComplete) 'tip': null,
      }, SetOptions(merge: true));
    }

    final updatedMilestones = milestones.asMap().entries.map((entry) {
      return entry.value.copyWith(completed: entry.key < 3);
    }).toList();
    final planRef = _planRef(uid, planId);
    for (final milestone in updatedMilestones) {
      batch.set(
        _milestoneRef(uid, planId, milestone.id),
        milestone.toJson(),
        SetOptions(merge: true),
      );
    }
    batch.set(
      planRef,
      plan
          .copyWith(
            progress: 3,
            currentMilestoneIndex: 3,
            isActive: true,
            startingXP: 0,
          )
          .toJson(),
      SetOptions(merge: true),
    );
    batch.set(userRef, {
      'activePlanId': planId,
      'totalXP': seededXP,
      'dailyQuestCompletionCount': completedQuestCount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    return GoalCompletionTestSeedResult(
      planId: planId,
      finalQuest: finalQuest,
      completedQuestCount: completedQuestCount,
      totalXP: seededXP,
    );
  }

  static int _questSequence(String nodeId) {
    final matches = RegExp(r'(\d+)').allMatches(nodeId).toList();
    return matches.isEmpty ? 0 : int.tryParse(matches.last.group(1)!) ?? 0;
  }

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
        final planSnapshot = await transaction.get(_planRef(uid, planId));
        final data = snapshot.data();
        if (data == null) return;

        final loadedUser = UserModel.fromJson(data, uid);
        final storedPlan = planSnapshot.data() == null
            ? loadedUser.currentPlan.copyWith(id: planId)
            : QuestPlanModel.fromJson(planSnapshot.data()!, docId: planId);

        final questsToWrite = newQuests
            .map((q) => q.copyWith(isActive: true, isCompleted: false))
            .toList();

        for (final quest in questsToWrite) {
          transaction.set(_questRef(uid, planId, quest.nodeId), quest.toJson());
        }

        for (final milestone in milestones) {
          transaction.set(
            _milestoneRef(uid, planId, milestone.id),
            milestone.toJson(),
          );
        }

        final plan = storedPlan.copyWith(
          id: planId,
          currentMilestoneIndex: currentMilestoneIndex,
          milestones: milestones,
          quests: questsToWrite,
        );
        transaction.set(_planRef(uid, planId), plan.toJson());

        transaction.set(userRef, {
          'activePlanId': planId,
          'updatedAt': DateTime.now(),
        }, SetOptions(merge: true));

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
    int? awardedXP,
  }) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    UserModel? updatedUser;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        final data = snapshot.data();
        if (data == null) return;

        final loadedUser = UserModel.fromJson(data, uid);
        final resolvedPlanId = planId.isNotEmpty
            ? planId
            : loadedUser.activePlanId;
        if (resolvedPlanId.isEmpty) return;

        final questRef = _questRef(uid, resolvedPlanId, questId);
        transaction.set(questRef, {
          'isCompleted': true,
          'isActive': false,
          'reflectionNote': reflectionNote,
          'completedAt': DateTime.now(),
          if (imageUrl != null) 'imageUrl': imageUrl,
          if (greeting != null) 'greeting': greeting,
          if (observation != null) 'observation': observation,
          if (tip != null) 'tip': tip,
          if (awardedXP != null) 'awardedXP': awardedXP,
        }, SetOptions(merge: true));

        transaction.set(userRef, {
          'updatedAt': DateTime.now(),
          'lastQuestCompletionDate': DateTime.now(),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      return null;
    }

    try {
      final resolvedPlanId = planId.isNotEmpty
          ? planId
          : (await userRef.get()).data()?['activePlanId'] as String? ?? '';
      if (resolvedPlanId.isEmpty) return null;

      final planSnapshot = await _planRef(uid, resolvedPlanId).get();
      if (!planSnapshot.exists) return null;

      final plan = QuestPlanModel.fromJson(
        planSnapshot.data()!,
        docId: resolvedPlanId,
      );
      final milestones = await loadMilestones(uid, resolvedPlanId);
      final quests = await loadQuests(uid, resolvedPlanId);

      final userSnapshot = await userRef.get();
      final userData = userSnapshot.data();
      if (userData == null) return null;

      final fullPlan = plan.copyWith(milestones: milestones, quests: quests);
      updatedUser = UserModel.fromJson(
        userData,
        uid,
      ).copyWith(activePlanId: resolvedPlanId, currentPlan: fullPlan);
    } catch (e) {
      return null;
    }

    return updatedUser;
  }
}
