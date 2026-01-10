import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../routes/app_routes.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void onReady() {
    super.onReady();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    // 1. Check if user is logged into Firebase Auth
    User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      // Case A: Not logged in at all -> Go to Welcome/Login
      Get.offAllNamed(AppRoutes.WELCOME);
    } else {
      // Case B: Logged in! But did they finish onboarding?
      // Check if their document exists in the 'users' collection
      final userDoc = await _db.collection('users').doc(currentUser.uid).get();

      if (userDoc.exists) {
        // Case B1: Profile exists -> Go to Home
        Get.offAllNamed(AppRoutes.HOME);
      } else {
        // Case B2: Zombie User (Auth yes, Data no) -> Force back to Onboarding
        print("User has account but no profile. Redirecting to Onboarding...");
        Get.offAllNamed(AppRoutes.ONBOARDING);
      }
    }
  }
}