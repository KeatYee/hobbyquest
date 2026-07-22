int calculateUpdatedStreak({
  required int currentStreak,
  required DateTime? lastStreakDate,
  required DateTime completionTime,
}) {
  if (lastStreakDate == null) return 1;

  final utcCompletion = completionTime.toUtc();
  final utcLastCompletion = lastStreakDate.toUtc();
  final completionDay = DateTime.utc(
    utcCompletion.year,
    utcCompletion.month,
    utcCompletion.day,
  );
  final lastCompletionDay = DateTime.utc(
    utcLastCompletion.year,
    utcLastCompletion.month,
    utcLastCompletion.day,
  );
  final dayDifference = completionDay.difference(lastCompletionDay).inDays;
  if (dayDifference == 0) return currentStreak;
  if (dayDifference == 1) return currentStreak + 1;
  return 1;
}
