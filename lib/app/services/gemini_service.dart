import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/milestone_model.dart';
import '../models/quest_node_model.dart';
import '../models/quest_plan_model.dart';

class ValidationResult {
  final bool isValid;
  final String? error;

  const ValidationResult({required this.isValid, this.error});

  const ValidationResult.valid() : isValid = true, error = null;

  const ValidationResult.invalid(this.error) : isValid = false;
}

class GeminiService {
  String get _apiKey {
    final key = dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['API_KEY'] ?? '';
    return key.trim();
  }

  // Initialize the Gemini Model
  GenerativeModel get _model {
    return GenerativeModel(model: 'gemini-3.1-flash-lite', apiKey: _apiKey);
  }

  bool get hasApiKey => _apiKey.isNotEmpty;

  ValidationResult validateOnboardingStep({
    required int step,
    required String nickname,
    required String birthDate,
    required String gender,
    required String category,
    required String hobby,
    required String level,
    required String goal,
    required String frequency,
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
        if (frequency.trim().isEmpty) {
          return const ValidationResult.invalid('Daily frequency is required');
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
    required String frequency,
  }) async {
    final normalizedGoal = goal.trim().isEmpty ? 'Master $hobby' : goal.trim();

    if (!hasApiKey) {
      final milestones = _buildMilestones(
        hobby: hobby,
        level: level,
        goal: normalizedGoal,
      );
      return QuestPlanModel(
        hobby: hobby,
        level: level,
        goal: normalizedGoal,
        frequency: frequency,
        currentMilestoneIndex: 0,
        progress: 0,
        milestones: milestones,
        quests: _buildFallbackPhaseDag(
          hobby: hobby,
          milestoneNumber: '1',
          frequency: frequency,
        ),
      );
    }

    try {
      print('[GeminiService] Calling generateQuestPlan API...');
      final prompt =
          '''
You are an expert tutor and quest planner for a gamified hobby app.
The user wants to learn $hobby. Their main goal is $normalizedGoal.
They consider themselves $level level and can commit $frequency daily. 

User Profile:
- Hobby: $hobby
- Skill Level: $level
- Goal: $normalizedGoal
- Daily Time Commitment: $frequency

Instructions:
1. Generate exactly 4 major Milestones that break this goal into logical phases.

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

      final response = await _model.generateContent([Content.text(prompt)]);
      print('[GeminiService] Quest plan API call succeeded');
      final rawText = response.text?.trim() ?? '';
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
        frequency: (jsonMap['frequency']?.toString().trim().isNotEmpty ?? false)
            ? jsonMap['frequency'].toString().trim()
            : frequency,
        progress: (jsonMap['progress'] as int?) ?? 0,
        milestones: milestones.take(4).toList(),
        quests: const [],
      );
    } catch (e) {
      print('[GeminiService] Quest plan API call failed: $e');
      return QuestPlanModel(
        hobby: hobby,
        level: level,
        goal: normalizedGoal,
        frequency: frequency,
        progress: 0,
        milestones: _buildMilestones(
          hobby: hobby,
          level: level,
          goal: normalizedGoal,
        ),
        quests: const [],
      );
    }
  }

  Future<List<QuestNodeModel>> generatePhaseDAG({
    required String hobby,
    required String level,
    required String goal,
    required String frequency,
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
        frequency: frequency,
      );
    }

    try {
      print(
        '[GeminiService] Calling generatePhaseDAG API for $milestoneTitle quests...',
      );

      final prompt =
          '''
Act as an elite, professional curriculum designer and expert instructor for $hobby. 
Your goal is to break down complex skills into professional, highly precise, and easy-to-follow micro-lessons.

User Context:
- Hobby: $hobby
- Skill Level: $level
- Goal: $normalizedGoal
- Preferred Learning Pace: $frequency
- Current Milestone Focus: $milestoneTitle

Instructions:
1. Generate a localized Skill Tree (Directed Acyclic Graph) for THIS MILESTONE ONLY.
2. Generate EXACTLY 20 skill nodes for the current phase only.
3. Every node must have dependencies to create a logical learning path. Foundational skills should have empty dependencies []. Advanced skills MUST depend on earlier node_ids.
4. STRICT TYPE DEFINITIONS:
If - "knowledge": Purely mental or theory-based. The user ONLY needs their eyes and brain.
   - "practice": Physical, hands-on drills to build muscle memory. 
   - "challenge": A major boss-level practical task combining multiple skills, requiring a photo upload for AI grading.
5. Titles and descriptions must sound like a professional syllabus. Do not use generic filler like "Learn how to do X." Use precise terms like "Mastering the X Technique."
6. Parallel execution is mandatory: the graph MUST NOT be a single straight line. Create multiple parallel branches.
7. Exactly 3 foundational root nodes MUST have empty dependencies: "depends_on": []. 
8. Convergence is required: advanced nodes should depend on multiple prior nodes from different branches.
9. STRICT MATH RULE: Nodes must be logically numbered from 1 to 20. A node's "depends_on" array can ONLY contain node IDs that are strictly LESS than its own ID. This guarantees no infinite loops.

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
      "depends_on": ["array of previous node_ids"]
    }
  ]
}
''';

      final response = await _model.generateContent([Content.text(prompt)]);

      final rawText = response.text?.trim() ?? '';

      debugPrint('[GeminiService] RAW API OUTPUT:\n$rawText\n-------------------');

      final jsonMap = _extractJsonObject(rawText);
      final listDynamic =
          jsonMap['nodes'] as List<dynamic>? ?? const <dynamic>[];

      // Convert dynamic items into QuestNodeModel instances
      final parsed = <QuestNodeModel>[];
      for (final item in listDynamic) {
        try {
          if (item is Map<String, dynamic>) {
            final rawId = (item['node_id'] ?? item['id'] ?? '').toString().trim();
            final formattedNodeId = '${milestoneNumber}_node_$rawId';
            
            // THE FIX: Override the integer with the formatted string BEFORE parsing
            item['node_id'] = formattedNodeId;

            // ALSO reformat depends_on entries so they match the formatted node IDs
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
              ),
            );
            continue;
          }

          if (item is Map) {
            final rawMap = Map<String, dynamic>.from(item);
            final rawId = (rawMap['node_id'] ?? rawMap['id'] ?? '').toString().trim();
            final formattedNodeId = '${milestoneNumber}_node_$rawId';
            
            // THE FIX: Override the integer with the formatted string BEFORE parsing
            rawMap['node_id'] = formattedNodeId;

            // ALSO reformat depends_on entries so they match the formatted node IDs
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
              ),
            );
            continue;
          }

          // Fallback for unexpected item shape
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
            ),
          );
        } catch (e) {
          // EXPOSE THE ERROR: Stop hiding the crash!
          debugPrint('[GeminiService] Failed to parse individual node: $e');
        }
      }

      final nodes = <QuestNodeModel>[];
      nodes.addAll(parsed);

      // Pad to 20 nodes if needed
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
        frequency: frequency,
      );
    }
  }

  /// Generate one alternative quest title/description pair for a quest reroll.
  /// Returns a map with `title` and `desc`, or a fallback pair on failure.
  Future<Map<String, dynamic>> generateAlternativeQuest({
    required String hobby,
    required String nodeTitle,
    required String nodeDesc,
    required String frequency,
    required String milestoneTitle,
    required String questType,
    required int durationMinutes,
  }) async {
    if (!hasApiKey) {
      print(
        '[GeminiService] No API key found for alternative quest generation.',
      );
      return _getAlternativeTaskFallback(hobby: hobby, currentTask: nodeTitle);
    }

    try {
      print('[GeminiService] Calling generateAlternativeQuestTitle API...');
      final prompt =
          '''

Act as an elite, professional curriculum designer and expert instructor for $hobby. 
The user has decided to "Reroll" (skip) their current daily quest.
Your job is to generate EXACTLY ONE alternative quest that teaches a similar underlying concept for their current milestone, but uses a completely different approach or mechanic.


User Context:
- Hobby: $hobby
- Current Milestone Focus: $milestoneTitle

The REJECTED Quest (DO NOT DUPLICATE THIS):
- Title: $nodeTitle
- Description: $nodeDesc

Instructions:
1. Generate EXACTLY ONE new skill node to replace the rejected quest.
2. It must be a completely different task/exercise from the rejected one, but still relevant to the "$milestoneTitle".
3. Titles and descriptions must sound like a professional syllabus. Do not use generic filler like "Learn how to do X." Use precise terms like "Mastering the X Technique."
4. The new quest MUST strictly be a "$questType" task that takes approximately $durationMinutes minutes to complete. 
5. STRICT TYPE DEFINITIONS:
   - "knowledge": Purely mental or theory-based. The user ONLY needs their eyes and brain.
   - "practice": Physical, hands-on drills to build muscle memory. 
   - "challenge": A major boss-level practical task combining multiple skills, requiring a photo upload for AI grading.


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
  "youtube_search_query": "String (3-to-5 word YouTube search query for this specific skill node)"
}
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      print('[GeminiService] Alternative task title API call succeeded');

      final rawText = response.text?.trim() ?? '';
      final jsonMap = _extractJsonObject(rawText);

      debugPrint('[GeminiService] RAW API OUTPUT:\n$rawText\n-------------------');

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

      return {
        'title': title,
        'desc': desc,
        'steps': steps,
        'youtube_search_query': youtubeSearchQuery,
      };
    } catch (e) {
      print('[GeminiService] Alternative task title API call failed: $e');
      return _getAlternativeTaskFallback(hobby: hobby, currentTask: nodeTitle);
    }
  }

  /// Backward-compatible alias for callers that still expect a single title.
  Future<String> generateAlternativeQuestTitle({
    required String hobby,
    required String nodeTitle,
    required String nodeDesc,
    required String milestoneTitle,
    required String questType,
    required String frequency,
    required int durationMinutes,
  }) async {
    final alternative = await generateAlternativeQuest(
      hobby: hobby,
      nodeTitle: nodeTitle,
      nodeDesc: nodeDesc,
      frequency: frequency,
      milestoneTitle: milestoneTitle,
      questType: questType,
      durationMinutes: durationMinutes,
    );
    return alternative['title'] ??
        _getAlternativeTaskFallback(
          hobby: hobby,
          currentTask: nodeTitle,
        )['title']!;
  }

  Future<Map<String, dynamic>?> generateQuestImageFeedback({
    required XFile imageFile,
    required String hobby,
    required String questTitle,
    required String questDescription,
    required String questSteps,
    required String questType,
    required String reflectionNote,
  }) async {
    if (!hasApiKey) {
      return null;
    }

    try {
      print('[GeminiService] Calling generateQuestImageFeedback API...');
      final bytes = await imageFile.readAsBytes();
      final mimeType = _guessMimeType(imageFile.name);

      final prompt =
          '''
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

      final response = await _model.generateContent([
        Content.multi([TextPart(prompt), DataPart(mimeType, bytes)]),
      ]);

      final rawText = response.text?.trim() ?? '';
      if (rawText.isEmpty) {
        return null;
      }

      final jsonMap = _extractJsonObject(rawText);
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

  List<QuestNodeModel> _buildFallbackQuests({
    required String hobby,
    required String level,
    required String focus,
  }) {
    final seed = DateTime.now().day;
    final variants = _questTemplatesForHobby(hobby);
    final random = Random(seed);
    variants.shuffle(random);

    return [
      QuestNodeModel(
        nodeId: 'q_${hobby.toLowerCase().replaceAll(' ', '_')}_1',
        title: variants[0]['title']!,
        desc: variants[0]['desc']!,
        steps: [
          'Read the topic overview.',
          'Try one guided example or drill.',
          'Write down one takeaway.',
        ],
        xpReward: _xpRewardForType('practice'),
        type: 'practice',
        durationMinutes: 15,
        dependsOn: const [],
      ),
      QuestNodeModel(
        nodeId: 'q_${hobby.toLowerCase().replaceAll(' ', '_')}_2',
        title: variants[1]['title']!,
        desc: variants[1]['desc']!,
        steps: [
          'Review the concept briefly.',
          'Apply it in a small exercise.',
          'Note one thing to improve next time.',
        ],
        xpReward: _xpRewardForType('knowledge'),
        type: 'knowledge',
        durationMinutes: 10,
        dependsOn: const [],
      ),
      QuestNodeModel(
        nodeId: 'q_${hobby.toLowerCase().replaceAll(' ', '_')}_3',
        title: 'Goal Push: ${_shorten(focus)}',
        desc: 'Take one concrete step today toward: $focus',
        steps: [
          'Break the goal into one small action.',
          'Complete the action now.',
          'Record the result or a quick note.',
        ],
        xpReward: _xpRewardForType('challenge'),
        type: 'challenge',
        durationMinutes: 30,
        dependsOn: const [],
      ),
    ];
  }

  List<QuestNodeModel> _parseQuests(
    List<dynamic>? questsDynamic, {
    required String hobby,
    required String level,
    required String focus,
  }) {
    final rawQuests = questsDynamic ?? const <dynamic>[];
    if (rawQuests.isEmpty) {
      return _buildFallbackQuests(hobby: hobby, level: level, focus: focus);
    }

    final parsed = rawQuests
        .map((item) {
          if (item is Map<String, dynamic>) {
            return QuestNodeModel.fromJson(item);
          }

          if (item is Map) {
            return QuestNodeModel.fromJson(Map<String, dynamic>.from(item));
          }

          return QuestNodeModel(
            nodeId: item.toString(),
            title: item.toString(),
            desc: 'Complete a focused step for $hobby today.',
            steps: [
              'Read the task once end to end.',
              'Do the smallest meaningful action.',
              'Capture one observation before finishing.',
            ],
            xpReward: 100,
            type: 'practice',
            durationMinutes: 15,
            dependsOn: const [],
          );
        })
        .where((quest) => quest.title.trim().isNotEmpty)
        .toList();

    if (parsed.length < 3) {
      return _buildFallbackQuests(hobby: hobby, level: level, focus: focus);
    }

    final normalized = parsed.take(3).toList();
    // Ensure at least one 'challenge' exists so UI can highlight a priority task.
    if (!normalized.any((quest) => quest.type == 'challenge')) {
      normalized[0] = normalized[0].copyWith(type: 'challenge');
    }

    return normalized
        .map((quest) => quest.copyWith(isCompleted: false, reflectionNote: ''))
        .toList();
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
    required String frequency,
  }) {
    final variants = _questTemplatesForHobby(hobby);
    final nodes = <QuestNodeModel>[];
    const laneCount = 3;
    final baseDurationMinutes = _durationFromFrequency(frequency);

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

  String _shorten(String text) {
    const maxLength = 36;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  int _durationFromFrequency(String frequency) {
    final match = RegExp(r'(\d+)').firstMatch(frequency);
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
