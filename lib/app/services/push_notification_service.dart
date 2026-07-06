import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/color_constants.dart';
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
      _openPendingTapArguments();
    });

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

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

    _openPendingTapArguments();
  }

  Future<void> registerCurrentDevice() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

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

  Future<void> _requestPermission() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      print('--- ERROR: Failed to initialize push notification permission: $e ---');
    }
  }

  Future<void> _bindMessageHandlers() async {
    if (_messageHandlersBound) return;
    _messageHandlersBound = true;

    _foregroundMessageSubscription =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    _messageOpenedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

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

    _openDashboard(arguments);
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
    final parts = path.split('/').where((part) => part.trim().isNotEmpty).toList();
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

  void _openPendingTapArguments() {
    final arguments = _pendingTapArguments;
    if (arguments == null || _auth.currentUser == null) return;

    _pendingTapArguments = null;
    _openDashboard(arguments);
  }

  void _openDashboard(Map<String, dynamic> arguments) {
    Future<void>.delayed(Duration.zero, () {
      Get.offAllNamed(AppRoutes.DASHBOARD, arguments: arguments);
    });
  }

  Future<void> _saveToken(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _lastUid = uid;
      _lastToken = token;
    } catch (e) {
      print('--- ERROR: Failed to save FCM token: $e ---');
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
      // The profile may not exist yet, or it may already be deleted.
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
