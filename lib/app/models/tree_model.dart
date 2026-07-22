import 'package:cloud_firestore/cloud_firestore.dart';

class TreeModel {
  static const int forestSpotCount = 9;
  static const int maturityXp = 800;
  static const List<int> growthThresholds = [0, 100, 300, 500, maturityXp];
  static const List<String> growthStageLabels = [
    'Seed',
    'Sprout',
    'Seedling',
    'Young Tree',
    'Mature Tree',
  ];

  static int stageForXp(int xp) {
    for (var index = growthThresholds.length - 1; index >= 0; index--) {
      if (xp >= growthThresholds[index]) return index;
    }
    return 0;
  }

  final String id;
  final String treeName;
  final String categoryId;
  final String planId;
  final int xpRequired;
  final int groveIndex;
  final int treeIndex;
  final int questsCompleted;
  final int learningMinutes;
  final DateTime? createdAt;
  final DateTime? grownAt;

  const TreeModel({
    this.id = '',
    required this.treeName,
    required this.categoryId,
    this.planId = '',
    this.xpRequired = 0,
    this.groveIndex = 1,
    this.treeIndex = 0,
    this.questsCompleted = 0,
    this.learningMinutes = 0,
    this.createdAt,
    this.grownAt,
  });

  factory TreeModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    return TreeModel(
      id: docId ?? (json['id'] as String? ?? ''),
      treeName: json['treeName'] as String? ?? (json['name'] as String? ?? ''),
      categoryId: json['categoryId'] as String? ?? '',
      planId: json['planId'] as String? ?? '',
      xpRequired: (json['xpRequired'] as num?)?.toInt() ?? 0,
      groveIndex: _readGroveIndex(json['groveIndex']),
      treeIndex: (json['treeIndex'] as num?)?.toInt() ?? 0,
      questsCompleted: (json['questsCompleted'] as num?)?.toInt() ?? 0,
      learningMinutes: (json['learningMinutes'] as num?)?.toInt() ?? 0,
      createdAt: _readDateTime(json['createdAt']),
      grownAt: _readDateTime(json['grownAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'treeName': treeName,
      'categoryId': categoryId,
      'planId': planId,
      'xpRequired': xpRequired,
      'groveIndex': groveIndex,
      'treeIndex': treeIndex,
      'questsCompleted': questsCompleted,
      'learningMinutes': learningMinutes,
      'createdAt': createdAt,
      'grownAt': grownAt,
    };
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  static int _readGroveIndex(dynamic value) {
    final index = (value as num?)?.toInt() ?? 1;
    return index < 1 ? 1 : index;
  }

  TreeModel copyWith({
    String? id,
    String? treeName,
    String? categoryId,
    String? planId,
    int? xpRequired,
    int? groveIndex,
    int? treeIndex,
    int? questsCompleted,
    int? learningMinutes,
    DateTime? createdAt,
    DateTime? grownAt,
  }) {
    return TreeModel(
      id: id ?? this.id,
      treeName: treeName ?? this.treeName,
      categoryId: categoryId ?? this.categoryId,
      planId: planId ?? this.planId,
      xpRequired: xpRequired ?? this.xpRequired,
      groveIndex: groveIndex ?? this.groveIndex,
      treeIndex: treeIndex ?? this.treeIndex,
      questsCompleted: questsCompleted ?? this.questsCompleted,
      learningMinutes: learningMinutes ?? this.learningMinutes,
      createdAt: createdAt ?? this.createdAt,
      grownAt: grownAt ?? this.grownAt,
    );
  }
}
