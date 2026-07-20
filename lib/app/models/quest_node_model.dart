class QuestNodeModel {
  final String nodeId;
  final String title;
  final String desc;
  final List<String> steps;
  final int xpReward;
  final String type;
  final int durationMinutes;
  final List<String> dependsOn;
  final bool isCompleted;
  final bool isActive;
  final String reflectionNote;
  final DateTime? completedAt;
  final String? imageUrl;
  final String? greeting;
  final String? observation;
  final String? tip;
  final String? youtubeSearchQuery;
  final int? awardedXP;

  const QuestNodeModel({
    required this.nodeId,
    required this.title,
    required this.desc,
    required this.steps,
    this.xpReward = 100,
    required this.type,
    required this.durationMinutes,
    required this.dependsOn,
    this.isCompleted = false,
    this.isActive = false,
    this.reflectionNote = '',
    this.completedAt,
    this.imageUrl,
    this.greeting,
    this.observation,
    this.tip,
    this.youtubeSearchQuery,
    this.awardedXP,
  });

  factory QuestNodeModel.fromJson(Map<String, dynamic> json) {
    final parsedNodeId = (json['node_id'] as String?) ?? (json['id'] as String?) ?? '';

    List<String> parseDepends(dynamic raw) {
      if (raw == null) {
        return <String>[];
      }
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return <String>[];
    }

    List<String> parseSteps(dynamic raw) {
      if (raw == null) {
        return <String>[];
      }
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return <String>[];
    }

    return QuestNodeModel(
      nodeId: parsedNodeId,
      title: json['title'] as String? ?? '',
      desc: json['desc'] as String? ?? '',
      steps: parseSteps(json['steps']),
      xpReward: (json['xp_reward'] as int?) ?? (json['xp'] as int?) ?? 100,
      type: json['type'] as String? ?? 'practice',
      durationMinutes:
          (json['duration_minutes'] as int?) ??
          (json['durationMinutes'] as int?) ??
          15,
      dependsOn: parseDepends(json['depends_on'] ?? json['dependsOn']),
      isCompleted: json['isCompleted'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? false,
      reflectionNote: json['reflectionNote'] as String? ?? '',
      completedAt: _readDateTime(json['completedAt']),
      imageUrl: json['imageUrl'] as String?,
      greeting: json['greeting'] as String?,
      observation: json['observation'] as String?,
      tip: json['tip'] as String?,
      youtubeSearchQuery:
          json['youtube_search_query'] as String? ?? json['youtubeSearchQuery'] as String?,
      awardedXP: (json['awardedXP'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'node_id': nodeId,
      'title': title,
      'desc': desc,
      'steps': steps,
      'xp_reward': xpReward,
      'type': type,
      'duration_minutes': durationMinutes,
      'depends_on': dependsOn,
      'isCompleted': isCompleted,
      'isActive': isActive,
      'reflectionNote': reflectionNote,
      'completedAt': completedAt,
      'imageUrl': imageUrl,
      'greeting': greeting,
      'observation': observation,
      'tip': tip,
      'youtube_search_query': youtubeSearchQuery,
      'awardedXP': awardedXP,
    };
  }

  QuestNodeModel copyWith({
    String? nodeId,
    String? title,
    String? desc,
    List<String>? steps,
    int? xpReward,
    String? type,
    int? durationMinutes,
    List<String>? dependsOn,
    bool? isCompleted,
    bool? isActive,
    String? reflectionNote,
    DateTime? completedAt,
    String? imageUrl,
    String? greeting,
    String? observation,
    String? tip,
    String? youtubeSearchQuery,
    int? awardedXP,
  }) {
    return QuestNodeModel(
      nodeId: nodeId ?? this.nodeId,
      title: title ?? this.title,
      desc: desc ?? this.desc,
      steps: steps ?? this.steps,
      xpReward: xpReward ?? this.xpReward,
      type: type ?? this.type,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      dependsOn: dependsOn ?? this.dependsOn,
      isCompleted: isCompleted ?? this.isCompleted,
      isActive: isActive ?? this.isActive,
      reflectionNote: reflectionNote ?? this.reflectionNote,
      completedAt: completedAt ?? this.completedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      greeting: greeting ?? this.greeting,
      observation: observation ?? this.observation,
      tip: tip ?? this.tip,
      youtubeSearchQuery: youtubeSearchQuery ?? this.youtubeSearchQuery,
      awardedXP: awardedXP ?? this.awardedXP,
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
