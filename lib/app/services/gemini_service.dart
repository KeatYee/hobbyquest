import 'dart:convert';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/milestone_model.dart';
import '../models/quest_model.dart';
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
      return QuestPlanModel(
        hobbyName: hobby,
        skillLevel: level,
        customGoal: normalizedGoal,
        frequency: frequency,
        progress: 0,
        milestones: _buildMilestones(hobby: hobby, level: level, goal: normalizedGoal),
        quests: _buildFallbackQuests(hobby: hobby, level: level, focus: normalizedGoal),
      );
    }

    try {
      print('[GeminiService] Calling generateQuestPlan API...');
      final prompt = '''
You are an expert tutor and quest planner for a gamified hobby app.
Generate a personalized learning plan as strict JSON.

User Profile:
- Hobby: $hobby
- Skill Level: $level
- Custom Goal: $normalizedGoal
- Frequency: $frequency

Instructions:
1. Generate exactly 4 major Milestones that break the user's custom goal into logical phases.
2. Generate exactly 3 initial Daily Quests to get the user started.
3. Quest 'desc' must be brief, encouraging, and actionable (under 3 sentences).
4. Quest 'type' MUST be exactly one of: "knowledge", "practice", or "challenge".
5. Set 'isPriority' to true ONLY for "challenge" quests.

Output formatting rules:
You MUST return ONLY a valid JSON object. Do not include markdown tags like ```json. Use this exact schema:
{
  "hobbyName": "string",
  "milestones": [
    { "title": "string" },
    { "title": "string" },
    { "title": "string" },
    { "title": "string" }
  ],
  "quests": [
    { "title": "string", "desc": "string", "type": "string", "isPriority": boolean },
    { "title": "string", "desc": "string", "type": "string", "isPriority": boolean },
    { "title": "string", "desc": "string", "type": "string", "isPriority": boolean }
  ]
}

''';

      final response = await _model.generateContent([Content.text(prompt)]);
      print('[GeminiService] Quest plan API call succeeded');
      final rawText = response.text?.trim() ?? '';
      final jsonMap = _extractJsonObject(rawText);
      final milestonesDynamic = jsonMap['milestones'] as List<dynamic>?;
      final questsDynamic = jsonMap['quests'] as List<dynamic>?;
      final milestones = (milestonesDynamic ?? const <dynamic>[])
          .map((item) {
            if (item is Map<String, dynamic>) {
              return MilestoneModel.fromJson(item);
            }

            if (item is Map) {
              return MilestoneModel.fromJson(Map<String, dynamic>.from(item));
            }

            return MilestoneModel(task: item.toString(), completed: false);
          })
          .where((item) => item.task.trim().isNotEmpty)
          .toList();
      final quests = _parseQuests(questsDynamic, hobby: hobby, level: level, focus: normalizedGoal);

      if (milestones.length < 4) {
        throw const FormatException('Gemini returned insufficient milestones');
      }
      if (quests.length < 3) {
        throw const FormatException('Gemini returned insufficient quests');
      }

      return QuestPlanModel(
        hobbyName: (jsonMap['hobbyName']?.toString().trim().isNotEmpty ?? false)
            ? jsonMap['hobbyName'].toString().trim()
            : hobby,
        skillLevel: (jsonMap['skillLevel']?.toString().trim().isNotEmpty ?? false)
            ? jsonMap['skillLevel'].toString().trim()
            : level,
        customGoal: (jsonMap['customGoal']?.toString().trim().isNotEmpty ?? false)
            ? jsonMap['customGoal'].toString().trim()
            : normalizedGoal,
        frequency: (jsonMap['frequency']?.toString().trim().isNotEmpty ?? false)
            ? jsonMap['frequency'].toString().trim()
            : frequency,
        progress: (jsonMap['progress'] as int?) ?? 0,
        milestones: milestones.take(4).toList(),
        quests: quests.take(3).toList(),
      );
    } catch (e) {
      print('[GeminiService] Quest plan API call failed: $e');
      return QuestPlanModel(
        hobbyName: hobby,
        skillLevel: level,
        customGoal: normalizedGoal,
        frequency: frequency,
        progress: 0,
        milestones: _buildMilestones(hobby: hobby, level: level, goal: normalizedGoal),
        quests: _buildFallbackQuests(hobby: hobby, level: level, focus: normalizedGoal),
      );
    }
  }

  Future<List<QuestModel>> generateDailyQuests({
    required String hobby,
    required String level,
    required String goal,
    required String frequency,
    required String currentMilestoneTitle, // NEW: Context for the AI
    required int activeQuestsCount,        // NEW: Prevents over-generating
    String focus = '',                     // Kept for fallback
  }) async {
    // Normalize goal like generateQuestPlan
    final normalizedGoal = goal.trim().isEmpty ? 'Master $hobby' : goal.trim();

    // 1. Calculate how many quests we actually need
    final int questsNeeded = activeQuestsCount >= 3 ? 3 : 3 - activeQuestsCount;

    // 2. Safety Check: If they already have 3, don't call the API!
    if (questsNeeded <= 0) {
      print('[GeminiService] User already has 3 active quests. Skipping API call.');
      return []; 
    }

    if (!hasApiKey) {
      final fallbackFocus = focus.trim().isEmpty ? normalizedGoal : focus;
      return _buildFallbackQuests(hobby: hobby, level: level, focus: fallbackFocus)
          .take(questsNeeded)
          .toList();
    }

    try {
      print('[GeminiService] Calling generateDailyQuests API for $questsNeeded quests...');
      
      // 3. The Dynamic "Daily Refill" Prompt
      final prompt = '''
You are an expert tutor and quest planner for a gamified hobby app. 
The user is currently learning a hobby and needs their next set of daily quests.

User Context:
- Hobby: $hobby
- Skill Level: $level
     - Custom Goal: $normalizedGoal
- Frequency: $frequency
- Current Milestone Focus: $currentMilestoneTitle
- Skill Level: $level


Instructions:
1. Generate EXACTLY $questsNeeded new sequential daily quests that help the user master the current milestone.
2. The 'desc' should be brief, encouraging, and actionable (under 3 sentences).
3. The 'type' MUST be exactly one of the following strings:
   - "knowledge" (reading theory or watching a quick tutorial)
   - "practice" (standard hands-on tasks to build muscle memory)
   - "challenge" (a major task where the user must snap a photo of their work for AI grading)
4. Set 'isPriority' to true ONLY for "challenge" type quests.

Output formatting rules:
You MUST return ONLY a valid JSON object. Do not include markdown tags like ```json. Use this exact schema:
{
  "quests": [
    {
      "title": "String",
      "desc": "String",
      "type": "String",
      "isPriority": boolean
    }
  ]
}
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      print('[GeminiService] Daily quests API call succeeded');
      
      final rawText = response.text?.trim() ?? '';
      final jsonMap = _extractJsonObject(rawText);
      final listDynamic = jsonMap['quests'] as List<dynamic>? ?? const <dynamic>[];

      // 4. Validate we got enough quests back
      if (listDynamic.isEmpty) {
        throw const FormatException('Gemini returned empty quests array');
      }

      final sanitized = <QuestModel>[];
      // Only loop up to questsNeeded, just in case the AI generated extra
      final int loopCount = min(listDynamic.length, questsNeeded);

      for (var i = 0; i < loopCount; i++) {
        final item = listDynamic[i] as Map<String, dynamic>;
        final type = _sanitizeType(item['type']?.toString() ?? 'practice');
        
        // Use milliseconds to ensure IDs don't collide with yesterday's quests!
        final uniqueId = 'q_${DateTime.now().millisecondsSinceEpoch}_$i';

        sanitized.add(QuestModel(
          id: uniqueId,
          title: (item['title']?.toString().trim().isNotEmpty ?? false)
              ? item['title'].toString().trim()
              : 'Quest ${i + 1}',
          desc: (item['desc']?.toString().trim().isNotEmpty ?? false)
              ? item['desc'].toString().trim()
              : 'Complete a focused step for $hobby today.',
          xp: 100, // Hardcoded 100 XP rule
          type: type,
          isPriority: item['isPriority'] == true,
          isCompleted: false, // Default
          reflectionNote: "", // Default
        ));
      }

      return sanitized;
    } catch (e) {
        print('[GeminiService] Daily quests API call failed: $e');
        final fallbackFocus = focus.trim().isEmpty ? normalizedGoal : focus;
        return _buildFallbackQuests(hobby: hobby, level: level, focus: fallbackFocus)
          .take(questsNeeded)
          .toList();
    }
  }



  /// Generate one alternative task title for a quest reroll.
  /// Returns just the task title string, or empty string on failure.
  Future<String> generateAlternativeQuestTitle({
    required String hobby,
    required String currentTask,
  }) async {
    if (!hasApiKey) {
      return _getAlternativeTaskFallback(hobby: hobby, currentTask: currentTask);
    }

    try {
      print('[GeminiService] Calling generateAlternativeQuestTitle API...');
      final prompt = '''The user is learning $hobby. Their current task was '$currentTask', but they want to skip it. Generate ONE new, alternative task of the same difficulty level. Return only the task title.''';

      final response = await _model.generateContent([Content.text(prompt)]);
      print('[GeminiService] Alternative task title API call succeeded');
      
      final title = response.text?.trim() ?? '';
      if (title.isEmpty) {
        return _getAlternativeTaskFallback(hobby: hobby, currentTask: currentTask);
      }
      
      return title;
    } catch (e) {
      print('[GeminiService] Alternative task title API call failed: $e');
      return _getAlternativeTaskFallback(hobby: hobby, currentTask: currentTask);
    }
  }

  String _getAlternativeTaskFallback({
    required String hobby,
    required String currentTask,
  }) {
    final fallbacks = <String>[
      'Master a new $hobby technique',
      'Practice $hobby for 20 minutes focused',
      'Review your $hobby progress today',
      'Learn one advanced $hobby concept',
      'Record yourself doing $hobby',
      'Watch a $hobby tutorial and take notes',
      'Set up your $hobby workspace',
      'Reflect on your $hobby journey',
      'Share your $hobby work with others',
      'Create something new in $hobby',
    ];
    
    final random = Random(DateTime.now().day);
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

  List<QuestModel> _buildFallbackQuests({
    required String hobby,
    required String level,
    required String focus,
  }) {
    final seed = DateTime.now().day;
    final variants = _questTemplatesForHobby(hobby);
    final random = Random(seed);
    variants.shuffle(random);

    return [
      QuestModel(
        id: 'q_${hobby.toLowerCase().replaceAll(' ', '_')}_1',
        title: variants[0]['title']!,
        desc: variants[0]['desc']!,
        xp: 100,
        type: 'practice',
        isPriority: true,
      ),
      QuestModel(
        id: 'q_${hobby.toLowerCase().replaceAll(' ', '_')}_2',
        title: variants[1]['title']!,
        desc: variants[1]['desc']!,
        xp: 100,
        type: 'knowledge',
      ),
      QuestModel(
        id: 'q_${hobby.toLowerCase().replaceAll(' ', '_')}_3',
        title: 'Goal Push: ${_shorten(focus)}',
        desc: 'Take one concrete step today toward: $focus',
        xp: 100,
        type: 'challenge',
      ),
    ];
  }

  List<QuestModel> _parseQuests(
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
        return QuestModel.fromJson(item);
      }

      if (item is Map) {
        return QuestModel.fromJson(Map<String, dynamic>.from(item));
      }

      return QuestModel(
        id: item.toString(),
        title: item.toString(),
        desc: 'Complete a focused step for $hobby today.',
        type: 'practice',
      );
    }).where((quest) => quest.title.trim().isNotEmpty).toList();

    if (parsed.length < 3) {
      return _buildFallbackQuests(hobby: hobby, level: level, focus: focus);
    }

    final normalized = parsed.take(3).toList();
    if (!normalized.any((quest) => quest.isPriority)) {
      normalized[0] = normalized[0].copyWith(isPriority: true);
    }

    return normalized
        .map((quest) => quest.copyWith(
              xp: 100,
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
      MilestoneModel(task: 'Phase 1: Learn core $hobby fundamentals', completed: false),
      MilestoneModel(task: 'Phase 2: Build a repeatable ${level.toLowerCase()} routine', completed: false),
      MilestoneModel(task: 'Phase 3: Complete one measurable mini-project', completed: false),
      MilestoneModel(task: 'Phase 4: Reach your boss goal: $goal', completed: false),
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

  String _shorten(String text) {
    const maxLength = 36;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }
}
