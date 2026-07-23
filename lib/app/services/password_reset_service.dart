import 'package:firebase_auth/firebase_auth.dart';

import '../../core/utils/validators.dart';

class PasswordResetService {
  PasswordResetService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<void> sendResetEmail(String email) async {
    final normalizedEmail = email.trim();
    final validationError = Validators.validateEmail(normalizedEmail);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    try {
      await _auth.sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (error) {
      // Do not reveal whether an account exists for a supplied email address.
      if (error.code == 'user-not-found') return;
      rethrow;
    }
  }

  static String errorMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'Please enter a valid email address.',
      'network-request-failed' => 'Check your internet connection and retry.',
      'too-many-requests' => 'Too many attempts. Please wait and try again.',
      _ => error.message ?? 'Unable to send the password reset email.',
    };
  }
}
