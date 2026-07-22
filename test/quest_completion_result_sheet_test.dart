import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobbyquest/app/controllers/quest_detail_controller.dart';
import 'package:hobbyquest/app/models/quest_node_model.dart';
import 'package:hobbyquest/app/services/quest_service.dart';
import 'package:hobbyquest/app/views/widgets/quest_completion_result_sheet.dart';

QuestCompletionOutcome _outcome({
  String categoryName = 'Creative Arts',
  int previousCategoryXp = 80,
  int updatedCategoryXp = 130,
  int previousCategoryStage = 0,
  int updatedCategoryStage = 1,
  int previousStreak = 2,
  int updatedStreak = 3,
  List<QuestNodeModel> newlyUnlockedQuests = const [],
  bool didLevelUp = false,
  List<int> unlockedProgressionMilestones = const [],
  bool completedMilestone = false,
  bool completedFinalMilestone = false,
}) {
  final quest = const QuestNodeModel(
    nodeId: 'completed-quest',
    title: 'Sketch a leaf study',
    desc: 'Observe one leaf and sketch its details.',
    steps: ['Observe', 'Sketch'],
    xpReward: 50,
    type: 'practice',
    durationMinutes: 15,
    dependsOn: [],
    isCompleted: true,
    awardedXP: 50,
  );

  return QuestCompletionOutcome(
    completion: QuestCompletionResult(
      planId: 'plan-1',
      quest: quest,
      didComplete: true,
      awardedXP: 50,
      previousTotalXP: 950,
      updatedTotalXP: 1000,
      updatedStreak: updatedStreak,
      dailyQuestCompletionCount: 1,
      updatedCategoryXp: {categoryName: updatedCategoryXp},
      completionTime: DateTime(2026, 7, 22),
    ),
    categoryName: categoryName,
    previousCategoryXp: previousCategoryXp,
    updatedCategoryXp: updatedCategoryXp,
    previousCategoryStage: previousCategoryStage,
    updatedCategoryStage: updatedCategoryStage,
    previousStreak: previousStreak,
    newlyUnlockedQuests: newlyUnlockedQuests,
    didLevelUp: didLevelUp,
    unlockedProgressionMilestones: unlockedProgressionMilestones,
    completedMilestone: completedMilestone,
    completedFinalMilestone: completedFinalMilestone,
  );
}

Widget _sheet(
  QuestCompletionOutcome outcome, {
  Future<void> Function()? onShare,
}) {
  return MaterialApp(
    home: Scaffold(
      body: QuestCompletionResultSheet(
        outcome: outcome,
        onShare: onShare ?? () async {},
      ),
    ),
  );
}

void main() {
  testWidgets('shows earned progress and every unlocked outcome', (
    tester,
  ) async {
    final unlockedQuest = const QuestNodeModel(
      nodeId: 'unlocked-quest',
      title: 'Try a new shading technique',
      desc: 'Practice shading.',
      steps: ['Practice'],
      type: 'knowledge',
      durationMinutes: 10,
      dependsOn: ['completed-quest'],
      isActive: true,
    );
    var shared = false;

    await tester.pumpWidget(
      _sheet(
        _outcome(
          newlyUnlockedQuests: [unlockedQuest],
          didLevelUp: true,
          unlockedProgressionMilestones: const [1],
          completedMilestone: true,
        ),
        onShare: () async {
          shared = true;
        },
      ),
    );

    expect(find.text('QUEST COMPLETE'), findsOneWidget);
    expect(find.text('+50 XP'), findsOneWidget);
    expect(find.text('3-day streak'), findsOneWidget);
    expect(find.text('Streak extended'), findsOneWidget);
    expect(find.text('Creative Arts tree'), findsOneWidget);
    expect(find.text('130 / 800 XP to mature tree'), findsOneWidget);
    expect(find.text('New quest: Try a new shading technique'), findsOneWidget);
    expect(find.text('Your tree can grow to Sprout.'), findsOneWidget);
    expect(find.text('Level 2 unlocked.'), findsOneWidget);
    expect(find.text('Progress milestone 1 unlocked.'), findsOneWidget);
    expect(find.text('Your next milestone is ready.'), findsOneWidget);

    await tester.tap(find.text('SHARE TO GUILD'));
    await tester.pump();
    expect(shared, isTrue);
  });

  testWidgets('uses the calm fallback without category progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: _sheet(
          _outcome(
            categoryName: '',
            previousCategoryXp: 0,
            updatedCategoryXp: 0,
            previousCategoryStage: 0,
            updatedCategoryStage: 0,
            previousStreak: 0,
            updatedStreak: 1,
          ),
        ),
      ),
    );

    expect(find.text('New streak started'), findsOneWidget);
    expect(find.byIcon(Icons.park_rounded), findsNothing);
    expect(
      find.text('Your progress is saved. Keep building your tree.'),
      findsOneWidget,
    );
    expect(find.text('CONTINUE'), findsOneWidget);
  });
}
