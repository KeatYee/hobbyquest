import 'milestone_model.dart';
import 'quest_model.dart';

class QuestPlanModel {
  final String hobbyName;
  final String skillLevel;
  final String customGoal;
  final String frequency;
  final int progress;
  final List<MilestoneModel> milestones;
  final List<QuestModel> quests;

  const QuestPlanModel({
    required this.hobbyName,
    required this.skillLevel,
    required this.customGoal,
    required this.frequency,
    required this.progress,
    required this.milestones,
    required this.quests,
  });

  String get targetBoss => customGoal;


  String get dailyCommitment => frequency;

  factory QuestPlanModel.fromJson(Map<String, dynamic> json) {
    final milestonesDynamic = json['milestones'] as List<dynamic>? ?? const <dynamic>[];
    final questsDynamic = json['quests'] as List<dynamic>? ?? const <dynamic>[];

    return QuestPlanModel(
      hobbyName: json['hobbyName'] as String? ?? '',
      skillLevel: json['skillLevel'] as String? ?? '',
      customGoal: json['customGoal'] as String? ?? (json['targetBoss'] as String? ?? ''),
      frequency: json['frequency'] as String? ?? (json['dailyCommitment'] as String? ?? ''),
      progress: json['progress'] as int? ?? 0,
      milestones: milestonesDynamic
          .map((item) => item is Map<String, dynamic>
              ? MilestoneModel.fromJson(item)
              : MilestoneModel(task: item.toString(), completed: false))
          .toList(),
        quests: questsDynamic
          .map((item) => item is Map<String, dynamic>
            ? QuestModel.fromJson(item)
            : QuestModel(
              id: item.toString(),
              title: item.toString(),
              desc: '',
              type: 'practice',
            ))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hobbyName': hobbyName,
      'skillLevel': skillLevel,
      'customGoal': customGoal,
      'frequency': frequency,
      'progress': progress,
      'targetBoss': customGoal,
      'dailyCommitment': frequency,
      'milestones': milestones.map((milestone) => milestone.toJson()).toList(),
      'quests': quests.map((quest) => quest.toJson()).toList(),
    };
  }

  QuestPlanModel copyWith({
    String? hobbyName,
    String? skillLevel,
    String? customGoal,
    String? frequency,
    int? progress,
    List<MilestoneModel>? milestones,
    List<QuestModel>? quests,
  }) {
    return QuestPlanModel(
      hobbyName: hobbyName ?? this.hobbyName,
      skillLevel: skillLevel ?? this.skillLevel,
      customGoal: customGoal ?? this.customGoal,
      frequency: frequency ?? this.frequency,
      progress: progress ?? this.progress,
      milestones: milestones ?? this.milestones,
      quests: quests ?? this.quests,
    );
  }
}