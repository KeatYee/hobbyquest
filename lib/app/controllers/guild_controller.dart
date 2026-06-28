import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../models/guild_post_model.dart';
import '../models/category_model.dart';
import '../services/imgbb_service.dart';
import 'home_controller.dart';

class GuildController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _guildPostsCollection = 'guild_posts';

  /// Reaction emojis available for guild posts
  static const List<String> reactionEmojis = ['🔥', '👏', '💡'];

  final posts = <GuildPostModel>[].obs;
  final categories = <CategoryModel>[].obs;
  final isLoading = false.obs;
  final userAvatars = <String, String>{}.obs;
  final userNicknames = <String, String>{}.obs;
  final selectedCategoryId = Rx<String?>(null);
  final userReactions = <String, Set<String>>{}.obs;
  final userPeerReviews = <String, Set<String>>{}.obs;
  final currentUserId = Rx<String?>(null);
  StreamSubscription? _authSubscription;

  @override
  void onInit() {
    super.onInit();

    // Listen for auth state changes (handles restore from persistence)
    _authSubscription = _auth.authStateChanges().listen((user) {
      currentUserId.value = user?.uid;
      // Load current user's own profile so it shows in reviewer lists
      if (user != null) {
        _ensureProfileLoaded(user.uid);
      }
      // Re-populate user state whenever auth changes (sign-in, restore, etc.)
      if (posts.isNotEmpty) {
        _populateCurrentUserState();
      }
    });

    seedGuildPosts().then((_) => loadAllData());
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    super.onClose();
  }

  /// Re-populate [userReactions] and [userPeerReviews] from loaded posts
  /// based on the current authenticated user.
  void _populateCurrentUserState() {
    final uid = currentUserId.value;
    userReactions.clear();
    userPeerReviews.clear();
    if (uid == null) return;

    for (final post in posts) {
      final reactedEmojis = <String>{};
      for (final entry in post.reactions.entries) {
        if (entry.value.contains(uid)) {
          reactedEmojis.add(entry.key);
        }
      }
      if (reactedEmojis.isNotEmpty) {
        userReactions[post.id] = reactedEmojis;
      }

      if (post.peerReviews.containsKey(uid)) {
        userPeerReviews[post.id] = <String>{uid};
      }
    }
  }

  /// Fetch a user's profile from Firestore and cache in [userAvatars]/[userNicknames].
  /// Does nothing if already cached.
  void _ensureProfileLoaded(String userId) {
    if (userNicknames.containsKey(userId) && userAvatars.containsKey(userId)) return;
    _firestore.collection('users').doc(userId).get().then((doc) {
      final data = doc.data();
      if (data == null) return;
      final avatarSvg = data['avatarSvg'] as String? ?? '';
      final nickname = data['nickname'] as String? ?? '';
      if (avatarSvg.trim().isNotEmpty) userAvatars[userId] = avatarSvg;
      if (nickname.trim().isNotEmpty) userNicknames[userId] = nickname;
    }).catchError((_) {});
  }

  /// Load all data (categories, posts, user profiles) from Firestore
  Future<void> loadAllData() async {
    try {
      isLoading.value = true;

      final results = await Future.wait([
        _firestore.collection('categories').get(),
        _firestore.collection(_guildPostsCollection).orderBy('createdAt', descending: true).get(),
      ]);

      final categorySnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final postSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;

      final loadedCategories = categorySnapshot.docs
          .map((doc) => CategoryModel.fromJson(doc.data(), doc.id))
          .where((category) => category.name.trim().isNotEmpty)
          .toList();

      final loadedPosts = postSnapshot.docs
          .map((doc) => GuildPostModel.fromJson(doc.data(), doc.id))
          .where((post) => post.title.trim().isNotEmpty)
          .toList();

      // Load user profiles for avatars/nicknames (post authors + reviewers)
      final userIds = loadedPosts
          .map((post) => post.userId.trim())
          .where((userId) => userId.isNotEmpty)
          .toSet();

      // Also include reviewer user IDs so their profiles are loaded
      for (final post in loadedPosts) {
        for (final reviewerId in post.peerReviews.keys) {
          if (reviewerId.trim().isNotEmpty) {
            userIds.add(reviewerId.trim());
          }
        }
      }

      final loadedUserAvatars = <String, String>{};
      final loadedUserNicknames = <String, String>{};
      for (var userId in userIds) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final data = userDoc.data();
        final avatarSvg = data?['avatarSvg'] as String? ?? '';
        final nickname = data?['nickname'] as String? ?? '';
        if (avatarSvg.trim().isNotEmpty) loadedUserAvatars[userId] = avatarSvg;
        if (nickname.trim().isNotEmpty) loadedUserNicknames[userId] = nickname;
      }

      categories.value = loadedCategories;
      posts.value = loadedPosts;
      userAvatars.value = loadedUserAvatars;
      userNicknames.value = loadedUserNicknames;

      // Populate reactions & peer reviews for the current user
      _populateCurrentUserState();

      // Debug: log loaded peer review state
      for (final post in loadedPosts) {
        if (post.peerReviews.isNotEmpty) {
          print('--- Post ${post.id} has ${post.peerReviews.length} review(s): ${post.peerReviews.keys.toList()} ---');
        }
      }
    } catch (e) {
      print('--- ERROR: Failed to load guild data: $e ---');
    } finally {
      isLoading.value = false;
    }
  }

  /// Resolve the default category based on user's hobby
  String? resolveDefaultCategoryId() {
    if (categories.isEmpty) return null;

    if (Get.isRegistered<HomeController>()) {
      try {
        final homeController = Get.find<HomeController>();
        final hobby = homeController.hobby.value.trim().toLowerCase();
        for (final category in categories) {
          if (category.hobbyNames.any((item) => item.toLowerCase() == hobby)) {
            return category.id;
          }
        }
      } catch (_) {}
    }

    return categories.first.id;
  }

  /// Get filtered posts for the currently selected category
  List<GuildPostModel> get filteredPosts {
    final selectedId = selectedCategoryId.value;
    if (selectedId == null) return [];

    final selectedCategory = categories.where((c) => c.id == selectedId).firstOrNull;
    if (selectedCategory == null) return [];

    return posts.where((post) {
      final matchesCategoryId = post.categoryId.trim().isNotEmpty && post.categoryId == selectedCategory.id;
      final matchesHobby = selectedCategory.hobbyNames.any(
        (hobby) => hobby.toLowerCase() == post.hobby.toLowerCase(),
      );
      return matchesCategoryId || matchesHobby;
    }).toList();
  }

  /// Get all hobbies from all categories
  List<String> get allHobbies {
    return categories.expand((c) => c.hobbyNames).toList();
  }

  final ImgBBService _imgbbService = ImgBBService();

  /// Add a new post to the guild_posts collection
  Future<String?> addPost({
    required String hobby,
    required String categoryId,
    required String title,
    required String body,
    XFile? imageFile,
  }) async {
    try {
      final uid = currentUserId.value;
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      // Upload image to ImgBB if provided
      String imageUrl = '';
      if (imageFile != null) {
        print('--- Uploading guild post image to ImgBB ---');
        imageUrl = await _imgbbService.uploadImage(imageFile.path);
        print('--- Image uploaded. URL: $imageUrl ---');
      }

      final newPost = GuildPostModel(
        id: '', // Firestore will generate ID
        userId: uid,
        hobby: hobby,
        categoryId: categoryId,
        title: title,
        body: body,
        imageUrl: imageUrl,
        reactions: {},
        createdAt: DateTime.now(),
      );

      // Add to Firestore and get the document reference
      final docRef = await _firestore
          .collection(_guildPostsCollection)
          .add(newPost.toJson());

      print('--- SUCCESS: Guild post created with ID: ${docRef.id} ---');

      // Reload posts to reflect the new post
      await loadAllData();

      return docRef.id;
    } catch (e) {
      print('--- ERROR: Failed to add guild post: $e ---');
      return null;
    }
  }

  /// Toggle a reaction emoji on a post
  Future<void> toggleReaction(String postId, String emoji) async {
    final uid = currentUserId.value;
    if (uid == null) return;

    try {
      final postRef = _firestore.collection(_guildPostsCollection).doc(postId);
      final index = posts.indexWhere((p) => p.id == postId);
      if (index < 0) return;

      final post = posts[index];
      final currentUserEmojis = Set<String>.from(userReactions[postId] ?? {});
      final alreadyReacted = currentUserEmojis.contains(emoji);

      if (alreadyReacted) {
        // Remove reaction
        await postRef.update({
          'reactions.$emoji': FieldValue.arrayRemove([uid]),
        });

        final updatedReactions = Map<String, List<String>>.from(post.reactions);
        final currentList = List<String>.from(updatedReactions[emoji] ?? []);
        currentList.remove(uid);
        if (currentList.isEmpty) {
          updatedReactions.remove(emoji);
        } else {
          updatedReactions[emoji] = currentList;
        }

        posts[index] = post.copyWith(
          reactions: updatedReactions,
        );

        currentUserEmojis.remove(emoji);
        if (currentUserEmojis.isEmpty) {
          userReactions.remove(postId);
        } else {
          userReactions[postId] = currentUserEmojis;
        }

        print('--- SUCCESS: Removed reaction $emoji from post $postId ---');
      } else {
        // Add reaction
        await postRef.update({
          'reactions.$emoji': FieldValue.arrayUnion([uid]),
        });

        final updatedReactions = Map<String, List<String>>.from(post.reactions);
        final currentList = List<String>.from(updatedReactions[emoji] ?? []);
        currentList.add(uid);
        updatedReactions[emoji] = currentList;

        posts[index] = post.copyWith(
          reactions: updatedReactions,
        );

        currentUserEmojis.add(emoji);
        userReactions[post.id] = currentUserEmojis;

        print('--- SUCCESS: Added reaction $emoji to post $postId ---');
      }

      posts.refresh();
    } catch (e) {
      print('--- ERROR: Failed to toggle reaction on post $postId: $e ---');
    }
  }

  /// Delete a post
  Future<void> deletePost(String postId) async {
    try {
      final uid = currentUserId.value;
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      // Verify user owns the post
      final postDoc = await _firestore
          .collection(_guildPostsCollection)
          .doc(postId)
          .get();

      final post = GuildPostModel.fromJson(postDoc.data()!, postDoc.id);
      if (post.userId != uid) {
        throw Exception('You can only delete your own posts');
      }

      await _firestore.collection(_guildPostsCollection).doc(postId).delete();

      // Remove from local list
      posts.removeWhere((p) => p.id == postId);

      print('--- SUCCESS: Post deleted: $postId ---');
    } catch (e) {
      print('--- ERROR: Failed to delete post: $e ---');
    }
  }

  // --- FIRESTORE SEEDING (For Dev Only) ---

  /// Demo user IDs used across seeded posts and peer reviews.
  /// Documents for these users are also created in Firestore
  /// via [seedDemoUsers] so avatars and nicknames resolve correctly.
  static const _demoUsers = [
    'demo_mia',
    'demo_jay',
    'demo_lee',
    'demo_sam',
    'demo_ray',
    'demo_tess',
  ];

  /// Profile data for each demo user.
  /// Order matches [_demoUsers].
  static const _demoUserProfiles = [
    {
      'nickname': 'Mia',
      'avatarSvg': 'assets/images/avatar_cultivator_f.png',
      'hobby': 'Painting',
    },
    {
      'nickname': 'Jay',
      'avatarSvg': 'assets/images/avatar_earthbreaker_m.png',
      'hobby': 'Photography',
    },
    {
      'nickname': 'Lee',
      'avatarSvg': 'assets/images/avatar_wildseed_m.png',
      'hobby': 'Drawing',
    },
    {
      'nickname': 'Sam',
      'avatarSvg': 'assets/images/avatar_grovekeeper_m.png',
      'hobby': 'Guitar',
    },
    {
      'nickname': 'Ray',
      'avatarSvg': 'assets/images/avatar_harvester_m.png',
      'hobby': 'Coding',
    },
    {
      'nickname': 'Tess',
      'avatarSvg': 'assets/images/avatar_nurturer_f.png',
      'hobby': 'Yoga',
    },
  ];

  /// Seed user documents for all demo users so that
  /// avatar and nickname lookups resolve correctly in the guild feed.
  Future<void> seedDemoUsers() async {
    print("--- SEEDING DEMO USERS ---");
    final usersRef = _firestore.collection('users');

    for (var i = 0; i < _demoUsers.length; i++) {
      final userId = _demoUsers[i];
      final profile = _demoUserProfiles[i];

      final doc = await usersRef.doc(userId).get();
      if (!doc.exists) {
        await usersRef.doc(userId).set({
          'nickname': profile['nickname'],
          'avatarSvg': profile['avatarSvg'],
          'isOnboardingComplete': true,
          'totalXP': 0,
          'currentStreak': 0,
          'dailyQuestCompletionCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'currentPlan': {
            'hobby': profile['hobby'],
            'level': 'Novice',
            'goal': '',
            'frequency': '15 mins/day',
            'progress': 0,
            'currentMilestoneIndex': 0,
            'milestones': <dynamic>[],
            'quests': <dynamic>[],
          },
        });
        print("✅ Created user: ${profile['nickname']} ($userId)");
      } else {
        print("⚠️ Skipped user $userId (Already exists)");
      }
    }
    print("--- SEEDING DEMO USERS COMPLETE ---");
  }

  Future<void> seedGuildPosts() async {
    print("--- SEEDING GUILD POSTS ---");
    final collection = _firestore.collection(_guildPostsCollection);

    // Seed demo user documents first so avatars/nicknames resolve
    await seedDemoUsers();

    // Fetch categories so we can map by name to real category IDs
    final refreshedCategories = await _firestore.collection('categories').get();
    Map<String, String> categoryMap = {};
    for (var doc in refreshedCategories.docs) {
      final name = doc.data()['name'] as String? ?? '';
      if (name.isNotEmpty) {
        categoryMap[name] = doc.id;
      }
    }

    // 1. Define the Data
    // ──────────────────────────────────────────────
    // Each post: userId, hobby, categoryId, title, body,
    //            imageUrl (empty), reactions, peerReviews, createdAt
    //
    // peerReviews structure:
    //   { reviewerUserId: { axisLabel1: rating1, axisLabel2: rating2, ... } }
    // Axis labels MUST match the hobby's axes defined in CategoryModel.
    // ──────────────────────────────────────────────
    final creativeArtsId = categoryMap['Creative Arts'] ?? '';
    final musicId = categoryMap['Music & Performing'] ?? '';
    final wellnessId = categoryMap['Lifestyle & Wellness'] ?? '';
    final strategyId = categoryMap['Skill & Strategy'] ?? '';

    List<Map<String, dynamic>> initialData = [
      // ----- Creative Arts -----
      {
        'userId': _demoUsers[0],
        'hobby': 'Painting',
        'categoryId': creativeArtsId,
        'title': 'Best watercolor techniques for beginners',
        'body': 'I have been experimenting with wet-on-wet and wet-on-dry techniques. Would love to hear what everyone else recommends for someone just starting out!',
        'imageUrl': '',
        'reactions': {'🔥': [_demoUsers[1], _demoUsers[2]], '👏': [_demoUsers[3]]},
        'peerReviews': {
          _demoUsers[1]: {'Creativity': 4.0, 'Technique': 3.5, 'Color Theory': 5.0},
          _demoUsers[3]: {'Creativity': 5.0, 'Technique': 4.0, 'Color Theory': 4.5},
        },
        'createdAt': DateTime.now().subtract(const Duration(days: 2)),
      },
      {
        'userId': _demoUsers[1],
        'hobby': 'Photography',
        'categoryId': creativeArtsId,
        'title': 'Golden hour photography spots in town',
        'body': 'I compiled a list of the best locations for sunset and sunrise shots around the city. Drop your favorite spots below and I will add them to the map!',
        'imageUrl': '',
        'reactions': {'🔥': [_demoUsers[0], _demoUsers[4]], '👏': [_demoUsers[2], _demoUsers[3]], '💡': [_demoUsers[5]]},
        'peerReviews': {
          _demoUsers[2]: {'Composition': 5.0, 'Lighting': 4.5, 'Editing': 3.0},
        },
        'createdAt': DateTime.now().subtract(const Duration(days: 3)),
      },
      {
        'userId': _demoUsers[2],
        'hobby': 'Drawing',
        'categoryId': creativeArtsId,
        'title': 'Daily sketch challenge — day 30 reflection',
        'body': 'Just finished my 30-day daily sketch challenge! I focused on gesture drawing and saw huge improvement in my line work. Highly recommend this to anyone looking to level up.',
        'imageUrl': '',
        'reactions': {'🔥': [_demoUsers[0], _demoUsers[1], _demoUsers[4]], '👏': [_demoUsers[3]]},
        'peerReviews': {
          _demoUsers[4]: {'Composition': 4.5, 'Line Work': 4.0, 'Shading': 3.5},
          _demoUsers[5]: {'Composition': 5.0, 'Line Work': 5.0, 'Shading': 4.0},
        },
        'createdAt': DateTime.now().subtract(const Duration(days: 6)),
      },

      // ----- Music & Performing -----
      {
        'userId': _demoUsers[3],
        'hobby': 'Guitar',
        'categoryId': musicId,
        'title': 'Learning my first chord progression',
        'body': 'Just mastered G-C-D progression! Any song recommendations that use these chords so I can practice transitioning between them?',
        'imageUrl': '',
        'reactions': {'👏': [_demoUsers[0], _demoUsers[1]]},
        'peerReviews': {
          _demoUsers[0]: {'Rhythm': 3.0, 'Technique': 2.5, 'Musicality': 3.5},
        },
        'createdAt': DateTime.now().subtract(const Duration(days: 5)),
      },
      {
        'userId': _demoUsers[4],
        'hobby': 'Singing',
        'categoryId': musicId,
        'title': 'Overcoming stage fright — my journey so far',
        'body': 'I used to freeze up before every open mic. After 6 months of practice and small performances, I can finally sing in front of a crowd without my voice shaking. Here is what helped me.',
        'imageUrl': '',
        'reactions': {'🔥': [_demoUsers[0], _demoUsers[3], _demoUsers[5]], '👏': [_demoUsers[1], _demoUsers[2]]},
        'peerReviews': {
          _demoUsers[2]: {'Pitch': 4.0, 'Tone': 4.5, 'Breath Control': 3.5},
          _demoUsers[3]: {'Pitch': 3.5, 'Tone': 5.0, 'Breath Control': 4.0},
        },
        'createdAt': DateTime.now().subtract(const Duration(days: 4)),
      },

      // ----- Lifestyle & Wellness -----
      {
        'userId': _demoUsers[5],
        'hobby': 'Yoga',
        'categoryId': wellnessId,
        'title': '30-day yoga challenge — who is in?',
        'body': 'Starting a 30-day yoga challenge next Monday. Minimum 15 minutes each day. I will post daily prompts. Comment if you want to join!',
        'imageUrl': '',
        'reactions': {'🔥': [_demoUsers[0], _demoUsers[3], _demoUsers[4], _demoUsers[1]], '👏': [_demoUsers[2]]},
        'peerReviews': {},
        'createdAt': DateTime.now().subtract(const Duration(days: 1)),
      },
      {
        'userId': _demoUsers[0],
        'hobby': 'Cooking',
        'categoryId': wellnessId,
        'title': 'Share your favorite quick weeknight dinner',
        'body': 'Busy schedule means I need dinners under 30 minutes. Please share your go-to recipes — bonus points if they use 5 ingredients or fewer!',
        'imageUrl': '',
        'reactions': {'🔥': [_demoUsers[1], _demoUsers[2], _demoUsers[3], _demoUsers[4], _demoUsers[5]], '👏': []},
        'peerReviews': {
          _demoUsers[3]: {'Taste': 4.0, 'Presentation': 3.5, 'Technique': 4.0},
          _demoUsers[4]: {'Taste': 5.0, 'Presentation': 4.5, 'Technique': 4.5},
        },
        'createdAt': DateTime.now().subtract(const Duration(days: 4)),
      },

      // ----- Skill & Strategy -----
      {
        'userId': _demoUsers[1],
        'hobby': 'Coding',
        'categoryId': strategyId,
        'title': 'Best resources for learning Flutter',
        'body': 'I am diving into Flutter development and looking for the best courses, YouTube channels, and books. What has worked for you?',
        'imageUrl': '',
        'reactions': {'💡': [_demoUsers[0], _demoUsers[2], _demoUsers[3]], '🔥': [_demoUsers[4]]},
        'peerReviews': {
          _demoUsers[5]: {'Code Quality': 4.0, 'Efficiency': 3.0, 'Readability': 4.5},
        },
        'createdAt': DateTime.now().subtract(const Duration(hours: 12)),
      },
      {
        'userId': _demoUsers[2],
        'hobby': 'Chess',
        'categoryId': strategyId,
        'title': 'Chess tactics puzzle of the day',
        'body': 'White to move and win material in 3 moves. I will post the solution tomorrow! Hint: look for a forcing sequence.',
        'imageUrl': '',
        'reactions': {'💡': [_demoUsers[0]], '🔥': [_demoUsers[1], _demoUsers[3]]},
        'peerReviews': {
          _demoUsers[0]: {'Strategy': 5.0, 'Tactics': 4.5, 'Endgame': 3.0},
          _demoUsers[4]: {'Strategy': 4.0, 'Tactics': 5.0, 'Endgame': 3.5},
        },
        'createdAt': DateTime.now().subtract(const Duration(hours: 6)),
      },
      {
        'userId': _demoUsers[4],
        'hobby': 'Language',
        'categoryId': strategyId,
        'title': 'How I learned 50 new words in a week',
        'body': 'I used the spaced repetition method with physical flashcards. Writing each word in a sentence helped way more than just memorizing definitions. Try it!',
        'imageUrl': '',
        'reactions': {'👏': [_demoUsers[0], _demoUsers[1], _demoUsers[5]], '💡': [_demoUsers[2]]},
        'peerReviews': {
          _demoUsers[3]: {'Vocabulary': 4.5, 'Grammar': 4.0, 'Pronunciation': 3.5},
        },
        'createdAt': DateTime.now().subtract(const Duration(days: 7)),
      },
    ];

    // 2. Upload Loop
    for (var data in initialData) {
      // Check if exists to prevent duplicates
      var snapshot = await collection.where('title', isEqualTo: data['title']).get();
      if (snapshot.docs.isEmpty) {
        await collection.add(data);
        print("✅ Added '${data['title']}'");
      } else {
        print("⚠️ Skipped '${data['title']}' (Already exists)");
      }
    }
    print("--- SEEDING GUILD POSTS COMPLETE ---");
  }

  /// Get posts by hobby
  List<GuildPostModel> getPostsByHobby(String hobby) {
    return posts.where((post) => post.hobby == hobby).toList();
  }

  /// Get posts by category
  List<GuildPostModel> getPostsByCategory(String categoryId) {
    return posts.where((post) => post.categoryId == categoryId).toList();
  }

  // --- Peer Review ---

  /// Whether the current user has already reviewed a given post.
  bool hasUserReviewed(String postId) {
    final uid = currentUserId.value;
    if (uid == null) return false;
    final postIndex = posts.indexWhere((p) => p.id == postId);
    if (postIndex < 0) return false;
    return posts[postIndex].peerReviews.containsKey(uid);
  }

  /// Fetch the 3 review axes for a given hobby from the category data.
  List<PeerReviewAxisModel> fetchReviewAxes(String hobby) {
    for (final category in categories) {
      final axes = category.getAxisForHobby(hobby);
      if (axes.isNotEmpty) return axes;
    }
    return _defaultAxesForHobby();
  }

  /// Submit a peer review rating for a post — stored inline in the post doc.
  /// Returns false if the user has already reviewed this post.
  Future<bool> submitPeerReview({
    required String postId,
    required String hobby,
    required Map<String, double> ratings,
  }) async {
    final uid = currentUserId.value;
    if (uid == null) return false;

    // Guard: one review per user per post
    final postIndex = posts.indexWhere((p) => p.id == postId);
    if (postIndex >= 0 && posts[postIndex].peerReviews.containsKey(uid)) {
      print('--- SKIP: User $uid already reviewed post $postId ---');
      return false;
    }

    try {
      final postRef = _firestore.collection(_guildPostsCollection).doc(postId);

      // Read current document, update peerReviews explicitly, write back
      final snapshot = await postRef.get();
      final currentPeerReviews = Map<String, dynamic>.from(
        (snapshot.data()?['peerReviews'] as Map?) ?? {},
      );
      currentPeerReviews[uid] = ratings;
      await postRef.update({'peerReviews': currentPeerReviews});

      // Update local state
      if (postIndex >= 0) {
        final existingReviews = Map<String, Map<String, double>>.from(
          posts[postIndex].peerReviews,
        );
        existingReviews[uid] = ratings;
        posts[postIndex] = posts[postIndex].copyWith(peerReviews: existingReviews);
        posts.refresh();

        // Track which posts the current user has reviewed
        userPeerReviews[postId] = <String>{uid};
      }

      // Ensure the reviewer's own profile is cached for the reviewer display
      _ensureProfileLoaded(uid);

      print('--- SUCCESS: Peer review submitted for post $postId ---');
      return true;
    } catch (e) {
      print('--- ERROR: Failed to submit peer review: $e ---');
      return false;
    }
  }

  /// Fallback default axes.
  List<PeerReviewAxisModel> _defaultAxesForHobby() {
    return [
      PeerReviewAxisModel.fromIconData(label: 'Quality', icon: Icons.star_outline),
      PeerReviewAxisModel.fromIconData(label: 'Effort', icon: Icons.trending_up),
      PeerReviewAxisModel.fromIconData(label: 'Impact', icon: Icons.rocket_launch_outlined),
    ];
  }
}
