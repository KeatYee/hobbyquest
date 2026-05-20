class QuestModel {
  final String id;
  final String title;
  final String desc;
  final int xp;
  final String type;
  final bool isPriority;
  final bool isCompleted;
  final String reflectionNote;
  final DateTime? completedAt;
  final String? imageUrl;
  final String? aiFeedback;

  const QuestModel({
    required this.id,
    required this.title,
    required this.desc,
    this.xp = 100,
    required this.type,
    this.isPriority = false,
    this.isCompleted = false,
    this.reflectionNote = '',
    this.completedAt,
    this.imageUrl,
    this.aiFeedback,
  });

  factory QuestModel.fromJson(Map<String, dynamic> json) {
    return QuestModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      desc: json['desc'] as String? ?? '',
      xp: json['xp'] as int? ?? 100,
      type: json['type'] as String? ?? 'practice',
      isPriority: json['isPriority'] as bool? ?? false,
      isCompleted: json['isCompleted'] as bool? ?? false,
      reflectionNote: json['reflectionNote'] as String? ?? '',
      completedAt: _readDateTime(json['completedAt']),
      imageUrl: json['imageUrl'] as String?,
      aiFeedback: json['aiFeedback'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'desc': desc,
      'xp': xp,
      'type': type,
      'isPriority': isPriority,
      'isCompleted': isCompleted,
      'reflectionNote': reflectionNote,
      'completedAt': completedAt,
      'imageUrl': imageUrl,
      'aiFeedback': aiFeedback,
    };
  }

  QuestModel copyWith({
    String? id,
    String? title,
    String? desc,
    int? xp,
    String? type,
    bool? isPriority,
    bool? isCompleted,
    String? reflectionNote,
    DateTime? completedAt,
    String? imageUrl,
    String? aiFeedback,
  }) {
    return QuestModel(
      id: id ?? this.id,
      title: title ?? this.title,
      desc: desc ?? this.desc,
      xp: xp ?? this.xp,
      type: type ?? this.type,
      isPriority: isPriority ?? this.isPriority,
      isCompleted: isCompleted ?? this.isCompleted,
      reflectionNote: reflectionNote ?? this.reflectionNote,
      completedAt: completedAt ?? this.completedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      aiFeedback: aiFeedback ?? this.aiFeedback,
    );
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    try {
      return (value as dynamic).toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }
}