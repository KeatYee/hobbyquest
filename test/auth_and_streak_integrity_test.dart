import 'package:flutter_test/flutter_test.dart';
import 'package:hobbyquest/core/utils/streak_calculator.dart';
import 'package:hobbyquest/core/utils/user_profile_state.dart';

void main() {
  group('onboarding gate', () {
    test('rejects a token-only user document', () {
      expect(
        hasCompletedUserProfile({
          'fcmTokens': ['token'],
          'fcmTokenUpdatedAt': DateTime.now(),
        }),
        isFalse,
      );
    });

    test('accepts explicit and legacy completed profiles', () {
      expect(
        hasCompletedUserProfile({'isOnboardingComplete': true}),
        isTrue,
      );
      expect(
        hasCompletedUserProfile({
          'nickname': 'Fox',
          'activePlanId': 'plan-1',
        }),
        isTrue,
      );
    });
  });

  group('UTC streak calculation', () {
    test('maintains a streak for the same trusted UTC day', () {
      expect(
        calculateUpdatedStreak(
          currentStreak: 4,
          lastStreakDate: DateTime.parse('2026-07-22T01:00:00Z'),
          completionTime: DateTime.parse('2026-07-22T23:00:00Z'),
        ),
        4,
      );
    });

    test('extends only on the next trusted UTC day', () {
      expect(
        calculateUpdatedStreak(
          currentStreak: 4,
          lastStreakDate: DateTime.parse('2026-07-22T23:30:00+08:00'),
          completionTime: DateTime.parse('2026-07-23T16:30:00Z'),
        ),
        5,
      );
    });

    test('resets after a gap', () {
      expect(
        calculateUpdatedStreak(
          currentStreak: 9,
          lastStreakDate: DateTime.parse('2026-07-20T10:00:00Z'),
          completionTime: DateTime.parse('2026-07-23T10:00:00Z'),
        ),
        1,
      );
    });
  });
}
