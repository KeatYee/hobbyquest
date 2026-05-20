import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../routes/app_routes.dart';
import '../models/quest_plan_model.dart';
import '../models/milestone_model.dart';
import '../models/category_model.dart';
import '../models/user_model.dart';
import '../services/category_service.dart';
import '../services/gemini_service.dart';
import '../views/pages/onboarding/plan_summary_view.dart';

class OnboardingController extends GetxController {

  final CategoryService _categoryService = CategoryService();
  final GeminiService _geminiService = GeminiService();

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
  var avatarSvg = "".obs;

  void updateAvatar(String svg) {
    avatarSvg.value = svg;
  }

  // --- STEP 2: CATEGORY + HOBBY ---
  var selectedCategory = "".obs;
  var selectedHobby = "".obs;

  // --- STEP 3: LEVEL ---
  var selectedLevel = "Novice".obs;

  // --- STEP 4: GOALS ---
  var frequency = "15 mins/day".obs;
  final goalInput = TextEditingController();

  // --- THE GENERATED PLAN (For Summary View) ---
  var generatedPlan = Rx<QuestPlanModel>(
    QuestPlanModel(
      hobbyName: "",
      skillLevel: "",
      customGoal: "",
      frequency: "",
      progress: 0,
      milestones: [],
      quests: []
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

    // If we are on final step (Goals), generate plan.
    if (currentPage.value == 3) {
      await _generateAndShowPlan(); 
      return; 
    }

    // Standard Navigation for Steps 1-3
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

    try {
      generatedPlan.value = await _geminiService.generateQuestPlan(
        hobby: selectedHobby.value,
        level: selectedLevel.value,
        goal: goalInput.text,
        frequency: frequency.value,
      );
    } catch (e) {
      print("--- ERROR: Failed to generate plan: $e ---");
      generatedPlan.value = QuestPlanModel(
        hobbyName: selectedHobby.value,
        skillLevel: selectedLevel.value,
        customGoal: goalInput.text.isNotEmpty ? goalInput.text : "Master ${selectedHobby.value}",
        frequency: frequency.value,
        progress: 0,
        milestones: [
          const MilestoneModel(task: "Phase 1: Foundations", completed: false),
          const MilestoneModel(task: "Phase 2: Consistency", completed: false),
          const MilestoneModel(task: "Phase 3: Advanced Skills", completed: false),
          const MilestoneModel(task: "Phase 4: The Final Boss", completed: false),
        ],
        quests: [],
      );
    } finally {
      isGenerating.value = false; // Stop loading
    }

    // 3. Navigate to Summary Page (Do NOT save to DB yet)
    Get.to(() => const PlanSummaryView());
  }

  /// Validate the current step before allowing navigation
  bool _validateCurrentStep() {
    final result = _geminiService.validateOnboardingStep(
      step: currentPage.value,
      nickname: nickname.text,
      birthDate: age.text,
      gender: selectedGender.value,
      category: selectedCategory.value,
      hobby: selectedHobby.value,
      level: selectedLevel.value,
      goal: goalInput.text,
      frequency: frequency.value,
    );

    if (!result.isValid) {
      print("--- VALIDATION: ${result.error} ---");
      return false;
    }

    return true;
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
      // Create a typed UserModel with onboarding data
      final userModel = UserModel(
        id: user.uid,
        nickname: nickname.text.trim(),
        birthDate: age.text.trim(),
        gender: selectedGender.value,
        avatarSvg: avatarSvg.value,
        isOnboardingComplete: true,
        totalXP: 0,
        currentPlan: generatedPlan.value,
        currentStreak: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to Firestore with timestamp
      final userData = userModel.toJson();
      userData['createdAt'] = FieldValue.serverTimestamp();
      userData['updatedAt'] = FieldValue.serverTimestamp();

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

  // --- FIRESTORE SEEDING (For Dev Only) ---
  Future<void> seedCategories() async {
    print("--- SEEDING FIRESTORE ---");
    // Quick guard: if the collection already has documents, skip seeding.
    final collection = FirebaseFirestore.instance.collection('categories');
    final existingSnapshot = await collection.limit(1).get();
    if (existingSnapshot.docs.isNotEmpty) {
      print("--- SEEDING SKIPPED: 'categories' collection already populated ---");
      return;
    }

    // 1. Define the Data
    List<CategoryModel> initialData = [
      CategoryModel(
        id: '', // Firestore will generate this
        name: "Creative Arts",
        description: "Express yourself visually",
        icon: "🎨", // Using Emoji because it's a String in your model
        hobbies: ["Painting", "Drawing", "Photography", "Calligraphy"],
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
    for (var category in initialData) {
      // Check if exists to prevent duplicates
      var snapshot = await collection.where('name', isEqualTo: category.name).get();
      if (snapshot.docs.isEmpty) {
        final data = Map<String, dynamic>.from(category.toJson());
        data.remove('id'); // Do not store the empty id field in the document
        await collection.add(data);
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