import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobbyquest/app/data/onboarding_catalog.dart';
import 'package:hobbyquest/app/models/category_model.dart';

CategoryModel _category(String name, List<String> hobbies, {String? id}) {
  return CategoryModel(
    id: id ?? name.toLowerCase().replaceAll(' ', '_'),
    name: name,
    description: '$name description',
    iconCodePoint: Icons.star.codePoint,
    hobbies: hobbies.map((name) => HobbyEntry(name: name)).toList(),
  );
}

void main() {
  group('supported onboarding catalogue', () {
    test('contains exactly four categories and sixteen unique hobbies', () {
      final hobbies = OnboardingCatalog.supportedCategories.values
          .expand((items) => items)
          .toList();

      expect(OnboardingCatalog.supportedCategories, hasLength(4));
      expect(hobbies, hasLength(16));
      expect(hobbies.toSet(), hasLength(16));
    });

    test('provides three concise, unique goals for every hobby and level', () {
      for (final hobby in OnboardingCatalog.supportedCategories.values.expand(
        (items) => items,
      )) {
        for (final level in OnboardingCatalog.levels) {
          final goals = OnboardingCatalog.goalsFor(hobby, level);

          expect(
            goals,
            hasLength(3),
            reason: '$hobby at $level must have three presets',
          );
          expect(
            goals.every((goal) => goal.trim().isNotEmpty && goal.length <= 48),
            isTrue,
            reason: '$hobby at $level has an empty or overly long preset',
          );
          expect(
            goals.toSet(),
            hasLength(3),
            reason: '$hobby at $level has duplicate presets',
          );
        }
      }
    });

    test('provides a distinct custom-goal hint for every hobby', () {
      final hints = OnboardingCatalog.supportedCategories.values
          .expand((hobbies) => hobbies)
          .map(OnboardingCatalog.customGoalHintFor)
          .toList();

      expect(hints, hasLength(16));
      expect(hints.toSet(), hasLength(16));
      expect(
        hints.every((hint) => hint.startsWith('e.g. ') && hint.length <= 48),
        isTrue,
      );
      expect(
        OnboardingCatalog.customGoalHintFor('Future Hobby'),
        'Describe what you want to achieve',
      );
    });

    test('filters unknown categories and unsupported hobbies', () {
      final categories = [
        _category('Creative Arts', [
          'Painting',
          'Drawing',
          'Photography',
          'Calligraphy',
          'Sculpture',
        ]),
        _category('Music & Performing', [
          'Guitar',
          'Piano',
          'Singing',
          'Dance',
        ]),
        _category('Lifestyle & Wellness', [
          'Yoga',
          'Fitness/Gym',
          'Meditation',
          'Cooking',
        ]),
        _category('Skill & Strategy', [
          'Coding',
          'Chess',
          'Language',
          'Public Speaking',
        ]),
        _category('Future Category', ['Future Hobby']),
      ];

      final filtered = OnboardingCatalog.filterSupportedCategories(categories);

      expect(filtered.map((category) => category.name), [
        'Creative Arts',
        'Music & Performing',
        'Lifestyle & Wellness',
        'Skill & Strategy',
      ]);
      expect(
        filtered.expand((category) => category.hobbyNames),
        isNot(contains('Sculpture')),
      );
      expect(
        filtered.expand((category) => category.hobbyNames),
        isNot(contains('Future Hobby')),
      );
    });

    test('preserves configured category order and hobby metadata', () {
      final paintingAxes = [
        PeerReviewAxisModel.fromIconData(label: 'Technique', icon: Icons.brush),
      ];
      final categories = [
        _category('Skill & Strategy', [
          'Public Speaking',
          'Coding',
          'Chess',
          'Language',
        ]),
        CategoryModel(
          id: 'creative',
          name: 'Creative Arts',
          description: 'Creative',
          iconCodePoint: Icons.palette.codePoint,
          hobbies: [
            HobbyEntry(name: 'Drawing'),
            HobbyEntry(name: 'Painting', axes: paintingAxes),
            HobbyEntry(name: 'Photography'),
            HobbyEntry(name: 'Calligraphy'),
          ],
        ),
      ];

      final filtered = OnboardingCatalog.filterSupportedCategories(categories);

      expect(filtered.map((category) => category.name), [
        'Creative Arts',
        'Skill & Strategy',
      ]);
      expect(filtered.first.hobbyNames, [
        'Drawing',
        'Painting',
        'Photography',
        'Calligraphy',
      ]);
      expect(filtered.first.getAxisForHobby('Painting'), paintingAxes);
    });
  });
}
