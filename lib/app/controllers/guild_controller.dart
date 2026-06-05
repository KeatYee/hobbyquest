import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  final posts = <GuildPostModel>[].obs;
  final categories = <CategoryModel>[].obs;
  final isLoading = false.obs;
  final userAvatars = <String, String>{}.obs;
  final userNicknames = <String, String>{}.obs;
  final selectedCategoryId = Rx<String?>(null);

  @override
  void onInit() {
    super.onInit();
    seedGuildPosts().then((_) => loadAllData());
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

      // Load user profiles for avatars/nicknames
      final userIds = loadedPosts
          .map((post) => post.userId.trim())
          .where((userId) => userId.isNotEmpty)
          .toSet();

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
          if (category.hobbies.any((item) => item.toLowerCase() == hobby)) {
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
      final matchesHobby = selectedCategory.hobbies.any(
        (hobby) => hobby.toLowerCase() == post.hobby.toLowerCase(),
      );
      return matchesCategoryId || matchesHobby;
    }).toList();
  }

  /// Get all hobbies from all categories
  List<String> get allHobbies {
    return categories.expand((c) => c.hobbies).toList();
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
      final user = _auth.currentUser;
      if (user == null) {
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
        userId: user.uid,
        hobby: hobby,
        categoryId: categoryId,
        title: title,
        body: body,
        imageUrl: imageUrl,
        likes: 0,
        replies: 0,
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

  /// Like a post (increment likes count)
  Future<void> likePost(String postId) async {
    try {
      final postRef = _firestore.collection(_guildPostsCollection).doc(postId);
      await postRef.update({
        'likes': FieldValue.increment(1),
      });

      // Update local post
      final index = posts.indexWhere((p) => p.id == postId);
      if (index >= 0) {
        final updatedPost = posts[index].copyWith(likes: posts[index].likes + 1);
        posts[index] = updatedPost;
        posts.refresh();
      }

      print('--- SUCCESS: Post liked: $postId ---');
    } catch (e) {
      print('--- ERROR: Failed to like post: $e ---');
    }
  }

  /// Increment reply count for a post
  Future<void> incrementReplyCount(String postId) async {
    try {
      final postRef = _firestore.collection(_guildPostsCollection).doc(postId);
      await postRef.update({
        'replies': FieldValue.increment(1),
      });

      // Update local post
      final index = posts.indexWhere((p) => p.id == postId);
      if (index >= 0) {
        final updatedPost = posts[index].copyWith(replies: posts[index].replies + 1);
        posts[index] = updatedPost;
        posts.refresh();
      }

      print('--- SUCCESS: Reply count incremented for post: $postId ---');
    } catch (e) {
      print('--- ERROR: Failed to increment reply count: $e ---');
    }
  }

  /// Delete a post
  Future<void> deletePost(String postId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Verify user owns the post
      final postDoc = await _firestore
          .collection(_guildPostsCollection)
          .doc(postId)
          .get();

      final post = GuildPostModel.fromJson(postDoc.data()!, postDoc.id);
      if (post.userId != user.uid) {
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

  Future<void> _seedCategoriesInline() async {
    List<CategoryModel> initialData = [
      CategoryModel(
        id: '',
        name: "Creative Arts",
        description: "Express yourself visually",
        icon: "🎨",
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

    for (var category in initialData) {
      var snapshot = await _firestore
          .collection('categories')
          .where('name', isEqualTo: category.name)
          .get();
      if (snapshot.docs.isEmpty) {
        final data = Map<String, dynamic>.from(category.toJson());
        data.remove('id');
        await _firestore.collection('categories').add(data);
        print("✅ Seeded category: ${category.name}");
      } else {
        print("⚠️ Category '${category.name}' already exists");
      }
    }
  }

  Future<void> seedGuildPosts() async {
    print("--- SEEDING GUILD POSTS ---");
    final collection = _firestore.collection(_guildPostsCollection);

    // Ensure categories exist before trying to map IDs
    final categorySnapshot = await _firestore.collection('categories').get();
    if (categorySnapshot.docs.isEmpty) {
      print("--- No categories found, seeding them first ---");
      await _seedCategoriesInline();
    }

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
        'likes': 12,
        'replies': 5,
        'createdAt': DateTime.now().subtract(const Duration(days: 2)),
      },
      {
        'userId': systemUserId,
        'hobby': 'Photography',
        'categoryId': categoryMap['Creative Arts'] ?? '',
        'title': 'Golden hour photography spots in town',
        'body': 'Compiling a list of the best locations for sunset and sunrise shots. Drop your favorite spots below!',
        'likes': 24,
        'replies': 8,
        'createdAt': DateTime.now().subtract(const Duration(days: 3)),
      },
      {
        'userId': systemUserId,
        'hobby': 'Guitar',
        'categoryId': categoryMap['Music & Performing'] ?? '',
        'title': 'Learning my first chord progression',
        'body': 'Just mastered G-C-D progression! Any song recommendations that use these chords so I can practice?',
        'likes': 8,
        'replies': 3,
        'createdAt': DateTime.now().subtract(const Duration(days: 5)),
      },
      {
        'userId': systemUserId,
        'hobby': 'Yoga',
        'categoryId': categoryMap['Lifestyle & Wellness'] ?? '',
        'title': '30-day yoga challenge - who is in?',
        'body': 'Starting a 30-day yoga challenge starting next Monday. We will do 15 minutes minimum each day. Comment if you want to join!',
        'likes': 35,
        'replies': 15,
        'createdAt': DateTime.now().subtract(const Duration(days: 1)),
      },
      {
        'userId': systemUserId,
        'hobby': 'Coding',
        'categoryId': categoryMap['Skill & Strategy'] ?? '',
        'title': 'Best resources for learning Flutter',
        'body': 'I am diving into Flutter development and looking for the best courses, YouTube channels, and books. What has worked for you?',
        'likes': 18,
        'replies': 7,
        'createdAt': DateTime.now().subtract(const Duration(hours: 12)),
      },
      {
        'userId': systemUserId,
        'hobby': 'Cooking',
        'categoryId': categoryMap['Lifestyle & Wellness'] ?? '',
        'title': 'Share your favorite quick weeknight dinner',
        'body': 'Need some inspiration for quick dinners under 30 minutes. Please share your go-to recipes!',
        'likes': 42,
        'replies': 20,
        'createdAt': DateTime.now().subtract(const Duration(days: 4)),
      },
      {
        'userId': systemUserId,
        'hobby': 'Chess',
        'categoryId': categoryMap['Skill & Strategy'] ?? '',
        'title': 'Chess tactics puzzle of the day',
        'body': 'White to move and win material in 3 moves. I will post the solution tomorrow!',
        'likes': 15,
        'replies': 10,
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
}
