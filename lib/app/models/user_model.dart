import 'quest_plan_model.dart';

class UserModel {
  final String id; // Firestore document ID
  final String nickname;
  final String birthDate;
  final String gender;
  final String avatarSvg;
  final bool isOnboardingComplete;

  // Flat progression source of truth
  final int totalXP;
  final int currentStreak; // Consecutive days with at least one completed quest
  final int dailyQuestCompletionCount;

  // Per-category XP (tree progression)
  final Map<String, int> categoryXp;

  // Tutorial flags
  final bool mapTutorialDone;

  // Timestamps
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastRerollDate;
  final DateTime? lastStreakDate; // Track when the last streak completion was recorded
  final DateTime? lastQuestCompletionDate;

  final QuestPlanModel currentPlan;

  UserModel({
    required this.id,
    required this.nickname,
    required this.birthDate,
    required this.gender,
    required this.avatarSvg,
    required this.isOnboardingComplete,
    required this.totalXP,
    required this.currentPlan,
    this.currentStreak = 0,
    this.dailyQuestCompletionCount = 0,
    this.categoryXp = const {},
    this.mapTutorialDone = false,
    this.createdAt,
    this.updatedAt,
    this.lastRerollDate,
    this.lastStreakDate,
    this.lastQuestCompletionDate,
  });

  /// Convert Firestore document to UserModel
  factory UserModel.fromJson(Map<String, dynamic> json, String docId) {
    final totalXp = json['totalXP'] as int? ?? _legacyTotalXp(json);
    final currentPlanJson = json['currentPlan'];
    final currentPlan = currentPlanJson is Map
      ? QuestPlanModel.fromJson(Map<String, dynamic>.from(currentPlanJson))
        : _legacyCurrentPlan(json);

    return UserModel(
      id: docId,
      nickname: json['nickname'] as String? ?? 'Hero',
      birthDate: json['birthDate'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      avatarSvg: json['avatarSvg'] as String? ?? '',
      isOnboardingComplete: json['isOnboardingComplete'] as bool? ?? false,
      totalXP: totalXp,
      currentPlan: currentPlan,
      currentStreak: json['currentStreak'] as int? ?? 0,
      dailyQuestCompletionCount: json['dailyQuestCompletionCount'] as int? ?? 0,
      categoryXp: _readCategoryXp(json),
      mapTutorialDone: json['mapTutorialDone'] as bool? ?? false,
      createdAt: _readDateTime(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? _readDateTime(json['updatedAt'])
          : null,
      lastRerollDate: _readDateTime(json['lastRerollDate']),
      lastStreakDate: _readDateTime(json['lastStreakDate']),
      lastQuestCompletionDate: _readDateTime(json['lastQuestCompletionDate']),
    );
  }

  /// Convert UserModel to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'birthDate': birthDate,
      'gender': gender,
      'avatarSvg': avatarSvg,
      'isOnboardingComplete': isOnboardingComplete,
      'totalXP': totalXP,
      'currentStreak': currentStreak,
      'dailyQuestCompletionCount': dailyQuestCompletionCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastRerollDate': lastRerollDate,
      'lastStreakDate': lastStreakDate,
      'lastQuestCompletionDate': lastQuestCompletionDate,
      'currentPlan': currentPlan.toJson(),
    };
  }

  /// Create a copy with modified fields
  UserModel copyWith({
    String? id,
    String? nickname,
    String? birthDate,
    String? gender,
    String? avatarSvg,
    bool? isOnboardingComplete,
    int? totalXP,
    int? currentStreak,
    int? dailyQuestCompletionCount,
    Map<String, int>? categoryXp,
    bool? mapTutorialDone,
    QuestPlanModel? currentPlan,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastRerollDate,
    DateTime? lastStreakDate,
    DateTime? lastQuestCompletionDate,
  }) {
    return UserModel(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      avatarSvg: avatarSvg ?? this.avatarSvg,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
      totalXP: totalXP ?? this.totalXP,
      currentPlan: currentPlan ?? this.currentPlan,
      currentStreak: currentStreak ?? this.currentStreak,
      dailyQuestCompletionCount: dailyQuestCompletionCount ?? this.dailyQuestCompletionCount,
      categoryXp: categoryXp ?? this.categoryXp,
      mapTutorialDone: mapTutorialDone ?? this.mapTutorialDone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastRerollDate: lastRerollDate ?? this.lastRerollDate,
      lastStreakDate: lastStreakDate ?? this.lastStreakDate,
      lastQuestCompletionDate: lastQuestCompletionDate ?? this.lastQuestCompletionDate,
    );
  }

  int get level => (totalXP ~/ 1000) + 1;

  int get currentXp => totalXP % 1000;

  /// Parses per-category XP from Firestore data.
  static Map<String, int> _readCategoryXp(Map<String, dynamic> json) {
    final raw = json['categoryXp'];
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    }
    return const {};
  }

  static int _legacyTotalXp(Map<String, dynamic> json) {
    final legacyLevel = json['level'] as int? ?? 1;
    final legacyCurrentXp = json['currentXp'] as int? ?? 0;
    if (legacyLevel <= 1) {
      return legacyCurrentXp;
    }
    return ((legacyLevel - 1) * 1000) + legacyCurrentXp;
  }

  static QuestPlanModel _legacyCurrentPlan(Map<String, dynamic> json) {
    return QuestPlanModel(
      hobby: json['hobby'] as String? ?? (json['hobbyName'] as String? ?? 'Learning'),
      level: json['level'] as String? ?? (json['skillLevel'] as String? ?? 'Novice'),
      goal: json['goal'] as String? ?? (json['customGoal'] as String? ?? ''),
      frequency: json['frequency'] as String? ?? '15 mins/day',
      progress: json['progress'] as int? ?? 0,
      currentMilestoneIndex: json['currentMilestoneIndex'] as int? ?? (json['progress'] as int? ?? 0),
      milestones: const [],
      quests: const [],
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

  @override
  String toString() {
    return 'UserModel(id: $id, nickname: $nickname, level: $level, hobby: ${currentPlan.hobby})';
  }
}
