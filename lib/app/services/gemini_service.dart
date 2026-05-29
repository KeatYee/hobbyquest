import 'dart:convert';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/milestone_model.dart';
import '../models/quest_node_model.dart';
import '../models/quest_plan_model.dart';

class ValidationResult {
  final bool isValid;
  final String? error;

  const ValidationResult({required this.isValid, this.error});

  const ValidationResult.valid()
      : isValid = true,
        error = null;

  const ValidationResult.invalid(this.error) : isValid = false;
}

class GeminiService {
  String get _apiKey {
    final key = dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['API_KEY'] ?? '';
    return key.trim();
  }

  // Initialize the Gemini Model
  GenerativeModel get _model {
    return GenerativeModel(
      model: 'gemini-3.1-flash-lite',
      apiKey: _apiKey,
    );
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
      final milestones = _buildMilestones(hobby: hobby, level: level, goal: normalizedGoal);
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
      final prompt = '''
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
        milestones: _buildMilestones(hobby: hobby, level: level, goal: normalizedGoal),
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
  
    String focus = '',
  }) async {
    final normalizedGoal = goal.trim().isEmpty ? 'Master $hobby' : goal.trim();

    if (!hasApiKey) {
      return _buildFallbackPhaseDag(
        hobby: hobby,
        milestoneNumber: milestoneNumber,
        frequency: frequency,
      );
    }

    try {
      print('[GeminiService] Calling generatePhaseDAG API for $milestoneTitle quests...');

      final prompt = '''
Act as an expert instructor for $hobby.
The user is at skill level: $level.
Their CURRENT milestone is: $milestoneTitle.

User Context:
- Hobby: $hobby
- Skill Level: $level
     - Custom Goal: $normalizedGoal
- Daily Time Commitment: $frequency
- Current Milestone Focus: $milestoneTitle

Instructions:
1. Generate a localized Skill Tree (Directed Acyclic Graph) for THIS MILESTONE ONLY.
2. Generate EXACTLY 20 skill nodes for the current phase only.
3. Every node must have dependencies to create a logical learning path. Foundational skills should have empty dependencies []. Advanced skills MUST depend on earlier node_ids.
4. The 'title' should be a short, descriptive name for the skill.
5. The 'desc' should be a clear, actionable instruction for the skill (1-2 sentences)
6. For every node, generate a 'steps' array containing exactly 2 to 4 micro-steps. These steps must act as a mini-tutorial guiding the user exactly HOW to complete the task practically.
7. The 'type' MUST be exactly one of the following strings:
   - "knowledge" (reading theory or watching a quick tutorial)
   - "practice" (standard hands-on tasks to build muscle memory)
   - "challenge" (a major task where the user must snap a photo of their work for AI grading)

CRITICAL GRAPH RULES:
8. Parallel execution is mandatory: the graph MUST NOT be a single straight line. Create multiple parallel learning branches (for example theory, practice, and setup/equipment).
9. Exactly 3 foundational root nodes MUST have empty dependencies: "depends_on": []. This ensures the user starts with exactly 3 choices.
10. Convergence is required: advanced nodes should depend on multiple prior nodes from different branches (for example node_7 depends on node_2 and node_5).
11. STRICT MATH RULE: Nodes must be logically numbered from 1 to 20. A node's "depends_on" array can ONLY contain node IDs that are strictly LESS than its own ID (e.g., node_5 can depend on node_2, but never on node_6). This guarantees no infinite loops.


Output formatting rules:
You MUST return ONLY a valid JSON object. Do not include markdown tags like ```json. Use this exact schema:
{
  "nodes": [
    {
      "node_id": "${milestoneNumber}_node_1",
      "title": "string",
      "desc": "string (under 2 sentences, respecting $frequency)",
      "steps": [
        "String (Step 1 actionable instruction)",
        "String (Step 2 actionable instruction)"
      ],
      "type": "String (knowledge, practice, or challenge)", 
      "duration_minutes": Integer (estimate based on $frequency),
      "xp_reward": 100,
      "depends_on": ["array of previous node_ids"]
    }
  ]
}
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      print('[GeminiService] Phase DAG API call succeeded');
      final rawText = response.text?.trim() ?? '';
      final jsonMap = _extractJsonObject(rawText);
      final listDynamic = jsonMap['nodes'] as List<dynamic>? ?? const <dynamic>[];

      // Convert dynamic items into QuestNodeModel instances
      final parsed = <QuestNodeModel>[];
      for (final item in listDynamic) {
        try {
          if (item is Map<String, dynamic>) {
            final node = QuestNodeModel.fromJson(item);
            parsed.add(node.copyWith(type: _sanitizeType(node.type)));
            continue;
          }

          if (item is Map) {
            final node = QuestNodeModel.fromJson(Map<String, dynamic>.from(item));
            parsed.add(node.copyWith(type: _sanitizeType(node.type)));
            continue;
          }

          // Fallback for unexpected item shape
          parsed.add(QuestNodeModel(
            nodeId: '${milestoneNumber}_node_${parsed.length + 1}',
            title: item.toString(),
            desc: 'Practice step for $hobby',
            steps: [
              'Open the task and review the goal.',
              'Do one concrete action toward the goal.',
              'Check the result and note one improvement.',
            ],
            xpReward: 100,
            type: 'practice',
            durationMinutes: 10,
            dependsOn: const [],
          ));
        } catch (_) {
          // Ignore single-item parse errors and continue
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
          nodes.add(QuestNodeModel(
            nodeId: '${milestoneNumber}_node_${nodes.length + 1}',
            title: variants[idx]['title']!,
            desc: variants[idx]['desc']!,
            steps: [
              'Read the task description carefully.',
              'Complete the practice step for this node.',
              'Reflect on what you learned.',
            ],
            xpReward: 100,
            type: 'practice',
            durationMinutes: 15,
            dependsOn: const [],
          ));
        }
      }

      return _ensureMinimumReadyNodes(
        nodes.take(20).toList(),
        minimumRoots: 3,
      );
    } catch (e) {
        print('[GeminiService] Phase DAG API call failed: $e');
        return _buildFallbackPhaseDag(
          hobby: hobby,
          milestoneNumber: milestoneNumber,
          frequency: frequency,
        );
    }
  }


  /// Generate one alternative quest title/description pair for a quest reroll.
  /// Returns a map with `title` and `desc`, or a fallback pair on failure.
  Future<Map<String, String>> generateAlternativeQuest({
    required String hobby,
    required String nodeTitle,
    required String nodeDesc,
  }) async {
    if (!hasApiKey) {
      print('[GeminiService] No API key found for alternative quest generation.');
      return _getAlternativeTaskFallback(hobby: hobby, currentTask: nodeTitle);
    }

    try {
      print('[GeminiService] Calling generateAlternativeQuestTitle API...');
      final prompt = '''

The user is learning $hobby. 
They are currently on a skill tree node titled: "$nodeTitle".
The current task is: "$nodeDesc".

They want to "reroll" and skip this specific task, but they STILL NEED TO LEARN THE CORE SKILL so they don't break their prerequisite learning path.

Generate ONE alternative task that teaches the EXACT SAME underlying skill or concept, but uses a different learning approach (e.g., if it was practice, maybe make it theory or a different exercise).

You MUST return ONLY a valid JSON object. Do not include markdown tags. Use this schema:
{
  "title": "string (Brief, engaging title)",
  "desc": "string (Actionable alternative step, under 2 sentences)"
}
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      print('[GeminiService] Alternative task title API call succeeded');
      
      final rawText = response.text?.trim() ?? '';
      final jsonMap = _extractJsonObject(rawText);
      final title = (jsonMap['title']?.toString().trim().isNotEmpty ?? false)
          ? jsonMap['title'].toString().trim()
          : _getAlternativeTaskFallback(hobby: hobby, currentTask: nodeTitle)['title']!;
      final desc = (jsonMap['desc']?.toString().trim().isNotEmpty ?? false)
          ? jsonMap['desc'].toString().trim()
          : 'Complete a focused step for $hobby today.';

      return {'title': title, 'desc': desc};
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
  }) async {
    final alternative = await generateAlternativeQuest(
      hobby: hobby,
      nodeTitle: nodeTitle,
      nodeDesc: nodeDesc,
    );
    return alternative['title'] ?? _getAlternativeTaskFallback(
      hobby: hobby,
      currentTask: nodeTitle,
    )['title']!;
  }

  Map<String, String> _getAlternativeTaskFallback({
    required String hobby,
    required String currentTask,
  }) {
    final fallbacks = [
      {'title': 'Alternative Study', 'desc': 'Watch a 5-minute video explaining $currentTask.'},
      {'title': 'Mental Reps', 'desc': 'Visualize the steps required to complete $currentTask.'},
      {'title': 'Break it Down', 'desc': 'Write down the 3 hardest parts about $currentTask.'},
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
        xpReward: 100,
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
        xpReward: 100,
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
        xpReward: 100,
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

    final parsed = rawQuests.map((item) {
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
    }).where((quest) => quest.title.trim().isNotEmpty).toList();

    if (parsed.length < 3) {
      return _buildFallbackQuests(hobby: hobby, level: level, focus: focus);
    }

    final normalized = parsed.take(3).toList();
    // Ensure at least one 'challenge' exists so UI can highlight a priority task.
    if (!normalized.any((quest) => quest.type == 'challenge')) {
      normalized[0] = normalized[0].copyWith(type: 'challenge');
    }

    return normalized
      .map((quest) => quest.copyWith(
          xpReward: 100,
          isCompleted: false,
          reflectionNote: '',
        ))
      .toList();
  }


  List<MilestoneModel> _buildMilestones({
    required String hobby,
    required String level,
    required String goal,
  }) {
    return <MilestoneModel>[
      MilestoneModel(title: 'Phase 1: Learn core $hobby fundamentals', completed: false),
      MilestoneModel(title: 'Phase 2: Build a repeatable ${level.toLowerCase()} routine', completed: false),
      MilestoneModel(title: 'Phase 3: Complete one measurable mini-project', completed: false),
      MilestoneModel(title: 'Phase 4: Reach your boss goal: $goal', completed: false),
    ];
  }

  List<Map<String, String>> _questTemplatesForHobby(String hobby) {
    final normalized = hobby.toLowerCase();

    if (normalized.contains('coding')) {
      return [
        {
          'title': 'Debug Sprint',
          'desc': 'Fix one bug and write a short note about the root cause.'
        },
        {
          'title': 'Refactor Drill',
          'desc': 'Refactor one small function for readability and naming clarity.'
        },
        {
          'title': 'Code Reading',
          'desc': 'Read one module and explain its flow in 5 bullet points.'
        },
      ];
    }

    if (normalized.contains('guitar') ||
        normalized.contains('piano') ||
        normalized.contains('sing')) {
      return [
        {
          'title': 'Technique Loop',
          'desc': 'Practice one technique slowly for 15 minutes with a metronome.'
        },
        {
          'title': 'Repertoire Step',
          'desc': 'Learn one new section from a song you enjoy.'
        },
        {
          'title': 'Playback Review',
          'desc': 'Record a take and note one strength and one improvement area.'
        },
      ];
    }

    if (normalized.contains('drawing') ||
        normalized.contains('painting') ||
        normalized.contains('photography')) {
      return [
        {
          'title': 'Study Session',
          'desc': 'Create one focused study on light, shape, or composition.'
        },
        {
          'title': 'Reference Challenge',
          'desc': 'Recreate one reference with your own style constraints.'
        },
        {
          'title': 'Portfolio Pick',
          'desc': 'Choose your best piece and write one improvement goal.'
        },
      ];
    }

    return [
      {
        'title': 'Focus Block',
        'desc': 'Do one focused practice block for 20 minutes.'
      },
      {
        'title': 'Knowledge Bite',
        'desc': 'Learn one concept and explain it in your own words.'
      },
      {
        'title': 'Output Challenge',
        'desc': 'Ship one small outcome and reflect on the process.'
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

      nodes.add(QuestNodeModel(
        nodeId: nodeId,
        title: variant['title']!,
        desc: variant['desc']!,
        steps: [
          'Start with the branch-specific skill.',
          'Follow the current node objective step by step.',
          'Check your result before moving on.',
        ],
        xpReward: 100,
        type: i % 5 == 4 ? 'challenge' : (i % 2 == 0 ? 'practice' : 'knowledge'),
        durationMinutes: baseDurationMinutes,
        dependsOn: dependsOn,
      ));
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
        .map((node) => node.copyWith(
              dependsOn: node.dependsOn.where(knownIds.contains).toList(),
            ))
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
