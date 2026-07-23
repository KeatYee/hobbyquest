import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobbyquest/app/services/password_reset_service.dart';
import 'package:hobbyquest/core/utils/streak_calculator.dart';
import 'package:hobbyquest/core/utils/user_profile_state.dart';
import 'package:hobbyquest/core/utils/validators.dart';

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
      expect(hasCompletedUserProfile({'isOnboardingComplete': true}), isTrue);
      expect(
        hasCompletedUserProfile({'nickname': 'Fox', 'activePlanId': 'plan-1'}),
        isTrue,
      );
    });
  });

  group('password reset email validation', () {
    test('accepts and trims a valid email', () {
      expect(Validators.validateEmail('  hero@example.com  '), isNull);
    });

    test('rejects empty and malformed emails', () {
      expect(Validators.validateEmail(''), 'Email is required');
      expect(
        Validators.validateEmail('not-an-email'),
        'Please enter a valid email address',
      );
    });

    test('maps common Firebase reset errors to useful messages', () {
      expect(
        PasswordResetService.errorMessage(
          FirebaseAuthException(code: 'network-request-failed'),
        ),
        'Check your internet connection and retry.',
      );
      expect(
        PasswordResetService.errorMessage(
          FirebaseAuthException(code: 'too-many-requests'),
        ),
        'Too many attempts. Please wait and try again.',
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

  group('UTC daily quest completion count', () {
    test('increments within the same UTC day', () {
      expect(
        calculateDailyQuestCompletionCount(
          currentCount: 2,
          lastCompletionDate: DateTime.parse('2026-07-22T01:00:00Z'),
          completionTime: DateTime.parse('2026-07-22T23:00:00Z'),
        ),
        3,
      );
    });

    test('resets on a new UTC day', () {
      expect(
        calculateDailyQuestCompletionCount(
          currentCount: 7,
          lastCompletionDate: DateTime.parse('2026-07-22T23:30:00+08:00'),
          completionTime: DateTime.parse('2026-07-23T16:30:00Z'),
        ),
        1,
      );
    });
  });
}
