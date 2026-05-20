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

  // Timestamps
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastRerollDate;
  final DateTime? lastStreakDate; // Track when the last streak completion was recorded

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
    this.createdAt,
    this.updatedAt,
    this.lastRerollDate,
    this.lastStreakDate,
  });

  /// Convert Firestore document to UserModel
  factory UserModel.fromJson(Map<String, dynamic> json, String docId) {
    final totalXp = json['totalXP'] as int? ?? _legacyTotalXp(json);
    final currentPlanJson = json['currentPlan'];
    final currentPlan = currentPlanJson is Map
      ? QuestPlanModel.fromJson(Map<String, dynamic>.from(currentPlanJson as Map))
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
      createdAt: _readDateTime(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? _readDateTime(json['updatedAt'])
          : null,
      lastRerollDate: _readDateTime(json['lastRerollDate']),
      lastStreakDate: _readDateTime(json['lastStreakDate']),
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
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastRerollDate': lastRerollDate,
      'lastStreakDate': lastStreakDate,
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
    QuestPlanModel? currentPlan,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastRerollDate,
    DateTime? lastStreakDate,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastRerollDate: lastRerollDate ?? this.lastRerollDate,
      lastStreakDate: lastStreakDate ?? this.lastStreakDate,
    );
  }

  int get level => (totalXP ~/ 1000) + 1;

  int get currentXp => totalXP % 1000;

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
      hobbyName: json['hobbyName'] as String? ?? 'Learning',
      skillLevel: json['skillLevel'] as String? ?? 'Novice',
      customGoal: json['customGoal'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '15 mins/day',
      progress: json['progress'] as int? ?? 0,
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
    return 'UserModel(id: $id, nickname: $nickname, level: $level, hobby: ${currentPlan.hobbyName})';
  }
}
