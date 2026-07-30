import 'package:flutter_test/flutter_test.dart';
import 'package:hobbyquest/app/models/quest_node_model.dart';
import 'package:hobbyquest/core/utils/quest_rubric_utils.dart';

void main() {
  const rubric = [
    'Clear separation between light, middle, and dark values',
    'Consistent light direction across the subject',
    'Controlled hard and soft edges where forms change',
  ];
  final assessments = [
    RubricAssessmentModel(
      criterion: rubric[0],
      met: true,
      feedback: 'The three value groups are clearly separated.',
    ),
    RubricAssessmentModel(
      criterion: rubric[1],
      met: true,
      feedback: 'Highlights consistently sit on the upper-left side.',
    ),
    RubricAssessmentModel(
      criterion: rubric[2],
      met: false,
      feedback: 'Several cast-shadow edges need a firmer transition.',
    ),
  ];

  test('rubric fields round-trip through quest JSON', () {
    final quest = QuestNodeModel(
      nodeId: '1_node_1',
      title: 'Shade a Simple Sphere',
      desc: 'Use one light source to shade a sphere.',
      steps: ['Draw', 'Shade', 'Review'],
      type: 'challenge',
      durationMinutes: 20,
      dependsOn: [],
      imageRubric: rubric,
      rubricAssessments: assessments,
    );

    final restored = QuestNodeModel.fromJson(quest.toJson());

    expect(restored.imageRubric, rubric);
    expect(restored.rubricAssessments, hasLength(3));
    expect(restored.rubricAssessments[1].met, isTrue);
    expect(restored.rubricAssessments[2].feedback, assessments[2].feedback);
  });

  test('legacy quests remain valid without rubric fields', () {
    final quest = QuestNodeModel.fromJson({
      'node_id': 'legacy',
      'title': 'Legacy Quest',
      'desc': 'Old saved quest.',
      'steps': ['Try it'],
      'type': 'challenge',
      'duration_minutes': 10,
      'depends_on': <String>[],
    });

    expect(quest.imageRubric, isEmpty);
    expect(quest.rubricAssessments, isEmpty);
    expect(quest.toJson(), isNot(contains('image_rubric')));
    expect(quest.toJson(), isNot(contains('rubricAssessments')));
  });

  test('partial and invalid criteria normalize to three safe values', () {
    final normalized = normalizeImageRubric(
      ['', 42, rubric[0], rubric[0], List.filled(121, 'x').join()],
      title: 'Shade a Simple Sphere',
      description: 'Show light and shadow.',
    );

    expect(normalized, hasLength(3));
    expect(normalized.toSet(), hasLength(3));
    expect(normalized, contains(rubric[0]));
    expect(normalized, contains(rubric[1]));
    expect(normalized, contains(rubric[2]));
    expect(normalized, isNot(contains('42')));
  });

  test('assessment parser preserves stored rubric order', () {
    final parsed = parseOrderedRubricAssessments([
      {'criterion': 'Model tried to rename this', 'met': true, 'feedback': 'A'},
      {'met': false, 'feedback': 'B'},
      {'met': true, 'feedback': 'C'},
    ], rubric);

    expect(parsed, isNotNull);
    expect(parsed!.map((item) => item.criterion), rubric);
  });

  test('assessment feedback is capped at twelve words', () {
    final parsed = parseOrderedRubricAssessments([
      {
        'met': true,
        'feedback':
            'One two three four five six seven eight nine ten eleven twelve thirteen fourteen',
      },
      {'met': false, 'feedback': 'Keep the light direction consistent.'},
      {'met': true, 'feedback': 'Edges are controlled.'},
    ], rubric);

    expect(parsed, isNotNull);
    expect(parsed!.first.feedback.split(' '), hasLength(12));
    expect(parsed.first.feedback, isNot(contains('thirteen')));
  });

  test('assessment parser rejects malformed responses', () {
    expect(
      parseOrderedRubricAssessments([
        {'met': 'true', 'feedback': 'A'},
        {'met': false, 'feedback': 'B'},
        {'met': true, 'feedback': 'C'},
      ], rubric),
      isNull,
    );
    expect(parseOrderedRubricAssessments(const [], rubric), isNull);
  });

  test('irrelevant evidence ignores missing or malformed results', () {
    final missingResults = parseRubricImageFeedbackResponse({
      'is_evidence_relevant': false,
      'greeting': '',
      'next_step': '',
    }, rubric);
    final malformedResults = parseRubricImageFeedbackResponse({
      'is_evidence_relevant': false,
      'results': [
        {'met': 'not-a-boolean'},
        42,
        {'feedback': ''},
        {'extra': true},
      ],
    }, rubric);

    expect(missingResults, isNotNull);
    expect(missingResults!['rubric_assessments'], isEmpty);
    expect(missingResults['greeting'], isNotEmpty);
    expect(missingResults['next_step'], isNotEmpty);
    expect(malformedResults, isNotNull);
    expect(malformedResults!['rubric_assessments'], isEmpty);
  });

  test('relevant evidence still requires exactly three valid results', () {
    expect(
      parseRubricImageFeedbackResponse({
        'is_evidence_relevant': true,
        'results': [
          {'met': true, 'feedback': 'Visible.'},
        ],
      }, rubric),
      isNull,
    );
  });

  test('challenge approval requires relevance and two criteria met', () {
    expect(
      rubricChallengeApproved(
        isEvidenceRelevant: true,
        assessments: assessments,
      ),
      isTrue,
    );
    expect(
      rubricChallengeApproved(
        isEvidenceRelevant: false,
        assessments: assessments,
      ),
      isFalse,
    );
    expect(
      rubricChallengeApproved(
        isEvidenceRelevant: true,
        assessments: assessments
            .map(
              (assessment) => RubricAssessmentModel(
                criterion: assessment.criterion,
                met: true,
                feedback: assessment.feedback,
              ),
            )
            .toList(),
      ),
      isTrue,
    );
    expect(
      rubricChallengeApproved(
        isEvidenceRelevant: true,
        assessments: [
          assessments[0],
          RubricAssessmentModel(
            criterion: rubric[1],
            met: false,
            feedback: 'Needs work.',
          ),
          assessments[2],
        ],
      ),
      isFalse,
    );
    expect(
      rubricChallengeApproved(
        isEvidenceRelevant: true,
        assessments: assessments
            .map(
              (assessment) => RubricAssessmentModel(
                criterion: assessment.criterion,
                met: false,
                feedback: assessment.feedback,
              ),
            )
            .toList(),
      ),
      isFalse,
    );
  });
}
