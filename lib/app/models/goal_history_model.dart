class GoalHistoryModel {
  final String id;
  final String hobby;
  final String level;
  final String goal;
  final String learningPace;
  final String category;
  final String? planId;
  final String? status;
  final DateTime? createdAt;
  final DateTime? completedAt;

  const GoalHistoryModel({
    this.id = '',
    required this.hobby,
    required this.level,
    required this.goal,
    required this.learningPace,
    required this.category,
    this.planId = '',
    this.status = 'active',
    this.createdAt,
    this.completedAt,
  });

  factory GoalHistoryModel.fromJson(Map<String, dynamic> json, String docId) {
    final learningPace = _readString(json['learningPace']);
    final frequency = _readString(json['frequency']);
    final status = _readString(json['status']);

    return GoalHistoryModel(
      id: docId,
      hobby: _readString(json['hobby']),
      level: _readString(json['level']),
      goal: _readString(json['goal']),
      learningPace: learningPace.isNotEmpty
          ? learningPace
          : (frequency.isNotEmpty ? frequency : 'Steady Learner'),
      category: _readString(json['category']),
      planId: _readString(json['planId']),
      status: status.isNotEmpty
          ? status
          : (json['completedAt'] == null ? 'active' : 'completed'),
      createdAt: _readDateTime(json['createdAt']),
      completedAt: _readDateTime(json['completedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'hobby': hobby,
      'level': level,
      'goal': goal,
      'learningPace': learningPace,
      'category': category,
      'planId': planId ?? '',
      'status': status ?? 'active',
      if (createdAt != null) 'createdAt': createdAt,
      if (completedAt != null) 'completedAt': completedAt,
    };
  }

  GoalHistoryModel copyWith({
    String? id,
    String? hobby,
    String? level,
    String? goal,
    String? learningPace,
    String? category,
    String? planId,
    String? status,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return GoalHistoryModel(
      id: id ?? this.id,
      hobby: hobby ?? this.hobby,
      level: level ?? this.level,
      goal: goal ?? this.goal,
      learningPace: learningPace ?? this.learningPace,
      category: category ?? this.category,
      planId: planId ?? this.planId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
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

  static String _readString(dynamic value) => value?.toString().trim() ?? '';

  @override
  String toString() =>
      'GoalHistoryModel(id: $id, goal: $goal, hobby: $hobby)';

  bool get isCompleted =>
      status?.trim().toLowerCase() == 'completed' || completedAt != null;
}
