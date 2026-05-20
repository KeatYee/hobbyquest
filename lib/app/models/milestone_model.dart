class MilestoneModel {
  final String task;
  final bool completed;

  const MilestoneModel({
    required this.task,
    required this.completed,
  });

  factory MilestoneModel.fromJson(Map<String, dynamic> json) {
    return MilestoneModel(
      task: json['task'] as String? ?? '',
      completed: json['completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task': task,
      'completed': completed,
    };
  }

  MilestoneModel copyWith({
    String? task,
    bool? completed,
  }) {
    return MilestoneModel(
      task: task ?? this.task,
      completed: completed ?? this.completed,
    );
  }
}