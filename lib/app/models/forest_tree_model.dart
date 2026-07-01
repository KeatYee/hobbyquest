class ForestTreeModel {
  final String name;
  final String categoryId;
  final String categoryName;
  final DateTime? savedAt;
  final int xpAtSave;

  ForestTreeModel({
    required this.name,
    required this.categoryId,
    required this.categoryName,
    this.savedAt,
    this.xpAtSave = 8000,
  });

  factory ForestTreeModel.fromJson(Map<String, dynamic> json) {
    return ForestTreeModel(
      name: json['name'] as String? ?? 'My Tree',
      categoryId: json['categoryId'] as String? ?? '',
      categoryName: json['categoryName'] as String? ?? '',
      savedAt: _readDateTime(json['savedAt']),
      xpAtSave: json['xpAtSave'] as int? ?? 8000,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'categoryId': categoryId,
      'categoryName': categoryName,
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
