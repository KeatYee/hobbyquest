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
import '../services/quest_service.dart';
import '../services/goal_history_service.dart';
import '../services/push_notification_service.dart';
import '../models/goal_history_model.dart';
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
  var gender = "".obs;
  var avatarSvg = "".obs;

  // --- AVATAR SELECTION ---
  static const List<Map<String, String>> _avatarClasses = [
    {
      'name': 'Cultivator',
      'asset': 'cultivator',
      'description': 'I love mastering skills step-by-step and watching my knowledge grow.',
    },
    {
      'name': 'Earthbreaker',
      'asset': 'earthbreaker',
      'description': 'I thrive by innovating, challenging the system, and trying unconventional approaches.',
    },
    {
      'name': 'Grovekeeper',
      'asset': 'grovekeeper',
      'description': 'I learn best by connecting with others and sharing our forest of progress.',
    },
    {
      'name': 'Harvester',
      'asset': 'harvester',
      'description': 'I am driven by collecting rewards, badges, and tangible proof of my hard work.',
    },
    {
      'name': 'Nurturer',
      'asset': 'nurturer',
      'description': 'I gain motivation by helping fellow learners and contributing to our community.',
    },
    {
      'name': 'Wildseed',
      'asset': 'wildseed',
      'description': 'I enjoy exploring new hobbies and forging my own unique learning path.',
    },
  ];

  List<Map<String, String>> getFilteredAvatars(String gender) {
    final result = <Map<String, String>>[];

    if (gender == "Male") {
      for (final avatar in _avatarClasses) {
        result.add({
          'name': avatar['name']!,
          'assetPath': "assets/images/avatar_${avatar['asset']}_m.png",
          'description': avatar['description']!,
        });
      }
    } else if (gender == "Female") {
      for (final avatar in _avatarClasses) {
        result.add({
          'name': avatar['name']!,
          'assetPath': "assets/images/avatar_${avatar['asset']}_f.png",
          'description': avatar['description']!,
        });
      }
    } else {
      // No gender or "Other": show all 12 avatars
      for (final avatar in _avatarClasses) {
        result.add({
          'name': avatar['name']!,
          'assetPath': "assets/images/avatar_${avatar['asset']}_m.png",
          'description': avatar['description']!,
        });
        result.add({
          'name': avatar['name']!,
          'assetPath': "assets/images/avatar_${avatar['asset']}_f.png",
          'description': avatar['description']!,
        });
      }
    }

    return result;
  }

  void clearAvatarIfGenderMismatch(String newGender) {
    if (avatarSvg.value.isEmpty) return;
    if (newGender == "Male" && !avatarSvg.value.contains('_m.')) {
      avatarSvg.value = "";
    } else if (newGender == "Female" && !avatarSvg.value.contains('_f.')) {
      avatarSvg.value = "";
    }
    // For "Other", keep any avatar
  }

  void updateAvatar(String svg) {
    avatarSvg.value = svg;
  }

  /// Extract the avatar class name from the asset path (e.g., "Cultivator", "Wildseed").
  String get avatarClassName {
    if (avatarSvg.value.isEmpty) return "";
    final filename = avatarSvg.value.split('/').last; // e.g. "avatar_cultivator_m.png"
    final parts = filename.split('_');
    if (parts.length >= 3) {
      final name = parts[1]; // "cultivator"
      return name[0].toUpperCase() + name.substring(1);
    }
    return "";
  }

  // --- STEP 2: CATEGORY + HOBBY ---
  var category = "".obs;
  var hobby = "".obs;

  // --- STEP 3: LEVEL ---
  var level = "Novice".obs;

  // --- STEP 4: GOALS ---
  var frequency = "".obs;
  final goalController = TextEditingController();
  var isGoalValidating = false.obs;
  var goalValidationError = ''.obs;
  var isPredefinedGoal = false.obs;

  // --- THE GENERATED PLAN (For Summary View) ---
  var generatedPlan = Rx<QuestPlanModel>(
    QuestPlanModel(
      hobby: "",
      level: "",
      goal: "",
      frequency: "",
      progress: 0,
      currentMilestoneIndex: 0,
      milestones: [],
      quests: []
    )
  );

  @override
  void onInit() {
    super.onInit();
    pageController = PageController();
    _initCategories();
  }

  Future<void> _initCategories() async {
    await seedCategories();
    await _loadCategories();
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
    // 1. Validate the goal with AI first (skip for predefined goals)
    if (!isPredefinedGoal.value) {
      isGoalValidating.value = true;
      goalValidationError.value = '';

      try {
        final validation = await _geminiService.validateGoal(
          hobby: hobby.value,
          level: level.value,
          goal: goalController.text,
        );

        if (!validation.isValid) {
          goalValidationError.value = validation.reason;
          isGoalValidating.value = false;
          return;
        }
      } catch (e) {
        print("--- ERROR: Goal validation failed: $e ---");
        goalValidationError.value = 'Unable to validate goal. Please try again.';
        isGoalValidating.value = false;
        return;
      }

      isGoalValidating.value = false;
    }

    // 2. Generate the plan
    isGenerating.value = true; // Start loading spinner

    try {
      generatedPlan.value = await _geminiService.generateQuestPlan(
        hobby: hobby.value,
        level: level.value,
        goal: goalController.text,
        frequency: frequency.value,
      );
    } catch (e) {
      print("--- ERROR: Failed to generate plan: $e ---");
      generatedPlan.value = QuestPlanModel(
        hobby: hobby.value,
        level: level.value,
        goal: goalController.text.isNotEmpty ? goalController.text : "Master ${hobby.value}",
        frequency: frequency.value,
        progress: 0,
        currentMilestoneIndex: 0,
        milestones: [
          const MilestoneModel(title: "Phase 1: Foundations", completed: false),
          const MilestoneModel(title: "Phase 2: Consistency", completed: false),
          const MilestoneModel(title: "Phase 3: Advanced Skills", completed: false),
          const MilestoneModel(title: "Phase 4: The Final Boss", completed: false),
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
      gender: gender.value,
      category: category.value,
      hobby: hobby.value,
      level: level.value,
      goal: goalController.text,
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
      final uid = user.uid;

      // Build the initial plan with milestones and quests
      final planWithData = await _buildInitialPlanWithMilestoneQuests();
      final planId = 'plan_001';

      // Build milestones with IDs
      final milestones = planWithData.milestones.asMap().entries.map((e) {
        return e.value.copyWith(
          id: e.value.id.isNotEmpty ? e.value.id : 'ms_${e.key}',
          order: e.key,
        );
      }).toList();

      // Prepare quests (set as active, not completed — preserve DAG)
      final quests = planWithData.quests.map((q) => q.copyWith(
        isActive: true,
        isCompleted: false,
      )).toList();

      // Create UserModel WITHOUT milestones/quests in currentPlan
      final userModel = UserModel(
        id: uid,
        nickname: nickname.text.trim(),
        birthDate: age.text.trim(),
        gender: gender.value,
        avatarSvg: avatarSvg.value,
        isOnboardingComplete: true,
        totalXP: 0,
        activePlanId: planId,
        currentPlan: planWithData.copyWith(
          id: planId,
          milestones: milestones,
          quests: quests,
        ),
        currentStreak: 0,
        categoryXp: {
          for (final cat in categories.value)
            cat.name: 0,
        },
        mapTutorialDone: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save user profile to user doc (currentPlan not serialized)
      final userData = userModel.toJson();
      userData['createdAt'] = FieldValue.serverTimestamp();
      userData['updatedAt'] = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(userData, SetOptions(merge: true));

      // Write plan metadata to subcollection
      await QuestService.savePlan(uid, planId, planWithData.copyWith(
        id: planId,
        currentMilestoneIndex: 0,
        isActive: true,
      ));

      // Write milestones to subcollection
      for (final ms in milestones) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('plans')
            .doc(planId)
            .collection('milestones')
            .doc(ms.id)
            .set(ms.toJson());
      }

      // Write quests to subcollection
      for (final quest in quests) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('plans')
            .doc(planId)
            .collection('quests')
            .doc(quest.nodeId)
            .set(quest.toJson());
      }

      // Save initial goal history
      await GoalHistoryService.saveGoalHistory(uid, GoalHistoryModel(
        hobby: planWithData.hobby,
        level: planWithData.level,
        goal: planWithData.goal,
        frequency: planWithData.frequency,
        category: category.value,
        createdAt: DateTime.now(),
      ));

      if (Get.isRegistered<PushNotificationService>()) {
        await Get.find<PushNotificationService>().registerCurrentDevice();
      }

      print("--- SUCCESS: User profile, plan, and goal history saved ---");
    } catch (e) {
      print("--- ERROR: Failed to save user data: $e ---");
      rethrow;
    }
  }

  Future<QuestPlanModel> _buildInitialPlanWithMilestoneQuests() async {
    final basePlan = generatedPlan.value;
    if (basePlan.milestones.isEmpty) {
      return basePlan;
    }

    final firstMilestone = basePlan.milestones.first;
    final initialQuests = await _geminiService.generatePhaseDAG(
      hobby: basePlan.hobby,
      level: basePlan.level,
      goal: basePlan.goal,
      frequency: basePlan.frequency,
      milestoneTitle: firstMilestone.title,
      milestoneNumber: '1',
    );

    return basePlan.copyWith(
      currentMilestoneIndex: 0,
      progress: 0,
      quests: initialQuests,
    );
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
        iconCodePoint: Icons.palette.codePoint,
        hobbies: [
          HobbyEntry(name: "Painting", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Creativity', icon: Icons.lightbulb_outline),
            PeerReviewAxisModel.fromIconData(label: 'Technique', icon: Icons.brush),
            PeerReviewAxisModel.fromIconData(label: 'Color Theory', icon: Icons.palette_outlined),
          ]),
          HobbyEntry(name: "Drawing", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Composition', icon: Icons.grid_view),
            PeerReviewAxisModel.fromIconData(label: 'Line Work', icon: Icons.gesture),
            PeerReviewAxisModel.fromIconData(label: 'Shading', icon: Icons.gradient),
          ]),
          HobbyEntry(name: "Photography", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Composition', icon: Icons.center_focus_strong),
            PeerReviewAxisModel.fromIconData(label: 'Lighting', icon: Icons.wb_sunny),
            PeerReviewAxisModel.fromIconData(label: 'Editing', icon: Icons.tune),
          ]),
          HobbyEntry(name: "Calligraphy", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Letter Form', icon: Icons.text_fields),
            PeerReviewAxisModel.fromIconData(label: 'Consistency', icon: Icons.compare_arrows),
            PeerReviewAxisModel.fromIconData(label: 'Ink Control', icon: Icons.edit),
          ]),
        ],
      ),
      CategoryModel(
        id: '',
        name: "Music & Performing",
        description: "Play, sing, and perform",
        iconCodePoint: Icons.music_note.codePoint,
        hobbies: [
          HobbyEntry(name: "Guitar", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Rhythm', icon: Icons.music_note),
            PeerReviewAxisModel.fromIconData(label: 'Technique', icon: Icons.touch_app),
            PeerReviewAxisModel.fromIconData(label: 'Musicality', icon: Icons.hearing),
          ]),
          HobbyEntry(name: "Piano", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Technique', icon: Icons.piano),
            PeerReviewAxisModel.fromIconData(label: 'Expression', icon: Icons.sentiment_satisfied_alt),
            PeerReviewAxisModel.fromIconData(label: 'Sight Reading', icon: Icons.visibility),
          ]),
          HobbyEntry(name: "Singing", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Pitch', icon: Icons.graphic_eq),
            PeerReviewAxisModel.fromIconData(label: 'Tone', icon: Icons.mic),
            PeerReviewAxisModel.fromIconData(label: 'Breath Control', icon: Icons.air),
          ]),
          HobbyEntry(name: "Dance", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Choreography', icon: Icons.directions_run),
            PeerReviewAxisModel.fromIconData(label: 'Expression', icon: Icons.mood),
            PeerReviewAxisModel.fromIconData(label: 'Technique', icon: Icons.accessibility_new),
          ]),
        ],
      ),
      CategoryModel(
        id: '',
        name: "Lifestyle & Wellness",
        description: "Heal your body and mind",
        iconCodePoint: Icons.self_improvement.codePoint,
        hobbies: [
          HobbyEntry(name: "Yoga", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Alignment', icon: Icons.straighten),
            PeerReviewAxisModel.fromIconData(label: 'Flexibility', icon: Icons.accessibility),
            PeerReviewAxisModel.fromIconData(label: 'Mindfulness', icon: Icons.self_improvement),
          ]),
          HobbyEntry(name: "Fitness/Gym", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Form', icon: Icons.fitness_center),
            PeerReviewAxisModel.fromIconData(label: 'Intensity', icon: Icons.trending_up),
            PeerReviewAxisModel.fromIconData(label: 'Consistency', icon: Icons.loop),
          ]),
          HobbyEntry(name: "Meditation", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Focus', icon: Icons.center_focus_strong),
            PeerReviewAxisModel.fromIconData(label: 'Duration', icon: Icons.timer),
            PeerReviewAxisModel.fromIconData(label: 'Mindfulness', icon: Icons.spa),
          ]),
          HobbyEntry(name: "Cooking", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Taste', icon: Icons.restaurant),
            PeerReviewAxisModel.fromIconData(label: 'Presentation', icon: Icons.dinner_dining),
            PeerReviewAxisModel.fromIconData(label: 'Technique', icon: Icons.kitchen),
          ]),
        ],
      ),
      CategoryModel(
        id: '',
        name: "Skill & Strategy",
        description: "Sharpen your mind",
        iconCodePoint: Icons.psychology.codePoint,
        hobbies: [
          HobbyEntry(name: "Coding", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Code Quality', icon: Icons.code),
            PeerReviewAxisModel.fromIconData(label: 'Efficiency', icon: Icons.speed),
            PeerReviewAxisModel.fromIconData(label: 'Readability', icon: Icons.article),
          ]),
          HobbyEntry(name: "Chess", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Strategy', icon: Icons.psychology),
            PeerReviewAxisModel.fromIconData(label: 'Tactics', icon: Icons.bolt),
            PeerReviewAxisModel.fromIconData(label: 'Endgame', icon: Icons.flag),
          ]),
          HobbyEntry(name: "Language", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Vocabulary', icon: Icons.menu_book),
            PeerReviewAxisModel.fromIconData(label: 'Grammar', icon: Icons.checklist),
            PeerReviewAxisModel.fromIconData(label: 'Pronunciation', icon: Icons.record_voice_over),
          ]),
          HobbyEntry(name: "Public Speaking", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Clarity', icon: Icons.record_voice_over),
            PeerReviewAxisModel.fromIconData(label: 'Engagement', icon: Icons.group),
            PeerReviewAxisModel.fromIconData(label: 'Structure', icon: Icons.account_tree),
          ]),
        ],
      ),
    ];

    // 2. Upload Loop
    for (var category in initialData) {
      // Check if exists to prevent duplicates
      var snapshot = await collection.where('name', isEqualTo: category.name).get();
      if (snapshot.docs.isEmpty) {
        final data = Map<String, dynamic>.from(category.toJson());
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
    goalController.dispose();
    super.onClose();
  }
}
