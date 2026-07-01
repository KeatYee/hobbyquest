import 'package:cloud_firestore/cloud_firestore.dart';

class TreeModel {
  final String id;
  final String treeName;
  final String goalName;
  final String categoryId;
  final String hobbyType;
  final DateTime? plantedDate;
  final DateTime? completedDate;
  final int totalQuestCompleted;
  final int totalxp;
  final int learningTimeMinutes;

  const TreeModel({
    this.id = '',
    required this.treeName,
    required this.goalName,
    required this.categoryId,
    required this.hobbyType,
    this.plantedDate,
    this.completedDate,
    this.totalQuestCompleted = 0,
    this.totalxp = 0,
    this.learningTimeMinutes = 0,
  });

  factory TreeModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    return TreeModel(
      id: docId ?? (json['id'] as String? ?? ''),
      treeName: json['treeName'] as String? ?? (json['name'] as String? ?? ''),
      goalName: json['goalName'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      hobbyType: json['hobbyType'] as String? ?? '',
      plantedDate: _readDateTime(json['plantedDate']),
      completedDate: _readDateTime(json['completedDate']),
      totalQuestCompleted: json['totalQuestCompleted'] as int? ?? 0,
      totalxp: json['totalxp'] as int? ?? 0,
      learningTimeMinutes: json['learningTimeMinutes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'treeName': treeName,
      'goalName': goalName,
      'categoryId': categoryId,
      'hobbyType': hobbyType,
      'plantedDate': plantedDate,
      'completedDate': completedDate,
      'totalQuestCompleted': totalQuestCompleted,
      'totalxp': totalxp,
      'learningTimeMinutes': learningTimeMinutes,
    };
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  TreeModel copyWith({
    String? id,
    String? treeName,
    String? goalName,
    String? categoryId,
    String? hobbyType,
    DateTime? plantedDate,
    DateTime? completedDate,
    int? totalQuestCompleted,
    int? totalxp,
    int? learningTimeMinutes,
  }) {
    return TreeModel(
      id: id ?? this.id,
      treeName: treeName ?? this.treeName,
      goalName: goalName ?? this.goalName,
      categoryId: categoryId ?? this.categoryId,
      hobbyType: hobbyType ?? this.hobbyType,
      plantedDate: plantedDate ?? this.plantedDate,
      completedDate: completedDate ?? this.completedDate,
      totalQuestCompleted: totalQuestCompleted ?? this.totalQuestCompleted,
      totalxp: totalxp ?? this.totalxp,
      learningTimeMinutes: learningTimeMinutes ?? this.learningTimeMinutes,
    );
  }
}
