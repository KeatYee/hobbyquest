class ForestTreeModel {
  final String categoryId;
  final DateTime? savedAt;
  final int xpAtSave;

  ForestTreeModel({
    required this.categoryId,
    this.savedAt,
    this.xpAtSave = 8000,
  });

  factory ForestTreeModel.fromJson(Map<String, dynamic> json) {
    return ForestTreeModel(
      categoryId: json['categoryId'] as String? ?? '',
      savedAt: _readDateTime(json['savedAt']),
      xpAtSave: json['xpAtSave'] as int? ?? 8000,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoryId': categoryId,
      'savedAt': savedAt,
      'xpAtSave': xpAtSave,
    };
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      return (value as dynamic).toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }
}
