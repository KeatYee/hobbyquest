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

  Future<void> seedGuildPosts() async {
    print("--- SEEDING GUILD POSTS ---");
    final collection = _firestore.collection(_guildPostsCollection);

    // Fetch categories so we can map by name to real category IDs
    final refreshedCategories = await _firestore.collection('categories').get();
    Map<String, String> categoryMap = {};
    for (var doc in refreshedCategories.docs) {
      final name = doc.data()['name'] as String? ?? '';
      if (name.isNotEmpty) {
        categoryMap[name] = doc.id;
      }
    }

    // Use a system user ID for seeded posts
    const systemUserId = 'seed_system_user';

    // 1. Define the Data
    List<Map<String, dynamic>> initialData = [
      {
        'userId': systemUserId,
        'hobby': 'Painting',
        'categoryId': categoryMap['Creative Arts'] ?? '',
        'title': 'Best watercolor techniques for beginners',
        'body': 'I have been experimenting with wet-on-wet and wet-on-dry techniques. Would love to hear what everyone else recommends for someone just starting out!',
        'reactions': {'🔥': ['seed_u1', 'seed_u2'], '👏': ['seed_u3']},
        'createdAt': DateTime.now().subtract(const Duration(days: 2)),
      },
      {
        'userId': systemUserId,
        'hobby': 'Photography',
        'categoryId': categoryMap['Creative Arts'] ?? '',
        'title': 'Golden hour photography spots in town',
        'body': 'Compiling a list of the best locations for sunset and sunrise shots. Drop your favorite spots below!',
        'reactions': {'🔥': ['seed_u1', 'seed_u4'], '👏': ['seed_u2', 'seed_u3'], '💡': ['seed_u5']},
        'createdAt': DateTime.now().subtract(const Duration(days: 3)),
      },
      {
        'userId': systemUserId,
        'hobby': 'Guitar',
        'categoryId': categoryMap['Music & Performing'] ?? '',
        'title': 'Learning my first chord progression',
        'body': 'Just mastered G-C-D progression! Any song recommendations that use these chords so I can practice?',
        'reactions': {'👏': ['seed_u1', 'seed_u2']},
        'createdAt': DateTime.now().subtract(const Duration(days: 5)),
      },
      {
        'userId': systemUserId,
        'hobby': 'Yoga',
        'categoryId': categoryMap['Lifestyle & Wellness'] ?? '',
        'title': '30-day yoga challenge - who is in?',
        'body': 'Starting a 30-day yoga challenge starting next Monday. We will do 15 minutes minimum each day. Comment if you want to join!',
        'reactions': {'🔥': ['seed_u1', 'seed_u3', 'seed_u4', 'seed_u5'], '👏': ['seed_u2']},
        'createdAt': DateTime.now().subtract(const Duration(days: 1)),
      },
      {
        'userId': systemUserId,
        'hobby': 'Coding',
        'categoryId': categoryMap['Skill & Strategy'] ?? '',
        'title': 'Best resources for learning Flutter',
        'body': 'I am diving into Flutter development and looking for the best courses, YouTube channels, and books. What has worked for you?',
        'reactions': {'💡': ['seed_u1', 'seed_u2', 'seed_u3'], '🔥': ['seed_u4']},
        'createdAt': DateTime.now().subtract(const Duration(hours: 12)),
      },
      {
        'userId': systemUserId,
        'hobby': 'Cooking',
        'categoryId': categoryMap['Lifestyle & Wellness'] ?? '',
        'title': 'Share your favorite quick weeknight dinner',
        'body': 'Need some inspiration for quick dinners under 30 minutes. Please share your go-to recipes!',
        'reactions': {'🔥': ['seed_u1', 'seed_u2', 'seed_u3', 'seed_u4', 'seed_u5'], '👏': ['seed_u6']},
        'createdAt': DateTime.now().subtract(const Duration(days: 4)),
      },
      {
        'userId': systemUserId,
        'hobby': 'Chess',
        'categoryId': categoryMap['Skill & Strategy'] ?? '',
        'title': 'Chess tactics puzzle of the day',
        'body': 'White to move and win material in 3 moves. I will post the solution tomorrow!',
        'reactions': {'💡': ['seed_u1'], '🔥': ['seed_u2', 'seed_u3']},
        'createdAt': DateTime.now().subtract(const Duration(hours: 6)),
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
