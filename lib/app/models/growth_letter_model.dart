import 'package:cloud_firestore/cloud_firestore.dart';

class GrowthLetterModel {
  final String id;
  final String uid;
  final String planId;
  final String hobby;
  final String nickname;
  final String letter;
  final int questCount;
  final int reflectionCount;
  final int weeklyStreakDays;
  final List<String> questIds;
  final String strongestGrowth;
  final String focusArea;
  final String nextWeekFocus;
  final bool hasPersonalizedInsights;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime? createdAt;
  final DateTime? readAt;

  const GrowthLetterModel({
    this.id = '',
    required this.uid,
    required this.planId,
    required this.hobby,
    required this.nickname,
    required this.letter,
    required this.questCount,
    required this.reflectionCount,
    this.weeklyStreakDays = 0,
    required this.questIds,
    this.strongestGrowth = 'Persistence',
    this.focusArea = 'Practice details',
    this.nextWeekFocus = 'Guided practice',
    this.hasPersonalizedInsights = true,
    required this.periodStart,
    required this.periodEnd,
    this.createdAt,
    this.readAt,
  });

  factory GrowthLetterModel.fromJson(
    Map<String, dynamic> json, {
    String docId = '',
  }) {
    final explicitInsightsFlag = json['hasPersonalizedInsights'] as bool?;
    final hasPersonalizedInsights =
        explicitInsightsFlag ??
        (_hasText(json['strongestGrowth']) &&
            _hasText(json['focusArea']) &&
            _hasText(json['nextWeekFocus']));

    return GrowthLetterModel(
      id: docId,
      uid: json['uid'] as String? ?? '',
      planId: json['planId'] as String? ?? '',
      hobby: json['hobby'] as String? ?? '',
      nickname: json['nickname'] as String? ?? 'Hero',
      letter: json['letter'] as String? ?? '',
      questCount: (json['questCount'] as num?)?.toInt() ?? 0,
      reflectionCount: (json['reflectionCount'] as num?)?.toInt() ?? 0,
      weeklyStreakDays: (json['weeklyStreakDays'] as num?)?.toInt() ?? 0,
      questIds: (json['questIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      strongestGrowth: json['strongestGrowth'] as String? ?? 'Persistence',
      focusArea: json['focusArea'] as String? ?? 'Practice details',
      nextWeekFocus: json['nextWeekFocus'] as String? ?? 'Guided practice',
      hasPersonalizedInsights: hasPersonalizedInsights,
      periodStart: _readDateTime(json['periodStart']) ?? DateTime.now(),
      periodEnd: _readDateTime(json['periodEnd']) ?? DateTime.now(),
      createdAt: _readDateTime(json['createdAt']),
      readAt: _readDateTime(json['readAt']),
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'uid': uid,
      'planId': planId,
      'hobby': hobby,
      'nickname': nickname,
      'letter': letter,
      'questCount': questCount,
      'reflectionCount': reflectionCount,
      'weeklyStreakDays': weeklyStreakDays,
      'questIds': questIds,
      'strongestGrowth': strongestGrowth,
      'focusArea': focusArea,
      'nextWeekFocus': nextWeekFocus,
      'hasPersonalizedInsights': hasPersonalizedInsights,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
    if (readAt != null) {
      data['readAt'] = Timestamp.fromDate(readAt!);
    }
    return data;
  }

  bool get hasWeeklyStats => questCount == 0 || weeklyStreakDays > 0;

  static bool _hasText(dynamic value) {
    return value is String && value.trim().isNotEmpty;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);

    try {
      return (value as dynamic).toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }
}
