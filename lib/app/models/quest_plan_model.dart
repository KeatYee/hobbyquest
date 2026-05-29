import 'milestone_model.dart';
import 'quest_node_model.dart';

class QuestPlanModel {
  final String hobby;
  final String level;
  final String goal;
  final String frequency;
  final int progress;
  final int currentMilestoneIndex;
  final List<MilestoneModel> milestones;
  final List<QuestNodeModel> quests;

  const QuestPlanModel({
    required this.hobby,
    required this.level,
    required this.goal,
    required this.frequency,
    required this.progress,
    this.currentMilestoneIndex = 0,
    required this.milestones,
    required this.quests,
  });

  factory QuestPlanModel.fromJson(Map<String, dynamic> json) {
    final milestonesDynamic = json['milestones'] as List<dynamic>? ?? const <dynamic>[];
    final questsDynamic = json['quests'] as List<dynamic>? ?? const <dynamic>[];

    return QuestPlanModel(
      hobby: json['hobby'] as String? ?? (json['hobbyName'] as String? ?? ''),
      level: json['level'] as String? ?? (json['skillLevel'] as String? ?? ''),
      goal: json['goal'] as String? ?? (json['customGoal'] as String? ?? (json['targetBoss'] as String? ?? '')),
      frequency: json['frequency'] as String? ?? (json['dailyCommitment'] as String? ?? ''),
      progress: json['progress'] as int? ?? 0,
      currentMilestoneIndex: json['currentMilestoneIndex'] as int? ?? (json['progress'] as int? ?? 0),
      milestones: milestonesDynamic
          .map((item) => item is Map<String, dynamic>
              ? MilestoneModel.fromJson(item)
              : MilestoneModel(title: item.toString(), completed: false))
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

  Map<String, dynamic> toJson() {
    return {
      'hobby': hobby,
      'level': level,
      'goal': goal,
      'frequency': frequency,
      'progress': progress,
      'currentMilestoneIndex': currentMilestoneIndex,
      'milestones': milestones.map((milestone) => milestone.toJson()).toList(),
      'quests': quests.map((quest) => quest.toJson()).toList(),
    };
  }

  QuestPlanModel copyWith({
    String? hobby,
    String? level,
    String? goal,
    String? frequency,
    int? progress,
    int? currentMilestoneIndex,
    List<MilestoneModel>? milestones,
    List<QuestNodeModel>? quests,
  }) {
    final resolvedMilestoneIndex = currentMilestoneIndex ?? this.currentMilestoneIndex;

    return QuestPlanModel(
      hobby: hobby ?? this.hobby,
      level: level ?? this.level,
      goal: goal ?? this.goal,
      frequency: frequency ?? this.frequency,
      progress: progress ?? resolvedMilestoneIndex,
      currentMilestoneIndex: resolvedMilestoneIndex,
      milestones: milestones ?? this.milestones,
      quests: quests ?? this.quests,
    );
  }
}