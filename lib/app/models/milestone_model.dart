class MilestoneModel {
  final String title;
  final bool completed;

  const MilestoneModel({
    required this.title,
    required this.completed,
  });

  factory MilestoneModel.fromJson(Map<String, dynamic> json) {
    return MilestoneModel(
      title: json['title'] as String? ?? (json['task'] as String? ?? ''),
      completed: json['completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'task': title,
      'completed': completed,
    };
  }

  MilestoneModel copyWith({
    String? title,
    bool? completed,
  }) {
    return MilestoneModel(
      title: title ?? this.title,
      completed: completed ?? this.completed,
    );
  }

  String get task => title;
}