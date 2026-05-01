import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../routes/app_routes.dart';
import '../models/quest_plan_model.dart';
import '../models/category_model.dart';
import '../services/category_service.dart';
import '../views/pages/onboarding/plan_summary_view.dart';

class OnboardingController extends GetxController {

  final CategoryService _categoryService = CategoryService();

  late PageController pageController; // Controller for PageView
  var currentPage = 0.obs; // Track current onboarding step
  var isGenerating = false.obs; // Loading state for plan generation

  // --- CATEGORIES (Fetched from Firestore) ---
  var categories = Rx<List<CategoryModel>>([]);
  var isLoadingCategories = true.obs;

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

  // --- THE GENERATED PLAN (For Summary View) ---
  var generatedPlan = Rx<QuestPlanModel>(
    QuestPlanModel(
      targetBoss: "", 
      duration: "", 
      dailyCommitment: "", 
      milestones: []
    )
  );

  @override
  void onInit() {
    super.onInit();
    pageController = PageController();
    _loadCategories();

    // ⚠️ RUN THIS ONLY ONCE TO UPLOAD DATA, THEN DELETE THIS LINE
    seedCategories();
  }

  /// Load categories from Firestore (with fallback)
  Future<void> _loadCategories() async {
    try {
      isLoadingCategories.value = true;
      final loadedCategories = await _categoryService.getCategories();
      categories.value = loadedCategories;
      print("--- SUCCESS: Loaded ${loadedCategories.length} categories ---");
    } catch (e) {
      print("--- ERROR: Failed to load categories: $e ---");
    } finally {
      isLoadingCategories.value = false;
    }
  }

  // --- NAVIGATION LOGIC ---
  Future<void> nextPage() async {
    if (!pageController.hasClients) {
      print("--- ERROR: PageController has no clients ---");
      return;
    }

    // Validate current step before advancing
    if (!_validateCurrentStep()) {
      return;
    }

    // Close keyboard to prevent animation crashes
    FocusManager.instance.primaryFocus?.unfocus();

    // If we are on Step 5 (Index 4), Generate Plan.
    if (currentPage.value == 4) {
      await _generateAndShowPlan(); 
      return; 
    }

    // Standard Navigation for Steps 1-4
    // Wait for keyboard to close before animating
    await Future.delayed(const Duration(milliseconds: 300));
    
    try {
      await pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      print("--- ERROR: Failed to navigate to next page: $e ---");
    }
  }

  Future<void> previousPage() async {
    if (!pageController.hasClients) return;
    
    FocusManager.instance.primaryFocus?.unfocus();
    
    if (currentPage.value > 0) {
      try {
        await pageController.previousPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } catch (e) {
        print("Error navigating to previous page: $e");
      }
    } else {
      Get.offAllNamed(AppRoutes.WELCOME);
    }
  }

  // --- 🧠 LOGIC: Generate Plan (Step 5 Action) ---
  Future<void> _generateAndShowPlan() async {
    isGenerating.value = true; // Start loading spinner

    // 1. Simulate AI Delay (Later: Call Gemini Here)
    await Future.delayed(const Duration(seconds: 2));

    // 2. Create the "Mock" Plan
    generatedPlan.value = QuestPlanModel(
      targetBoss: goalInput.text.isNotEmpty ? goalInput.text : "Master ${selectedHobby.value}",
      duration: _calculateDuration(),
      dailyCommitment: frequency.value,
      milestones: [
        "Phase 1: Foundations",
        "Phase 2: Consistency",
        "Phase 3: Advanced Skills",
        "Phase 4: The Final Boss"
      ],
    );

    isGenerating.value = false; // Stop loading

    // 3. Navigate to Summary Page (Do NOT save to DB yet)
    Get.to(() => const PlanSummaryView());
  }

  /// Calculate duration based on skill level
  String _calculateDuration() {
    switch (selectedLevel.value) {
      case "Expert":
        return "8 Weeks";
      case "Intermediate":
        return "6 Weeks";
      case "Novice":
      default:
        return "4 Weeks";
    }
  }

  // --- 💾 LOGIC: Confirm & Save (Summary Page Action) ---
  // This is called when user clicks "Accept & Start"
  Future<void> confirmAndStart() async {
    print("--- USER ACCEPTED PLAN. SAVING TO DB... ---");
    
    try {
      isGenerating.value = true;
      await _saveUserDataToFirestore();
      isGenerating.value = false;
      
      // ✅ Navigate to Dashboard (Main App)
      Get.offAllNamed(AppRoutes.DASHBOARD);
    } catch (e) {
      isGenerating.value = false;
      print("--- ERROR: Failed to confirm and start: $e ---");
    }
  }

  Future<void> _saveUserDataToFirestore() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not authenticated");
    }

    try {
      final userData = {
        'nickname': nickname.text.trim(),
        'birthDate': age.text.trim(),
        'gender': selectedGender.value,
        'hobbyCategory': selectedCategory.value,
        'hobbyName': selectedHobby.value,
        'skillLevel': selectedLevel.value,
        'customGoal': generatedPlan.value.targetBoss, // Save the finalized goal
        'frequency': frequency.value,
        'isOnboardingComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
        
        // Initial Gamification Stats
        'level': 1,
        'currentXp': 0,
        'currentStreak': 0,
        'totalMinutesPlayed': 0,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));
      
      print("--- SUCCESS: User profile saved ---");
    } catch (e) {
      print("--- ERROR: Failed to save user data: $e ---");
      rethrow;
    }
  }

  /// Validate the current step before allowing navigation
  bool _validateCurrentStep() {
    switch (currentPage.value) {
      case 0: // Step 1: Identity
        if (nickname.text.trim().isEmpty) {
          print("--- VALIDATION: Nickname is empty ---");
          return false;
        }
        if (age.text.trim().isEmpty) {
          print("--- VALIDATION: Birth date is empty ---");
          return false;
        }
        if (selectedGender.value.isEmpty) {
          print("--- VALIDATION: Gender is not selected ---");
          return false;
        }
        return true;
      case 1: // Step 2: Category
        if (selectedCategory.value.isEmpty) {
          print("--- VALIDATION: Category is not selected ---");
          return false;
        }
        return true;
      case 2: // Step 3: Hobby
        if (selectedHobby.value.isEmpty) {
          print("--- VALIDATION: Hobby is not selected ---");
          return false;
        }
        return true;
      case 3: // Step 4: Level
        if (selectedLevel.value.isEmpty) {
          print("--- VALIDATION: Level is not selected ---");
          return false;
        }
        return true;
      case 4: // Step 5: Goals
        if (goalInput.text.trim().isEmpty && selectedHobby.value.isEmpty) {
          print("--- VALIDATION: Goal and hobby are empty ---");
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  // --- FIRESTORE SEEDING (For Dev Only) ---
  Future<void> seedCategories() async {
    print("--- SEEDING FIRESTORE ---");
    
    // 1. Define the Data
    List<CategoryModel> initialData = [
      CategoryModel(
        id: '', // Firestore will generate this
        name: "Creative Arts",
        description: "Express yourself visually",
        icon: "🎨", // Using Emoji because it's a String in your model
        hobbies: ["Painting", "Digital Art", "Photography", "Calligraphy"],
      ),
      CategoryModel(
        id: '',
        name: "Music & Performing",
        description: "Play, sing, and perform",
        icon: "🎭",
        hobbies: ["Guitar", "Piano", "Singing", "Dance"],
      ),
      CategoryModel(
        id: '',
        name: "Lifestyle & Wellness",
        description: "Heal your body and mind",
        icon: "🧘",
        hobbies: ["Yoga", "Fitness/Gym", "Meditation", "Cooking"],
      ),
      CategoryModel(
        id: '',
        name: "Skill & Strategy",
        description: "Sharpen your mind",
        icon: "♟️",
        hobbies: ["Coding", "Chess", "Language", "Public Speaking"],
      ),
    ];

    // 2. Upload Loop
    final collection = FirebaseFirestore.instance.collection('categories');
    
    for (var category in initialData) {
      // Check if exists to prevent duplicates
      var snapshot = await collection.where('name', isEqualTo: category.name).get();
      if (snapshot.docs.isEmpty) {
        await collection.add(category.toJson());
        print("✅ Added ${category.name}");
      } else {
        print("⚠️ Skipped ${category.name} (Already exists)");
      }
    }
    print("--- SEEDING COMPLETE ---");
  }

  @override
  void onClose() {
    // Properly dispose of resources
    pageController.dispose();
    nickname.dispose();
    age.dispose();
    goalInput.dispose();
    super.onClose();
  }
}