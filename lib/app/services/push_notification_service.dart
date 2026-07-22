import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/color_constants.dart';
import '../../core/utils/user_profile_state.dart';
import '../routes/app_routes.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService extends GetxService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  String? _lastUid;
  String? _lastToken;
  RemoteMessage? _pendingInitialMessage;
  Map<String, dynamic>? _pendingTapArguments;
  String? _lastHandledMessageKey;
  bool _messageHandlersBound = false;

  Future<PushNotificationService> init() async {
    await _requestPermission();
    await _bindMessageHandlers();
    await registerCurrentDevice();

    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        await _removeLastToken();
        return;
      }

      await registerCurrentDevice();
      await _openPendingTapArguments();
    });

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      if (!await _notificationsEnabledFor(uid)) {
        await _removeToken(uid, token);
        return;
      }

      await _removeLastToken();
      await _saveToken(uid, token);
    });

    return this;
  }

  Future<void> openPendingInitialMessageIfAny() async {
    final message = _pendingInitialMessage;
    _pendingInitialMessage = null;

    if (message != null) {
      await _handleNotificationTap(message);
      return;
    }

    await _openPendingTapArguments();
  }

  Future<void> registerCurrentDevice() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    if (!await _notificationsEnabledFor(uid)) {
      await _removeCurrentDeviceToken(uid);
      return;
    }

    String? token;
    try {
      token = await _messaging.getToken();
    } catch (e) {
      print('--- ERROR: Failed to get FCM token: $e ---');
      return;
    }

    if (token == null || token.trim().isEmpty) return;

    await _saveToken(uid, token);
  }

  Future<void> applyNotificationPreference(bool enabled) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    if (!enabled) {
      await _removeCurrentDeviceToken(uid);
      return;
    }

    await _requestPermission();
    await registerCurrentDevice();
  }

  Future<void> _requestPermission() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      print(
        '--- ERROR: Failed to initialize push notification permission: $e ---',
      );
    }
  }

  Future<void> _bindMessageHandlers() async {
    if (_messageHandlersBound) return;
    _messageHandlersBound = true;

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTap,
    );

    _pendingInitialMessage = await _messaging.getInitialMessage();
    if (_pendingInitialMessage != null) {
      unawaited(_openInitialMessageAfterStartup());
    }
  }

  Future<void> _openInitialMessageAfterStartup() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await openPendingInitialMessageIfAny();
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title?.trim();
    final body = message.notification?.body?.trim();

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    Get.snackbar(
      title?.isNotEmpty == true ? title! : 'New notification',
      body?.isNotEmpty == true ? body! : 'Tap to view it.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.surface,
      colorText: AppColors.textPrimary,
      icon: const Icon(
        Icons.notifications_active_outlined,
        color: AppColors.primary,
      ),
      borderColor: AppColors.border,
      borderWidth: 1,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 5),
      onTap: (_) => unawaited(_handleNotificationTap(message)),
    );
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    final arguments = _routeArgumentsFor(message);
    if (arguments == null) return;

    final messageKey = _messageKeyFor(message);
    if (messageKey.isNotEmpty && messageKey == _lastHandledMessageKey) {
      return;
    }
    _lastHandledMessageKey = messageKey;

    if (_auth.currentUser == null) {
      _pendingTapArguments = arguments;
      Get.offAllNamed(AppRoutes.WELCOME);
      return;
    }

    if (await _hasCompletedProfile()) {
      _openDashboard(arguments);
    } else {
      _pendingTapArguments = null;
      Get.offAllNamed(AppRoutes.ONBOARDING);
    }
  }

  Map<String, dynamic>? _routeArgumentsFor(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? '').toString().trim();
    final postId = (data['postId'] ?? '').toString().trim();
    final guildPostPath = (data['guildPostPath'] ?? '').toString().trim();

    final isGuildPostNotification =
        type == 'post_reaction' ||
        type == 'post_review' ||
        postId.isNotEmpty ||
        guildPostPath.startsWith('guild_posts/');

    if (!isGuildPostNotification) {
      return null;
    }

    return {
      'tabIndex': 2,
      'notificationType': type,
      'postId': postId.isNotEmpty ? postId : _postIdFromPath(guildPostPath),
      'actorId': (data['actorId'] ?? '').toString().trim(),
      'guildPostPath': guildPostPath,
    };
  }

  String _postIdFromPath(String path) {
    final parts = path
        .split('/')
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.length >= 2 && parts.first == 'guild_posts') {
      return parts[1];
    }
    return '';
  }

  String _messageKeyFor(RemoteMessage message) {
    final messageId = message.messageId?.trim() ?? '';
    if (messageId.isNotEmpty) return messageId;

    final data = message.data;
    return [
      data['type'],
      data['postId'],
      data['actorId'],
      data['guildPostPath'],
      message.sentTime?.millisecondsSinceEpoch,
    ].map((value) => value?.toString() ?? '').join('|');
  }

  Future<void> _openPendingTapArguments() async {
    final arguments = _pendingTapArguments;
    if (arguments == null || _auth.currentUser == null) return;

    if (!await _hasCompletedProfile()) {
      _pendingTapArguments = null;
      Get.offAllNamed(AppRoutes.ONBOARDING);
      return;
    }

    _pendingTapArguments = null;
    _openDashboard(arguments);
  }

  Future<bool> _hasCompletedProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      final snapshot = await _firestore.collection('users').doc(uid).get();
      return hasCompletedUserProfile(snapshot.data());
    } catch (e) {
      print('--- ERROR: Failed to verify onboarding state: $e ---');
      return false;
    }
  }

  void _openDashboard(Map<String, dynamic> arguments) {
    Future<void>.delayed(Duration.zero, () {
      Get.offAllNamed(AppRoutes.DASHBOARD, arguments: arguments);
    });
  }

  Future<void> _saveToken(String uid, String token) async {
    try {
      // update() deliberately refuses to create a token-only user document.
      await _firestore.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      _lastUid = uid;
      _lastToken = token;
    } catch (e) {
      print('--- ERROR: Failed to save FCM token: $e ---');
    }
  }

  Future<bool> _notificationsEnabledFor(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      if (!hasCompletedUserProfile(data)) return false;
      final value = data?['notificationsEnabled'];
      return value is bool ? value : true;
    } catch (e) {
      print('--- ERROR: Failed to read notification preference: $e ---');
      return false;
    }
  }

  Future<void> _removeToken(String uid, String token) async {
    if (token.trim().isEmpty) return;

    try {
      await _firestore.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
    } finally {
      if (_lastUid == uid && _lastToken == token) {
        _lastUid = null;
        _lastToken = null;
      }
    }
  }

  Future<void> _removeCurrentDeviceToken(String uid) async {
    final tokens = <String>{};
    final lastToken = _lastUid == uid ? _lastToken : null;
    if (lastToken != null && lastToken.trim().isNotEmpty) {
      tokens.add(lastToken);
    }

    try {
      final currentToken = await _messaging.getToken();
      if (currentToken != null && currentToken.trim().isNotEmpty) {
        tokens.add(currentToken);
      }
    } catch (e) {
      print('--- ERROR: Failed to get FCM token for removal: $e ---');
    }

    if (tokens.isEmpty) return;

    try {
      await _firestore.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove(tokens.toList()),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
    } finally {
      if (_lastUid == uid && tokens.contains(_lastToken)) {
        _lastUid = null;
        _lastToken = null;
      }
    }
  }

  Future<void> _removeLastToken() async {
    final uid = _lastUid;
    final token = _lastToken;
    if (uid == null || token == null) return;

    try {
      await _firestore.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
    } finally {
      _lastUid = null;
      _lastToken = null;
    }
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    _messageOpenedSubscription?.cancel();
    super.onClose();
  }
}
