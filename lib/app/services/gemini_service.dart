import 'dart:convert';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/milestone_model.dart';
import '../models/quest_node_model.dart';
import '../models/quest_plan_model.dart';
import '../../core/utils/quest_rubric_utils.dart';

class ValidationResult {
  final bool isValid;
  final String? error;

  const ValidationResult({required this.isValid, this.error});

  const ValidationResult.valid() : isValid = true, error = null;

  const ValidationResult.invalid(this.error) : isValid = false;
}

class GrowthLetterDraft {
  final String letter;
  final String strongestGrowth;
  final String focusArea;
  final String nextWeekFocus;

  const GrowthLetterDraft({
    required this.letter,
    required this.strongestGrowth,
    required this.focusArea,
    required this.nextWeekFocus,
  });
}

class GoalValidationResult {
  final bool isValid;
  final String reason;

  const GoalValidationResult({required this.isValid, required this.reason});
}

class GeminiService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  bool get hasApiKey => true;

  Future<String> _generateText(
    String prompt, {
    String? mimeType,
    Uint8List? imageBytes,
  }) async {
    final result = await _functions.httpsCallable('generateWithGemini').call({
      'prompt': prompt,
      if (mimeType != null && imageBytes != null) ...{
        'mimeType': mimeType,
        'imageBase64': base64Encode(imageBytes),
      },
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['text']?.toString().trim() ?? '';
  }

  ValidationResult validateOnboardingStep({
    required int step,
    required String nickname,
    required String birthDate,
    required String gender,
    required String category,
    required String hobby,
    required String level,
    required String goal,
    required String learningPace,
  }) {
    switch (step) {
      case 0:
        if (nickname.trim().isEmpty) {
          return const ValidationResult.invalid('Nickname is required');
        }
        if (birthDate.trim().isEmpty) {
          return const ValidationResult.invalid('Birth date is required');
        }
        if (gender.trim().isEmpty) {
          return const ValidationResult.invalid('Gender is required');
        }
        return const ValidationResult.valid();
      case 1:
        if (category.trim().isEmpty) {
          return const ValidationResult.invalid('Category is required');
        }
        if (hobby.trim().isEmpty) {
          return const ValidationResult.invalid('Hobby is required');
        }
        return const ValidationResult.valid();
      case 2:
        if (level.trim().isEmpty) {
          return const ValidationResult.invalid('Skill level is required');
        }
        return const ValidationResult.valid();
      case 3:
        if (goal.trim().isEmpty && hobby.trim().isEmpty) {
          return const ValidationResult.invalid('Goal is required');
        }
        if (learningPace.trim().isEmpty) {
          return const ValidationResult.invalid('Learning pace is required');
        }
        return const ValidationResult.valid();
      default:
        return const ValidationResult.valid();
    }
  }

  Future<QuestPlanModel> generateQuestPlan({
    required String hobby,
    required String level,
    required String goal,
    required String learningPace,
  }) async {
    final normalizedGoal = goal.trim().isEmpty ? 'Master $hobby' : goal.trim();

    if (!hasApiKey) {
      return _buildFallbackQuestPlan(
        hobby: hobby,
        level: level,
        goal: normalizedGoal,
        learningPace: learningPace,
      );
    }

    try {
      print('[GeminiService] Calling generateQuestPlan API...');
      final prompt =
          '''
You are an expert tutor and quest planner for a gamified hobby app.
The user wants to learn $hobby. Their main goal is $normalizedGoal.
They consider themselves $level level and prefer a "$learningPace" learning pace.

User Profile:
- Hobby: $hobby
- Skill Level: $level
- Goal: $normalizedGoal
- Learning Pace: $learningPace

Instructions:
1. Generate exactly 4 major Milestones that break this goal into logical phases.
2. Each milestone title must describe a clear action the user can take.

Plain-language rules:
- Use common everyday words.
- Titles must be action-led, 2 to 7 words, and no longer than 48 characters.
- Avoid jargon, acronyms, medical or scientific wording, and formal phrases such as "mastering" or "methodology".
- Use a technical term only when no plain alternative exists, then explain it immediately in simple words.
- Avoid "Interphalangeal Joint Mapping"; prefer "Learn How Your Fingers Move".
- Avoid "Mastering Chromatic Modulation"; prefer "Practice Smooth Key Changes".

Output formatting rules:
You MUST return ONLY a valid JSON object. Do not include markdown tags. Use this exact schema:
{
  "hobby": "string",
  "level": "string",
  "goal": "string",
  "milestones": [
    { "title": "string" },
    { "title": "string" },
    { "title": "string" },
    { "title": "string" }
  ]
}
''';

      final rawText = await _generateText(prompt);
      print('[GeminiService] Quest plan API call succeeded');
      final jsonMap = _extractJsonObject(rawText);
      final milestonesDynamic = jsonMap['milestones'] as List<dynamic>?;
      final milestones = (milestonesDynamic ?? const <dynamic>[])
          .map((item) {
            if (item is Map<String, dynamic>) {
              return MilestoneModel.fromJson(item);
            }

            if (item is Map) {
              return MilestoneModel.fromJson(Map<String, dynamic>.from(item));
            }

            return MilestoneModel(title: item.toString(), completed: false);
          })
          .where((item) => item.title.trim().isNotEmpty)
          .toList();

      if (milestones.length < 4) {
        throw const FormatException('Gemini returned insufficient milestones');
      }

      return QuestPlanModel(
        hobby: (jsonMap['hobby']?.toString().trim().isNotEmpty ?? false)
            ? jsonMap['hobby'].toString().trim()
            : ((jsonMap['hobbyName']?.toString().trim().isNotEmpty ?? false)
                  ? jsonMap['hobbyName'].toString().trim()
                  : hobby),
        level: (jsonMap['level']?.toString().trim().isNotEmpty ?? false)
            ? jsonMap['level'].toString().trim()
            : ((jsonMap['skillLevel']?.toString().trim().isNotEmpty ?? false)
                  ? jsonMap['skillLevel'].toString().trim()
                  : level),
        goal: (jsonMap['goal']?.toString().trim().isNotEmpty ?? false)
            ? jsonMap['goal'].toString().trim()
            : ((jsonMap['customGoal']?.toString().trim().isNotEmpty ?? false)
                  ? jsonMap['customGoal'].toString().trim()
                  : normalizedGoal),
        learningPace:
            (jsonMap['learningPace']?.toString().trim().isNotEmpty ?? false)
            ? jsonMap['learningPace'].toString().trim()
            : ((jsonMap['frequency']?.toString().trim().isNotEmpty ?? false)
                  ? jsonMap['frequency'].toString().trim()
                  : learningPace),
        progress: (jsonMap['progress'] as int?) ?? 0,
        milestones: milestones.take(4).toList(),
        quests: const [],
      );
    } catch (e) {
      print('[GeminiService] Quest plan API call failed: $e');
      return _buildFallbackQuestPlan(
        hobby: hobby,
        level: level,
        goal: normalizedGoal,
        learningPace: learningPace,
      );
    }
  }

  Future<GoalValidationResult> validateGoal({
    required String hobby,
    required String level,
    required String goal,
  }) async {
    final localValidation = _validateGoalLocally(hobby: hobby, goal: goal);

    if (!localValidation.isValid) {
      return localValidation;
    }

    if (!hasApiKey) {
      return localValidation;
    }

    try {
      final prompt =
          '''
You are a goal validator for a gamified hobby learning app.

User Context:
- Hobby: $hobby
- Skill Level: $level
- Goal: $goal

Instructions:
Evaluate whether this goal is valid for the hobby and skill level.
Check:
1. Is the goal RELEVANT to the hobby?
2. Is it APPROPRIATELY SCOPED for a $level learner? (not too easy, not impossibly hard)
3. Is it SPECIFIC ENOUGH to generate a step-by-step learning plan?

Output formatting rules:
You MUST return ONLY a valid JSON object. Do not include markdown tags.
Use this exact schema:
{
  "is_valid": true or false,
  "reason": "If not valid, explain why in a helpful way. If valid, keep empty."
}
''';

      final rawText = await _generateText(prompt);
      final jsonMap = _extractJsonObject(rawText);

      final isValid = _readBool(jsonMap['is_valid'] ?? jsonMap['isValid']);
      if (isValid == null) {
        return localValidation;
      }

      final reason = jsonMap['reason']?.toString().trim() ?? '';

      return GoalValidationResult(isValid: isValid, reason: reason);
    } catch (e) {
      print('[GeminiService] Goal validation API call failed: $e');
      return localValidation;
    }
  }

  Future<List<QuestNodeModel>> generatePhaseDAG({
    required String hobby,
    required String level,
    required String goal,
    required String learningPace,
    required String milestoneTitle,
    required String milestoneNumber,
  }) async {
    print('--- [GeminiService] generatePhaseDAG TRIGGERED ---');
    final normalizedGoal = goal.trim().isEmpty ? 'Master $hobby' : goal.trim();

    if (!hasApiKey) {
      print('[GeminiService] ABORT: hasApiKey is FALSE. Returning fallback.');
      return _buildFallbackPhaseDag(
        hobby: hobby,
        milestoneNumber: milestoneNumber,
        learningPace: learningPace,
      );
    }

    try {
      print(
        '[GeminiService] Calling generatePhaseDAG API for $milestoneTitle quests...',
      );

      final prompt =
          '''
Act as a friendly hobby coach for $hobby.
Break each skill into clear, practical tasks that a new learner can understand.

User Context:
- Hobby: $hobby
- Skill Level: $level
- Goal: $normalizedGoal
- Preferred Learning Pace: $learningPace
- Current Milestone Focus: $milestoneTitle

Instructions:
1. Generate a localized Skill Tree (Directed Acyclic Graph) for THIS MILESTONE ONLY.
2. Generate EXACTLY 20 skill nodes for the current phase only.
3. Every node must have dependencies to create a logical learning path. Foundational skills should have empty dependencies []. Advanced skills MUST depend on earlier node_ids.
4. STRICT TYPE DEFINITIONS:
If - "knowledge": Purely mental or theory-based. The user ONLY needs their eyes and brain.
   - "practice": Physical, hands-on drills to build muscle memory. 
   - "challenge": A major boss-level practical task combining multiple skills, requiring a photo upload for AI grading.
5. Make every title action-led and make every task easy to understand at first reading.
6. Parallel execution is mandatory: the graph MUST NOT be a single straight line. Create multiple parallel branches.
7. Exactly 3 foundational root nodes MUST have empty dependencies: "depends_on": []. 
8. Convergence is required: advanced nodes should depend on multiple prior nodes from different branches.
9. STRICT MATH RULE: Nodes must be logically numbered from 1 to 20. A node's "depends_on" array can ONLY contain node IDs that are strictly LESS than its own ID. This guarantees no infinite loops.
10. Generate exactly 3 image_rubric criteria for every node. Each criterion must describe one task-specific quality that can be observed in a photo. Never claim a photo can prove taste, sound, pain, safety, or authenticity.

Plain-language rules:
- Use common everyday words for titles, descriptions, and steps.
- Titles must be action-led, 2 to 7 words, and no longer than 48 characters.
- Avoid jargon, acronyms, medical or scientific wording, and formal phrases such as "mastering" or "methodology".
- Use a technical term only when no plain alternative exists, then explain it immediately in simple words.
- Descriptions must use 1 or 2 short sentences.
- Start every step with a clear verb and keep it to about 14 words or fewer.
- Avoid "Interphalangeal Joint Mapping"; prefer "Learn How Your Fingers Move".
- Avoid "Mastering Chromatic Modulation"; prefer "Practice Smooth Key Changes".

Output formatting rules:
You MUST return ONLY a valid JSON object. Do not include markdown tags like ```json. Use this exact schema:
{
  "nodes": [
    {
      "node_id": Integer (1 to 20),
      "title": "String",
      "desc": "String",
      "steps": [
        "String",
        "String",
        "String",
        "String",
        "String (You MUST provide exactly 5 steps, even if some are very simple. Do not output fewer than 5 steps.)"
      ],
      "duration_minutes": Integer (estimated time to complete this node, within 5 to 60 minutes range),
      "type": "String", 
      "youtube_search_query": "String (a 3-to-5 word YouTube search query for this specific skill node)",
      "image_rubric": [
        "String (observable criterion 1, maximum 120 characters)",
        "String (observable criterion 2, maximum 120 characters)",
        "String (observable criterion 3, maximum 120 characters)"
      ],
      "depends_on": ["array of previous node_ids"]
    }
  ]
}
''';

      final rawText = await _generateText(prompt);

      debugPrint(
        '[GeminiService] RAW API OUTPUT:\n$rawText\n-------------------',
      );

      final jsonMap = _extractJsonObject(rawText);
      final listDynamic =
          jsonMap['nodes'] as List<dynamic>? ?? const <dynamic>[];

      final parsed = <QuestNodeModel>[];
      for (final item in listDynamic) {
        try {
          if (item is Map<String, dynamic>) {
            final rawId = (item['node_id'] ?? item['id'] ?? '')
                .toString()
                .trim();
            final formattedNodeId = '${milestoneNumber}_node_$rawId';

            item['node_id'] = formattedNodeId;

            final rawDependsOn = item['depends_on'] ?? item['dependsOn'];
            if (rawDependsOn is List) {
              item['depends_on'] = rawDependsOn
                  .map((dep) => '${milestoneNumber}_node_$dep')
                  .toList();
            }

            final node = QuestNodeModel.fromJson(item);
            final sanitizedType = _sanitizeType(node.type);

            parsed.add(
              node.copyWith(
                nodeId: formattedNodeId,
                type: sanitizedType,
                xpReward: _xpRewardForType(sanitizedType),
                imageRubric: normalizeImageRubric(
                  item['image_rubric'] ?? item['imageRubric'],
                  title: node.title,
                  description: node.desc,
                ),
              ),
            );
            continue;
          }

          if (item is Map) {
            final rawMap = Map<String, dynamic>.from(item);
            final rawId = (rawMap['node_id'] ?? rawMap['id'] ?? '')
                .toString()
                .trim();
            final formattedNodeId = '${milestoneNumber}_node_$rawId';

            rawMap['node_id'] = formattedNodeId;

            final rawDependsOn = rawMap['depends_on'] ?? rawMap['dependsOn'];
            if (rawDependsOn is List) {
              rawMap['depends_on'] = rawDependsOn
                  .map((dep) => '${milestoneNumber}_node_$dep')
                  .toList();
            }

            final node = QuestNodeModel.fromJson(rawMap);
            final sanitizedType = _sanitizeType(node.type);

            parsed.add(
              node.copyWith(
                nodeId: formattedNodeId,
                type: sanitizedType,
                xpReward: _xpRewardForType(sanitizedType),
                imageRubric: normalizeImageRubric(
                  rawMap['image_rubric'] ?? rawMap['imageRubric'],
                  title: node.title,
                  description: node.desc,
                ),
              ),
            );
            continue;
          }

          parsed.add(
            QuestNodeModel(
              nodeId: '${milestoneNumber}_node_${parsed.length + 1}',
              title: item.toString(),
              desc: 'Practice step for $hobby',
              steps: [
                'Open the task and review the goal.',
                'Do one concrete action toward the goal.',
                'Check the result and note one improvement.',
              ],
              xpReward: _xpRewardForType('practice'),
              type: 'practice',
              durationMinutes: 10,
              dependsOn: const [],
              imageRubric: fallbackImageRubric(
                title: item.toString(),
                description: 'Practice step for $hobby',
              ),
            ),
          );
        } catch (e) {
          debugPrint('[GeminiService] Failed to parse individual node: $e');
        }
      }

      final nodes = <QuestNodeModel>[];
      nodes.addAll(parsed);

      if (nodes.length < 20) {
        final padCount = 20 - nodes.length;
        final variants = _questTemplatesForHobby(hobby);
        for (var i = 0; i < padCount; i++) {
          final idx = i % variants.length;
          nodes.add(
            QuestNodeModel(
              nodeId: '${milestoneNumber}_node_${nodes.length + 1}',
              title: variants[idx]['title']!,
              desc: variants[idx]['desc']!,
              steps: [
                'Read the task description carefully.',
                'Complete the practice step for this node.',
                'Reflect on what you learned.',
              ],
              xpReward: _xpRewardForType('practice'),
              type: 'practice',
              durationMinutes: 15,
              dependsOn: const [],
              imageRubric: fallbackImageRubric(
                title: variants[idx]['title']!,
                description: variants[idx]['desc']!,
              ),
            ),
          );
        }
      }

      return _ensureMinimumReadyNodes(nodes.take(20).toList(), minimumRoots: 3);
    } catch (e, stackTrace) {
      print('[GeminiService] Phase DAG API call failed: $e');
      print('--- DEBUG START ---');
      print('[GeminiService] Exception Type: ${e.runtimeType}');
      print('[GeminiService] Exception Details: $e');
      print('[GeminiService] Stack Trace:\n$stackTrace');
      print('--- DEBUG END ---');
      return _buildFallbackPhaseDag(
        hobby: hobby,
        milestoneNumber: milestoneNumber,
        learningPace: learningPace,
      );
    }
  }

  /// Generate one alternative quest title/description pair for a quest reroll.
  /// Returns a map with `title` and `desc`, or a fallback pair on failure.
  Future<Map<String, dynamic>> generateAlternativeQuest({
    required String hobby,
    required String nodeTitle,
    required String nodeDesc,
    required String learningPace,
    required String milestoneTitle,
    required String questType,
    required int durationMinutes,
    required List<String> existingImageRubric,
  }) async {
    if (!hasApiKey) {
      print(
        '[GeminiService] No API key found for alternative quest generation.',
      );
      return _alternativeQuestFallback(
        hobby: hobby,
        currentTask: nodeTitle,
        includeImageRubric: existingImageRubric.isNotEmpty,
      );
    }

    try {
      print('[GeminiService] Calling generateAlternativeQuestTitle API...');
      final prompt =
          '''

Act as a friendly hobby coach for $hobby.
The user has decided to "Reroll" (skip) their current daily quest.
Your job is to generate EXACTLY ONE alternative quest that teaches a similar underlying concept for their current milestone, but uses a completely different approach or mechanic.


User Context:
- Hobby: $hobby
- Preferred Learning Pace: $learningPace
- Current Milestone Focus: $milestoneTitle

The REJECTED Quest (DO NOT DUPLICATE THIS):
- Title: $nodeTitle
- Description: $nodeDesc

Instructions:
1. Generate EXACTLY ONE new skill node to replace the rejected quest.
2. It must be a completely different task/exercise from the rejected one, but still relevant to the "$milestoneTitle".
3. Make the title action-led and immediately understandable.
4. The new quest MUST strictly be a "$questType" task that takes approximately $durationMinutes minutes to complete. 
5. STRICT TYPE DEFINITIONS:
   - "knowledge": Purely mental or theory-based. The user ONLY needs their eyes and brain.
   - "practice": Physical, hands-on drills to build muscle memory. 
   - "challenge": A major boss-level practical task combining multiple skills, requiring a photo upload for AI grading.
${existingImageRubric.isNotEmpty ? '6. Generate exactly 3 task-specific image_rubric criteria that can be judged from a photo. Each must be 120 characters or fewer.' : ''}

Plain-language rules:
- Use common everyday words for the title, description, and steps.
- The title must be action-led, 2 to 7 words, and no longer than 48 characters.
- Avoid jargon, acronyms, medical or scientific wording, and formal phrases such as "mastering" or "methodology".
- Use a technical term only when no plain alternative exists, then explain it immediately in simple words.
- Use 1 or 2 short sentences for the description.
- Start every step with a clear verb and keep it to about 14 words or fewer.
- Avoid "Interphalangeal Joint Mapping"; prefer "Learn How Your Fingers Move".
- Avoid "Mastering Chromatic Modulation"; prefer "Practice Smooth Key Changes".


Output formatting rules:
You MUST return ONLY a valid JSON object. Use this exact schema:
{
  "title": "String",
  "desc": "String",
  "steps": [
    "String",
    "String",
    "String",
    "String",
    "String (You MUST provide exactly 5 steps, even if some are very simple. Do not output fewer than 5 steps.)"
  ],
  "youtube_search_query": "String (3-to-5 word YouTube search query for this specific skill node)"${existingImageRubric.isNotEmpty ? ',\n  "image_rubric": ["observable criterion 1", "observable criterion 2", "observable criterion 3"]' : ''}
}
''';

      final rawText = await _generateText(prompt);
      print('[GeminiService] Alternative task title API call succeeded');
      final jsonMap = _extractJsonObject(rawText);

      debugPrint(
        '[GeminiService] RAW API OUTPUT:\n$rawText\n-------------------',
      );

      final title = (jsonMap['title']?.toString().trim().isNotEmpty ?? false)
          ? jsonMap['title'].toString().trim()
          : _getAlternativeTaskFallback(
              hobby: hobby,
              currentTask: nodeTitle,
            )['title']!;
      final desc = (jsonMap['desc']?.toString().trim().isNotEmpty ?? false)
          ? jsonMap['desc'].toString().trim()
          : 'Complete a focused step for $hobby today.';
      final steps = (jsonMap['steps'] is List)
          ? (jsonMap['steps'] as List).map((e) => e.toString().trim()).toList()
          : [
              'Step 1: Understand the basics.',
              'Step 2: Practice the fundamentals.',
              'Step 3: Apply your knowledge.',
            ];
      final youtubeSearchQuery =
          (jsonMap['youtube_search_query']?.toString().trim().isNotEmpty ??
              false)
          ? jsonMap['youtube_search_query'].toString().trim()
          : '$hobby $nodeTitle';
      final imageRubric = existingImageRubric.isEmpty
          ? const <String>[]
          : normalizeImageRubric(
              jsonMap['image_rubric'] ?? jsonMap['imageRubric'],
              title: title,
              description: desc,
            );

      return {
        'title': title,
        'desc': desc,
        'steps': steps,
        'youtube_search_query': youtubeSearchQuery,
        if (imageRubric.isNotEmpty) 'image_rubric': imageRubric,
      };
    } catch (e) {
      print('[GeminiService] Alternative task title API call failed: $e');
      return _alternativeQuestFallback(
        hobby: hobby,
        currentTask: nodeTitle,
        includeImageRubric: existingImageRubric.isNotEmpty,
      );
    }
  }

  /// Backward-compatible alias for callers that still expect a single title.
  Future<String> generateAlternativeQuestTitle({
    required String hobby,
    required String nodeTitle,
    required String nodeDesc,
    required String milestoneTitle,
    required String questType,
    required String learningPace,
    required int durationMinutes,
    List<String> existingImageRubric = const [],
  }) async {
    final alternative = await generateAlternativeQuest(
      hobby: hobby,
      nodeTitle: nodeTitle,
      nodeDesc: nodeDesc,
      learningPace: learningPace,
      milestoneTitle: milestoneTitle,
      questType: questType,
      durationMinutes: durationMinutes,
      existingImageRubric: existingImageRubric,
    );
    return alternative['title'] ??
        _getAlternativeTaskFallback(
          hobby: hobby,
          currentTask: nodeTitle,
        )['title']!;
  }

  Future<GrowthLetterDraft> generateGrowthLetter({
    required String nickname,
    required String hobby,
    required int questCount,
    required List<String> questTitles,
    required List<String> reflections,
  }) async {
    if (!hasApiKey) {
      return _buildFallbackGrowthLetterDraft(
        nickname: nickname,
        hobby: hobby,
        questCount: questCount,
        reflections: reflections,
      );
    }

    try {
      final prompt =
          '''
You are writing a warm weekly growth letter for a gamified hobby learning app.
The user is learning $hobby.

User:
- Name: $nickname
- Completed quests this week: $questCount
- Quest titles: ${questTitles.isEmpty ? 'None provided' : questTitles.join(' | ')}
- Reflection notes: ${reflections.isEmpty ? 'None provided' : reflections.join(' | ')}

Return valid JSON only with this exact shape:
{
  "letter": "Dear $nickname,...",
  "strongestGrowth": "2 to 4 words",
  "focusArea": "2 to 4 words",
  "nextWeekFocus": "2 to 4 words"
}

Instructions:
1. The letter must write directly to the user as a short letter.
2. The letter must start with "Dear $nickname,".
3. Briefly acknowledge what the user worked on this week.
4. Mention one struggle, pattern, or improvement from the reflections.
5. Keep the letter between 70 and 110 words. Use 4 short paragraphs. Each paragraph should be 1 sentence only.
6. strongestGrowth must name the user's best growth pattern from the quests/reflections.
7. focusArea must name one specific skill or habit that needs attention.
8. nextWeekFocus must name one specific next practice path.
9. Keep chip values short, natural, and specific. Do not use markdown, bullets, headings, or emojis.
''';

      final text = await _generateText(prompt);
      if (text.isEmpty) {
        throw const FormatException('Empty growth letter response');
      }

      final json = _extractJsonObject(text);
      final letter = json['letter']?.toString().trim() ?? '';
      if (letter.isEmpty) {
        throw const FormatException('Empty growth letter field');
      }

      return GrowthLetterDraft(
        letter: letter,
        strongestGrowth: _readShortString(
          json['strongestGrowth'],
          fallback: 'Persistence',
        ),
        focusArea: _readShortString(
          json['focusArea'],
          fallback: 'Practice details',
        ),
        nextWeekFocus: _readShortString(
          json['nextWeekFocus'],
          fallback: 'Guided practice',
        ),
      );
    } catch (e) {
      print('[GeminiService] Growth letter API call failed: $e');
      return _buildFallbackGrowthLetterDraft(
        nickname: nickname,
        hobby: hobby,
        questCount: questCount,
        reflections: reflections,
      );
    }
  }

  Future<Map<String, dynamic>?> generateQuestImageFeedback({
    required XFile imageFile,
    required String hobby,
    required String questTitle,
    required String questDescription,
    required String questSteps,
    required String questType,
    required String reflectionNote,
    required List<String> imageRubric,
  }) async {
    if (!hasApiKey) {
      return null;
    }

    try {
      print('[GeminiService] Calling generateQuestImageFeedback API...');
      final bytes = await imageFile.readAsBytes();
      final mimeType = _guessMimeType(imageFile.name);
      final hasRubric = imageRubric.length == questRubricSize;
      final rubricText = imageRubric
          .asMap()
          .entries
          .map((entry) => '${entry.key + 1}. ${entry.value}')
          .join('\n');

      final prompt = hasRubric
          ? '''
Act as Hobie the Fox, a careful and encouraging visual reviewer for $hobby.
The learner submitted a photo and reflection for this quest.

Quest Context:
- Title: $questTitle
- Type: $questType
- Description: $questDescription
- Steps: $questSteps
- Reflection: ${reflectionNote.trim().isEmpty ? 'None provided' : reflectionNote.trim()}

Assess only what is visibly supported by the photo. Do not claim to judge taste,
sound, pain, safety, authenticity, or anything else a photo cannot establish.

Use these criteria in this exact order:
$rubricText

Rules:
1. is_evidence_relevant is true only when the photo clearly shows work related to this quest.
2. If evidence is relevant, return exactly three results in criterion order.
   If evidence is irrelevant, results may be an empty array.
3. Mark met true only when the visible evidence demonstrates the criterion.
4. Give one concrete visual observation per criterion, maximum 12 words.
5. Address the reflection when relevant without inventing facts.
6. Keep the greeting to 4 words and next_step to 10 words.
7. next_step must be one concrete action for the learner's next photo attempt.
8. Return JSON only.

Use this exact schema:
{
  "is_evidence_relevant": true,
  "greeting": "String",
  "results": [
    {"met": true, "feedback": "String"},
    {"met": false, "feedback": "String"},
    {"met": true, "feedback": "String"}
  ],
  "next_step": "String"
}
'''
          : '''
  Act as Hobie the Fox, an expert, highly observant, and energetic AI tutor for $hobby.
  The user has just completed a quest and submitted a photo of their work along with a reflection note.

  Quest Context:
  - Hobby: $hobby
  - Quest Title: $questTitle
  - Quest Type: $questType
  - Quest Description: $questDescription
  - Required Steps for this Quest: $questSteps
  - Reflection Note: ${reflectionNote.trim().isEmpty ? 'None provided' : reflectionNote.trim()}

  CRITICAL EVALUATION RULES:
  1. LENIENT BUT REALISTIC VALIDATION: Evaluate based on "$questType". 
    - If "knowledge": Be highly lenient. Accept photos of study notes, books, or screens.
    - If "practice" or "challenge": Demand physical proof of the hobby. Reject completely unrelated spam.
    
  2. ACTIVE LISTENING (The Reflection Rule): You MUST act like a real teacher who listens!
    - If the user wrote a Reflection Note, your feedback MUST directly address what they said. 
    - If they express frustration or struggle in the note, show empathy and validate their effort before giving advice. 
    - If they share a success, celebrate that specific win!
    - If the note is "None provided", rely entirely on the visual analysis of the photo.

  3. HOBIE'S PERSONA: You are Hobie the Fox! Be playful, highly energetic, and wildly encouraging. Use gamified terms (e.g., "Hero", "Quest").

  4. THE FEEDBACK FORMULA (Strict Word Limits):
    To prevent user reading fatigue, you MUST split your feedback into three distinct parts, strictly obeying these maximum word counts:
    - Greeting (Max 5 words): A short, high-energy validation.
    - Observation (Max 15 words): Prove you are paying attention! Explicitly mention a physical detail you see in the photo AND directly respond to their Reflection Note. 
    - Tip (Max 15 words): Look at the "Required Steps". Provide one specific, mechanical technique to overcome their struggle or improve next time. No generic fluff.

  5. JSON FORMAT: You MUST return ONLY a valid JSON object. Do not include markdown tags like ```json.

  Use this exact JSON schema:
  {
    "is_approved": Boolean (true if genuine effort, false if spam/unrelated),
    "greeting": "String (Max 5 words. Cheerful, high-energy validation)",
    "observation": "String (Max 15 words. Must address the reflection note and a visual detail)",
    "tip": "String (Max 15 words. Specific actionable improvement based on steps)"
  }''';

      final rawText = await _generateText(
        prompt,
        mimeType: mimeType,
        imageBytes: bytes,
      );
      if (rawText.isEmpty) {
        return null;
      }

      final jsonMap = _extractJsonObject(rawText);
      if (hasRubric) {
        final parsedFeedback = parseRubricImageFeedbackResponse(
          jsonMap,
          imageRubric,
        );
        if (parsedFeedback == null) {
          throw const FormatException('Invalid rubric feedback response');
        }
        return parsedFeedback;
      }

      final isApprovedRaw = jsonMap['is_approved'];
      final greetingRaw = jsonMap['greeting'];
      final observationRaw = jsonMap['observation'];
      final tipRaw = jsonMap['tip'];

      final isApproved = isApprovedRaw is bool
          ? isApprovedRaw
          : isApprovedRaw?.toString().toLowerCase() == 'true';

      final greeting = greetingRaw?.toString().trim() ?? '';
      final observation = observationRaw?.toString().trim() ?? '';
      final tip = tipRaw?.toString().trim() ?? '';

      return {
        'is_approved': isApproved,
        'greeting': greeting,
        'observation': observation,
        'tip': tip,
      };
    } catch (e) {
      print('[GeminiService] Quest image feedback call failed: $e');
      return null;
    }
  }

  Map<String, dynamic> _getAlternativeTaskFallback({
    required String hobby,
    required String currentTask,
  }) {
    final fallbacks = [
      {
        'title': 'Alternative Study',
        'desc': 'Watch a 5-minute video explaining $currentTask.',
      },
      {
        'title': 'Mental Reps',
        'desc': 'Visualize the steps required to complete $currentTask.',
      },
      {
        'title': 'Break it Down',
        'desc': 'Write down the 3 hardest parts about $currentTask.',
      },
    ];

    final random = Random(DateTime.now().millisecondsSinceEpoch);
    return fallbacks[random.nextInt(fallbacks.length)];
  }

  Map<String, dynamic> _alternativeQuestFallback({
    required String hobby,
    required String currentTask,
    required bool includeImageRubric,
  }) {
    final fallback = Map<String, dynamic>.from(
      _getAlternativeTaskFallback(hobby: hobby, currentTask: currentTask),
    );
    final fallbackTitle = fallback['title']?.toString() ?? currentTask;
    fallback['steps'] = [
      'Review what this alternative asks you to do.',
      'Prepare the materials you need.',
      'Complete one focused attempt.',
      'Check the result against the task.',
      'Note one improvement for next time.',
    ];
    fallback['youtube_search_query'] = '$hobby $fallbackTitle';
    if (includeImageRubric) {
      fallback['image_rubric'] = fallbackImageRubric(
        title: fallbackTitle,
        description: fallback['desc']?.toString() ?? '',
      );
    }
    return fallback;
  }

  GrowthLetterDraft _buildFallbackGrowthLetterDraft({
    required String nickname,
    required String hobby,
    required int questCount,
    required List<String> reflections,
  }) {
    final reflectionHint = reflections.isEmpty
        ? 'Even without long notes, your completed quests show steady effort.'
        : 'Your reflections show that you are starting to notice what feels difficult and what improves with practice.';

    final letter =
        'Dear $nickname,\n\n'
        'This week, your $hobby tree grew through $questCount quest${questCount == 1 ? '' : 's'}. '
        '$reflectionHint\n\n'
        'Your strongest growth this week: you kept showing up and turning small actions into progress.\n\n'
        'Next week, your path will focus on one clear practice step at a time.';

    return GrowthLetterDraft(
      letter: letter,
      strongestGrowth: 'Persistence',
      focusArea: reflections.isEmpty ? 'Reflection notes' : 'Practice details',
      nextWeekFocus: 'Guided practice',
    );
  }

  String _readShortString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return fallback;
    return text.length <= 48 ? text : text.substring(0, 48).trim();
  }

  Map<String, dynamic> _extractJsonObject(String source) {
    final trimmed = source.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return jsonDecode(trimmed) as Map<String, dynamic>;
    }

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw const FormatException('No JSON object found in model response');
    }

    final raw = trimmed.substring(start, end + 1);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  QuestPlanModel _buildFallbackQuestPlan({
    required String hobby,
    required String level,
    required String goal,
    required String learningPace,
  }) {
    return QuestPlanModel(
      hobby: hobby,
      level: level,
      goal: goal,
      learningPace: learningPace,
      currentMilestoneIndex: 0,
      progress: 0,
      milestones: _buildMilestones(hobby: hobby, level: level, goal: goal),
      quests: _buildFallbackPhaseDag(
        hobby: hobby,
        milestoneNumber: '1',
        learningPace: learningPace,
      ),
    );
  }

  GoalValidationResult _validateGoalLocally({
    required String hobby,
    required String goal,
  }) {
    final normalizedGoal = goal.trim();
    if (normalizedGoal.isEmpty) {
      return const GoalValidationResult(
        isValid: false,
        reason: 'Please define your quest.',
      );
    }

    if (normalizedGoal.length < 4) {
      return const GoalValidationResult(
        isValid: false,
        reason: 'Add a little more detail to your goal.',
      );
    }

    final words = normalizedGoal
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;

    if (words < 2 && hobby.trim().isEmpty) {
      return const GoalValidationResult(
        isValid: false,
        reason: 'Make your goal specific enough to build a plan.',
      );
    }

    return const GoalValidationResult(isValid: true, reason: '');
  }

  bool? _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return null;
  }

  String _sanitizeType(String type) {
    const allowed = {'practice', 'knowledge', 'challenge'};
    final normalized = type.toLowerCase().trim();
    if (allowed.contains(normalized)) {
      return normalized;
    }
    return 'practice';
  }

  int _xpRewardForType(String type) {
    switch (_sanitizeType(type)) {
      case 'practice':
        return 100;
      case 'challenge':
        return 150;
      case 'knowledge':
      default:
        return 50;
    }
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  List<MilestoneModel> _buildMilestones({
    required String hobby,
    required String level,
    required String goal,
  }) {
    return <MilestoneModel>[
      MilestoneModel(
        title: 'Phase 1: Learn core $hobby fundamentals',
        completed: false,
      ),
      MilestoneModel(
        title: 'Phase 2: Build a repeatable ${level.toLowerCase()} routine',
        completed: false,
      ),
      MilestoneModel(
        title: 'Phase 3: Complete one measurable mini-project',
        completed: false,
      ),
      MilestoneModel(
        title: 'Phase 4: Reach your boss goal: $goal',
        completed: false,
      ),
    ];
  }

  List<Map<String, String>> _questTemplatesForHobby(String hobby) {
    final normalized = hobby.toLowerCase();

    if (normalized.contains('coding')) {
      return [
        {
          'title': 'Debug Sprint',
          'desc': 'Fix one bug and write a short note about the root cause.',
        },
        {
          'title': 'Refactor Drill',
          'desc':
              'Refactor one small function for readability and naming clarity.',
        },
        {
          'title': 'Code Reading',
          'desc': 'Read one module and explain its flow in 5 bullet points.',
        },
      ];
    }

    if (normalized.contains('guitar') ||
        normalized.contains('piano') ||
        normalized.contains('sing')) {
      return [
        {
          'title': 'Technique Loop',
          'desc':
              'Practice one technique slowly for 15 minutes with a metronome.',
        },
        {
          'title': 'Repertoire Step',
          'desc': 'Learn one new section from a song you enjoy.',
        },
        {
          'title': 'Playback Review',
          'desc':
              'Record a take and note one strength and one improvement area.',
        },
      ];
    }

    if (normalized.contains('drawing') ||
        normalized.contains('painting') ||
        normalized.contains('photography')) {
      return [
        {
          'title': 'Study Session',
          'desc': 'Create one focused study on light, shape, or composition.',
        },
        {
          'title': 'Reference Challenge',
          'desc': 'Recreate one reference with your own style constraints.',
        },
        {
          'title': 'Portfolio Pick',
          'desc': 'Choose your best piece and write one improvement goal.',
        },
      ];
    }

    return [
      {
        'title': 'Focus Block',
        'desc': 'Do one focused practice block for 20 minutes.',
      },
      {
        'title': 'Knowledge Bite',
        'desc': 'Learn one concept and explain it in your own words.',
      },
      {
        'title': 'Output Challenge',
        'desc': 'Ship one small outcome and reflect on the process.',
      },
    ];
  }

  List<QuestNodeModel> _buildFallbackPhaseDag({
    required String hobby,
    required String milestoneNumber,
    required String learningPace,
  }) {
    final variants = _questTemplatesForHobby(hobby);
    final nodes = <QuestNodeModel>[];
    const laneCount = 3;
    final baseDurationMinutes = _durationFromLearningPace(learningPace);

    for (var i = 0; i < 20; i++) {
      final variant = variants[i % variants.length];
      final nodeId = '${milestoneNumber}_node_${i + 1}';
      final dependsOn = <String>[];
      final lane = i % laneCount;
      final step = i ~/ laneCount;
      if (step > 0) {
        final previousInLane = ((step - 1) * laneCount) + lane + 1;
        dependsOn.add('${milestoneNumber}_node_$previousInLane');
      }

      nodes.add(
        QuestNodeModel(
          nodeId: nodeId,
          title: variant['title']!,
          desc: variant['desc']!,
          steps: [
            'Start with the branch-specific skill.',
            'Follow the current node objective step by step.',
            'Check your result before moving on.',
          ],
          xpReward: _xpRewardForType(
            i % 5 == 4 ? 'challenge' : (i % 2 == 0 ? 'practice' : 'knowledge'),
          ),
          type: i % 5 == 4
              ? 'challenge'
              : (i % 2 == 0 ? 'practice' : 'knowledge'),
          durationMinutes: baseDurationMinutes,
          dependsOn: dependsOn,
          imageRubric: fallbackImageRubric(
            title: variant['title']!,
            description: variant['desc']!,
          ),
        ),
      );
    }

    return _ensureMinimumReadyNodes(nodes, minimumRoots: 3);
  }

  List<QuestNodeModel> _ensureMinimumReadyNodes(
    List<QuestNodeModel> nodes, {
    int minimumRoots = 3,
  }) {
    if (nodes.length <= minimumRoots) {
      return nodes;
    }

    final rootCount = nodes.where((node) => node.dependsOn.isEmpty).length;
    if (rootCount >= minimumRoots) {
      return nodes;
    }

    final knownIds = nodes.map((node) => node.nodeId).toSet();
    final normalized = nodes
        .map(
          (node) => node.copyWith(
            dependsOn: node.dependsOn.where(knownIds.contains).toList(),
          ),
        )
        .toList();

    for (var i = 0; i < minimumRoots && i < normalized.length; i++) {
      normalized[i] = normalized[i].copyWith(dependsOn: const []);
    }

    return normalized;
  }

  int _durationFromLearningPace(String learningPace) {
    final normalized = learningPace.toLowerCase();
    if (normalized.contains('casual')) return 10;
    if (normalized.contains('steady')) return 20;
    if (normalized.contains('hardcore')) return 35;

    final match = RegExp(r'(\d+)').firstMatch(learningPace);
    if (match == null) {
      return 15;
    }

    final parsed = int.tryParse(match.group(1)!);
    if (parsed == null || parsed <= 0) {
      return 15;
    }

    return parsed;
  }
}
