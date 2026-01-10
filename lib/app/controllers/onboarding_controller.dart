import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../routes/app_routes.dart';

class OnboardingController extends GetxController {
  // --- NAVIGATION ---
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
  Future<void> nextPage() async {
    print("--- CONTROLLER: nextPage() triggered ---");
    
    // 1. Check if the PageView is actually listening
    if (!pageController.hasClients) {
      print(" CRITICAL ERROR: PageController has NO CLIENTS."); 
      return;
    }

    print("--- CONTROLLER: Current Page Index is ${currentPage.value} ---");

    if (currentPage.value < 4) {
      print("--- CONTROLLER: Animating to Page ${currentPage.value + 1}... ---");
      
      await pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
      print("--- DEBUG: Animation completed successfully ---");
    } else {
      print("--- CONTROLLER: Last page reached. Generating Plan. ---");
      await generateQuestPlan();
    }
  }

  Future<void> previousPage() async {
    if (currentPage.value > 0) {
      await pageController.previousPage(
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