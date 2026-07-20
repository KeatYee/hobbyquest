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

  Future<GrowthLetterModel?> _loadGrowthLetterForWeek({
    required String uid,
    required DateTime periodStart,
  }) async {
    final doc = await _lettersCol(uid).doc(_weekDocumentId(periodStart)).get();
    if (doc.exists && doc.data() != null) {
      return GrowthLetterModel.fromJson(doc.data()!, docId: doc.id);
    }

    // Preserve compatibility with letters created before week-based IDs were
    // introduced.
    final legacy = await _lettersCol(uid)
        .where('periodStart', isEqualTo: Timestamp.fromDate(periodStart))
        .limit(1)
        .get();
    if (legacy.docs.isEmpty) return null;
    final legacyDoc = legacy.docs.first;
    return GrowthLetterModel.fromJson(legacyDoc.data(), docId: legacyDoc.id);
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

    final now = DateTime.now();
    final week = _mostRecentlyCompletedWeek(now);
    final existing = await _loadGrowthLetterForWeek(
      uid: uid,
      periodStart: week.start,
    );
    if (existing != null) {
      return GrowthLetterAvailability(isAvailable: existing.readAt == null);
    }

    final hasCompletedQuests = await _hasCompletedQuestsForPeriod(
      uid: uid,
      planId: planId,
      periodStart: week.start,
      periodEndExclusive: week.endExclusive,
    );

    return GrowthLetterAvailability(
      isAvailable: hasCompletedQuests,
      nextCheckAt: hasCompletedQuests
          ? null
          : _startOfCurrentWeek(now).add(const Duration(days: 7)),
    );
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

    final week = _mostRecentlyCompletedWeek(DateTime.now());
    final existing = await _loadGrowthLetterForWeek(
      uid: uid,
      periodStart: week.start,
    );
    if (existing != null) return existing;

    final quests = await _loadCompletedQuestsForPeriod(
      uid: uid,
      planId: planId,
      periodStart: week.start,
      periodEndExclusive: week.endExclusive,
    );
    if (quests.isEmpty) return loadLatestGrowthLetter(uid);

    final weeklyStreakDays = _calculateWeeklyStreakDays(quests);

    final reflections = quests
        .map((quest) => quest.reflectionNote.trim())
        .where((reflection) => reflection.isNotEmpty)
        .take(8)
        .toList();

    final draft = await _geminiService.generateGrowthLetter(
      nickname: user.nickname,
      hobby: user.currentPlan.hobby,
      questCount: quests.length,
      questTitles: quests.map((quest) => quest.title).take(10).toList(),
      reflections: reflections,
    );

    final docRef = _lettersCol(uid).doc(_weekDocumentId(week.start));
    final letterData = GrowthLetterModel(
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
        periodStart: week.start,
        periodEnd: week.endExclusive.subtract(const Duration(microseconds: 1)),
      ).toJson();

    // A transaction makes the saved letter idempotent across multiple devices.
    // It never replaces an existing week's content.
    await _firestore.runTransaction((transaction) async {
      final current = await transaction.get(docRef);
      if (!current.exists) transaction.set(docRef, letterData);
    });

    final saved = await docRef.get();
    return GrowthLetterModel.fromJson(saved.data()!, docId: saved.id);
  }

  Future<List<QuestNodeModel>> _loadCompletedQuestsForPeriod({
    required String uid,
    required String planId,
    required DateTime periodStart,
    required DateTime periodEndExclusive,
  }) async {
    final query = _questsCol(uid, planId)
        .where(
          'completedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart),
        )
        .where(
          'completedAt',
          isLessThan: Timestamp.fromDate(periodEndExclusive),
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
    required DateTime periodEndExclusive,
  }) async {
    final quests = await _loadCompletedQuestsForPeriod(
      uid: uid,
      planId: planId,
      periodStart: periodStart,
      periodEndExclusive: periodEndExclusive,
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

  static DateTime _startOfCurrentWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static _CalendarWeek _mostRecentlyCompletedWeek(DateTime now) {
    final endExclusive = _startOfCurrentWeek(now);
    return _CalendarWeek(
      start: endExclusive.subtract(const Duration(days: 7)),
      endExclusive: endExclusive,
    );
  }

  static String _weekDocumentId(DateTime periodStart) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return 'week_${periodStart.year}-${twoDigits(periodStart.month)}-'
        '${twoDigits(periodStart.day)}';
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

class _CalendarWeek {
  final DateTime start;
  final DateTime endExclusive;

  const _CalendarWeek({required this.start, required this.endExclusive});
}
