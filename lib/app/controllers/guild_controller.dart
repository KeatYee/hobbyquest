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

enum GuildFeedFilter { forYou, sameHobby, sameCharacter }

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
  final userPostStatsVisible = <String, bool>{}.obs;
  final selectedFeedFilter = GuildFeedFilter.forYou.obs;
  final userReactions = <String, Set<String>>{}.obs;
  final userPeerReviews = <String, Set<String>>{}.obs;
  final currentUserId = Rx<String?>(null);
  final focusedPostId = Rx<String?>(null);
  StreamSubscription? _authSubscription;

  @override
  void onInit() {
    super.onInit();

    _authSubscription = _auth.authStateChanges().listen((user) {
      currentUserId.value = user?.uid;
      if (user != null) {
        _ensureProfileLoaded(user.uid);
      }
      if (posts.isNotEmpty) {
        _populateCurrentUserState();
      }
    });

    loadAllData();
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
    if (userNicknames.containsKey(userId) &&
        userAvatars.containsKey(userId) &&
        userPostStatsVisible.containsKey(userId)) {
      return;
    }
    _firestore
        .collection('users')
        .doc(userId)
        .get()
        .then((doc) {
          final data = doc.data();
          if (data == null) return;
          final avatarSvg = data['avatarSvg'] as String? ?? '';
          final nickname = data['nickname'] as String? ?? '';
          if (avatarSvg.trim().isNotEmpty) userAvatars[userId] = avatarSvg;
          if (nickname.trim().isNotEmpty) userNicknames[userId] = nickname;
          userPostStatsVisible[userId] =
              data['postStatsVisible'] as bool? ?? true;
        })
        .catchError((_) {});
  }

  bool canViewPostStats(GuildPostModel post) {
    final uid = currentUserId.value;
    return uid == post.userId || (userPostStatsVisible[post.userId] ?? true);
  }

  /// Load all data (categories, posts, user profiles) from Firestore
  Future<void> loadAllData() async {
    try {
      isLoading.value = true;

      final results = await Future.wait([
        _firestore.collection('categories').get(),
        _firestore
            .collection(_guildPostsCollection)
            .orderBy('createdAt', descending: true)
            .get(),
      ]);

      final categorySnapshot = results[0];
      final postSnapshot = results[1];

      final loadedCategories = categorySnapshot.docs
          .map((doc) => CategoryModel.fromJson(doc.data(), doc.id))
          .where((category) => category.name.trim().isNotEmpty)
          .toList();

      final loadedPosts = postSnapshot.docs
          .map((doc) => GuildPostModel.fromJson(doc.data(), doc.id))
          .where((post) => post.title.trim().isNotEmpty)
          .toList();

      final userIds = loadedPosts
          .map((post) => post.userId.trim())
          .where((userId) => userId.isNotEmpty)
          .toSet();

      for (final post in loadedPosts) {
        for (final reviewerId in post.peerReviews.keys) {
          if (reviewerId.trim().isNotEmpty) {
            userIds.add(reviewerId.trim());
          }
        }
      }

      final loadedUserAvatars = <String, String>{};
      final loadedUserNicknames = <String, String>{};
      final loadedUserPostStatsVisible = <String, bool>{};
      for (var userId in userIds) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final data = userDoc.data();
        final avatarSvg = data?['avatarSvg'] as String? ?? '';
        final nickname = data?['nickname'] as String? ?? '';
        if (avatarSvg.trim().isNotEmpty) loadedUserAvatars[userId] = avatarSvg;
        if (nickname.trim().isNotEmpty) loadedUserNicknames[userId] = nickname;
        loadedUserPostStatsVisible[userId] =
            data?['postStatsVisible'] as bool? ?? true;
      }

      categories.value = loadedCategories;
      posts.value = loadedPosts;
      userAvatars.value = loadedUserAvatars;
      userNicknames.value = loadedUserNicknames;
      userPostStatsVisible.value = loadedUserPostStatsVisible;

      _populateCurrentUserState();

      for (final post in loadedPosts) {
        if (post.peerReviews.isNotEmpty) {
          print(
            '--- Post ${post.id} has ${post.peerReviews.length} review(s): ${post.peerReviews.keys.toList()} ---',
          );
        }
      }
    } catch (e) {
      print('--- ERROR: Failed to load guild data: $e ---');
    } finally {
      isLoading.value = false;
    }
  }

  /// Extract character class name from an avatar asset path.
  /// e.g. "assets/images/avatar_cultivator_m.png" → "Cultivator"
  static String extractCharacterClass(String avatarPath) {
    if (avatarPath.isEmpty) return '';
    final filename = avatarPath.split('/').last;
    final parts = filename.split('_');
    if (parts.length >= 3) {
      final name = parts[1];
      return name[0].toUpperCase() + name.substring(1);
    }
    return '';
  }

  String get currentHobbyName {
    if (!Get.isRegistered<HomeController>()) return '';

    try {
      return Get.find<HomeController>().hobby.value.trim();
    } catch (_) {
      return '';
    }
  }

  String get currentCharacterClass {
    if (!Get.isRegistered<HomeController>()) return '';

    try {
      return extractCharacterClass(Get.find<HomeController>().avatarSvg.value);
    } catch (_) {
      return '';
    }
  }

  void setFeedFilter(GuildFeedFilter filter) {
    selectedFeedFilter.value = filter;
  }

  List<GuildPostModel> get visiblePosts {
    switch (selectedFeedFilter.value) {
      case GuildFeedFilter.forYou:
        return sortedByRelevance;
      case GuildFeedFilter.sameHobby:
        final hobby = currentHobbyName.toLowerCase();
        if (hobby.isEmpty) return const [];
        return _sortByDateDesc(
          posts.where((post) => post.hobby.toLowerCase() == hobby),
        );
      case GuildFeedFilter.sameCharacter:
        final characterClass = currentCharacterClass;
        if (characterClass.isEmpty) return const [];
        return _sortByDateDesc(
          posts.where((post) {
            final authorClass = extractCharacterClass(
              userAvatars[post.userId] ?? '',
            );
            return authorClass == characterClass;
          }),
        );
    }
  }

  /// Posts sorted by relevance to the current user:
  ///   3 pts — same hobby
  ///   2 pts — same category (when hobby differs)
  ///   1 pt  — same character class (from avatar)
  ///   tiebreaker: createdAt descending
  List<GuildPostModel> get sortedByRelevance {
    String? currentHobby;
    String? currentCategoryId;
    String? currentCharacterClass;

    if (Get.isRegistered<HomeController>()) {
      try {
        final hc = Get.find<HomeController>();
        final hobbyTrimmed = hc.hobby.value.trim();
        if (hobbyTrimmed.isNotEmpty) {
          currentHobby = hobbyTrimmed.toLowerCase();
          currentCharacterClass = extractCharacterClass(hc.avatarSvg.value);
          for (final cat in categories) {
            if (cat.hobbyNames.any((h) => h.toLowerCase() == currentHobby)) {
              currentCategoryId = cat.id;
              break;
            }
          }
        }
      } catch (_) {}
    }

    if (currentHobby == null) {
      final sorted = List<GuildPostModel>.from(posts)
        ..sort((a, b) => _compareDesc(a.createdAt, b.createdAt));
      return _withFocusedPostFirst(sorted);
    }

    final Map<GuildPostModel, int> scored = {};
    for (final post in posts) {
      int score = 0;

      if (post.hobby.toLowerCase() == currentHobby) {
        score += 5;
      }

      if (currentCategoryId != null &&
          post.categoryId.isNotEmpty &&
          post.categoryId == currentCategoryId &&
          post.hobby.toLowerCase() != currentHobby) {
        score += 2;
      }

      if (currentCharacterClass != null && currentCharacterClass.isNotEmpty) {
        final authorClass = extractCharacterClass(
          userAvatars[post.userId] ?? '',
        );
        if (authorClass == currentCharacterClass) {
          score += 1;
        }
      }

      scored[post] = score;
    }

    final sorted = scored.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        if (cmp != 0) return cmp;
        return _compareDesc(a.key.createdAt, b.key.createdAt);
      });

    return _withFocusedPostFirst(sorted.map((e) => e.key).toList());
  }

  List<GuildPostModel> _sortByDateDesc(Iterable<GuildPostModel> source) {
    final sorted = List<GuildPostModel>.from(source)
      ..sort((a, b) => _compareDesc(a.createdAt, b.createdAt));
    return _withFocusedPostFirst(sorted);
  }

  void focusPost(String? postId) {
    final normalizedPostId = postId?.trim() ?? '';
    if (normalizedPostId.isEmpty) return;

    focusedPostId.value = normalizedPostId;
  }

  List<GuildPostModel> _withFocusedPostFirst(List<GuildPostModel> sortedPosts) {
    final postId = focusedPostId.value;
    if (postId == null || postId.isEmpty) return sortedPosts;

    final focusedIndex = sortedPosts.indexWhere((post) => post.id == postId);
    if (focusedIndex <= 0) return sortedPosts;

    final reordered = List<GuildPostModel>.from(sortedPosts);
    final focusedPost = reordered.removeAt(focusedIndex);
    reordered.insert(0, focusedPost);
    return reordered;
  }

  /// Compare two nullable DateTimes descending (most recent first).
  static int _compareDesc(DateTime? a, DateTime? b) {
    final aTime = a ?? DateTime(2000);
    final bTime = b ?? DateTime(2000);
    return bTime.compareTo(aTime);
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

      String imageUrl = '';
      if (imageFile != null) {
        print('--- Uploading guild post image to ImgBB ---');
        imageUrl = await _imgbbService.uploadImage(imageFile.path);
        print('--- Image uploaded. URL: $imageUrl ---');
      }

      final newPost = GuildPostModel(
        id: '',
        userId: uid,
        hobby: hobby,
        categoryId: categoryId,
        title: title,
        body: body,
        imageUrl: imageUrl,
        reactions: {},
        createdAt: DateTime.now(),
      );
      final postData = newPost.toJson()
        ..['createdAt'] = FieldValue.serverTimestamp();

      final docRef = await _firestore
          .collection(_guildPostsCollection)
          .add(postData);

      print('--- SUCCESS: Guild post created with ID: ${docRef.id} ---');

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
    if (uid == null || !reactionEmojis.contains(emoji)) return;

    try {
      final postRef = _firestore.collection(_guildPostsCollection).doc(postId);
      final updatedReactions = await _firestore
          .runTransaction<Map<String, List<String>>>((transaction) async {
            final snapshot = await transaction.get(postRef);
            final data = snapshot.data();
            if (data == null) {
              throw StateError('Guild post not found.');
            }

            final reactions = _readReactions(data['reactions']);
            final users = List<String>.from(reactions[emoji] ?? const []);
            if (users.contains(uid)) {
              users.removeWhere((userId) => userId == uid);
            } else {
              users.add(uid);
            }

            if (users.isEmpty) {
              reactions.remove(emoji);
            } else {
              reactions[emoji] = users;
            }
            transaction.update(postRef, {'reactions': reactions});
            return reactions;
          });

      final index = posts.indexWhere((post) => post.id == postId);
      if (index >= 0) {
        posts[index] = posts[index].copyWith(reactions: updatedReactions);
        posts.refresh();
      }

      final reactedEmojis = updatedReactions.entries
          .where((entry) => entry.value.contains(uid))
          .map((entry) => entry.key)
          .toSet();
      if (reactedEmojis.isEmpty) {
        userReactions.remove(postId);
      } else {
        userReactions[postId] = reactedEmojis;
      }

      print('--- SUCCESS: Synchronized reaction $emoji on post $postId ---');
    } catch (e) {
      print('--- ERROR: Failed to toggle reaction on post $postId: $e ---');
    }
  }

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
    if (ratings.isEmpty ||
        ratings.values.any(
          (rating) => !rating.isFinite || rating < 1 || rating > 5,
        )) {
      return false;
    }

    try {
      final postRef = _firestore.collection(_guildPostsCollection).doc(postId);
      final updatedReviews = await _firestore
          .runTransaction<Map<String, Map<String, double>>?>((
            transaction,
          ) async {
            final snapshot = await transaction.get(postRef);
            final data = snapshot.data();
            if (data == null) {
              throw StateError('Guild post not found.');
            }

            final reviews = _readPeerReviews(data['peerReviews']);
            if (reviews.containsKey(uid)) {
              return null;
            }

            reviews[uid] = Map<String, double>.from(ratings);
            transaction.update(postRef, {'peerReviews': reviews});
            return reviews;
          });
      if (updatedReviews == null) {
        print('--- SKIP: User $uid already reviewed post $postId ---');
        return false;
      }

      final postIndex = posts.indexWhere((post) => post.id == postId);
      if (postIndex >= 0) {
        posts[postIndex] = posts[postIndex].copyWith(
          peerReviews: updatedReviews,
        );
        posts.refresh();

        userPeerReviews[postId] = <String>{uid};
      }

      _ensureProfileLoaded(uid);

      print('--- SUCCESS: Peer review submitted for post $postId ---');
      return true;
    } catch (e) {
      print('--- ERROR: Failed to submit peer review: $e ---');
      return false;
    }
  }

  Map<String, List<String>> _readReactions(dynamic value) {
    if (value is! Map) return <String, List<String>>{};

    final reactions = <String, List<String>>{};
    for (final entry in value.entries) {
      if (entry.value is! List) continue;
      reactions[entry.key.toString()] = (entry.value as List)
          .map((userId) => userId.toString().trim())
          .where((userId) => userId.isNotEmpty)
          .toSet()
          .toList();
    }
    return reactions;
  }

  Map<String, Map<String, double>> _readPeerReviews(dynamic value) {
    if (value is! Map) return <String, Map<String, double>>{};

    final reviews = <String, Map<String, double>>{};
    for (final entry in value.entries) {
      if (entry.value is! Map) continue;
      final ratings = <String, double>{};
      for (final rating in (entry.value as Map).entries) {
        final score = rating.value;
        if (score is num) {
          ratings[rating.key.toString()] = score.toDouble();
        }
      }
      reviews[entry.key.toString()] = ratings;
    }
    return reviews;
  }

  /// Fallback default axes.
  List<PeerReviewAxisModel> _defaultAxesForHobby() {
    return [
      PeerReviewAxisModel.fromIconData(
        label: 'Quality',
        icon: Icons.star_outline,
      ),
      PeerReviewAxisModel.fromIconData(
        label: 'Effort',
        icon: Icons.trending_up,
      ),
      PeerReviewAxisModel.fromIconData(
        label: 'Impact',
        icon: Icons.rocket_launch_outlined,
      ),
    ];
  }
}
