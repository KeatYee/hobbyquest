import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/user_model.dart';
import '../models/quest_node_model.dart';
import '../models/quest_plan_model.dart';
import '../models/milestone_model.dart';
import '../../core/utils/streak_calculator.dart';

class QuestCompletionResult {
  final String planId;
  final QuestNodeModel quest;
  final bool didComplete;
  final int awardedXP;
  final int previousTotalXP;
  final int updatedTotalXP;
  final int updatedStreak;
  final int dailyQuestCompletionCount;
  final Map<String, int> updatedCategoryXp;
  final DateTime completionTime;
  final UserModel? updatedUser;

  const QuestCompletionResult({
    required this.planId,
    required this.quest,
    required this.didComplete,
    required this.awardedXP,
    required this.previousTotalXP,
    required this.updatedTotalXP,
    required this.updatedStreak,
    required this.dailyQuestCompletionCount,
    required this.updatedCategoryXp,
    required this.completionTime,
    this.updatedUser,
  });

  QuestCompletionResult copyWithUpdatedUser(UserModel user) {
    return QuestCompletionResult(
      planId: planId,
      quest: quest,
      didComplete: didComplete,
      awardedXP: awardedXP,
      previousTotalXP: previousTotalXP,
      updatedTotalXP: updatedTotalXP,
      updatedStreak: updatedStreak,
      dailyQuestCompletionCount: dailyQuestCompletionCount,
      updatedCategoryXp: updatedCategoryXp,
      completionTime: completionTime,
      updatedUser: user,
    );
  }
}

class QuestService {
  static const int reflectionImageBonusXP = 50;

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

  /// Advances a completed milestone and writes the next milestone atomically.
  Future<UserModel> addQuestsToPlan({
    required String uid,
    required String planId,
    required List<QuestNodeModel> newQuests,
    required List<String> expectedCompletedQuestIds,
    required int expectedCurrentMilestoneIndex,
    required int currentMilestoneIndex,
    required List<MilestoneModel> milestones,
  }) async {
    if (uid.trim().isEmpty || planId.trim().isEmpty) {
      throw ArgumentError('A user and plan are required for advancement.');
    }
    if (newQuests.isEmpty) {
      throw ArgumentError('At least one quest is required for a milestone.');
    }
    if (expectedCompletedQuestIds.isEmpty) {
      throw ArgumentError('Completed milestone quests are required.');
    }
    if (currentMilestoneIndex != expectedCurrentMilestoneIndex + 1 ||
        expectedCurrentMilestoneIndex < 0 ||
        currentMilestoneIndex >= milestones.length) {
      throw ArgumentError('The milestone transition is invalid.');
    }

    final newQuestIds = newQuests.map((quest) => quest.nodeId.trim()).toList();
    if (newQuestIds.any((id) => id.isEmpty) ||
        newQuestIds.toSet().length != newQuestIds.length) {
      throw ArgumentError('Next-milestone quest IDs must be unique.');
    }
    final completedQuestIds = expectedCompletedQuestIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (completedQuestIds.length != expectedCompletedQuestIds.length) {
      throw ArgumentError('Completed-milestone quest IDs must be unique.');
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    late UserModel updatedUser;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final planSnapshot = await transaction.get(_planRef(uid, planId));
      final data = snapshot.data();
      if (data == null) {
        throw StateError('User profile not found.');
      }
      if (!planSnapshot.exists || planSnapshot.data() == null) {
        throw StateError('Active plan not found.');
      }

      final loadedUser = UserModel.fromJson(data, uid);
      final storedPlan = QuestPlanModel.fromJson(
        planSnapshot.data()!,
        docId: planId,
      );
      if (loadedUser.activePlanId != planId || !storedPlan.isActive) {
        throw StateError('This is no longer the active learning plan.');
      }
      if (storedPlan.currentMilestoneIndex != expectedCurrentMilestoneIndex) {
        throw StateError('The milestone has already changed.');
      }

      for (final questId in completedQuestIds) {
        final questSnapshot = await transaction.get(
          _questRef(uid, planId, questId),
        );
        if (!questSnapshot.exists ||
            questSnapshot.data()?['isCompleted'] != true) {
          throw StateError('The current milestone is not complete yet.');
        }
      }

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
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      updatedUser = loadedUser.copyWith(
        activePlanId: planId,
        currentPlan: plan,
        updatedAt: DateTime.now(),
      );
    });

    return updatedUser;
  }

  /// Completes a quest and awards all progression state atomically.
  ///
  /// The quest document is read before any writes. A retry of an already
  /// completed quest returns its current state without awarding XP again.
  Future<QuestCompletionResult> completeQuestTransaction({
    required String uid,
    required String planId,
    required String questId,
    String reflectionNote = '',
    String? imageUrl,
    String? greeting,
    String? observation,
    String? tip,
    String? fallbackCategoryName,
  }) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError('A user ID is required to complete a quest.');
    }
    if (questId.trim().isEmpty) {
      throw ArgumentError('A quest ID is required to complete a quest.');
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final timeResult = await FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable('getServerTime').call();
    final timeData = Map<String, dynamic>.from(timeResult.data as Map);
    final serverMilliseconds = timeData['millisecondsSinceEpoch'];
    if (serverMilliseconds is! num) {
      throw StateError('The server returned an invalid completion time.');
    }
    final completionTime = DateTime.fromMillisecondsSinceEpoch(
      serverMilliseconds.toInt(),
      isUtc: true,
    );
    final normalizedReflection = reflectionNote.trim();
    final normalizedImageUrl = imageUrl?.trim();

    final result = await FirebaseFirestore.instance
        .runTransaction<QuestCompletionResult>((transaction) async {
          final userSnapshot = await transaction.get(userRef);
          final userData = userSnapshot.data();
          if (userData == null) {
            throw StateError('User profile not found.');
          }

          final storedActivePlanId =
              userData['activePlanId']?.toString().trim() ?? '';
          final requestedPlanId = planId.trim();
          final resolvedPlanId = requestedPlanId.isNotEmpty
              ? requestedPlanId
              : storedActivePlanId;
          if (resolvedPlanId.isEmpty) {
            throw StateError('No active plan was found.');
          }
          if (storedActivePlanId.isNotEmpty &&
              storedActivePlanId != resolvedPlanId) {
            throw StateError('The requested quest is not in the active plan.');
          }

          final planRef = _planRef(uid, resolvedPlanId);
          final questRef = _questRef(uid, resolvedPlanId, questId);
          final planSnapshot = await transaction.get(planRef);
          final questSnapshot = await transaction.get(questRef);
          final planData = planSnapshot.data();
          final rawQuestData = questSnapshot.data();
          if (planData == null) {
            throw StateError('Active plan not found.');
          }
          if (rawQuestData == null) {
            throw StateError('Quest not found.');
          }

          final questData = Map<String, dynamic>.from(rawQuestData);
          final storedNodeId = questData['node_id']?.toString().trim() ?? '';
          if (storedNodeId.isEmpty) questData['node_id'] = questId;
          final storedQuest = QuestNodeModel.fromJson(questData);
          final currentTotalXP = _readTotalXP(userData);
          final currentStreak = _readInt(userData['currentStreak']);
          final currentCompletionCount = _readInt(
            userData['dailyQuestCompletionCount'],
          );
          final updatedCompletionCount = calculateDailyQuestCompletionCount(
            currentCount: currentCompletionCount,
            lastCompletionDate: _readDateTime(
              userData['lastQuestCompletionDate'],
            ),
            completionTime: completionTime,
          );
          final currentCategoryXp = _readCategoryXp(userData['categoryXp']);

          if (storedQuest.isCompleted) {
            return QuestCompletionResult(
              planId: resolvedPlanId,
              quest: storedQuest,
              didComplete: false,
              awardedXP: storedQuest.awardedXP ?? 0,
              previousTotalXP: currentTotalXP,
              updatedTotalXP: currentTotalXP,
              updatedStreak: currentStreak,
              dailyQuestCompletionCount: currentCompletionCount,
              updatedCategoryXp: currentCategoryXp,
              completionTime: storedQuest.completedAt ?? completionTime,
            );
          }

          if (planData['isActive'] == false) {
            throw StateError('This learning plan is no longer active.');
          }
          if (normalizedReflection.length < 15) {
            throw ArgumentError(
              'A reflection of at least 15 characters is required.',
            );
          }
          if (storedQuest.type == 'challenge' &&
              (normalizedImageUrl == null || normalizedImageUrl.isEmpty)) {
            throw ArgumentError('Photo evidence is required for this quest.');
          }

          for (final dependencyId in storedQuest.dependsOn.toSet()) {
            if (dependencyId == questId) {
              throw StateError('Quest dependencies contain a cycle.');
            }
            final dependencySnapshot = await transaction.get(
              _questRef(uid, resolvedPlanId, dependencyId),
            );
            final dependencyData = dependencySnapshot.data();
            if (dependencyData == null ||
                dependencyData['isCompleted'] != true) {
              throw StateError(
                'Complete all prerequisite quests before this quest.',
              );
            }
          }

          final baseXP = storedQuest.xpReward;
          if (baseXP < 0) {
            throw StateError('Quest XP cannot be negative.');
          }
          final imageBonus = normalizedImageUrl?.isNotEmpty == true
              ? reflectionImageBonusXP
              : 0;
          final awardedXP = baseXP + imageBonus;
          final updatedTotalXP = currentTotalXP + awardedXP;
          final updatedStreak = calculateUpdatedStreak(
            currentStreak: currentStreak,
            lastStreakDate: _readDateTime(userData['lastStreakDate']),
            completionTime: completionTime,
          );
          final updatedCategoryXp = Map<String, int>.from(currentCategoryXp);
          final storedCategory = planData['category']?.toString().trim() ?? '';
          final categoryName = storedCategory.isNotEmpty
              ? storedCategory
              : fallbackCategoryName?.trim() ?? '';
          if (categoryName.isNotEmpty) {
            updatedCategoryXp[categoryName] =
                (updatedCategoryXp[categoryName] ?? 0) + awardedXP;
          }

          transaction.set(questRef, {
            'isCompleted': true,
            'isActive': false,
            'reflectionNote': normalizedReflection,
            'completedAt': FieldValue.serverTimestamp(),
            if (normalizedImageUrl?.isNotEmpty == true)
              'imageUrl': normalizedImageUrl,
            if (greeting?.trim().isNotEmpty == true)
              'greeting': greeting!.trim(),
            if (observation?.trim().isNotEmpty == true)
              'observation': observation!.trim(),
            if (tip?.trim().isNotEmpty == true) 'tip': tip!.trim(),
            'awardedXP': awardedXP,
          }, SetOptions(merge: true));

          transaction.set(userRef, {
            'totalXP': updatedTotalXP,
            'currentStreak': updatedStreak,
            'lastStreakDate': FieldValue.serverTimestamp(),
            'lastQuestCompletionDate': FieldValue.serverTimestamp(),
            'dailyQuestCompletionCount': updatedCompletionCount,
            'categoryXp': updatedCategoryXp,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          transaction.set(
            FirebaseFirestore.instance.collection('publicProfiles').doc(uid),
            {
              'totalXP': updatedTotalXP,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          return QuestCompletionResult(
            planId: resolvedPlanId,
            quest: storedQuest.copyWith(
              isCompleted: true,
              isActive: false,
              reflectionNote: normalizedReflection,
              completedAt: completionTime,
              imageUrl: normalizedImageUrl,
              greeting: greeting?.trim(),
              observation: observation?.trim(),
              tip: tip?.trim(),
              awardedXP: awardedXP,
            ),
            didComplete: true,
            awardedXP: awardedXP,
            previousTotalXP: currentTotalXP,
            updatedTotalXP: updatedTotalXP,
            updatedStreak: updatedStreak,
            dailyQuestCompletionCount: updatedCompletionCount,
            updatedCategoryXp: updatedCategoryXp,
            completionTime: completionTime,
          );
        });

    try {
      final plan = await loadPlan(uid, result.planId);
      final milestones = await loadMilestones(uid, result.planId);
      final quests = await loadQuests(uid, result.planId);
      final userSnapshot = await userRef.get();
      final userData = userSnapshot.data();
      if (userData == null) return result;

      final fullPlan = plan.copyWith(milestones: milestones, quests: quests);
      final updatedUser = UserModel.fromJson(
        userData,
        uid,
      ).copyWith(activePlanId: result.planId, currentPlan: fullPlan);
      return result.copyWithUpdatedUser(updatedUser);
    } catch (e) {
      print(
        '--- WARNING: Quest completed, but refreshed profile loading failed: $e ---',
      );
      return result;
    }
  }

  static int _readTotalXP(Map<String, dynamic> data) {
    final totalXP = data['totalXP'];
    if (totalXP is num) return totalXP.toInt();

    final legacyLevel = _readInt(data['level'], fallback: 1);
    final legacyCurrentXP = _readInt(data['currentXp']);
    return ((legacyLevel - 1) * 1000) + legacyCurrentXP;
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    return value is num ? value.toInt() : fallback;
  }

  static Map<String, int> _readCategoryXp(dynamic value) {
    if (value is! Map) return <String, int>{};

    return value.map(
      (key, xp) => MapEntry(key.toString(), xp is num ? xp.toInt() : 0),
    );
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
