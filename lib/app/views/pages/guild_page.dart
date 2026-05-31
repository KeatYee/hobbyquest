import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../controllers/home_controller.dart';
import '../../models/category_model.dart';
import '../../models/guild_post_model.dart';
import '../../../core/constants/color_constants.dart';

class GuildPage extends StatefulWidget {
  const GuildPage({super.key});

  @override
  State<GuildPage> createState() => _GuildPageState();
}

class _GuildPageState extends State<GuildPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _guildPostsCollection = 'guild_posts';

  List<CategoryModel> _categories = [];
  List<GuildPostModel> _posts = [];
  Map<String, String> _userAvatars = {};
  Map<String, String> _userNicknames = {};
  bool _isLoading = true;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _db.collection('categories').get(),
        _db.collection(_guildPostsCollection).orderBy('createdAt', descending: true).get(),
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

      final userIds = loadedPosts
          .map((post) => post.userId.trim())
          .where((userId) => userId.isNotEmpty)
          .toSet();

      final userProfilePairs = await Future.wait(
        userIds.map((userId) async {
          final userDoc = await _db.collection('users').doc(userId).get();
          final data = userDoc.data();
          final avatarSvg = data?['avatarSvg'] as String? ?? '';
          final nickname = data?['nickname'] as String? ?? '';
          return MapEntry(userId, {'avatarSvg': avatarSvg, 'nickname': nickname});
        }),
      );

      final loadedUserAvatars = <String, String>{};
      final loadedUserNicknames = <String, String>{};
      for (final entry in userProfilePairs) {
        final map = entry.value;
        final avatar = (map['avatarSvg'] ?? '').toString();
        final nick = (map['nickname'] ?? '').toString();
        if (avatar.trim().isNotEmpty) {
          loadedUserAvatars[entry.key] = avatar;
        }
        if (nick.trim().isNotEmpty) {
          loadedUserNicknames[entry.key] = nick;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _categories = loadedCategories;
        _posts = loadedPosts;
        _userAvatars = loadedUserAvatars;
        _userNicknames = loadedUserNicknames;
        _selectedCategoryId = _resolveDefaultCategoryId(loadedCategories);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _categories = [];
        _posts = [];
        _userAvatars = {};
        _selectedCategoryId = null;
        _isLoading = false;
      });
      print('--- ERROR: Failed to load guild data: $e ---');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Text(
              'Guild',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            _buildLoadingView(context)
          else if (_categories.isEmpty)
            _buildEmptyState(context, 'No categories found in Firestore.')
          else ...[
            _buildCategoryChips(context),
            const SizedBox(height: 12),
            Expanded(child: _buildFilteredFeed(context)),
          ],
        ],
      ),
    );
  }

  Widget _buildFilteredFeed(BuildContext context) {
    final selectedCategory = _selectedCategory;
    if (selectedCategory == null) {
      return _buildEmptyState(context, 'Select a category to view the guild feed.');
    }

    final filteredPosts = _posts.where((post) {
      final matchesCategoryId = post.categoryId.trim().isNotEmpty && post.categoryId == selectedCategory.id;
      final matchesHobby = selectedCategory.hobbies.any(
        (hobby) => hobby.toLowerCase() == post.hobby.toLowerCase(),
      );
      return matchesCategoryId || matchesHobby;
    }).toList();

    if (filteredPosts.isEmpty) {
      return _buildEmptyState(
        context,
        'No posts yet in ${selectedCategory.name.toLowerCase()}.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      physics: const BouncingScrollPhysics(),
      itemCount: filteredPosts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final post = filteredPosts[index];
        return _buildPostCard(context, post, selectedCategory);
      },
    );
  }

  Widget _buildCategoryChips(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category.id == _selectedCategoryId;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ChoiceChip(
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              avatar: Text(category.icon),
              label: Text(category.name),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedCategoryId = category.id;
                });
              },
              selectedColor: AppColors.primary.withOpacity(0.22),
              backgroundColor: AppColors.surface,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w800,
                color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: _categories.length,
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, GuildPostModel post, CategoryModel category) {
    final avatarLabel = post.userId.trim().isNotEmpty ? post.userId.trim()[0].toUpperCase() : '?';
    final avatarSvg = _userAvatars[post.userId];
    final hasAvatarSvg = avatarSvg != null && avatarSvg.trim().isNotEmpty;
    final displayName = _userNicknames[post.userId] ?? post.userId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: hasAvatarSvg
                    ? ClipOval(
                        child: SvgPicture.string(
                          avatarSvg!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Text(
                        avatarLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${post.hobby} • ${_formatTime(post.createdAt) ?? post.hobby}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            post.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            post.body,
            style: const TextStyle(
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMetric(Icons.favorite_border, post.likes.toString()),
              const SizedBox(width: 14),
              _buildMetric(Icons.chat_bubble_outline, post.replies.toString()),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // chips skeleton
          SizedBox(
            height: 60,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) => Container(
                width: 110,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemCount: 4,
            ),
          ),
          const SizedBox(height: 12),
          // posts skeleton
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemBuilder: (_, __) => Container(
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.symmetric(vertical: 6),
              ),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined, size: 42, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 6),
              const Text(
                'Add posts to the guild_posts collection in Firestore to populate this feed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('How to post'),
              ),
          ],
        ),
      ),
    );
  }

  CategoryModel? get _selectedCategory {
    if (_categories.isEmpty) {
      return null;
    }

    final selectedId = _selectedCategoryId;
    if (selectedId != null && selectedId.isNotEmpty) {
      for (final category in _categories) {
        if (category.id == selectedId) {
          return category;
        }
      }
    }

    return _categories.first;
  }

  String _resolveDefaultCategoryId(List<CategoryModel> categories) {
    if (categories.isEmpty) {
      return '';
    }

    if (Get.isRegistered<HomeController>()) {
      final homeController = Get.find<HomeController>();
      final hobby = homeController.hobby.value.trim().toLowerCase();

      for (final category in categories) {
        final matches = category.hobbies.any(
          (item) => item.toLowerCase() == hobby,
        );
        if (matches) {
          return category.id;
        }
      }
    }

    return categories.first.id;
  }

  String? _formatTime(DateTime? createdAt) {
    if (createdAt == null) {
      return null;
    }

    final difference = DateTime.now().difference(createdAt);
    if (difference.inMinutes < 1) {
      return 'just now';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inDays}d ago';
  }
}
