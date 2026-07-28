import '../models/category_model.dart';

class OnboardingCatalog {
  OnboardingCatalog._();

  static const List<String> levels = ['Novice', 'Intermediate', 'Expert'];

  static const Map<String, List<String>> supportedCategories = {
    'Creative Arts': ['Painting', 'Drawing', 'Photography', 'Calligraphy'],
    'Music & Performing': ['Guitar', 'Piano', 'Singing', 'Dance'],
    'Lifestyle & Wellness': ['Yoga', 'Fitness/Gym', 'Meditation', 'Cooking'],
    'Skill & Strategy': ['Coding', 'Chess', 'Language', 'Public Speaking'],
  };

  static List<CategoryModel> filterSupportedCategories(
    Iterable<CategoryModel> categories,
  ) {
    final categoriesByName = {
      for (final category in categories) category.name: category,
    };

    return supportedCategories.entries
        .map((entry) {
          final category = categoriesByName[entry.key];
          if (category == null) return null;

          final allowedHobbies = entry.value.toSet();
          return category.copyWith(
            hobbies: category.hobbies
                .where((hobby) => allowedHobbies.contains(hobby.name))
                .toList(),
          );
        })
        .whereType<CategoryModel>()
        .toList();
  }

  static List<String> goalsFor(String hobby, String level) {
    return List<String>.unmodifiable(
      _goalPresets[hobby]?[level] ?? const <String>[],
    );
  }

  static String customGoalHintFor(String hobby) {
    return _customGoalHints[hobby] ?? 'Describe what you want to achieve';
  }

  static const Map<String, String> _customGoalHints = {
    'Painting': 'e.g. Paint a sunset landscape',
    'Drawing': 'e.g. Learn to draw Doraemon',
    'Photography': 'e.g. Take professional portrait photos',
    'Calligraphy': 'e.g. Write an elegant wedding invitation',
    'Guitar': 'e.g. Play my favourite song',
    'Piano': 'e.g. Perform a complete piano piece',
    'Singing': 'e.g. Sing confidently on pitch',
    'Dance': 'e.g. Perform a full dance routine',
    'Yoga': 'e.g. Complete a balanced yoga flow',
    'Fitness/Gym': 'e.g. Build a consistent strength routine',
    'Meditation': 'e.g. Meditate for twenty minutes',
    'Cooking': 'e.g. Cook a three-course dinner',
    'Coding': 'e.g. Build my first mobile app',
    'Chess': 'e.g. Win with a planned strategy',
    'Language': 'e.g. Hold a ten-minute conversation',
    'Public Speaking': 'e.g. Deliver a confident presentation',
  };

  static const Map<String, Map<String, List<String>>> _goalPresets = {
    'Painting': {
      'Novice': [
        'Mix a balanced color palette',
        'Paint a simple still life',
        'Practice smooth brush control',
      ],
      'Intermediate': [
        'Paint a landscape with depth',
        'Create convincing light and shadow',
        'Complete a themed canvas series',
      ],
      'Expert': [
        'Develop a signature painting style',
        'Complete a gallery-ready collection',
        'Teach an advanced painting workshop',
      ],
    },
    'Drawing': {
      'Novice': [
        'Learn basic shading',
        'Sketch a coffee cup',
        'Draw a simple cartoon',
      ],
      'Intermediate': [
        'Draw a realistic portrait',
        'Use two-point perspective',
        'Learn to draw hands',
      ],
      'Expert': [
        'Design dynamic action poses',
        'Complete a full anatomy study',
        'Create hyper-realistic lighting',
      ],
    },
    'Photography': {
      'Novice': [
        'Use the exposure triangle',
        'Photograph a balanced composition',
        'Complete a seven-day photo challenge',
      ],
      'Intermediate': [
        'Create a portrait photo series',
        'Control light in difficult scenes',
        'Tell a story with ten photos',
      ],
      'Expert': [
        'Build a professional photo portfolio',
        'Direct a complex editorial shoot',
        'Teach an advanced lighting session',
      ],
    },
    'Calligraphy': {
      'Novice': [
        'Form consistent basic strokes',
        'Write a polished alphabet',
        'Create a simple quote card',
      ],
      'Intermediate': [
        'Develop consistent letter spacing',
        'Create an elegant invitation',
        'Combine flourishes with clear lettering',
      ],
      'Expert': [
        'Develop a signature lettering style',
        'Complete a commissioned calligraphy set',
        'Teach an advanced flourishing lesson',
      ],
    },
    'Guitar': {
      'Novice': [
        'Play five open chords',
        'Change chords without stopping',
        'Perform one complete beginner song',
      ],
      'Intermediate': [
        'Play clean barre chords',
        'Improvise over a backing track',
        'Perform a polished fingerstyle piece',
      ],
      'Expert': [
        'Arrange a complex solo guitar piece',
        'Develop a distinctive improvising voice',
        'Teach an advanced guitar masterclass',
      ],
    },
    'Piano': {
      'Novice': [
        'Play with both hands',
        'Read a simple music score',
        'Perform one complete beginner piece',
      ],
      'Intermediate': [
        'Play scales with even timing',
        'Perform a piece with expression',
        'Arrange a song for solo piano',
      ],
      'Expert': [
        'Interpret a demanding concert piece',
        'Create an advanced piano arrangement',
        'Teach an expressive performance lesson',
      ],
    },
    'Singing': {
      'Novice': [
        'Match pitch with confidence',
        'Support notes with steady breath',
        'Perform one complete beginner song',
      ],
      'Intermediate': [
        'Extend vocal range safely',
        'Sing with controlled dynamics',
        'Record a polished cover song',
      ],
      'Expert': [
        'Develop a distinctive vocal style',
        'Prepare a professional live set',
        'Teach an advanced vocal workshop',
      ],
    },
    'Dance': {
      'Novice': [
        'Keep time with basic steps',
        'Learn a short dance routine',
        'Perform with confident posture',
      ],
      'Intermediate': [
        'Master clean movement transitions',
        'Perform a full choreography',
        'Create an original dance sequence',
      ],
      'Expert': [
        'Choreograph a stage-ready performance',
        'Develop a distinctive movement style',
        'Teach an advanced dance workshop',
      ],
    },
    'Yoga': {
      'Novice': [
        'Learn a safe sun salutation',
        'Hold basic poses with alignment',
        'Complete a seven-day yoga routine',
      ],
      'Intermediate': [
        'Build a balanced personal flow',
        'Improve stability in balance poses',
        'Complete a thirty-minute sequence',
      ],
      'Expert': [
        'Design an advanced yoga sequence',
        'Refine challenging pose transitions',
        'Teach a safe themed yoga class',
      ],
    },
    'Fitness/Gym': {
      'Novice': [
        'Learn safe lifting form',
        'Complete a balanced full-body workout',
        'Build a consistent weekly routine',
      ],
      'Intermediate': [
        'Improve strength in compound lifts',
        'Complete a progressive training block',
        'Balance strength and conditioning',
      ],
      'Expert': [
        'Design an advanced training programme',
        'Reach a challenging performance target',
        'Teach safe advanced lifting technique',
      ],
    },
    'Meditation': {
      'Novice': [
        'Complete a five-minute meditation',
        'Notice distractions without reacting',
        'Build a seven-day mindfulness habit',
      ],
      'Intermediate': [
        'Sustain twenty minutes of focus',
        'Use mindfulness during daily stress',
        'Complete a month-long meditation routine',
      ],
      'Expert': [
        'Deepen a consistent meditation practice',
        'Design a personal mindfulness programme',
        'Guide an advanced meditation session',
      ],
    },
    'Cooking': {
      'Novice': [
        'Use a knife safely',
        'Cook a balanced one-pan meal',
        'Prepare three reliable basic dishes',
      ],
      'Intermediate': [
        'Create a complete three-course meal',
        'Balance seasoning without a recipe',
        'Master three essential cooking techniques',
      ],
      'Expert': [
        'Design an original tasting menu',
        'Execute a restaurant-quality dinner',
        'Teach an advanced cooking workshop',
      ],
    },
    'Coding': {
      'Novice': [
        'Build a simple working program',
        'Use variables and control flow',
        'Fix common beginner coding errors',
      ],
      'Intermediate': [
        'Build and test a complete application',
        'Refactor code for readability',
        'Design a clean application architecture',
      ],
      'Expert': [
        'Build a production-ready system',
        'Optimise a complex application',
        'Teach an advanced software workshop',
      ],
    },
    'Chess': {
      'Novice': [
        'Recognise basic tactical patterns',
        'Play a complete opening plan',
        'Checkmate with king and queen',
      ],
      'Intermediate': [
        'Calculate three-move combinations',
        'Build a dependable opening repertoire',
        'Convert a winning endgame',
      ],
      'Expert': [
        'Prepare for a competitive tournament',
        'Analyse complex strategic positions',
        'Teach an advanced chess lesson',
      ],
    },
    'Language': {
      'Novice': [
        'Hold a basic introduction',
        'Learn one hundred useful words',
        'Complete a simple daily conversation',
      ],
      'Intermediate': [
        'Discuss familiar topics naturally',
        'Write a clear personal story',
        'Understand a short native-language video',
      ],
      'Expert': [
        'Deliver a fluent formal presentation',
        'Write a nuanced long-form essay',
        'Teach an advanced conversation session',
      ],
    },
    'Public Speaking': {
      'Novice': [
        'Deliver a clear two-minute talk',
        'Speak with confident body language',
        'Organise a simple persuasive speech',
      ],
      'Intermediate': [
        'Deliver a polished ten-minute talk',
        'Handle audience questions confidently',
        'Tell a compelling personal story',
      ],
      'Expert': [
        'Deliver a keynote-style presentation',
        'Adapt a speech to any audience',
        'Teach an advanced speaking workshop',
      ],
    },
  };
}
