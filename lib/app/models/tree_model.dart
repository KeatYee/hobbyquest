import 'package:cloud_firestore/cloud_firestore.dart';

class TreeModel {
  final String id;
  final String treeName;
  final String categoryId;
  final int xpRequired;
  final int treeIndex;
  final DateTime? createdAt;
  final DateTime? grownAt;

  const TreeModel({
    this.id = '',
    required this.treeName,
    required this.categoryId,
    this.xpRequired = 0,
    this.treeIndex = 0,
    this.createdAt,
    this.grownAt,
  });

  factory TreeModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    return TreeModel(
      id: docId ?? (json['id'] as String? ?? ''),
      treeName: json['treeName'] as String? ?? (json['name'] as String? ?? ''),
      categoryId: json['categoryId'] as String? ?? '',
      xpRequired: json['xpRequired'] as int? ?? 0,
      treeIndex: json['treeIndex'] as int? ?? 0,
      createdAt: _readDateTime(json['createdAt']),
      grownAt: _readDateTime(json['grownAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'treeName': treeName,
      'categoryId': categoryId,
      'xpRequired': xpRequired,
      'treeIndex': treeIndex,
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

  TreeModel copyWith({
    String? id,
    String? treeName,
    String? categoryId,
    int? xpRequired,
    int? treeIndex,
    DateTime? createdAt,
    DateTime? grownAt,
  }) {
    return TreeModel(
      id: id ?? this.id,
      treeName: treeName ?? this.treeName,
      categoryId: categoryId ?? this.categoryId,
      xpRequired: xpRequired ?? this.xpRequired,
      treeIndex: treeIndex ?? this.treeIndex,
      createdAt: createdAt ?? this.createdAt,
      grownAt: grownAt ?? this.grownAt,
    );
  }
}
