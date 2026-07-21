import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/goal_history_model.dart';

class GoalHistoryService {

  static String _historyDocPath(String uid, String historyId) =>
      'users/$uid/goalHistory/$historyId';

  static DocumentReference<Map<String, dynamic>> _historyRef(
          String uid, String historyId) =>
      FirebaseFirestore.instance.doc(_historyDocPath(uid, historyId));

  static CollectionReference<Map<String, dynamic>> _historyCol(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('goalHistory');


  /// Saves a new goal history entry. Returns the generated document ID.
  static Future<String> saveGoalHistory(
      String uid, GoalHistoryModel entry, {String? historyId}) async {
    if (historyId != null && historyId.isNotEmpty) {
      final docRef = _historyCol(uid).doc(historyId);
      await docRef.set(entry.toJson(), SetOptions(merge: true));
      return docRef.id;
    }
    final docRef = await _historyCol(uid).add(entry.toJson());
    return docRef.id;
  }

  static Future<void> markGoalCompleted(
    String uid,
    GoalHistoryModel completedEntry,
  ) async {
    final snapshot = await _historyCol(uid).get();
    QueryDocumentSnapshot<Map<String, dynamic>>? matchingDoc;
    final completedPlanId = completedEntry.planId?.trim() ?? '';

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final savedPlanId = data['planId']?.toString().trim() ?? '';
      if (completedPlanId.isNotEmpty && savedPlanId == completedPlanId) {
        matchingDoc = doc;
        break;
      }
      if (savedPlanId.isEmpty &&
          data['goal'] == completedEntry.goal &&
          data['hobby'] == completedEntry.hobby &&
          data['completedAt'] == null) {
        matchingDoc = doc;
      }
    }

    final historyRef = matchingDoc?.reference ??
        _historyCol(uid).doc(
          completedPlanId.isEmpty
              ? _historyCol(uid).doc().id
              : completedPlanId,
        );
    await historyRef.set(completedEntry.toJson(), SetOptions(merge: true));
  }


  /// Loads a single goal history entry by ID.
  static Future<GoalHistoryModel?> loadGoalHistory(
      String uid, String historyId) async {
    final snapshot = await _historyRef(uid, historyId).get();
    if (!snapshot.exists) return null;
    return GoalHistoryModel.fromJson(snapshot.data()!, historyId);
  }

  /// Loads all goal history entries for a user, sorted by createdAt descending.
  static Future<List<GoalHistoryModel>> loadAllGoalHistory(String uid) async {
    final snapshot = await _historyCol(uid).get();
    final entries = snapshot.docs
        .map((doc) => GoalHistoryModel.fromJson(doc.data(), doc.id))
        .toList();
    entries.sort((a, b) {
      final aDate = a.completedAt ?? a.createdAt ?? DateTime(1970);
      final bDate = b.completedAt ?? b.createdAt ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
    return entries;
  }


  /// Deletes a specific goal history entry.
  static Future<void> deleteGoalHistory(
      String uid, String historyId) async {
    await _historyRef(uid, historyId).delete();
  }

  /// Deletes all goal history entries for a user (used during account deletion).
  static Future<void> deleteAllGoalHistory(String uid) async {
    final snapshot = await _historyCol(uid).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    if (snapshot.docs.isNotEmpty) {
      await batch.commit();
    }
  }
}
