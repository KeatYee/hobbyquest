import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../routes/app_routes.dart';

class OnboardingController extends GetxController {
  // --- NAVIGATION ---
  // ⚠️ FIX: Do not initialize here. Use 'late' or nullable.
  late PageController pageController; 
  var currentPage = 0.obs;

  // --- STEP 1: IDENTITY ---
  final nickname = TextEditingController();
  final age = TextEditingController();
  var selectedGender = "".obs;

  // --- STEP 2: CATEGORY ---
  var selectedCategory = "".obs;

  // --- STEP 3: HOBBY ---
  var selectedHobby = "".obs;

  // --- STEP 4: LEVEL ---
  var selectedLevel = "Novice".obs;

  // --- STEP 5: GOALS ---
  var frequency = "15 mins/day".obs;
  final goalInput = TextEditingController();

@override
  void onInit() {
    super.onInit();
    print("--- CONTROLLER: onInit() Called. Creating new PageController... ---");
    pageController = PageController();
  }

  // --- DEBUGGED NAVIGATION ---
  void nextPage() {
    print("--- CONTROLLER: nextPage() triggered ---");
    
    // 1. Check if the PageView is actually listening
    if (!pageController.hasClients) {
      print("❌ CRITICAL ERROR: PageController has NO CLIENTS."); 
      print("   (This means the PageView in OnboardingView is not using this controller)");
      return;
    }

    print("--- CONTROLLER: Current Page Index is ${currentPage.value} ---");

    if (currentPage.value < 4) {
      print("--- CONTROLLER: Animating to Page ${currentPage.value + 1}... ---");
      
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      ).then((_) {
        print("--- CONTROLLER: Animation command sent successfully ---");
      });
      
    } else {
      print("--- CONTROLLER: Last page reached. Generating Plan. ---");
      generateQuestPlan();
    }
  }

  void previousPage() {
    if (currentPage.value > 0) {
      pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    } else {
      Get.back();
    }
  }

  Future<void> generateQuestPlan() async {
    // ... (Your existing code)
    await _saveUserDataToFirestore();
    await Future.delayed(const Duration(seconds: 3)); 
    Get.offAllNamed(AppRoutes.HOME);
  }

  Future<void> _saveUserDataToFirestore() async {
    // ... (Your existing code)
  }

  @override
  void onClose() {
    // This kills the controller when you leave.
    // By using onInit above, we ensure a fresh one is made next time.
    pageController.dispose();
    nickname.dispose();
    age.dispose();
    goalInput.dispose();
    super.onClose();
  }
}