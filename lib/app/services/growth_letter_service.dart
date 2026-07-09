import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/growth_letter_model.dart';
import '../models/quest_node_model.dart';
import '../models/user_model.dart';
import 'gemini_service.dart';

class GrowthLetterAvailability {
  final bool isAvailable;
  final DateTime? nextCheckAt;

  const GrowthLetterAvailability({
    required this.isAvailable,
    this.nextCheckAt,
  });
}

class GrowthLetterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GeminiService _geminiService = GeminiService();

  CollectionReference<Map<String, dynamic>> _lettersCol(String uid) {
    return _firestore.collection('users').doc(uid).collection('growthLetters');
  }

  CollectionReference<Map<String, dynamic>> _questsCol(
    String uid,
    String planId,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('plans')
        .doc(planId)
        .collection('quests');
  }

  Future<GrowthLetterModel?> loadLatestGrowthLetter(String uid) async {
    final snapshot = await _lettersCol(uid)
        .orderBy('periodEnd', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return GrowthLetterModel.fromJson(doc.data(), docId: doc.id);
  }

  Stream<GrowthLetterModel?> watchLatestGrowthLetter(String uid) {
    if (uid.isEmpty) return Stream.value(null);

    return _lettersCol(uid)
        .orderBy('periodEnd', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return GrowthLetterModel.fromJson(doc.data(), docId: doc.id);
    });
  }

  Future<GrowthLetterAvailability> checkGrowthLetterAvailability({
    required String uid,
    required String planId,
  }) async {
    if (uid.isEmpty || planId.isEmpty) {
      return const GrowthLetterAvailability(isAvailable: false);
    }

    final latest = await loadLatestGrowthLetter(uid);
    if (latest != null && latest.readAt == null) {
      return const GrowthLetterAvailability(isAvailable: true);
    }

    final now = DateTime.now();
    final latestAnchorDate = latest?.createdAt ?? latest?.periodEnd;
    if (latestAnchorDate != null) {
      final nextAllowed = latestAnchorDate.add(const Duration(days: 7));
      if (now.isBefore(nextAllowed)) {
        return GrowthLetterAvailability(
          isAvailable: false,
          nextCheckAt: nextAllowed,
        );
      }
    }

    final hasCompletedQuests = await _hasCompletedQuestsForPeriod(
      uid: uid,
      planId: planId,
      periodStart: now.subtract(const Duration(days: 7)),
      periodEnd: now,
    );

    return GrowthLetterAvailability(isAvailable: hasCompletedQuests);
  }

  Future<void> markGrowthLetterRead({
    required String uid,
    required String letterId,
  }) async {
    if (uid.isEmpty || letterId.isEmpty || letterId == 'demo') return;

    await _lettersCol(uid).doc(letterId).update({
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<GrowthLetterModel?> generateWeeklyGrowthLetter({
    required UserModel user,
  }) async {
    final uid = user.id;
    final planId = user.activePlanId;
    if (uid.isEmpty || planId.isEmpty) return null;

    final now = DateTime.now();
    final periodEnd = now;
    final periodStart = now.subtract(const Duration(days: 7));

    final latest = await loadLatestGrowthLetter(uid);
    var shouldReuseLatest = false;
    final latestAnchorDate = latest?.createdAt ?? latest?.periodEnd;
    if (latestAnchorDate != null) {
      final nextAllowed = latestAnchorDate.add(const Duration(days: 7));
      if (now.isBefore(nextAllowed)) {
        shouldReuseLatest = true;
      }
    }

    if (shouldReuseLatest &&
        latest != null &&
        latest.hasPersonalizedInsights &&
        latest.hasWeeklyStats) {
      return latest;
    }

    final needsInsightBackfill =
        shouldReuseLatest && latest != null && !latest.hasPersonalizedInsights;
    final needsStatsBackfill =
        shouldReuseLatest && latest != null && !latest.hasWeeklyStats;

    final questPeriodStart = shouldReuseLatest && latest != null
        ? latest.periodStart
        : periodStart;
    final questPeriodEnd = shouldReuseLatest && latest != null
        ? latest.periodEnd
        : periodEnd;

    final quests = await _loadCompletedQuestsForPeriod(
      uid: uid,
      planId: planId,
      periodStart: questPeriodStart,
      periodEnd: questPeriodEnd,
    );
    if (quests.isEmpty) return latest;

    final weeklyStreakDays = _calculateWeeklyStreakDays(quests);

    final reflections = quests
        .map((quest) => quest.reflectionNote.trim())
        .where((reflection) => reflection.isNotEmpty)
        .take(8)
        .toList();

    if (needsStatsBackfill && !needsInsightBackfill) {
      final letterRef = _lettersCol(uid).doc(latest!.id);
      await letterRef.update({
        'questCount': quests.length,
        'reflectionCount': reflections.length,
        'weeklyStreakDays': weeklyStreakDays,
        'questIds': quests.map((quest) => quest.nodeId).toList(),
      });

      final saved = await letterRef.get();
      return GrowthLetterModel.fromJson(saved.data()!, docId: saved.id);
    }

    final draft = await _geminiService.generateGrowthLetter(
      nickname: user.nickname,
      hobby: user.currentPlan.hobby,
      questCount: quests.length,
      questTitles: quests.map((quest) => quest.title).take(10).toList(),
      reflections: reflections,
    );

    if (needsInsightBackfill) {
      final letterRef = _lettersCol(uid).doc(latest!.id);
      await letterRef.update({
        'questCount': quests.length,
        'reflectionCount': reflections.length,
        'weeklyStreakDays': weeklyStreakDays,
        'questIds': quests.map((quest) => quest.nodeId).toList(),
        'strongestGrowth': draft.strongestGrowth,
        'focusArea': draft.focusArea,
        'nextWeekFocus': draft.nextWeekFocus,
        'hasPersonalizedInsights': true,
      });

      final saved = await letterRef.get();
      return GrowthLetterModel.fromJson(saved.data()!, docId: saved.id);
    }

    final docRef = await _lettersCol(uid).add(
      GrowthLetterModel(
        uid: uid,
        planId: planId,
        hobby: user.currentPlan.hobby,
        nickname: user.nickname,
        letter: draft.letter,
        questCount: quests.length,
        reflectionCount: reflections.length,
        weeklyStreakDays: weeklyStreakDays,
        questIds: quests.map((quest) => quest.nodeId).toList(),
        strongestGrowth: draft.strongestGrowth,
        focusArea: draft.focusArea,
        nextWeekFocus: draft.nextWeekFocus,
        periodStart: periodStart,
        periodEnd: periodEnd,
      ).toJson(),
    );

    final saved = await docRef.get();
    return GrowthLetterModel.fromJson(saved.data()!, docId: saved.id);
  }

  Future<List<QuestNodeModel>> _loadCompletedQuestsForPeriod({
    required String uid,
    required String planId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final query = _questsCol(uid, planId)
        .where(
          'completedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart),
        )
        .where(
          'completedAt',
          isLessThanOrEqualTo: Timestamp.fromDate(periodEnd),
        )
        .orderBy('completedAt', descending: true);

    final snapshot = await query.get();

    final quests = snapshot.docs
        .map((doc) => QuestNodeModel.fromJson(doc.data()))
        .where((quest) => quest.isCompleted)
        .toList();
    quests.sort((a, b) {
      final aDate = a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return quests;
  }

  Future<bool> _hasCompletedQuestsForPeriod({
    required String uid,
    required String planId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final quests = await _loadCompletedQuestsForPeriod(
      uid: uid,
      planId: planId,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
    return quests.isNotEmpty;
  }

  int _calculateWeeklyStreakDays(List<QuestNodeModel> quests) {
    final completedDays = <DateTime>{};
    for (final quest in quests) {
      final completedAt = quest.completedAt;
      if (completedAt == null) continue;

      completedDays.add(
        DateTime(completedAt.year, completedAt.month, completedAt.day),
      );
    }

    if (completedDays.isEmpty) return 0;

    final sortedDays = completedDays.toList()..sort();
    var longestStreak = 1;
    var currentStreak = 1;

    for (var index = 1; index < sortedDays.length; index++) {
      final dayGap = sortedDays[index].difference(sortedDays[index - 1]).inDays;
      if (dayGap == 1) {
        currentStreak += 1;
      } else if (dayGap > 1) {
        currentStreak = 1;
      }

      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }
    }

    return longestStreak;
  }

  static Future<void> deleteAllGrowthLetters(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('growthLetters')
        .get();
    if (snapshot.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
