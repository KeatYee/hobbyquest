import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeController extends GetxController {
  // --- STATE VARIABLES (Reactivity) ---
  
  // User Profile Data
  var nickname = "Hero".obs;
  var level = 5.obs;
  var currentXp = 450.obs;
  var requiredXp = 800.obs;
  var currentStreak = 0.obs;
  var selectedHobby = "".obs;
  
  // Loading state
  var isLoadingProfile = true.obs;

  // Computed property for the progress bar (0.0 to 1.0)
  double get xpPercent => currentXp.value / requiredXp.value;

  // Quest List (Mock Data)
  var dailyQuests = <Map<String, dynamic>>[
    {
      "id": "q1",
      "title": "Chord Mastery",
      "desc": "Practice transitions for 15 mins.",
      "xp": 100,
      "type": "practice",
      "isPriority": true,
    },
    {
      "id": "q2",
      "title": "Theory Check",
      "desc": "Identify the G-Major scale.",
      "xp": 50,
      "type": "knowledge",
      "isPriority": false,
    },
    {
      "id": "q3",
      "title": "Creative Flow",
      "desc": "Upload a photo of your practice setup.",
      "xp": 150,
      "type": "challenge",
      "isPriority": false,
    },
  ].obs;

  @override
  void onInit() {
    super.onInit();
    _loadUserProfile();
  }

  /// Load user profile data from Firestore
  Future<void> _loadUserProfile() async {
    try {
      isLoadingProfile.value = true;
      
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("--- ERROR: No user logged in ---");
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        
        // Update reactive variables with user data
        nickname.value = data['nickname'] ?? 'Hero';
        level.value = data['level'] ?? 1;
        currentXp.value = data['currentXp'] ?? 0;
        requiredXp.value = 800; // Or fetch from config
        currentStreak.value = data['currentStreak'] ?? 0;
        selectedHobby.value = data['hobbyName'] ?? 'Learning';
        
        print("--- SUCCESS: Loaded user profile for ${nickname.value} ---");
      } else {
        print("--- WARNING: User profile not found ---");
      }
    } catch (e) {
      print("--- ERROR: Failed to load user profile: $e ---");
    } finally {
      isLoadingProfile.value = false;
    }
  }

  // --- ACTIONS ---

  void rerollDailyQuests() {
    print("--- LOGIC: Rerrolling Quests... ---");
    dailyQuests.shuffle();
  }

  void startQuest(String id) {
    print("--- LOGIC: Starting Quest $id ---");
  }
}