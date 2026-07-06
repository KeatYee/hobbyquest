import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';

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
  String? _lastUid;
  String? _lastToken;

  Future<PushNotificationService> init() async {
    await _requestPermission();
    await registerCurrentDevice();

    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        await _removeLastToken();
        return;
      }

      await registerCurrentDevice();
    });

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      await _removeLastToken();
      await _saveToken(uid, token);
    });

    return this;
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
    super.onClose();
  }
}
