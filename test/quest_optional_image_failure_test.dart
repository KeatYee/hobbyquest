import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hobbyquest/app/controllers/quest_detail_controller.dart';
import 'package:hobbyquest/app/models/quest_node_model.dart';
import 'package:hobbyquest/app/services/quest_service.dart';
import 'package:hobbyquest/app/views/dialogs/rubric_feedback_dialog.dart';

class _RecordingQuestService extends QuestService {
  int completionCalls = 0;
  String? receivedImageUrl;
  List<RubricAssessmentModel> receivedAssessments = const [];

  @override
  Future<QuestCompletionResult> completeQuestTransaction({
    required String uid,
    required String planId,
    required String questId,
    String reflectionNote = '',
    String? imageUrl,
    String? greeting,
    String? observation,
    String? tip,
    List<RubricAssessmentModel> rubricAssessments = const [],
    String? fallbackCategoryName,
  }) async {
    completionCalls++;
    receivedImageUrl = imageUrl;
    receivedAssessments = rubricAssessments;
    final completedQuest = _quest.copyWith(
      isCompleted: true,
      isActive: false,
      imageUrl: imageUrl,
      rubricAssessments: rubricAssessments,
      awardedXP: _quest.xpReward,
    );
    return QuestCompletionResult(
      planId: planId,
      quest: completedQuest,
      didComplete: true,
      awardedXP: _quest.xpReward,
      previousTotalXP: 0,
      updatedTotalXP: _quest.xpReward,
      updatedStreak: 1,
      dailyQuestCompletionCount: 1,
      updatedCategoryXp: const {'Creative Arts': 100},
      completionTime: DateTime.utc(2026, 7, 28),
    );
  }
}

class _FakeHomeContext implements QuestDetailHomeContext {
  _FakeHomeContext(QuestNodeModel quest) : dailyQuests = [quest];

  @override
  final List<QuestNodeModel> dailyQuests;

  @override
  String get uid => 'user-1';

  @override
  String get activePlanId => 'plan-1';

  @override
  String get hobby => 'Drawing';

  @override
  String get category => 'Creative Arts';

  @override
  int get currentStreak => 0;

  @override
  Map<String, int> get categoryXp => const {'Creative Arts': 0};

  @override
  void applyQuestCompletion(QuestCompletionResult completion) {
    dailyQuests
      ..clear()
      ..add(completion.quest);
  }

  @override
  Future<void> refreshGrowthLetterAvailability() async {}

  @override
  bool hasCompletedMilestone() => false;

  @override
  bool hasCompletedFinalMilestone() => false;
}

class _FakeProgressionContext implements QuestDetailProgressionContext {
  @override
  List<int> applyQuestCompletion(QuestCompletionResult completion) => const [];

  @override
  Future<String?> resolveCurrentCategoryName() async => 'Creative Arts';
}

const _rubric = [
  'Clear value separation',
  'Consistent light direction',
  'Controlled hard and soft edges',
];

const _quest = QuestNodeModel(
  nodeId: 'optional-image-quest',
  title: 'Shade a Sphere',
  desc: 'Practice one light source.',
  steps: ['Draw', 'Shade', 'Review'],
  xpReward: 100,
  type: 'practice',
  durationMinutes: 15,
  dependsOn: [],
  isActive: true,
  imageRubric: _rubric,
);

final _assessments = [
  RubricAssessmentModel(
    criterion: _rubric[0],
    met: true,
    feedback: 'Values are clearly separated.',
  ),
  RubricAssessmentModel(
    criterion: _rubric[1],
    met: false,
    feedback: 'Shadow directions differ.',
  ),
  RubricAssessmentModel(
    criterion: _rubric[2],
    met: true,
    feedback: 'Edges show clear control.',
  ),
];

QuestDetailController _controller({
  required _RecordingQuestService questService,
  required QuestImageFeedbackGenerator feedbackGenerator,
  required OptionalPhotoRecoveryPresenter recoveryPresenter,
  QuestNodeModel initialQuest = _quest,
  QuestImageUploader? imageUploader,
  RubricFeedbackPresenter? rubricPresenter,
  void Function(String title, String message)? errorPresenter,
}) {
  return QuestDetailController(
    initialQuest: initialQuest,
    questService: questService,
    homeContext: _FakeHomeContext(initialQuest),
    progressionContext: _FakeProgressionContext(),
    feedbackGenerator: feedbackGenerator,
    imageUploader: imageUploader,
    optionalRecoveryPresenter: recoveryPresenter,
    rubricFeedbackPresenter: rubricPresenter,
    errorPresenter: errorPresenter,
  );
}

void main() {
  test(
    'optional Gemini failure can continue without upload or bonus',
    () async {
      final questService = _RecordingQuestService();
      var uploadCalled = false;
      final controller = _controller(
        questService: questService,
        feedbackGenerator:
            ({
              required imageFile,
              required hobby,
              required questTitle,
              required questDescription,
              required questSteps,
              required questType,
              required reflectionNote,
              required imageRubric,
            }) async => null,
        imageUploader: (path) async {
          uploadCalled = true;
          return 'unexpected';
        },
        recoveryPresenter: ({required uploadFailed}) async {
          expect(uploadFailed, isFalse);
          return RubricFeedbackAction.continueQuest;
        },
      );

      final outcome = await controller.completeQuest(
        'I practised the value groups.',
        imageFile: XFile('unused.jpg'),
      );

      expect(outcome, isNotNull);
      expect(uploadCalled, isFalse);
      expect(questService.completionCalls, 1);
      expect(questService.receivedImageUrl, isNull);
      expect(questService.receivedAssessments, isEmpty);
      expect(outcome!.completion.awardedXP, _quest.xpReward);
    },
  );

  test('optional Gemini failure retake performs no completion', () async {
    final questService = _RecordingQuestService();
    final controller = _controller(
      questService: questService,
      feedbackGenerator:
          ({
            required imageFile,
            required hobby,
            required questTitle,
            required questDescription,
            required questSteps,
            required questType,
            required reflectionNote,
            required imageRubric,
          }) async => null,
      recoveryPresenter: ({required uploadFailed}) async =>
          RubricFeedbackAction.retakePhoto,
    );

    final outcome = await controller.completeQuest(
      'I practised the value groups.',
      imageFile: XFile('unused.jpg'),
    );

    expect(outcome, isNull);
    expect(questService.completionCalls, 0);
    expect(controller.consumeRetakeImageRequest(), isTrue);
  });

  test(
    'optional upload failure keeps feedback but removes image bonus',
    () async {
      final questService = _RecordingQuestService();
      final controller = _controller(
        questService: questService,
        feedbackGenerator:
            ({
              required imageFile,
              required hobby,
              required questTitle,
              required questDescription,
              required questSteps,
              required questType,
              required reflectionNote,
              required imageRubric,
            }) async => {
              'is_evidence_relevant': true,
              'greeting': 'Good focused effort.',
              'rubric_assessments': _assessments,
              'next_step': 'Align the cast shadow.',
            },
        imageUploader: (path) async => throw Exception('upload failed'),
        rubricPresenter:
            ({
              required isEvidenceRelevant,
              required isApproved,
              required isChallenge,
              required greeting,
              required assessments,
              required nextStep,
            }) async => RubricFeedbackAction.continueQuest,
        recoveryPresenter: ({required uploadFailed}) async {
          expect(uploadFailed, isTrue);
          return RubricFeedbackAction.continueQuest;
        },
      );

      final outcome = await controller.completeQuest(
        'I practised the value groups.',
        imageFile: XFile('unused.jpg'),
      );

      expect(outcome, isNotNull);
      expect(questService.completionCalls, 1);
      expect(questService.receivedImageUrl, isNull);
      expect(questService.receivedAssessments, _assessments);
      expect(outcome!.completion.awardedXP, _quest.xpReward);
    },
  );

  test('optional upload failure retake performs no completion', () async {
    final questService = _RecordingQuestService();
    final controller = _controller(
      questService: questService,
      feedbackGenerator:
          ({
            required imageFile,
            required hobby,
            required questTitle,
            required questDescription,
            required questSteps,
            required questType,
            required reflectionNote,
            required imageRubric,
          }) async => {
            'is_evidence_relevant': true,
            'greeting': 'Good focused effort.',
            'rubric_assessments': _assessments,
            'next_step': 'Align the cast shadow.',
          },
      imageUploader: (path) async => throw Exception('upload failed'),
      rubricPresenter:
          ({
            required isEvidenceRelevant,
            required isApproved,
            required isChallenge,
            required greeting,
            required assessments,
            required nextStep,
          }) async => RubricFeedbackAction.continueQuest,
      recoveryPresenter: ({required uploadFailed}) async {
        expect(uploadFailed, isTrue);
        return RubricFeedbackAction.retakePhoto;
      },
    );

    final outcome = await controller.completeQuest(
      'I practised the value groups.',
      imageFile: XFile('unused.jpg'),
    );

    expect(outcome, isNull);
    expect(questService.completionCalls, 0);
    expect(controller.consumeRetakeImageRequest(), isTrue);
  });

  test('challenge Gemini failure never completes the quest', () async {
    final questService = _RecordingQuestService();
    var errorShown = false;
    final controller = _controller(
      initialQuest: _quest.copyWith(type: 'challenge'),
      questService: questService,
      feedbackGenerator:
          ({
            required imageFile,
            required hobby,
            required questTitle,
            required questDescription,
            required questSteps,
            required questType,
            required reflectionNote,
            required imageRubric,
          }) async => null,
      recoveryPresenter: ({required uploadFailed}) async {
        fail('Challenge failures must not use optional recovery.');
      },
      errorPresenter: (title, message) {
        errorShown = true;
      },
    );

    final outcome = await controller.completeQuest(
      'I practised the value groups.',
      imageFile: XFile('unused.jpg'),
    );

    expect(outcome, isNull);
    expect(errorShown, isTrue);
    expect(questService.completionCalls, 0);
    expect(controller.consumeRetakeImageRequest(), isFalse);
  });

  test('challenge upload failure never completes the quest', () async {
    final questService = _RecordingQuestService();
    var errorShown = false;
    final controller = _controller(
      initialQuest: _quest.copyWith(type: 'challenge'),
      questService: questService,
      feedbackGenerator:
          ({
            required imageFile,
            required hobby,
            required questTitle,
            required questDescription,
            required questSteps,
            required questType,
            required reflectionNote,
            required imageRubric,
          }) async => {
            'is_evidence_relevant': true,
            'greeting': 'Good focused effort.',
            'rubric_assessments': _assessments,
            'next_step': 'Align the cast shadow.',
          },
      imageUploader: (path) async => throw Exception('upload failed'),
      rubricPresenter:
          ({
            required isEvidenceRelevant,
            required isApproved,
            required isChallenge,
            required greeting,
            required assessments,
            required nextStep,
          }) async => RubricFeedbackAction.continueQuest,
      recoveryPresenter: ({required uploadFailed}) async {
        fail('Challenge failures must not use optional recovery.');
      },
      errorPresenter: (title, message) {
        errorShown = true;
      },
    );

    final outcome = await controller.completeQuest(
      'I practised the value groups.',
      imageFile: XFile('unused.jpg'),
    );

    expect(outcome, isNull);
    expect(errorShown, isTrue);
    expect(questService.completionCalls, 0);
  });
}
