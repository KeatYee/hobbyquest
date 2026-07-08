import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/growth_letter_model.dart';
import '../models/quest_node_model.dart';
import '../models/user_model.dart';
import 'gemini_service.dart';

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

  Future<bool> hasUnreadGrowthLetter(String uid) async {
    final latest = await loadLatestGrowthLetter(uid);
    return latest != null && latest.readAt == null;
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
    if (latest?.createdAt != null) {
      final nextAllowed = latest!.createdAt!.add(const Duration(days: 7));
      if (now.isBefore(nextAllowed)) {
        return latest;
      }
    }

    final quests = await _loadCompletedQuestsForPeriod(
      uid: uid,
      planId: planId,
      periodStart: periodStart,
    );
    if (quests.isEmpty) return latest;

    final reflections = quests
        .map((quest) => quest.reflectionNote.trim())
        .where((reflection) => reflection.isNotEmpty)
        .take(8)
        .toList();

    final letterText = await _geminiService.generateGrowthLetter(
      nickname: user.nickname,
      hobby: user.currentPlan.hobby,
      questCount: quests.length,
      questTitles: quests.map((quest) => quest.title).take(10).toList(),
      reflections: reflections,
    );

    final docRef = await _lettersCol(uid).add(
      GrowthLetterModel(
        uid: uid,
        planId: planId,
        hobby: user.currentPlan.hobby,
        nickname: user.nickname,
        letter: letterText,
        questCount: quests.length,
        reflectionCount: reflections.length,
        questIds: quests.map((quest) => quest.nodeId).toList(),
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
  }) async {
    final snapshot = await _questsCol(uid, planId)
        .where(
          'completedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart),
        )
        .orderBy('completedAt', descending: true)
        .get();

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
