import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../controllers/guild_controller.dart';
import '../../controllers/home_controller.dart';
import '../../models/guild_post_model.dart';
import '../../models/category_model.dart';
import '../dialogs/add_guild_post_dialog.dart';
import '../../../core/constants/color_constants.dart';

class GuildPage extends StatelessWidget {
  const GuildPage({super.key});

  @override
  Widget build(BuildContext context) {
    final GuildController controller = Get.find<GuildController>();

    // Set default category once data loads
    ever(controller.categories, (_) {
      if (controller.selectedCategoryId.value == null && controller.categories.isNotEmpty) {
        controller.selectedCategoryId.value = controller.resolveDefaultCategoryId();
      }
    });

    return SafeArea(
      child: Stack(
        children: [
          // Main content — full screen
          Obx(() {
            if (controller.isLoading.value) {
              return _buildLoadingView(context);
            } else if (controller.categories.isEmpty) {
              return _buildEmptyState(context, controller, 'No categories found in Firestore.');
            }

            return Column(
              children: [
                _buildCategoryChips(context, controller),
                Expanded(child: _buildFilteredFeed(context, controller)),
              ],
            );
          }),
          // Floating Add Post button
          Positioned(
            right: 20,
            bottom: 16,
            child: Obx(() => AnimatedOpacity(
              opacity: controller.isLoading.value || controller.categories.isEmpty ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: controller.isLoading.value || controller.categories.isEmpty,
                child: FloatingActionButton(
                  onPressed: () => _showAddPostDialog(context, controller),
                  backgroundColor: AppColors.primary,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.edit_rounded, color: Colors.white),
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }

  void _showAddPostDialog(BuildContext context, GuildController controller) {
    if (controller.categories.isEmpty) return;

    // Resolve hobby and categoryId from user's current plan
    String hobby = '';
    String categoryId = '';
    try {
      final homeController = Get.find<HomeController>();
      hobby = homeController.hobby.value;
    } catch (_) {}

    // Match hobby to a category
    for (final category in controller.categories) {
      if (category.hobbies.any((h) => h.toLowerCase() == hobby.toLowerCase())) {
        categoryId = category.id;
        break;
      }
    }
    if (categoryId.isEmpty && controller.categories.isNotEmpty) {
      categoryId = controller.categories.first.id;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddGuildPostDialog(
          hobby: hobby,
          categoryId: categoryId,
        ),
      ),
    );
  }

  Widget _buildFilteredFeed(BuildContext context, GuildController controller) {
    final filteredPosts = controller.filteredPosts;
    final selectedCategoryId = controller.selectedCategoryId.value;
    final selectedCategory = controller.categories
        .where((c) => c.id == selectedCategoryId)
        .firstOrNull;

    if (selectedCategory == null) {
      return _buildEmptyState(context, controller, 'Select a category to view the guild feed.');
    }

    if (filteredPosts.isEmpty) {
      return _buildEmptyState(
        context,
        controller,
        'No posts yet in ${selectedCategory.name.toLowerCase()}.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
      physics: const BouncingScrollPhysics(),
      itemCount: filteredPosts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final post = filteredPosts[index];
        return _buildPostCard(context, controller, post, selectedCategory);
      },
    );
  }

  Widget _buildCategoryChips(BuildContext context, GuildController controller) {
    return Container(
      height: 68,
      padding: const EdgeInsets.only(top: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final category = controller.categories[index];
          final isSelected = category.id == controller.selectedCategoryId.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ChoiceChip(
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              avatar: Text(category.icon),
              label: Text(category.name),
              selected: isSelected,
              onSelected: (_) {
                controller.selectedCategoryId.value = category.id;
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
        itemCount: controller.categories.length,
      ),
    );
  }

  Widget _buildPostCard(
    BuildContext context,
    GuildController controller,
    GuildPostModel post,
    CategoryModel category,
  ) {
    final avatarLabel = post.userId.trim().isNotEmpty
        ? post.userId.trim()[0].toUpperCase()
        : '?';
    final avatarSvg = controller.userAvatars[post.userId];
    final hasAvatarSvg = avatarSvg != null && avatarSvg.trim().isNotEmpty;
    final displayName = controller.userNicknames[post.userId] ?? post.userId;
    final hasImage = post.imageUrl.isNotEmpty;

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
          // Header row
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: hasAvatarSvg
                    ? ClipOval(
                        child: SvgPicture.string(
                          avatarSvg,
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
          // Title
          Text(
            post.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 6),
          // Body
          Text(
            post.body,
            style: const TextStyle(
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          // Image
          if (hasImage) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _buildPostImage(post.imageUrl),
            ),
          ],
          const SizedBox(height: 14),
          // Metrics row: reactions + category
          Row(
            children: [
              // Reaction buttons — gamified
              ...GuildController.reactionEmojis.map((emoji) {
                final isReacted = (controller.userReactions[post.id] ?? <String>{}).contains(emoji);
                final count = post.reactions[emoji]?.length ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => controller.toggleReaction(post.id, emoji),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isReacted ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isReacted ? AppColors.primary.withOpacity(0.5) : AppColors.border.withOpacity(0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 15)),
                          const SizedBox(width: 3),
                          Text(
                            count.toString(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isReacted ? AppColors.primaryDark : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

  Widget _buildPostImage(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildLoadingView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

  Widget _buildEmptyState(BuildContext context, GuildController controller, String message) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined,
                size: 42, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _showAddPostDialog(context, controller),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Create a post'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _formatTime(DateTime? createdAt) {
    if (createdAt == null) return null;
    final difference = DateTime.now().difference(createdAt);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}