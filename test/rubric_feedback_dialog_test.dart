import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hobbyquest/app/models/quest_node_model.dart';
import 'package:hobbyquest/app/views/dialogs/rubric_feedback_dialog.dart';

void main() {
  tearDown(Get.reset);

  const assessments = [
    RubricAssessmentModel(
      criterion: 'Clear separation between light and dark values',
      met: true,
      feedback: 'The light and shadow groups read clearly.',
    ),
    RubricAssessmentModel(
      criterion: 'Consistent light direction',
      met: false,
      feedback: 'The cast shadow points away from the highlights.',
    ),
    RubricAssessmentModel(
      criterion: 'Controlled hard and soft edges',
      met: true,
      feedback: 'The form shadow uses a gradual transition.',
    ),
  ];

  testWidgets('groups rubric feedback into clear visual sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(
          body: Center(
            child: Dialog(
              child: RubricFeedbackDialog(
                isEvidenceRelevant: true,
                isApproved: true,
                isChallenge: true,
                greeting: 'Strong work, Hero!',
                assessments: assessments,
                nextStep: 'Soften the edge nearest the reflected light.',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Quest Passed'), findsOneWidget);
    expect(find.text('2 of 3 met'), findsOneWidget);
    expect(find.text('WHAT YOU DID WELL'), findsOneWidget);
    expect(find.text('WHAT TO IMPROVE'), findsOneWidget);
    expect(find.text('TRY THIS NEXT'), findsNothing);
    expect(find.text('Strong work, Hero!'), findsOneWidget);
    expect(
      find.text('Next step: Soften the edge nearest the reflected light.'),
      findsOneWidget,
    );
    expect(find.text('Consistent light direction'), findsOneWidget);
    expect(find.text('Retake Photo'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('irrelevant optional evidence offers retake and continue', (
    tester,
  ) async {
    RubricFeedbackAction? selectedAction;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                selectedAction = await Get.dialog<RubricFeedbackAction>(
                  const Dialog(
                    child: RubricFeedbackDialog(
                      isEvidenceRelevant: false,
                      isApproved: false,
                      isChallenge: false,
                      greeting: 'Let us try again.',
                      assessments: assessments,
                      nextStep: 'Place the finished work in the centre.',
                    ),
                  ),
                  barrierDismissible: false,
                );
              },
              child: const Text('Open feedback'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open feedback'));
    await tester.pumpAndSettle();

    expect(find.text('Photo Check'), findsOneWidget);
    expect(find.text('TRY THIS NEXT'), findsNothing);
    expect(find.text('WHAT YOU DID WELL'), findsNothing);
    expect(find.text('WHAT TO IMPROVE'), findsNothing);
    expect(find.text('Let us try again.'), findsOneWidget);
    expect(
      find.text('Next step: Place the finished work in the centre.'),
      findsOneWidget,
    );
    expect(find.text('Retake Photo'), findsOneWidget);
    expect(find.text('Continue without photo'), findsOneWidget);

    final retakeButton = find.text('Retake Photo');
    await tester.ensureVisible(retakeButton);
    await tester.tap(retakeButton);
    await tester.pumpAndSettle();

    expect(selectedAction, RubricFeedbackAction.retakePhoto);
  });

  testWidgets('failed criteria show only the unmet feedback', (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(
          body: Center(
            child: Dialog(
              child: RubricFeedbackDialog(
                isEvidenceRelevant: true,
                isApproved: false,
                isChallenge: true,
                greeting: 'Almost there.',
                assessments: [
                  RubricAssessmentModel(
                    criterion: 'Clear value separation',
                    met: true,
                    feedback: 'The light and dark groups are visible.',
                  ),
                  RubricAssessmentModel(
                    criterion: 'Consistent light direction',
                    met: false,
                    feedback: 'The shadows point in different directions.',
                  ),
                  RubricAssessmentModel(
                    criterion: 'Controlled edges',
                    met: false,
                    feedback: 'The form shadow needs a softer edge.',
                  ),
                ],
                nextStep: 'Adjust the cast shadow direction.',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Needs Work'), findsOneWidget);
    expect(find.text('1 of 3 met'), findsOneWidget);
    expect(find.text('WHAT TO IMPROVE'), findsOneWidget);
    expect(find.text('WHAT YOU DID WELL'), findsNothing);
    expect(find.text('TRY THIS NEXT'), findsNothing);
    expect(find.text('Almost there.'), findsOneWidget);
    expect(
      find.text('Next step: Adjust the cast shadow direction.'),
      findsOneWidget,
    );
    expect(find.text('Retake Photo'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('optional recovery returns both available actions', (
    tester,
  ) async {
    for (final entry in const {
      'Retake Photo': RubricFeedbackAction.retakePhoto,
      'Continue without photo': RubricFeedbackAction.continueQuest,
    }.entries) {
      RubricFeedbackAction? selectedAction;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  selectedAction = await Get.dialog<RubricFeedbackAction>(
                    const Dialog(
                      child: OptionalPhotoRecoveryDialog(uploadFailed: true),
                    ),
                    barrierDismissible: false,
                  );
                },
                child: const Text('Open recovery'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open recovery'));
      await tester.pumpAndSettle();
      expect(find.text('Photo Couldn’t Be Used'), findsOneWidget);
      expect(find.text('Retake Photo'), findsOneWidget);
      expect(find.text('Continue without photo'), findsOneWidget);

      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(selectedAction, entry.value);
    }
  });
}
