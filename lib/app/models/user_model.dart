import 'quest_plan_model.dart';

class UserModel {
  final String id;
  final String nickname;
  final String birthDate;
  final String gender;
  final String avatarSvg;
  final bool isOnboardingComplete;

  final int totalXP;
  final int currentStreak;
  final int dailyQuestCompletionCount;

  final Map<String, int> categoryXp;
  final int currentGroveIndex;
  final List<int> completedGroveIndexes;
  final Map<int, List<int>> occupiedTreeSlotsByGrove;

  final bool mapTutorialDone;
  final bool notificationsEnabled;
  final bool profileVisible;
  final bool postStatsVisible;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastRerollDate;
  final DateTime? lastStreakDate;
  final DateTime? lastQuestCompletionDate;

  final String activePlanId;
  final QuestPlanModel currentPlan;

  UserModel({
    required this.id,
    required this.nickname,
    required this.birthDate,
    required this.gender,
    required this.avatarSvg,
    required this.isOnboardingComplete,
    required this.totalXP,
    this.activePlanId = '',
    required this.currentPlan,
    this.currentStreak = 0,
    this.dailyQuestCompletionCount = 0,
    this.categoryXp = const {},
    this.currentGroveIndex = 1,
    this.completedGroveIndexes = const [],
    this.occupiedTreeSlotsByGrove = const {},
    this.mapTutorialDone = false,
    this.notificationsEnabled = true,
    this.profileVisible = true,
    this.postStatsVisible = true,
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

    print('--- DEBUG UserModel.fromJson: parsing doc $docId ---');
    print('--- DEBUG categories: ${json['categoryXp']} ---');
    print('--- DEBUG groveIndex: ${json['currentGroveIndex']} (${json['currentGroveIndex'].runtimeType}) ---');
    print('--- DEBUG completedGroveIndexes: ${json['completedGroveIndexes']} (${json['completedGroveIndexes'].runtimeType}) ---');
    print('--- DEBUG occupiedTreeSlotsByGrove raw: ${json['occupiedTreeSlotsByGrove']} ---');
    if (json['occupiedTreeSlotsByGrove'] is Map) {
      for (final e in (json['occupiedTreeSlotsByGrove'] as Map).entries) {
        print('--- DEBUG   slot entry "${e.key}": ${e.value} (${e.value.runtimeType}) ---');
      }
    }

    Map<int, List<int>> parsedSlots;
    try {
      parsedSlots = _readGroveSlots(json);
      print('--- DEBUG _readGroveSlots OK, result=$parsedSlots ---');
    } catch (e) {
      print('--- DEBUG _readGroveSlots FAILED: $e ---');
      rethrow;
    }

    List<int> parsedIndexes;
    try {
      parsedIndexes = _readGroveIndexes(json['completedGroveIndexes']);
    } catch (e) {
      print('--- DEBUG _readGroveIndexes FAILED: $e ---');
      rethrow;
    }

    return UserModel(
      id: docId,
      nickname: json['nickname'] as String? ?? 'Hero',
      birthDate: json['birthDate'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      avatarSvg: json['avatarSvg'] as String? ?? '',
      isOnboardingComplete: json['isOnboardingComplete'] as bool? ?? false,
      totalXP: totalXp,
      activePlanId: json['activePlanId'] as String? ?? '',
      currentPlan: currentPlan,
      currentStreak: json['currentStreak'] as int? ?? 0,
      dailyQuestCompletionCount: json['dailyQuestCompletionCount'] as int? ?? 0,
      categoryXp: _readCategoryXp(json),
      currentGroveIndex: _readCurrentGroveIndex(json['currentGroveIndex']),
      completedGroveIndexes: parsedIndexes,
      occupiedTreeSlotsByGrove: parsedSlots,
      mapTutorialDone: json['mapTutorialDone'] as bool? ?? false,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      profileVisible: json['profileVisible'] as bool? ?? true,
      postStatsVisible: json['postStatsVisible'] as bool? ?? true,
      createdAt: _readDateTime(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? _readDateTime(json['updatedAt'])
          : null,
      lastRerollDate: _readDateTime(json['lastRerollDate']),
      lastStreakDate: _readDateTime(json['lastStreakDate']),
      lastQuestCompletionDate: _readDateTime(json['lastQuestCompletionDate']),
    );
  }

  /// Convert UserModel to Firestore document (without currentPlan — stored in subcollection).
  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'birthDate': birthDate,
      'gender': gender,
      'avatarSvg': avatarSvg,
      'isOnboardingComplete': isOnboardingComplete,
      'totalXP': totalXP,
      'activePlanId': activePlanId,
      'currentStreak': currentStreak,
      'dailyQuestCompletionCount': dailyQuestCompletionCount,
      'categoryXp': categoryXp,
      'currentGroveIndex': currentGroveIndex,
      'completedGroveIndexes': completedGroveIndexes,
      'occupiedTreeSlotsByGrove': {
        for (final entry in occupiedTreeSlotsByGrove.entries)
          entry.key.toString(): entry.value,
      },
      'mapTutorialDone': mapTutorialDone,
      'notificationsEnabled': notificationsEnabled,
      'profileVisible': profileVisible,
      'postStatsVisible': postStatsVisible,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastRerollDate': lastRerollDate,
      'lastStreakDate': lastStreakDate,
      'lastQuestCompletionDate': lastQuestCompletionDate,
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
    String? activePlanId,
    int? currentStreak,
    int? dailyQuestCompletionCount,
    Map<String, int>? categoryXp,
    int? currentGroveIndex,
    List<int>? completedGroveIndexes,
    Map<int, List<int>>? occupiedTreeSlotsByGrove,
    bool? mapTutorialDone,
    bool? notificationsEnabled,
    bool? profileVisible,
    bool? postStatsVisible,
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
      activePlanId: activePlanId ?? this.activePlanId,
      currentPlan: currentPlan ?? this.currentPlan,
      currentStreak: currentStreak ?? this.currentStreak,
      dailyQuestCompletionCount:
          dailyQuestCompletionCount ?? this.dailyQuestCompletionCount,
      categoryXp: categoryXp ?? this.categoryXp,
      currentGroveIndex: currentGroveIndex ?? this.currentGroveIndex,
      completedGroveIndexes:
          completedGroveIndexes ?? this.completedGroveIndexes,
      occupiedTreeSlotsByGrove:
          occupiedTreeSlotsByGrove ?? this.occupiedTreeSlotsByGrove,
      mapTutorialDone: mapTutorialDone ?? this.mapTutorialDone,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      profileVisible: profileVisible ?? this.profileVisible,
      postStatsVisible: postStatsVisible ?? this.postStatsVisible,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastRerollDate: lastRerollDate ?? this.lastRerollDate,
      lastStreakDate: lastStreakDate ?? this.lastStreakDate,
      lastQuestCompletionDate:
          lastQuestCompletionDate ?? this.lastQuestCompletionDate,
    );
  }

  int get level => (totalXP ~/ 1000) + 1;

  int get currentXp => totalXP % 1000;

  /// Parses per-category XP from Firestore data.
  static Map<String, int> _readCategoryXp(Map<String, dynamic> json) {
    final raw = json['categoryXp'];
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v is num ? v.toInt() : 0));
    }

    final legacy = <String, int>{};
    for (final entry in json.entries) {
      if (entry.key.startsWith('categoryXp.') && entry.value is num) {
        final categoryName = entry.key.substring('categoryXp.'.length);
        legacy[categoryName] = (entry.value as num).toInt();
      }
    }
    if (legacy.isNotEmpty) return legacy;

    return const {};
  }

  static int _readCurrentGroveIndex(dynamic value) {
    final index = value is num ? value.toInt() : 1;
    return index < 1 ? 1 : index;
  }

  static List<int> _readGroveIndexes(dynamic value) {
    if (value is! List) return const [];
    final buffer = <int>[];
    for (final item in value) {
      if (item is num) {
        final idx = item.toInt();
        if (idx > 0) buffer.add(idx);
      }
    }
    final indexes = buffer.toSet().toList()..sort();
    return indexes;
  }

  static Map<int, List<int>> _readGroveSlots(Map<String, dynamic> json) {
    final result = <int, List<int>>{};
    final raw = json['occupiedTreeSlotsByGrove'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final groveIndex = int.tryParse(entry.key.toString()) ?? 0;
        if (groveIndex < 1 || entry.value is! List) continue;
        final buffer = <int>[];
        for (final item in (entry.value as List)) {
          if (item is num) {
            final idx = item.toInt();
            if (idx >= 0 && idx < 9) buffer.add(idx);
          }
        }
        result[groveIndex] = buffer.toSet().toList()..sort();
      }
    }

    if (result.isEmpty && json['occupiedTreeSlots'] is List) {
      final buffer = <int>[];
      for (final item in (json['occupiedTreeSlots'] as List)) {
        if (item is num) {
          final idx = item.toInt();
          if (idx >= 0 && idx < 9) buffer.add(idx);
        }
      }
      result[1] = buffer.toSet().toList()..sort();
    }
    return result;
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
      hobby:
          json['hobby'] as String? ??
          (json['hobbyName'] as String? ?? 'Learning'),
      level:
          json['level'] as String? ??
          (json['skillLevel'] as String? ?? 'Novice'),
      goal: json['goal'] as String? ?? (json['customGoal'] as String? ?? ''),
      learningPace:
          json['learningPace'] as String? ??
          (json['frequency'] as String? ??
              (json['dailyCommitment'] as String? ?? 'Steady Learner')),
      progress: json['progress'] as int? ?? 0,
      currentMilestoneIndex:
          json['currentMilestoneIndex'] as int? ??
          (json['progress'] as int? ?? 0),
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
