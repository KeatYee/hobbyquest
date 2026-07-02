import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/goal_history_model.dart';

class GoalHistoryService {
  // ──────────────────────────────────────────────
  //  Subcollection reference helpers
  // ──────────────────────────────────────────────

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

  // ──────────────────────────────────────────────
  //  Create
  // ──────────────────────────────────────────────

  /// Saves a new goal history entry. Returns the generated document ID.
  static Future<String> saveGoalHistory(
      String uid, GoalHistoryModel entry) async {
    final docRef = await _historyCol(uid).add(entry.toJson());
    return docRef.id;
  }

  // ──────────────────────────────────────────────
  //  Read
  // ──────────────────────────────────────────────

  /// Loads a single goal history entry by ID.
  static Future<GoalHistoryModel?> loadGoalHistory(
      String uid, String historyId) async {
    final snapshot = await _historyRef(uid, historyId).get();
    if (!snapshot.exists) return null;
    return GoalHistoryModel.fromJson(snapshot.data()!, historyId);
  }

  /// Loads all goal history entries for a user, sorted by createdAt descending.
  static Future<List<GoalHistoryModel>> loadAllGoalHistory(String uid) async {
    final snapshot =
        await _historyCol(uid).orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .map((doc) => GoalHistoryModel.fromJson(doc.data(), doc.id))
        .toList();
  }

  // ──────────────────────────────────────────────
  //  Delete
  // ──────────────────────────────────────────────

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
