import 'milestone_model.dart';
import 'quest_node_model.dart';

class QuestPlanModel {
  final String id;
  final String hobby;
  final String level;
  final String goal;
  final String learningPace;
  final int progress;
  final int currentMilestoneIndex;
  final bool isActive;
  final List<MilestoneModel> milestones;
  final List<QuestNodeModel> quests;

  const QuestPlanModel({
    this.id = '',
    required this.hobby,
    required this.level,
    required this.goal,
    required this.learningPace,
    required this.progress,
    this.currentMilestoneIndex = 0,
    this.isActive = true,
    required this.milestones,
    required this.quests,
  });

  factory QuestPlanModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    final milestonesDynamic =
        json['milestones'] as List<dynamic>? ?? const <dynamic>[];
    final questsDynamic = json['quests'] as List<dynamic>? ?? const <dynamic>[];

    return QuestPlanModel(
      id: docId ?? (json['id'] as String? ?? ''),
      hobby: json['hobby'] as String? ?? (json['hobbyName'] as String? ?? ''),
      level: json['level'] as String? ?? (json['skillLevel'] as String? ?? ''),
      goal: json['goal'] as String? ??
          (json['customGoal'] as String? ??
              (json['targetBoss'] as String? ?? '')),
      learningPace: json['learningPace'] as String? ??
          (json['frequency'] as String? ??
              (json['dailyCommitment'] as String? ?? 'Steady Learner')),
      progress: json['progress'] as int? ?? 0,
      currentMilestoneIndex: json['currentMilestoneIndex'] as int? ??
          (json['progress'] as int? ?? 0),
      isActive: json['isActive'] as bool? ?? true,
      milestones: milestonesDynamic
          .map((item) => item is Map<String, dynamic>
              ? MilestoneModel.fromJson(item)
              : MilestoneModel(id: '', title: item.toString(), completed: false))
          .toList(),
      quests: questsDynamic
          .map((item) => item is Map<String, dynamic>
              ? QuestNodeModel.fromJson(item)
              : QuestNodeModel(
                  nodeId: item.toString(),
                  title: item.toString(),
                  desc: '',
                  steps: const [],
                  xpReward: 100,
                  type: 'practice',
                  durationMinutes: 15,
                  dependsOn: const [],
                ))
          .toList(),
    );
  }

  /// Serializes plan metadata ONLY (milestones/quests go to subcollections).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hobby': hobby,
      'level': level,
      'goal': goal,
      'learningPace': learningPace,
      'progress': progress,
      'currentMilestoneIndex': currentMilestoneIndex,
      'isActive': isActive,
    };
  }

  QuestPlanModel copyWith({
    String? id,
    String? hobby,
    String? level,
    String? goal,
    String? learningPace,
    int? progress,
    int? currentMilestoneIndex,
    bool? isActive,
    List<MilestoneModel>? milestones,
    List<QuestNodeModel>? quests,
  }) {
    final resolvedMilestoneIndex =
        currentMilestoneIndex ?? this.currentMilestoneIndex;

    return QuestPlanModel(
      id: id ?? this.id,
      hobby: hobby ?? this.hobby,
      level: level ?? this.level,
      goal: goal ?? this.goal,
      learningPace: learningPace ?? this.learningPace,
      progress: progress ?? resolvedMilestoneIndex,
      currentMilestoneIndex: resolvedMilestoneIndex,
      isActive: isActive ?? this.isActive,
      milestones: milestones ?? this.milestones,
      quests: quests ?? this.quests,
    );
  }
}
