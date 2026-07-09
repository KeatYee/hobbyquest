class GoalHistoryModel {
  final String id;
  final String hobby;
  final String level;
  final String goal;
  final String learningPace;
  final String category;
  final DateTime? createdAt;

  const GoalHistoryModel({
    this.id = '',
    required this.hobby,
    required this.level,
    required this.goal,
    required this.learningPace,
    required this.category,
    this.createdAt,
  });

  factory GoalHistoryModel.fromJson(Map<String, dynamic> json, String docId) {
    return GoalHistoryModel(
      id: docId,
      hobby: json['hobby'] as String? ?? '',
      level: json['level'] as String? ?? '',
      goal: json['goal'] as String? ?? '',
      learningPace:
          json['learningPace'] as String? ??
          (json['frequency'] as String? ?? 'Steady Learner'),
      category: json['category'] as String? ?? '',
      createdAt: _readDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hobby': hobby,
      'level': level,
      'goal': goal,
      'learningPace': learningPace,
      'category': category,
      'createdAt': createdAt,
    };
  }

  GoalHistoryModel copyWith({
    String? id,
    String? hobby,
    String? level,
    String? goal,
    String? learningPace,
    String? category,
    DateTime? createdAt,
  }) {
    return GoalHistoryModel(
      id: id ?? this.id,
      hobby: hobby ?? this.hobby,
      level: level ?? this.level,
      goal: goal ?? this.goal,
      learningPace: learningPace ?? this.learningPace,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
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

  @override
  String toString() =>
      'GoalHistoryModel(id: $id, goal: $goal, hobby: $hobby)';
}
