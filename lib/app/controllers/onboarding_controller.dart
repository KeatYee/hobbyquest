import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OnboardingController extends GetxController {
  // Page Controller to manage sliding
  var pageController = PageController();
  var currentPage = 0.obs;

  // --- STEP 1: IDENTITY ---
  final nickname = TextEditingController();
  final age = TextEditingController();
  var selectedGender = "Male".obs;

  // --- STEP 2: CATEGORY ---
  var selectedCategory = "".obs; // e.g., "Music"

  // --- STEP 3: HOBBY ---
  var selectedHobby = "".obs; // e.g., "Guitar"

  // --- STEP 4: LEVEL ---
  var selectedLevel = "Novice".obs;

  // --- STEP 5: GOALS ---
  var frequency = "15 mins/day".obs;
  final goalInput = TextEditingController(); // e.g., "Play a song"

  // --- NAVIGATION LOGIC ---
  void nextPage() {
    pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  void previousPage() {
    pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  // --- AI GENERATION PLACEHOLDER ---
  Future<void> generateQuestPlan() async {
    // We will code the Gemini connection here in the next step!
    print("Generating plan for ${selectedHobby.value}...");
    await Future.delayed(const Duration(seconds: 3)); // Fake loading
    nextPage(); // Go to results
  }
}