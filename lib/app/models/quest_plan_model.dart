class QuestPlanModel {
  final String targetBoss;    // "The Campfire Hero"
  final String duration;      // "4 Weeks"
  final String dailyCommitment; // "15 mins/day"
  final List<String> milestones; // ["Learn G Major", "Master Transitions", "Final Performance"]
  
  QuestPlanModel({
    required this.targetBoss,
    required this.duration,
    required this.dailyCommitment,
    required this.milestones,
  });
}