import 'dart:async';

import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'guild_controller.dart';
import 'home_controller.dart';
import '../routes/app_routes.dart';
import '../services/push_notification_service.dart';
import '../services/password_reset_service.dart';
import '../../core/utils/dialog_utils.dart';

class ProfileController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );
  final PasswordResetService _passwordResetService = PasswordResetService();

  final isLoading = true.obs;
  final isUpdatingNotifications = false.obs;
  final isUpdatingPrivacy = false.obs;
  final userModel = Rxn<UserModel>();
  final guildPostCount = 0.obs;
  final notificationsEnabled = true.obs;
  final profileVisible = true.obs;
  final postStatsVisible = true.obs;
  bool _isDeletingAccount = false;
  StreamSubscription? _guildPostsSubscription;
  StreamSubscription? _userProfileSubscription;

  int get totalXP => userModel.value?.totalXP ?? 0;
  int get level => userModel.value?.level ?? 1;
  int get xp => userModel.value?.currentXp ?? 0;
  int get streak => userModel.value?.currentStreak ?? 0;
  String get nickname => userModel.value?.nickname ?? 'Hero';
  String get avatarSvg => userModel.value?.avatarSvg ?? '';
  String get birthDate => userModel.value?.birthDate ?? '';
  String get email => _auth.currentUser?.email ?? '';
  String get uid => _auth.currentUser?.uid ?? '';

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  @override
  void onClose() {
    _guildPostsSubscription?.cancel();
    _userProfileSubscription?.cancel();
    super.onClose();
  }

  Future<void> loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      isLoading.value = false;
      return;
    }

    try {
      isLoading.value = true;

      final results = await Future.wait([
        _firestore.collection('users').doc(user.uid).get(),
        refreshGuildPostCount(),
      ]);

      final docSnap = results[0] as DocumentSnapshot;

      if (docSnap.exists) {
        userModel.value = UserModel.fromJson(
          docSnap.data() as Map<String, dynamic>,
          user.uid,
        );
        notificationsEnabled.value =
            userModel.value?.notificationsEnabled ?? true;
        profileVisible.value = userModel.value?.profileVisible ?? true;
        postStatsVisible.value = userModel.value?.postStatsVisible ?? true;
      }

      _listenToUserProfile(user.uid);
      _listenToGuildPosts(user.uid);
    } catch (e) {
      print('--- ERROR loading profile: $e ---');
      AppDialogs.error('Error', 'Failed to load profile');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshGuildPostCount() async {
    final user = _auth.currentUser;
    if (user == null) {
      guildPostCount.value = 0;
      return;
    }

    try {
      final postSnap = await _firestore
          .collection('guild_posts')
          .where('userId', isEqualTo: user.uid)
          .get();
      guildPostCount.value = postSnap.docs.length;
    } catch (e) {
      print('--- ERROR refreshing guild post count: $e ---');
    }
  }

  void _listenToUserProfile(String userId) {
    _userProfileSubscription?.cancel();
    _userProfileSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists) return;

          final data = snapshot.data();
          if (data == null) return;

          final updatedUser = UserModel.fromJson(data, userId);
          userModel.value = updatedUser;
          notificationsEnabled.value = updatedUser.notificationsEnabled;
          profileVisible.value = updatedUser.profileVisible;
          postStatsVisible.value = updatedUser.postStatsVisible;
        }, onError: (e) {
          print('--- ERROR listening to user profile: $e ---');
        });
  }

  void _listenToGuildPosts(String userId) {
    _guildPostsSubscription?.cancel();
    _guildPostsSubscription = _firestore
        .collection('guild_posts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
          guildPostCount.value = snapshot.docs.length;
        }, onError: (e) {
          print('--- ERROR listening to guild posts: $e ---');
        });
  }

  /// Update the user's display name in Firestore.
  Future<bool> updateNickname(String newNickname) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final trimmed = newNickname.trim();
    if (trimmed.isEmpty || trimmed.length < 2) {
      AppDialogs.error('Invalid Name', 'Name must be at least 2 characters');
      return false;
    }
    if (trimmed.length > 50) {
      AppDialogs.error('Invalid Name', 'Name must be 50 characters or less');
      return false;
    }
    try {
      final batch = _firestore.batch();
      batch.update(_firestore.collection('users').doc(user.uid), {
        'nickname': trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        _firestore.collection('publicProfiles').doc(user.uid),
        {'nickname': trimmed, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      await batch.commit();

      if (userModel.value != null) {
        userModel.value = userModel.value!.copyWith(nickname: trimmed);
      }
      if (Get.isRegistered<HomeController>()) {
        final homeController = Get.find<HomeController>();
        homeController.nickname.value = trimmed;
        final homeUser = homeController.user.value;
        if (homeUser != null) {
          homeController.user.value = homeUser.copyWith(nickname: trimmed);
        }
      }
      if (Get.isRegistered<GuildController>()) {
        Get.find<GuildController>().userNicknames[user.uid] = trimmed;
      }

      AppDialogs.success('Updated', 'Avatar name changed to $trimmed');
      return true;
    } catch (e) {
      AppDialogs.error('Error', 'Failed to update name: $e');
      return false;
    }
  }

  /// Change the Firebase Auth email. Requires recent login.
  Future<bool> changeEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final trimmed = newEmail.trim();
    if (trimmed.isEmpty) {
      AppDialogs.error('Invalid Email', 'Email cannot be empty');
      return false;
    }
    if (!trimmed.contains('@') || !trimmed.contains('.')) {
      AppDialogs.error('Invalid Email', 'Please enter a valid email address');
      return false;
    }
    try {
      await user.verifyBeforeUpdateEmail(trimmed);

      AppDialogs.success(
        'Confirm Email Change',
        'A verification link was sent to $trimmed',
        durationSeconds: 3,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        AppDialogs.warning(
          'Re-login Needed',
          'Please logout and sign in again to change your email',
          durationSeconds: 3,
        );
      } else {
        AppDialogs.error('Error', e.message ?? 'Failed to update email');
      }
      return false;
    } catch (e) {
      AppDialogs.error('Error', 'Failed to update email: $e');
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail() async {
    final currentEmail = _auth.currentUser?.email?.trim() ?? '';
    if (currentEmail.isEmpty) {
      AppDialogs.error(
        'Reset Unavailable',
        'This account does not have an email address.',
      );
      return false;
    }

    try {
      await _passwordResetService.sendResetEmail(currentEmail);
      AppDialogs.success(
        'Check Your Email',
        'A password reset link has been sent to $currentEmail.',
        durationSeconds: 4,
      );
      return true;
    } on FirebaseAuthException catch (error) {
      AppDialogs.error(
        'Reset Failed',
        PasswordResetService.errorMessage(error),
      );
      return false;
    } catch (_) {
      AppDialogs.error(
        'Reset Failed',
        'Unable to send the password reset email.',
      );
      return false;
    }
  }

  /// Update birth date in Firestore.
  Future<bool> updateBirthDate(String newBirthDate) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final trimmed = newBirthDate.trim();
    final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!regex.hasMatch(trimmed)) {
      AppDialogs.error('Invalid Date', 'Use YYYY-MM-DD format');
      return false;
    }
    try {
      final date = DateTime.parse(trimmed);
      final dateParts = trimmed.split('-').map(int.parse).toList();
      if (date.year != dateParts[0] ||
          date.month != dateParts[1] ||
          date.day != dateParts[2]) {
        throw const FormatException('Invalid calendar date');
      }
      final now = DateTime.now();
      if (date.isAfter(now)) {
        AppDialogs.error('Invalid Date', 'Birth date cannot be in the future');
        return false;
      }
      var age = now.year - date.year;
      if (now.month < date.month ||
          (now.month == date.month && now.day < date.day)) {
        age--;
      }
      if (age > 150) {
        AppDialogs.error('Invalid Date', 'Age seems unrealistic');
        return false;
      }
      if (age < 5) {
        AppDialogs.error('Invalid Date', 'Age seems too young');
        return false;
      }
    } catch (_) {
      AppDialogs.error('Invalid Date', 'Could not parse the date');
      return false;
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'birthDate': trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (userModel.value != null) {
        userModel.value = userModel.value!.copyWith(birthDate: trimmed);
      }

      AppDialogs.success('Updated', 'Birth date saved');
      return true;
    } catch (e) {
      AppDialogs.error('Error', 'Failed to update birth date: $e');
      return false;
    }
  }

  /// Persist notification preference and add/remove this device token.
  Future<bool> updateNotificationsEnabled(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null || isUpdatingNotifications.value) return false;

    final previousValue = notificationsEnabled.value;
    notificationsEnabled.value = enabled;
    isUpdatingNotifications.value = true;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'notificationsEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (Get.isRegistered<PushNotificationService>()) {
        await Get.find<PushNotificationService>().applyNotificationPreference(
          enabled,
        );
      }

      if (userModel.value != null) {
        userModel.value = userModel.value!.copyWith(
          notificationsEnabled: enabled,
        );
      }

      AppDialogs.success(
        enabled ? 'Notifications On' : 'Notifications Off',
        enabled
            ? 'Guild alerts will be sent to this device.'
            : 'This device will stop receiving push alerts.',
      );
      return true;
    } catch (e) {
      notificationsEnabled.value = previousValue;
      AppDialogs.error('Error', 'Failed to update notifications: $e');
      return false;
    } finally {
      isUpdatingNotifications.value = false;
    }
  }

  Future<bool> updateProfileVisibility(bool visible) {
    return _updatePrivacySetting(
      field: 'profileVisible',
      value: visible,
      currentValue: profileVisible,
      successTitle: visible ? 'Profile Visible' : 'Profile Hidden',
      successMessage: visible
          ? 'Other adventurers can view your profile.'
          : 'Other adventurers will see that your profile is private.',
      applyToModel: (model) => model.copyWith(profileVisible: visible),
    );
  }

  Future<bool> updatePostStatsVisibility(bool visible) async {
    final updated = await _updatePrivacySetting(
      field: 'postStatsVisible',
      value: visible,
      currentValue: postStatsVisible,
      successTitle: visible ? 'Post Stats Visible' : 'Post Stats Hidden',
      successMessage: visible
          ? 'Other adventurers can view your post stats.'
          : 'Reaction and review stats will be hidden from other adventurers.',
      applyToModel: (model) => model.copyWith(postStatsVisible: visible),
    );

    if (updated && Get.isRegistered<GuildController>()) {
      Get.find<GuildController>().userPostStatsVisible[uid] = visible;
    }

    return updated;
  }

  Future<bool> _updatePrivacySetting({
    required String field,
    required bool value,
    required RxBool currentValue,
    required String successTitle,
    required String successMessage,
    required UserModel Function(UserModel model) applyToModel,
  }) async {
    final user = _auth.currentUser;
    if (user == null || isUpdatingPrivacy.value) return false;

    final previousValue = currentValue.value;
    currentValue.value = value;
    isUpdatingPrivacy.value = true;

    try {
      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(user.uid), {
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(
        _firestore.collection('publicProfiles').doc(user.uid),
        {field: value, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      await batch.commit();

      if (userModel.value != null) {
        userModel.value = applyToModel(userModel.value!);
      }

      AppDialogs.success(successTitle, successMessage);
      return true;
    } catch (e) {
      currentValue.value = previousValue;
      AppDialogs.error('Error', 'Failed to update privacy setting: $e');
      return false;
    } finally {
      isUpdatingPrivacy.value = false;
    }
  }

  /// Sign out from Google & Firebase, then navigate to welcome.
  Future<void> logout() async {
    try {
      AppDialogs.showLoading(message: 'Logging out...');

      if (!kIsWeb) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (e) {
          print('--- GOOGLE SIGN-OUT ERROR: $e ---');
        }
      }
      await _auth.signOut();

      AppDialogs.dismissLoading();

      AppDialogs.info('Logged Out', 'See you next time, adventurer!');

      await Future.delayed(const Duration(milliseconds: 500));
      Get.offAllNamed(AppRoutes.WELCOME);
    } catch (e) {
      AppDialogs.dismissLoading();
      print('--- LOGOUT ERROR: $e ---');
      AppDialogs.error('Logout Failed', 'Error: $e');
    }
  }

  /// Permanently delete the user's account and all their data.
  Future<bool> deleteAccount() async {
    if (_auth.currentUser == null || _isDeletingAccount) return false;
    _isDeletingAccount = true;

    try {
      AppDialogs.showLoading(message: 'Deleting account...');

      await _functions.httpsCallable('deleteAccount').call<void>();
      await _clearLocalSessionAfterDeletion();

      AppDialogs.dismissLoading();

      AppDialogs.success(
        'Account Deleted',
        'Your account has been permanently removed.',
        durationSeconds: 3,
      );

      await Future.delayed(const Duration(milliseconds: 500));
      Get.offAllNamed(AppRoutes.WELCOME);
      return true;
    } on FirebaseFunctionsException catch (e) {
      AppDialogs.dismissLoading();
      print('--- DELETE ACCOUNT FUNCTION ERROR: ${e.code} ${e.message} ---');
      final message = e.code == 'unauthenticated'
          ? 'Your session expired. Please sign in again and retry.'
          : e.message ?? 'Account deletion failed. Please try again.';
      AppDialogs.error('Unable to Delete Account', message);
      return false;
    } catch (e) {
      AppDialogs.dismissLoading();
      print('--- DELETE ACCOUNT ERROR: $e ---');
      AppDialogs.error('Error', 'Failed to delete account: $e');
      return false;
    } finally {
      _isDeletingAccount = false;
    }
  }

  Future<void> _clearLocalSessionAfterDeletion() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (e) {
        print('--- GOOGLE SESSION CLEANUP ERROR: $e ---');
      }
    }

    try {
      await _auth.signOut();
    } catch (e) {
      print('--- FIREBASE SESSION CLEANUP ERROR: $e ---');
    }
  }
}
