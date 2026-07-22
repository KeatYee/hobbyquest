import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../routes/app_routes.dart';
import '../services/push_notification_service.dart';
import '../../core/utils/user_profile_state.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void onReady() {
    super.onReady();
    checkUserStatus();
  }

  Future<void> checkUserStatus() async {
    User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      Get.offAllNamed(AppRoutes.WELCOME);
    } else {
      try {
        final userDoc = await _db
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (hasCompletedUserProfile(userDoc.data())) {
          if (Get.isRegistered<PushNotificationService>()) {
            await Get.find<PushNotificationService>().registerCurrentDevice();
          }

          Get.offAllNamed(AppRoutes.DASHBOARD);
          if (Get.isRegistered<PushNotificationService>()) {
            await Get.find<PushNotificationService>()
                .openPendingInitialMessageIfAny();
          }
        } else {
          print("User has no completed profile. Redirecting to Onboarding...");
          Get.offAllNamed(AppRoutes.ONBOARDING);
        }
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          print(
            "Firestore denied reading users/${currentUser.uid}. Check Firestore rules for the users collection.",
          );
          Get.offAllNamed(AppRoutes.WELCOME);
        } else {
          rethrow;
        }
      }
    }
  }
}
