class MilestoneModel {
  final String id;
  final String title;
  final bool completed;
  final int order;

  const MilestoneModel({
    this.id = '',
    required this.title,
    required this.completed,
    this.order = 0,
  });

  factory MilestoneModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    return MilestoneModel(
      id: docId ?? (json['id'] as String? ?? ''),
      title: json['title'] as String? ?? (json['task'] as String? ?? ''),
      completed: json['completed'] as bool? ?? false,
      order: json['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'task': title,
      'completed': completed,
      'order': order,
    };
  }

  MilestoneModel copyWith({
    String? id,
    String? title,
    bool? completed,
    int? order,
  }) {
    return MilestoneModel(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      order: order ?? this.order,
    );
  }

  String get task => title;
}