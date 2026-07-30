import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/asset_constants.dart';
import '../routes/app_routes.dart';
import '../models/quest_plan_model.dart';
import '../models/milestone_model.dart';
import '../models/category_model.dart';
import '../models/user_model.dart';
import '../models/quest_node_model.dart';
import '../services/category_service.dart';
import '../services/gemini_service.dart';
import '../services/push_notification_service.dart';
import '../models/goal_history_model.dart';
import '../views/pages/onboarding/plan_summary_view.dart';
import '../../core/utils/performance_tracker.dart';

class OnboardingController extends GetxController {
  final CategoryService _categoryService = CategoryService();
  final GeminiService _geminiService = GeminiService();

  late PageController pageController;
  var currentPage = 0.obs;
  var minimumPage = 0;
  var isGenerating = false.obs;

  var categories = Rx<List<CategoryModel>>([]);
  var isLoadingCategories = true.obs;

  final nickname = TextEditingController();
  final age = TextEditingController();
  var gender = "".obs;
  var avatarSvg = "".obs;

  static const List<Map<String, String>> _avatarClasses = [
    {
      'name': 'Cultivator',
      'asset': 'cultivator',
      'traits': 'Steady|Reflective|Step-by-step',
      'description':
          'For learners who like calm progress, reflection, and improving through small daily steps.',
    },
    {
      'name': 'Earthbreaker',
      'asset': 'earthbreaker',
      'traits': 'Inventive|Independent|Experimental',
      'description':
          'For learners who enjoy challenging the obvious path and trying unconventional approaches.',
    },
    {
      'name': 'Grovekeeper',
      'asset': 'grovekeeper',
      'traits': 'Grounded|Social|Consistent',
      'description':
          'For learners who stay motivated through balance, shared progress, and steady routines.',
    },
    {
      'name': 'Harvester',
      'asset': 'harvester',
      'traits': 'Goal-driven|Focused|Progress-minded',
      'description':
          'For learners who feel energized by milestones, badges, and visible proof of effort.',
    },
    {
      'name': 'Nurturer',
      'asset': 'nurturer',
      'traits': 'Helpful|Empathetic|Community',
      'description':
          'For learners who grow by encouraging others, sharing feedback, and building community.',
    },
    {
      'name': 'Wildseed',
      'asset': 'wildseed',
      'traits': 'Adventurous|Flexible|Self-led',
      'description':
          'For learners who like exploring, experimenting, and forging their own learning path.',
    },
  ];

  List<Map<String, String>> getFilteredAvatars(String gender) {
    final result = <Map<String, String>>[];

    if (gender == "Male") {
      for (final avatar in _avatarClasses) {
        result.add({
          'name': avatar['name']!,
          'assetPath': AppAssets.avatar(avatar['asset']!, 'male'),
          'traits': avatar['traits']!,
          'description': avatar['description']!,
        });
      }
    } else if (gender == "Female") {
      for (final avatar in _avatarClasses) {
        result.add({
          'name': avatar['name']!,
          'assetPath': AppAssets.avatar(avatar['asset']!, 'female'),
          'traits': avatar['traits']!,
          'description': avatar['description']!,
        });
      }
    } else {
      for (final avatar in _avatarClasses) {
        result.add({
          'name': avatar['name']!,
          'assetPath': AppAssets.avatar(avatar['asset']!, 'male'),
          'traits': avatar['traits']!,
          'description': avatar['description']!,
        });
        result.add({
          'name': avatar['name']!,
          'assetPath': AppAssets.avatar(avatar['asset']!, 'female'),
          'traits': avatar['traits']!,
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
  }

  void updateAvatar(String svg) {
    avatarSvg.value = svg;
  }

  /// Extract the avatar class name from the asset path (e.g., "Cultivator", "Wildseed").
  String get avatarClassName {
    if (avatarSvg.value.isEmpty) return "";
    final filename = avatarSvg.value.split('/').last;
    final parts = filename.split('_');
    if (parts.length >= 3) {
      final name = parts[1];
      return name[0].toUpperCase() + name.substring(1);
    }
    return "";
  }

  var category = "".obs;
  var hobby = "".obs;

  var level = "Novice".obs;

  var learningPace = "".obs;
  final goalController = TextEditingController();
  var isGoalValidating = false.obs;
  var goalValidationError = ''.obs;
  var isPredefinedGoal = false.obs;

  void selectHobby(String categoryName, String hobbyName) {
    category.value = categoryName;
    if (hobby.value == hobbyName) return;
    hobby.value = hobbyName;
    _clearPredefinedGoal();
  }

  void selectLevel(String selectedLevel) {
    if (level.value == selectedLevel) return;
    level.value = selectedLevel;
    _clearPredefinedGoal();
  }

  void _clearPredefinedGoal() {
    if (!isPredefinedGoal.value) return;
    goalController.clear();
    isPredefinedGoal.value = false;
    goalValidationError.value = '';
  }

  var generatedPlan = Rx<QuestPlanModel>(
    QuestPlanModel(
      hobby: "",
      level: "",
      goal: "",
      learningPace: "",
      progress: 0,
      currentMilestoneIndex: 0,
      milestones: [],
      quests: [],
    ),
  );

  @override
  void onInit() {
    super.onInit();
    final arguments = Get.arguments;
    final requestedPage = arguments is Map
        ? int.tryParse(arguments['startPage']?.toString() ?? '') ?? 0
        : 0;
    final initialPage = requestedPage.clamp(0, 3).toInt();
    minimumPage = initialPage;
    currentPage.value = initialPage;
    pageController = PageController(initialPage: initialPage);

    if (arguments is Map && initialPage > 0) {
      nickname.text = arguments['nickname']?.toString() ?? '';
      age.text = arguments['birthDate']?.toString() ?? '';
      gender.value = arguments['gender']?.toString() ?? '';
      avatarSvg.value = arguments['avatarSvg']?.toString() ?? '';
    }
    _initCategories();
  }

  Future<void> _initCategories() async {
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

  Future<void> nextPage() async {
    if (!pageController.hasClients) {
      print("--- ERROR: PageController has no clients ---");
      return;
    }

    if (!_validateCurrentStep()) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    if (currentPage.value == 3) {
      await _generateAndShowPlan();
      return;
    }

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

    if (currentPage.value > minimumPage) {
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

  Future<void> _generateAndShowPlan() async {
    await PerformanceTracker.measure<void>(
      'AI_MILESTONE_PLAN_GENERATION',
      () async {
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
            goalValidationError.value =
                'Unable to validate goal. Please try again.';
            isGoalValidating.value = false;
            return;
          }

          isGoalValidating.value = false;
        }

        isGenerating.value = true;

        try {
          generatedPlan.value = await _geminiService.generateQuestPlan(
            hobby: hobby.value,
            level: level.value,
            goal: goalController.text,
            learningPace: learningPace.value,
          );
        } catch (e) {
          print("--- ERROR: Failed to generate plan: $e ---");
          generatedPlan.value = QuestPlanModel(
            hobby: hobby.value,
            level: level.value,
            goal: goalController.text.isNotEmpty
                ? goalController.text
                : "Master ${hobby.value}",
            learningPace: learningPace.value,
            progress: 0,
            currentMilestoneIndex: 0,
            milestones: [
              const MilestoneModel(title: "Phase 1: Foundations", completed: false),
              const MilestoneModel(title: "Phase 2: Consistency", completed: false),
              const MilestoneModel(
                title: "Phase 3: Advanced Skills",
                completed: false,
              ),
              const MilestoneModel(
                title: "Phase 4: The Final Boss",
                completed: false,
              ),
            ],
            quests: [],
          );
        } finally {
          isGenerating.value = false;
        }

        Get.to(() => const PlanSummaryView());

        // Wait until the Plan Summary screen has rendered.
        await Future<void>.delayed(Duration.zero);
        await WidgetsBinding.instance.endOfFrame;
      },
    );
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
      learningPace: learningPace.value,
    );

    if (!result.isValid) {
      print("--- VALIDATION: ${result.error} ---");
      return false;
    }

    return true;
  }

  Future<void> confirmAndStart() async {
    print("--- USER ACCEPTED PLAN. SAVING TO DB... ---");

    await PerformanceTracker.measure<void>(
      'AI_QUEST_GRAPH_GENERATION_TO_DASHBOARD',
      () async {
        try {
          isGenerating.value = true;

          await _saveUserDataToFirestore();

          Get.offAllNamed(AppRoutes.DASHBOARD);

          // Measures until the first Dashboard frame is displayed.
          await Future<void>.delayed(Duration.zero);
          await WidgetsBinding.instance.endOfFrame;
        } catch (e) {
          print("--- ERROR: Failed to confirm and start: $e ---");
        } finally {
          isGenerating.value = false;
        }
      },
    );
  }

  Future<void> _saveUserDataToFirestore() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not authenticated");
    }

    try {
      final uid = user.uid;
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final existingUserSnapshot = await userRef.get();
      final existingUserData = existingUserSnapshot.data();
      final existingUser = existingUserData == null
          ? null
          : UserModel.fromJson(existingUserData, uid);

      final planWithData = await _buildInitialPlanWithMilestoneQuests();
      if (planWithData.milestones.isEmpty || planWithData.quests.isEmpty) {
        throw StateError(
          'The learning plan is incomplete. Please generate it again.',
        );
      }
      final existingPlanId = existingUser?.isOnboardingComplete == false
          ? existingUser?.activePlanId.trim() ?? ''
          : '';
      final planRef = existingPlanId.isEmpty
          ? userRef.collection('plans').doc()
          : userRef.collection('plans').doc(existingPlanId);
      final planId = planRef.id;

      final milestones = planWithData.milestones.asMap().entries.map((e) {
        return e.value.copyWith(
          id: e.value.id.isNotEmpty ? e.value.id : 'ms_${e.key}',
          order: e.key,
        );
      }).toList();

      final quests = planWithData.quests
          .map((q) => q.copyWith(isActive: true, isCompleted: false))
          .toList();
      final questIds = quests.map((quest) => quest.nodeId.trim()).toList();
      if (questIds.any((id) => id.isEmpty) ||
          questIds.toSet().length != questIds.length) {
        throw StateError(
          'The generated learning plan contains invalid quests.',
        );
      }

      final existingCategoryXp =
          existingUser?.categoryXp ?? const <String, int>{};
      final categoryXp = <String, int>{
        ...existingCategoryXp,
        for (final cat in categories.value)
          cat.name: existingCategoryXp[cat.name] ?? 0,
      };

      final savedPlan = planWithData.copyWith(
        id: planId,
        category: category.value,
        currentMilestoneIndex: 0,
        isActive: true,
        startingXP: existingUser?.totalXP ?? 0,
        milestones: milestones,
        quests: quests,
      );
      final userModel = UserModel(
        id: uid,
        nickname: nickname.text.trim(),
        birthDate: age.text.trim(),
        gender: gender.value,
        avatarSvg: avatarSvg.value,
        isOnboardingComplete: true,
        totalXP: existingUser?.totalXP ?? 0,
        activePlanId: planId,
        currentPlan: savedPlan,
        currentStreak: existingUser?.currentStreak ?? 0,
        dailyQuestCompletionCount: existingUser?.dailyQuestCompletionCount ?? 0,
        categoryXp: categoryXp,
        currentGroveIndex: existingUser?.currentGroveIndex ?? 1,
        completedGroveIndexes:
            existingUser?.completedGroveIndexes ?? const <int>[],
        occupiedTreeSlotsByGrove:
            existingUser?.occupiedTreeSlotsByGrove ?? const <int, List<int>>{},
        mapTutorialDone: existingUser?.mapTutorialDone ?? false,
        notificationsEnabled: existingUser?.notificationsEnabled ?? true,
        profileVisible: existingUser?.profileVisible ?? true,
        postStatsVisible: existingUser?.postStatsVisible ?? true,
        createdAt: existingUser?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        lastRerollDate: existingUser?.lastRerollDate,
        lastStreakDate: existingUser?.lastStreakDate,
        lastQuestCompletionDate: existingUser?.lastQuestCompletionDate,
      );

      final userData = userModel.toJson();
      if (existingUser?.createdAt == null) {
        userData['createdAt'] = FieldValue.serverTimestamp();
      }
      userData['updatedAt'] = FieldValue.serverTimestamp();

      final batch = FirebaseFirestore.instance.batch();
      batch.set(userRef, userData, SetOptions(merge: true));
      batch.set(
        FirebaseFirestore.instance.collection('publicProfiles').doc(uid),
        {
          'nickname': userModel.nickname,
          'avatarSvg': userModel.avatarSvg,
          'profileVisible': userModel.profileVisible,
          'postStatsVisible': userModel.postStatsVisible,
          'totalXP': userModel.totalXP,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batch.set(planRef, savedPlan.toJson());

      for (final ms in milestones) {
        batch.set(planRef.collection('milestones').doc(ms.id), ms.toJson());
      }

      for (final quest in quests) {
        batch.set(
          planRef.collection('quests').doc(quest.nodeId),
          quest.toJson(),
        );
      }

      final historyData = GoalHistoryModel(
        planId: planId,
        status: 'active',
        hobby: planWithData.hobby,
        level: planWithData.level,
        goal: planWithData.goal,
        learningPace: planWithData.learningPace,
        category: category.value,
        createdAt: DateTime.now(),
      ).toJson()..['createdAt'] = FieldValue.serverTimestamp();
      batch.set(userRef.collection('goalHistory').doc(planId), historyData);

      await batch.commit();

      if (Get.isRegistered<PushNotificationService>()) {
        try {
          await Get.find<PushNotificationService>().registerCurrentDevice();
        } catch (e) {
          print(
            '--- WARNING: Onboarding saved, but push registration failed: $e ---',
          );
        }
      }

      print("--- SUCCESS: User profile, plan, and goal history saved ---");
    } catch (e) {
      print("--- ERROR: Failed to save user data: $e ---");
      rethrow;
    } finally {
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
      learningPace: basePlan.learningPace,
      milestoneTitle: firstMilestone.title,
      milestoneNumber: '1',
    );

    return basePlan.copyWith(
      currentMilestoneIndex: 0,
      progress: 0,
      quests: initialQuests,
    );
  }

  Future<void> seedCategories() async {
    print("--- SEEDING FIRESTORE ---");
    final collection = FirebaseFirestore.instance.collection('categories');
    final existingSnapshot = await collection.limit(1).get();
    if (existingSnapshot.docs.isNotEmpty) {
      print(
        "--- SEEDING SKIPPED: 'categories' collection already populated ---",
      );
      return;
    }

    List<CategoryModel> initialData = [
      CategoryModel(
        id: '',
        name: "Creative Arts",
        description: "Express yourself visually",
        iconCodePoint: Icons.palette.codePoint,
        hobbies: [
          HobbyEntry(
            name: "Painting",
            axes: [
              PeerReviewAxisModel.fromIconData(
                label: 'Creativity',
                icon: Icons.lightbulb_outline,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Technique',
                icon: Icons.brush,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Color Theory',
                icon: Icons.palette_outlined,
              ),
            ],
          ),
          HobbyEntry(
            name: "Drawing",
            axes: [
              PeerReviewAxisModel.fromIconData(
                label: 'Composition',
                icon: Icons.grid_view,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Line Work',
                icon: Icons.gesture,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Shading',
                icon: Icons.gradient,
              ),
            ],
          ),
          HobbyEntry(
            name: "Photography",
            axes: [
              PeerReviewAxisModel.fromIconData(
                label: 'Composition',
                icon: Icons.center_focus_strong,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Lighting',
                icon: Icons.wb_sunny,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Editing',
                icon: Icons.tune,
              ),
            ],
          ),
          HobbyEntry(
            name: "Calligraphy",
            axes: [
              PeerReviewAxisModel.fromIconData(
                label: 'Letter Form',
                icon: Icons.text_fields,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Consistency',
                icon: Icons.compare_arrows,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Ink Control',
                icon: Icons.edit,
              ),
            ],
          ),
        ],
      ),
      CategoryModel(
        id: '',
        name: "Music & Performing",
        description: "Play, sing, and perform",
        iconCodePoint: Icons.music_note.codePoint,
        hobbies: [
          HobbyEntry(
            name: "Guitar",
            axes: [
              PeerReviewAxisModel.fromIconData(
                label: 'Rhythm',
                icon: Icons.music_note,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Technique',
                icon: Icons.touch_app,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Musicality',
                icon: Icons.hearing,
              ),
            ],
          ),
          HobbyEntry(
            name: "Piano",
            axes: [
              PeerReviewAxisModel.fromIconData(
                label: 'Technique',
                icon: Icons.piano,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Expression',
                icon: Icons.sentiment_satisfied_alt,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Sight Reading',
                icon: Icons.visibility,
              ),
            ],
          ),
          HobbyEntry(
            name: "Singing",
            axes: [
              PeerReviewAxisModel.fromIconData(
                label: 'Pitch',
                icon: Icons.graphic_eq,
              ),
              PeerReviewAxisModel.fromIconData(label: 'Tone', icon: Icons.mic),
              PeerReviewAxisModel.fromIconData(
                label: 'Breath Control',
                icon: Icons.air,
              ),
            ],
          ),
          HobbyEntry(
            name: "Dance",
            axes: [
              PeerReviewAxisModel.fromIconData(
                label: 'Choreography',
                icon: Icons.directions_run,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Expression',
                icon: Icons.mood,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Technique',
                icon: Icons.accessibility_new,
              ),
            ],
          ),
        ],
      ),
      CategoryModel(
        id: '',
        name: "Lifestyle & Wellness",
        description: "Heal your body and mind",
        iconCodePoint: Icons.self_improvement.codePoint,
        hobbies: [
          HobbyEntry(
            name: "Yoga",
            axes: [
              PeerReviewAxisModel.fromIconData(
                label: 'Alignment',
                icon: Icons.straighten,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Flexibility',
                icon: Icons.accessibility,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Mindfulness',
                icon: Icons.self_improvement,
              ),
            ],
          ),
          HobbyEntry(
            name: "Fitness/Gym",
            axes: [
              PeerReviewAxisModel.fromIconData(
                label: 'Form',
                icon: Icons.fitness_center,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Intensity',
                icon: Icons.trending_up,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Consistency',
                icon: Icons.loop,
              ),
            ],
          ),
          HobbyEntry(
            name: "Meditation",
            axes: [
              PeerReviewAxisModel.fromIconData(
                label: 'Focus',
                icon: Icons.center_focus_strong,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Duration',
                icon: Icons.timer,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Mindfulness',
                icon: Icons.spa,
              ),
            ],
          ),
          HobbyEntry(
            name: "Cooking",
            axes: [
              PeerReviewAxisModel.fromIconData(
                label: 'Taste',
                icon: Icons.restaurant,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Presentation',
                icon: Icons.dinner_dining,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Technique',
                icon: Icons.kitchen,
              ),
            ],
          ),
        ],
      ),
      CategoryModel(
        id: '',
        name: "Skill & Strategy",
        description: "Sharpen your mind",
        iconCodePoint: Icons.psychology.codePoint,
        hobbies: [
          HobbyEntry(
            name: "Coding",
            axes: [
              PeerReviewAxisModel.fromIconData(
                label: 'Code Quality',
                icon: Icons.code,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Efficiency',
                icon: Icons.speed,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Readability',
                icon: Icons.article,
              ),
            ],
          ),
          HobbyEntry(
            name: "Chess",
            axes: [
              PeerReviewAxisModel.fromIconData(
                label: 'Strategy',
                icon: Icons.psychology,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Tactics',
                icon: Icons.bolt,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Endgame',
                icon: Icons.flag,
              ),
            ],
          ),
          HobbyEntry(
            name: "Language",
            axes: [
              PeerReviewAxisModel.fromIconData(
                label: 'Vocabulary',
                icon: Icons.menu_book,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Grammar',
                icon: Icons.checklist,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Pronunciation',
                icon: Icons.record_voice_over,
              ),
            ],
          ),
          HobbyEntry(
            name: "Public Speaking",
            axes: [
              PeerReviewAxisModel.fromIconData(
                label: 'Clarity',
                icon: Icons.record_voice_over,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Engagement',
                icon: Icons.group,
              ),
              PeerReviewAxisModel.fromIconData(
                label: 'Structure',
                icon: Icons.account_tree,
              ),
            ],
          ),
        ],
      ),
    ];

    for (var category in initialData) {
      var snapshot = await collection
          .where('name', isEqualTo: category.name)
          .get();
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
    pageController.dispose();
    nickname.dispose();
    age.dispose();
    goalController.dispose();
    super.onClose();
  }
}
