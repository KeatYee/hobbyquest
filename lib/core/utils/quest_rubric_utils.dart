import '../../app/models/quest_node_model.dart';

const int questRubricSize = 3;
const int questRubricApprovalThreshold = 2;
const int questRubricCriterionMaxLength = 120;
const int questRubricFeedbackMaxLength = 300;
const int questRubricFeedbackMaxWords = 12;

String limitWords(String value, int maxWords) {
  final words = value.trim().split(RegExp(r'\s+'));
  if (words.length <= maxWords) return words.join(' ');
  return words.take(maxWords).join(' ');
}

List<String> normalizeImageRubric(
  dynamic raw, {
  required String title,
  required String description,
}) {
  final criteria = raw is List
      ? raw
            .whereType<String>()
            .map((item) => item.trim())
            .where(
              (item) =>
                  item.isNotEmpty &&
                  item.length <= questRubricCriterionMaxLength,
            )
            .toSet()
            .take(questRubricSize)
            .toList()
      : <String>[];

  final fallback = fallbackImageRubric(title: title, description: description);
  for (final criterion in fallback) {
    if (criteria.length == questRubricSize) break;
    if (!criteria.contains(criterion)) criteria.add(criterion);
  }
  return criteria.take(questRubricSize).toList(growable: false);
}

List<String> fallbackImageRubric({
  required String title,
  required String description,
}) {
  final context = '$title $description'.toLowerCase();
  if (context.contains('shad') ||
      context.contains('value') ||
      context.contains('light')) {
    return const [
      'Clear separation between light, middle, and dark values',
      'Consistent light direction across the subject',
      'Controlled hard and soft edges where forms change',
    ];
  }
  if (context.contains('photo') ||
      context.contains('portrait') ||
      context.contains('composition')) {
    return const [
      'Subject is framed with a clear visual focus',
      'Lighting reveals the intended subject clearly',
      'Background and details support the composition',
    ];
  }
  if (context.contains('cook') ||
      context.contains('dish') ||
      context.contains('meal')) {
    return const [
      'Finished result visibly matches the requested dish',
      'Presentation is complete and intentionally arranged',
      'Visible texture and colour are consistent across the dish',
    ];
  }
  if (context.contains('yoga') ||
      context.contains('fitness') ||
      context.contains('dance') ||
      context.contains('pose')) {
    return const [
      'The requested movement or pose is clearly visible',
      'Body position appears stable in the captured moment',
      'The image shows the task in a suitable practice space',
    ];
  }
  return const [
    'The requested outcome is clearly visible',
    'The named technique is visibly applied',
    'The work appears complete and carefully presented',
  ];
}

List<RubricAssessmentModel>? parseOrderedRubricAssessments(
  dynamic raw,
  List<String> rubric,
) {
  if (rubric.length != questRubricSize ||
      raw is! List ||
      raw.length != questRubricSize) {
    return null;
  }

  final assessments = <RubricAssessmentModel>[];
  for (var index = 0; index < questRubricSize; index++) {
    final item = raw[index];
    if (item is! Map) return null;
    final map = Map<String, dynamic>.from(item);
    final met = map['met'];
    final feedback = map['feedback']?.toString().trim() ?? '';
    if (met is! bool ||
        feedback.isEmpty ||
        feedback.length > questRubricFeedbackMaxLength) {
      return null;
    }
    assessments.add(
      RubricAssessmentModel(
        criterion: rubric[index],
        met: met,
        feedback: limitWords(feedback, questRubricFeedbackMaxWords),
      ),
    );
  }
  return assessments;
}

Map<String, dynamic>? parseRubricImageFeedbackResponse(
  Map<String, dynamic> response,
  List<String> rubric,
) {
  final relevance = response['is_evidence_relevant'];
  if (relevance is! bool) return null;

  final greetingValue = limitWords(response['greeting']?.toString() ?? '', 4);
  final nextStepValue = limitWords(response['next_step']?.toString() ?? '', 10);
  final greeting = greetingValue.isNotEmpty
      ? greetingValue
      : relevance
      ? 'Here is your feedback.'
      : 'Let us check this.';
  final nextStep = nextStepValue.isNotEmpty
      ? nextStepValue
      : relevance
      ? 'Use the feedback for your next attempt.'
      : 'Retake with the quest work clearly visible.';

  if (!relevance) {
    return {
      'is_evidence_relevant': false,
      'greeting': greeting,
      'rubric_assessments': const <RubricAssessmentModel>[],
      'next_step': nextStep,
    };
  }

  final assessments = parseOrderedRubricAssessments(
    response['results'],
    rubric,
  );
  if (assessments == null) return null;

  return {
    'is_evidence_relevant': true,
    'greeting': greeting,
    'rubric_assessments': assessments,
    'next_step': nextStep,
  };
}

bool rubricChallengeApproved({
  required bool isEvidenceRelevant,
  required List<RubricAssessmentModel> assessments,
}) {
  return isEvidenceRelevant &&
      assessments.length == questRubricSize &&
      assessments.where((assessment) => assessment.met).length >= questRubricApprovalThreshold;
}
